import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'logic/auth_provider.dart';
import 'logic/deck_provider.dart';
import 'logic/reading_provider.dart';
import 'logic/settings_provider.dart';
import 'core/translation_service.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'data/datasources/cloud_sync_service.dart';
import 'data/datasources/database_helper.dart';
import 'data/datasources/tarotdesk_api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Đăng ký observer để nút Forward (didPushRoute) hoạt động.
  WidgetsBinding.instance.addObserver(_routeObserver);
  // Khởi tạo DB (bao gồm cả web init bên trong DatabaseHelper)
  await DatabaseHelper.instance.database;
  runApp(const TarotDeskApp());
}

/// Key điều hướng của app — để ESC quay lại được mà không cần
/// BuildContext, và để nút Forward xử lý lại route vừa pop.
final GlobalKey<NavigatorState> _navigatorKey =
    GlobalKey<NavigatorState>();

/// Theo dõi route trên cùng + các route vừa bị pop (để Forward
/// đẩy lại được).
///
/// - ESC: nếu route trên cùng là hộp thoại / bottom-sheet
///   (PopupRoute) thì bỏ qua — hộp thoại tự đóng bằng ESC có sẵn;
///   nếu không thì ESC pop màn hình hiện tại.
/// - Forward (chuột gaming / trình duyệt): trình duyệt chỉ gửi URL
///   (didPushRoute), app không có bảng route theo tên nên không tự
///   dựng lại được route — observer này ghi nhớ route vừa pop
///   (kèm builder + settings để dựng lại y hệt) và đẩy lại khi
///   didPushRoute gọi đúng URL của nó. Đẩy route mới bằng tay thì
///   xoá hết "forward" đã nhớ, giống hành vi của trình duyệt.
class _RouteStackObserver extends NavigatorObserver
    with WidgetsBindingObserver {
  final List<Route<dynamic>> _stack = <Route<dynamic>>[];

  /// Các route trang vừa bị pop (mới nhất ở cuối), chờ Forward đẩy lại.
  final List<MaterialPageRoute<dynamic>> _poppedPages =
      <MaterialPageRoute<dynamic>>[];

  /// Đang đẩy lại route bằng Forward — lúc này didPush không xoá
  /// _poppedPages (người dùng còn có thể Forward tiếp).
  bool _isForwardPush = false;

  bool get topIsPopup => _stack.isNotEmpty && _stack.last is PopupRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(route);
    // Route trang mới (không phải hộp thoại) thì xoá "forward" đã nhớ.
    if (!_isForwardPush && route is! PopupRoute) _poppedPages.clear();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    // Chỉ nhớ route trang (MaterialPageRoute) để Forward dựng lại.
    if (route is MaterialPageRoute<dynamic>) _poppedPages.add(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _stack.remove(oldRoute);
    if (newRoute != null) _stack.add(newRoute);
  }

  @override
  Future<bool> didPushRoute(String route) async {
    // Chỉ xử lý khi URL khớp đúng route trang vừa pop mới nhất.
    if (_poppedPages.isEmpty) return false;
    final last = _poppedPages.last;
    if (last.settings.name != route) return false;
    _poppedPages.removeLast();
    final nav = _navigatorKey.currentState;
    if (nav == null) return false;
    _isForwardPush = true;
    nav.push(
      MaterialPageRoute<dynamic>(
        builder: last.builder,
        settings: last.settings,
      ),
    );
    _isForwardPush = false;
    return true;
  }
}

final _RouteStackObserver _routeObserver = _RouteStackObserver();

class TarotDeskApp extends StatelessWidget {
  const TarotDeskApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Settings first: AuthProvider's create reads it (via the
        // create context) to wire the automatic login/reload sync
        // with the active language for the sync's translation
        // warm-up.
        ChangeNotifierProvider(create: (_) => SettingsProvider()..initSettings()),
        ChangeNotifierProvider(create: (context) {
          final settings = context.read<SettingsProvider>();
          final auth = AuthProvider();
          // AUTOMATIC SYNC (no manual button): after a successful
          // Google login AND after a saved session is validated on
          // app start (page reload), sync the cloud data in the
          // background via the two-way login policy
          // (CloudSyncService.syncAfterLogin — download when the
          // cloud has data this device lacks, upload when this
          // device has user data the cloud lacks, never overwrite
          // when both sides have data). Best-effort: a failure
          // never breaks the login or the Home screen; the next
          // login / reload retries. Guests never trigger it
          // (AuthProvider only fires the hook on loggedIn).
          auth.onLoggedIn = () async {
            try {
              await CloudSyncService(
                auth,
                targetLanguageCode: () => settings.language.code,
              ).syncAfterLogin();
            } catch (_) {
              // Best-effort: a failed auto-sync never breaks login.
            }
          };
          unawaited(auth.restoreSession());
          return auth;
        }),
        ChangeNotifierProvider(create: (_) => DeckProvider()),
        ChangeNotifierProvider(create: (_) => ReadingProvider()),
        ProxyProvider2<AuthProvider, SettingsProvider, TranslationService>(
          update: (_, auth, settings, previous) => previous ?? TranslationService(
            TarotdeskApiService(),
            sessionToken: () => auth.sessionToken,
            targetLanguageCode: () => settings.language.code,
            // WIRING (V2 display path): the signed-in user's Google
            // `sub`, or null for guests. The service needs it to
            // derive a personal deck_key for preloading a deck's
            // stored translations ([preloadLocalDeck]). It is a
            // closure, so it tracks logins/logouts live.
            userSub: () => auth.user?.sub,
          ),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          final themeData = settings.currentThemeData;

          // ESC thoát từng lớp giao diện: hộp thoại / bottom-sheet
          // đang mở thì để nó tự đóng bằng ESC có sẵn (không pop
          // thêm màn hình bên dưới); còn không thì ESC quay lại màn
          // hình trước. Nút Back/Forward của chuột gaming = Back/
          // Forward của trình duyệt — chạy được vì mỗi màn hình có
          // tên route riêng (RouteSettings ở các Navigator.push)
          // và _RouteStackObserver dựng lại route khi Forward.
          return Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                if (_routeObserver.topIsPopup) {
                  return KeyEventResult.ignored;
                }
                final nav = _navigatorKey.currentState;
                if (nav != null && nav.canPop()) {
                  nav.pop();
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: MaterialApp(
              navigatorKey: _navigatorKey,
              navigatorObservers: [_routeObserver],
              title: 'TarotDesk - Không Gian Giải Nghĩa Bài Tarot',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                brightness: Brightness.dark,
                scaffoldBackgroundColor: themeData.backgroundColor,
                primaryColor: themeData.primaryColor,
                colorScheme: ColorScheme.dark(
                  primary: themeData.primaryColor,
                  secondary: themeData.accentColor,
                  surface: themeData.cardBackgroundColor,
                ),
                fontFamily: 'Roboto',
              ),
              home: const _AuthGate(),
            ),
          );
        },
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    switch (auth.state) {
      case AuthState.loading:
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                // While the app exchanges the ?code= after redirecting
                // back from Google, say so under the spinner.
                if (auth.isCompletingOAuthCallback) ...[
                  const SizedBox(height: 16),
                  Text(
                    context.read<SettingsProvider>().tr('auth.completingLogin'),
                  ),
                ],
              ],
            ),
          ),
        );
      case AuthState.loggedOut:
        return const LoginScreen();
      case AuthState.loggedIn:
      case AuthState.guest:
        return const HomeScreen();
    }
  }
}
