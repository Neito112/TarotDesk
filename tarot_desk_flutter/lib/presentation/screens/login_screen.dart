import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../logic/auth_provider.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';

/// Login screen (root while logged out).
///
/// Google Web Application Flow: the user taps the login button and
/// the app redirects the same tab to Google's authorize page. After
/// the user authorizes, Google redirects back to the app with a
/// `?code=` and [AuthProvider.restoreSession] exchanges it for a
/// Worker session token on start; the app gate then swaps to
/// HomeScreen once [AuthProvider] reports loggedIn. This screen never
/// navigates itself and never shows a blank screen: any failure lands
/// on a readable error + retry button.
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// True between tapping the login button and the browser leaving
  /// for Google. The redirect normally navigates away, so this only
  /// ever turns back off on the failure path.
  bool _isRedirecting = false;

  Future<void> _startLogin() async {
    if (_isRedirecting) return;
    final auth = context.read<AuthProvider>();
    setState(() {
      _isRedirecting = true;
    });
    // startGoogleLogin never throws: it saves a fresh state and then
    // redirects the tab to Google's authorize page.
    await auth.startGoogleLogin();
    if (!mounted) return;
    // Still here: the redirect did not happen (failure path).
    setState(() {
      _isRedirecting = false;
    });
  }

  /// Headline for the last OAuth failure, mapped from its code.
  String _errorHeadline(String code, SettingsProvider settings) {
    switch (code) {
      case 'state_mismatch':
        return settings.tr('auth.stateMismatch');
      case 'exchange_failed':
        return settings.tr('auth.loginFailed');
      case 'network':
        return settings.tr('auth.errorNetwork');
      default:
        return settings.tr('auth.errorGeneric');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();
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
                if (auth.lastAuthErrorCode != null) ...[
                  _buildErrorPanel(context, theme, settings, auth),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isRedirecting ? null : _startLogin,
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
                if (_isRedirecting)
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
                          settings.tr('auth.redirecting'),
                          style: TextStyle(
                            color: theme.secondaryTextColor,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    settings.tr('auth.webLoginNote'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () =>
                      context.read<AuthProvider>().continueAsGuest(),
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
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Error panel for a failed OAuth callback: headline mapped from
  /// the error code, the English detail (when present), and a retry
  /// button that starts the Google login again.
  Widget _buildErrorPanel(
    BuildContext context,
    dynamic theme,
    SettingsProvider settings,
    AuthProvider auth,
  ) {
    final errorCode = auth.lastAuthErrorCode;
    final errorDetail = auth.lastAuthErrorDetail;
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
                _errorHeadline(errorCode ?? '', settings),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              if (errorDetail != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorDetail,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isRedirecting ? null : _startLogin,
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
