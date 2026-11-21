import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../data/datasources/gist_sync_service.dart';
import '../../data/datasources/github_service.dart';
import '../../logic/auth_provider.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';

/// Login screen (root while logged out).
///
/// GitHub Device Flow: the user taps the login button, gets a short
/// user code + verification link, authorizes in a browser, and the
/// app gate swaps to HomeScreen once [AuthProvider] reports loggedIn.
/// This screen never navigates itself and never shows a blank screen:
/// any failure lands on a readable error + retry button.
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _LoginPhase { idle, starting, waiting, error }

class _LoginScreenState extends State<LoginScreen> {
  _LoginPhase _phase = _LoginPhase.idle;
  DeviceCodeResponse? _code;
  String? _errorMessage;
  // Guards a stale background poll: cancel / restart bumps the id and
  // late completions are ignored.
  int _flowId = 0;

  /// Maps a [GithubException] to a user-facing message. Known codes
  /// use translated strings; anything else shows the message as-is
  /// (GitHub's English detail is acceptable as error detail).
  String _errorText(GithubException e, SettingsProvider settings) {
    switch (e.code) {
      case 'expired_token':
        return settings.tr('auth.errorExpired');
      case 'access_denied':
        return settings.tr('auth.errorDenied');
      case 'network':
        return settings.tr('auth.errorNetwork');
      default:
        return e.message;
    }
  }

  Future<void> _startLogin() async {
    final auth = context.read<AuthProvider>();
    final flowId = ++_flowId;
    setState(() {
      _phase = _LoginPhase.starting;
      _errorMessage = null;
      _code = null;
    });
    DeviceCodeResponse code;
    try {
      code = await auth.startDeviceFlow();
    } on GithubException catch (e) {
      if (!mounted || flowId != _flowId) return;
      final settings = context.read<SettingsProvider>();
      setState(() {
        _phase = _LoginPhase.error;
        _errorMessage = _errorText(e, settings);
      });
      return;
    } catch (_) {
      if (!mounted || flowId != _flowId) return;
      final settings = context.read<SettingsProvider>();
      setState(() {
        _phase = _LoginPhase.error;
        _errorMessage = settings.tr('auth.errorGeneric');
      });
      return;
    }
    if (!mounted || flowId != _flowId) return;
    setState(() {
      _code = code;
      _phase = _LoginPhase.waiting;
    });
    // Poll in the background without blocking the UI.
    _waitForAuthorization(auth, code, flowId);
  }

  Future<void> _waitForAuthorization(
    AuthProvider auth,
    DeviceCodeResponse code,
    int flowId,
  ) async {
    bool ok;
    try {
      ok = await auth.waitForAuthorization(code);
    } on GithubException catch (e) {
      if (!mounted || flowId != _flowId) return;
      final settings = context.read<SettingsProvider>();
      setState(() {
        _phase = _LoginPhase.error;
        _errorMessage = _errorText(e, settings);
      });
      return;
    } catch (_) {
      if (!mounted || flowId != _flowId) return;
      final settings = context.read<SettingsProvider>();
      setState(() {
        _phase = _LoginPhase.error;
        _errorMessage = settings.tr('auth.errorGeneric');
      });
      return;
    }
    if (!mounted || flowId != _flowId) return;
    if (!ok) {
      final settings = context.read<SettingsProvider>();
      setState(() {
        _phase = _LoginPhase.error;
        _errorMessage = settings.tr('auth.errorGeneric');
      });
      return;
    }
    // Authorized. Post-login sync runs fire-and-forget: wait for it
    // briefly, but never block the gate swap and never surface its
    // errors — sync failures must not lock the user out.
    try {
      await GistSyncService(auth)
          .syncOnLogin()
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Silently ignored by design (see above).
    }
    // Nothing else to do: the app gate watches AuthProvider and swaps
    // to HomeScreen on its own.
  }

  void _cancelWaiting() {
    // Bumps the flow id so the still-running poll is ignored when it
    // finishes; the UI goes straight back to the initial state.
    _flowId++;
    setState(() {
      _phase = _LoginPhase.idle;
      _code = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentThemeData;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ResponsiveCenter(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                Text(
                  'TarotDesk',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  settings.tr('auth.intro'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  settings.tr('auth.offlineNote'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),
                _buildPhaseBody(context, theme, settings),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseBody(
    BuildContext context,
    dynamic theme,
    SettingsProvider settings,
  ) {
    switch (_phase) {
      case _LoginPhase.idle:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _startLogin,
                icon: const Icon(Icons.login, size: 22),
                label: Text(
                  settings.tr('auth.loginButton'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: theme.backgroundColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.read<AuthProvider>().continueAsGuest(),
              child: Text(
                settings.tr('auth.guestButton'),
                style: TextStyle(color: theme.primaryColor, fontSize: 14),
              ),
            ),
            Text(
              settings.tr('auth.guestNote'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        );
      case _LoginPhase.starting:
        return Center(
          child: CircularProgressIndicator(color: theme.primaryColor),
        );
      case _LoginPhase.waiting:
        return _buildDeviceFlowPanel(context, theme, settings);
      case _LoginPhase.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassPanel(
              backgroundColor: theme.cardBackgroundColor,
              borderColor: theme.glassBorderColor,
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade300,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage ?? settings.tr('auth.errorGeneric'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _startLogin,
                icon: const Icon(Icons.refresh, size: 20),
                label: Text(
                  settings.tr('auth.retry'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: theme.backgroundColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        );
    }
  }

  /// Device Flow panel: big copyable user code, copyable verification
  /// link (there is no launcher dependency — the user copies the link),
  /// instructions, and a spinner while authorization is pending.
  Widget _buildDeviceFlowPanel(
    BuildContext context,
    dynamic theme,
    SettingsProvider settings,
  ) {
    final code = _code;
    if (code == null) {
      return Center(
        child: CircularProgressIndicator(color: theme.primaryColor),
      );
    }
    return GlassPanel(
      backgroundColor: theme.cardBackgroundColor,
      borderColor: theme.glassBorderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            settings.tr('auth.codeLabel'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            code.userCode,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.primaryColor,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            settings.tr('auth.linkLabel'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            code.verificationUri,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            settings.tr('auth.instruction'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: theme.primaryColor,
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  settings.tr('auth.waiting'),
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _cancelWaiting,
            child: Text(
              settings.tr('auth.cancel'),
              style: TextStyle(color: theme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}
