import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../data/datasources/tarotdesk_api_service.dart';
import '../../logic/auth_provider.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';

/// Admin / server management screen.
///
/// Only reachable when the logged-in Google account is the admin
/// ([AuthProvider.isAdmin]); the caller gates navigation, but a
/// non-admin who lands here anyway only sees a "not authorized"
/// message, never the management UI.
///
/// Two lists, both served by [TarotdeskApiService] against the Worker:
/// 1. Pending deck submissions (approve / reject). Approving moves the
///    submission into the shared library directly on the Worker —
///    there is no separate move step.
/// 2. The shared library itself, with delete.
class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final TarotdeskApiService _api = TarotdeskApiService();

  Future<List<Map<String, dynamic>>>? _pendingFuture;
  Future<List<Map<String, dynamic>>>? _sharedFuture;

  // Per-item busy state so one running action never disables the
  // whole screen. Keyed by submission / shared-deck id.
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  String _sessionToken() {
    final token = context.read<AuthProvider>().sessionToken;
    if (token == null || token.isEmpty) {
      throw TarotdeskApiException('unauthorized', 'Not logged in');
    }
    return token;
  }

  void _loadAll() {
    setState(() {
      // A null session token (guest) never reaches this screen as an
      // admin, but the calls below throw a readable unauthorized
      // error instead of crashing if it ever happens.
      _pendingFuture = _loadPending();
      _sharedFuture = _loadShared();
    });
  }

  Future<List<Map<String, dynamic>>> _loadPending() async {
    return _api.listSubmissions(_sessionToken());
  }

  Future<List<Map<String, dynamic>>> _loadShared() async {
    return _api.listSharedDecksAdmin(_sessionToken());
  }

  void _refreshAll() => _loadAll();

  /// Submission / shared-deck id as a string (the Worker ids may be
  /// strings or numbers; both are accepted here).
  String _entryId(Map<String, dynamic> entry) {
    final id = entry['id'];
    return id == null ? '' : id.toString();
  }

  /// Display title of a submission: the submitted deck's name, then
  /// the entry's own name/title, then the id.
  String _entryTitle(Map<String, dynamic> entry) {
    final deck = entry['deck'];
    if (deck is Map) {
      final name = deck['name'];
      if (name is String && name.isNotEmpty) return name;
    }
    for (final key in <String>['name', 'title', 'deckName']) {
      final value = entry[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return _entryId(entry);
  }

  /// Who submitted it: author name, then email, then submitter id.
  String _entryAuthor(Map<String, dynamic> entry) {
    for (final key in <String>['author', 'authorName', 'email', 'submittedBy']) {
      final value = entry[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return '';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _approve(Map<String, dynamic> item) async {
    final id = _entryId(item);
    if (id.isEmpty || _busyIds.contains(id)) return;
    final settings = context.read<SettingsProvider>();
    setState(() => _busyIds.add(id));
    try {
      await _api.approveSubmission(_sessionToken(), id);
      if (!mounted) return;
      _refreshAll();
      _showMessage(settings.tr('admin.approved'));
    } on TarotdeskApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Future<void> _reject(Map<String, dynamic> item) async {
    final settings = context.read<SettingsProvider>();
    final theme = settings.currentThemeData;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.94),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.primaryColor.withOpacity(0.5),
            width: 1,
          ),
        ),
        title: Text(
          settings.tr('admin.rejectTitle'),
          style: TextStyle(color: theme.primaryColor),
        ),
        content: Text(
          settings
              .tr('admin.rejectConfirm')
              .replaceAll('{title}', _entryTitle(item)),
          style: const TextStyle(color: Colors.white, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(settings.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              settings.tr('admin.reject'),
              style: TextStyle(color: Colors.red.shade300),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final id = _entryId(item);
    if (id.isEmpty || _busyIds.contains(id)) return;
    setState(() => _busyIds.add(id));
    try {
      await _api.rejectSubmission(_sessionToken(), id);
      if (!mounted) return;
      _refreshAll();
      _showMessage(settings.tr('admin.rejected'));
    } on TarotdeskApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Future<void> _deleteShared(Map<String, dynamic> info) async {
    final settings = context.read<SettingsProvider>();
    final theme = settings.currentThemeData;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.94),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.primaryColor.withOpacity(0.5),
            width: 1,
          ),
        ),
        title: Text(
          settings.tr('admin.deleteTitle'),
          style: TextStyle(color: theme.primaryColor),
        ),
        content: Text(
          settings
              .tr('admin.deleteConfirm')
              .replaceAll('{name}', _entryTitle(info)),
          style: const TextStyle(color: Colors.white, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(settings.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              settings.tr('common.delete'),
              style: TextStyle(color: Colors.red.shade300),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final id = _entryId(info);
    if (id.isEmpty || _busyIds.contains(id)) return;
    setState(() => _busyIds.add(id));
    try {
      await _api.deleteSharedDeck(_sessionToken(), id);
      if (!mounted) return;
      _refreshAll();
      _showMessage(settings.tr('admin.deleted'));
    } on TarotdeskApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentThemeData;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: Text(settings.tr('admin.title')),
        backgroundColor: Colors.transparent,
        foregroundColor: theme.primaryColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: ResponsiveCenter(
            child: auth.isAdmin
                ? _buildAdminBody(context, theme, settings)
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Text(
                        settings.tr('admin.notAuthorized'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminBody(
    BuildContext context,
    dynamic theme,
    SettingsProvider settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPendingSection(context, theme, settings),
        const SizedBox(height: 16),
        _buildSharedSection(context, theme, settings),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Section header: title + refresh button.
  Widget _sectionHeader(
    dynamic theme,
    SettingsProvider settings,
    String title,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: theme.primaryColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.refresh, color: theme.primaryColor, size: 22),
          tooltip: settings.tr('admin.refresh'),
          onPressed: _refreshAll,
        ),
      ],
    );
  }

  Widget _sectionPanel(
    dynamic theme,
    SettingsProvider settings,
    String title,
    Widget child,
  ) {
    return GlassPanel(
      backgroundColor: theme.cardBackgroundColor,
      borderColor: theme.glassBorderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(theme, settings, title),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _loadingIndicator(dynamic theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: CircularProgressIndicator(color: theme.primaryColor),
      ),
    );
  }

  Widget _emptyText(dynamic theme, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: TextStyle(
          color: theme.secondaryTextColor,
          fontSize: 14,
          height: 1.6,
        ),
      ),
    );
  }

  /// Error box with the translated label, the raw error detail, and
  /// a retry button — the screen never goes blank on API failure.
  Widget _errorBox(
    dynamic theme,
    SettingsProvider settings,
    Object error,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          settings.tr('admin.loadError'),
          style: TextStyle(
            color: Colors.red.shade300,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          error.toString(),
          style: TextStyle(
            color: theme.secondaryTextColor,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(settings.tr('admin.retry')),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.primaryColor,
              side: BorderSide(color: theme.primaryColor),
            ),
          ),
        ),
      ],
    );
  }

  // --- Section 1: pending deck submissions ------------------------

  Widget _buildPendingSection(
    BuildContext context,
    dynamic theme,
    SettingsProvider settings,
  ) {
    return _sectionPanel(
      theme,
      settings,
      settings.tr('server.pendingTitle'),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _pendingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _loadingIndicator(theme);
          }
          if (snapshot.hasError) {
            return _errorBox(theme, settings, snapshot.error!);
          }
          final items = snapshot.data ?? const <Map<String, dynamic>>[];
          if (items.isEmpty) {
            return _emptyText(theme, settings.tr('server.noPending'));
          }
          return Column(
            children: [
              for (final item in items) _buildPendingRow(item, theme, settings),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPendingRow(
    Map<String, dynamic> item,
    dynamic theme,
    SettingsProvider settings,
  ) {
    final id = _entryId(item);
    final busy = _busyIds.contains(id);
    final author = _entryAuthor(item);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _entryTitle(item),
            style: TextStyle(
              color: theme.textColor,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (author.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              settings.tr('admin.byAuthor').replaceAll('{author}', author),
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton(
                onPressed: (busy || id.isEmpty) ? null : () => _approve(item),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: theme.backgroundColor,
                ),
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(settings.tr('admin.approve')),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: busy ? null : () => _reject(item),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.primaryColor,
                  side: BorderSide(color: theme.primaryColor),
                ),
                child: Text(settings.tr('admin.reject')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Section 2: shared library (server/decks/) --------------------

  Widget _buildSharedSection(
    BuildContext context,
    dynamic theme,
    SettingsProvider settings,
  ) {
    return _sectionPanel(
      theme,
      settings,
      settings.tr('server.sharedTitle'),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _sharedFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _loadingIndicator(theme);
          }
          if (snapshot.hasError) {
            return _errorBox(theme, settings, snapshot.error!);
          }
          final items = snapshot.data ?? const <Map<String, dynamic>>[];
          if (items.isEmpty) {
            return _emptyText(theme, settings.tr('server.noShared'));
          }
          return Column(
            children: [
              for (final info in items) _buildSharedRow(info, theme, settings),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSharedRow(
    Map<String, dynamic> info,
    dynamic theme,
    SettingsProvider settings,
  ) {
    final busy = _busyIds.contains(_entryId(info));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _entryTitle(info),
              style: TextStyle(
                color: theme.textColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: Colors.red.shade300,
              size: 22,
            ),
            tooltip: settings.tr('common.delete'),
            onPressed: busy ? null : () => _deleteShared(info),
          ),
        ],
      ),
    );
  }
}
