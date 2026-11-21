import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../data/datasources/github_service.dart';
import '../../data/datasources/server_deck_service.dart';
import '../../logic/auth_provider.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';

/// Admin / server management screen.
///
/// Only reachable when the logged-in GitHub user is the admin; the
/// caller gates navigation, but a non-admin who lands here anyway
/// only sees a "not authorized" message, never the management UI.
///
/// Three lists, all served by [ServerDeckService]:
/// 1. Open deck-submission PRs (approve / reject).
/// 1b. Files currently sitting in server/submissions/ — each can be
///     moved into the shared library after its PR was merged.
/// 2. The shared library itself (server/decks/) with delete.
class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late final ServerDeckService _service;

  Future<List<OpenSubmission>>? _pendingFuture;
  Future<List<SharedDeckInfo>>? _submissionsFuture;
  Future<List<SharedDeckInfo>>? _sharedFuture;

  // PR numbers already approved in this session (their PR disappears
  // from the open list after refresh; the merged file then shows up
  // in the submissions file list below).
  final Set<int> _mergedNumbers = {};

  // Per-item busy state so one running action never disables the
  // whole screen.
  final Set<int> _busyPrs = {};
  final Set<String> _busyPaths = {};

  @override
  void initState() {
    super.initState();
    _service = ServerDeckService(context.read<AuthProvider>());
    _loadAll();
  }

  void _loadAll() {
    setState(() {
      _pendingFuture = _service.listOpenSubmissions();
      _submissionsFuture = _service.listSubmissions();
      _sharedFuture = _service.listSharedDecks();
    });
  }

  void _refreshAll() => _loadAll();

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _approve(OpenSubmission item) async {
    if (_busyPrs.contains(item.number)) return;
    final settings = context.read<SettingsProvider>();
    setState(() => _busyPrs.add(item.number));
    try {
      await _service.approveSubmission(item.number);
      if (!mounted) return;
      _mergedNumbers.add(item.number);
      _refreshAll();
      _showMessage(settings.tr('admin.approved'));
    } on GithubException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _busyPrs.remove(item.number));
    }
  }

  Future<void> _reject(OpenSubmission item) async {
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
              .replaceAll('{title}', item.title),
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
    if (_busyPrs.contains(item.number)) return;
    setState(() => _busyPrs.add(item.number));
    try {
      await _service.rejectSubmission(item.number);
      if (!mounted) return;
      _refreshAll();
      _showMessage(settings.tr('admin.rejected'));
    } on GithubException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _busyPrs.remove(item.number));
    }
  }

  Future<void> _moveToShared(SharedDeckInfo info) async {
    if (_busyPaths.contains(info.path)) return;
    final settings = context.read<SettingsProvider>();
    setState(() => _busyPaths.add(info.path));
    try {
      await _service.moveSubmissionToShared(info.path);
      if (!mounted) return;
      _refreshAll();
      _showMessage(settings.tr('admin.moved'));
    } on GithubException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _busyPaths.remove(info.path));
    }
  }

  Future<void> _deleteShared(SharedDeckInfo info) async {
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
              .replaceAll('{name}', info.name),
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
    if (_busyPaths.contains(info.path)) return;
    setState(() => _busyPaths.add(info.path));
    try {
      await _service.deleteSharedDeck(info.path);
      if (!mounted) return;
      _refreshAll();
      _showMessage(settings.tr('admin.deleted'));
    } on GithubException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _busyPaths.remove(info.path));
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
        _buildSubmissionsSection(context, theme, settings),
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

  // --- Section 1: open submission PRs -------------------------------

  Widget _buildPendingSection(
    BuildContext context,
    dynamic theme,
    SettingsProvider settings,
  ) {
    return _sectionPanel(
      theme,
      settings,
      settings.tr('server.pendingTitle'),
      FutureBuilder<List<OpenSubmission>>(
        future: _pendingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _loadingIndicator(theme);
          }
          if (snapshot.hasError) {
            return _errorBox(theme, settings, snapshot.error!);
          }
          final items = snapshot.data ?? const <OpenSubmission>[];
          if (items.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _emptyText(theme, settings.tr('server.noPending')),
                Text(
                  settings.tr('admin.mergedNote'),
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ],
            );
          }
          return Column(
            children: [
              for (final item in items) _buildPendingRow(item, theme, settings),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  settings.tr('admin.mergedNote'),
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPendingRow(
    OpenSubmission item,
    dynamic theme,
    SettingsProvider settings,
  ) {
    final busy = _busyPrs.contains(item.number);
    final merged = _mergedNumbers.contains(item.number);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            settings.tr('admin.byAuthor').replaceAll('{author}', item.author),
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            item.url,
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton(
                onPressed: (busy || merged) ? null : () => _approve(item),
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

  // --- Section 1b: files waiting in server/submissions/ --------------

  Widget _buildSubmissionsSection(
    BuildContext context,
    dynamic theme,
    SettingsProvider settings,
  ) {
    return _sectionPanel(
      theme,
      settings,
      settings.tr('server.submissionsTitle'),
      FutureBuilder<List<SharedDeckInfo>>(
        future: _submissionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _loadingIndicator(theme);
          }
          if (snapshot.hasError) {
            return _errorBox(theme, settings, snapshot.error!);
          }
          final items = snapshot.data ?? const <SharedDeckInfo>[];
          if (items.isEmpty) {
            return _emptyText(theme, settings.tr('server.noSubmissionFiles'));
          }
          return Column(
            children: [
              for (final info in items)
                _buildSubmissionRow(info, theme, settings),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSubmissionRow(
    SharedDeckInfo info,
    dynamic theme,
    SettingsProvider settings,
  ) {
    final busy = _busyPaths.contains(info.path);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              info.name,
              style: TextStyle(
                color: theme.textColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: busy ? null : () => _moveToShared(info),
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
                : Text(settings.tr('admin.moveToShared')),
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
      FutureBuilder<List<SharedDeckInfo>>(
        future: _sharedFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _loadingIndicator(theme);
          }
          if (snapshot.hasError) {
            return _errorBox(theme, settings, snapshot.error!);
          }
          final items = snapshot.data ?? const <SharedDeckInfo>[];
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
    SharedDeckInfo info,
    dynamic theme,
    SettingsProvider settings,
  ) {
    final busy = _busyPaths.contains(info.path);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              info.name,
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
