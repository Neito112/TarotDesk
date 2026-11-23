import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'logic/auth_provider.dart';
import 'logic/deck_provider.dart';
import 'logic/reading_provider.dart';
import 'logic/settings_provider.dart';
import 'core/translation_service.dart';
import 'data/models/tarot_card.dart';
import 'data/models/tarot_deck.dart';
import 'data/models/tarot_reading.dart';
import 'presentation/screens/about_screen.dart';
import 'presentation/screens/add_deck_screen.dart';
import 'presentation/screens/admin_screen.dart';
import 'presentation/screens/deck_detail_screen.dart';
import 'presentation/screens/edit_card_screen.dart';
import 'presentation/screens/history_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/new_reading_screen.dart';
import 'presentation/screens/reading_detail_screen.dart';
import 'presentation/screens/select_deck_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'data/datasources/cloud_sync_service.dart';
import 'data/datasources/database_helper.dart';
import 'data/datasources/tarotdesk_api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Khởi tạo DB (bao gồm cả web init bên trong DatabaseHelper)
  await DatabaseHelper.instance.database;
  runApp(const TarotDeskApp());
}

/// Key điều hướng của app — để ESC quay lại được mà không cần
/// BuildContext.
final GlobalKey<NavigatorState> _navigatorKey =
    GlobalKey<NavigatorState>();

/// Theo dõi route trên cùng — để ESC biết có hộp thoại /
/// bottom-sheet đang mở hay không.
///
/// (Bản §17 từng ghi nhớ route vừa pop để Forward đẩy lại, nhưng
/// Forward vẫn không chạy: Navigator 1.0 + RouteSettings(name)
/// không dựng lại được trang từ tên. §18 chuyển sang
/// onGenerateRoute — ID nằm trong URL nên Forward, tải lại trang
/// và deep link đều dựng lại được trang. Observer này chỉ còn giữ
/// stack để ESC không pop màn hình khi hộp thoại đang mở.)
class _RouteStackObserver extends NavigatorObserver {
  final List<Route<dynamic>> _stack = <Route<dynamic>>[];

  bool get topIsPopup => _stack.isNotEmpty && _stack.last is PopupRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
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
          // URL riêng (onGenerateRoute dựng lại trang từ ID trong
          // URL khi Forward / tải lại / deep link).
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
              onGenerateRoute: _onGenerateRoute,
              onUnknownRoute: _onUnknownRoute,
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

/// Bảng route theo tên — để nút Forward (và tải lại trang /
/// deep link) dựng lại được đúng màn hình từ URL.
///
/// Navigator 1.0 + RouteSettings(name) KHÔNG đủ cho Forward: khi
/// bấm Forward, hệ thống chỉ gửi lại tên route (didPushRoute) mà
/// app không có cách nào dựng lại trang từ tên đó (trang cần cả
/// object deck/reading/card). Vì vậy mọi màn hình có dữ liệu đều
/// mã hoá ID vào URL, và onGenerateRoute dựng lại trang bằng cách
/// nạp dữ liệu theo ID đó (qua các _...Route bọc ngoài, hiện vòng
/// xoay trong lúc nạp). Nhờ vậy Back, Forward và tải lại trang đều
/// khôi phục đúng màn hình.
Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
  final name = settings.name ?? '/';
  // Tách đường dẫn, bỏ các đoạn rỗng (dấu / đầu/cuối).
  final parts = name.split('/').where((s) => s.isNotEmpty).toList();
  Widget? page;
  if (parts.isEmpty) {
    page = const _AuthGate();
  } else if (parts.length == 1 && parts[0] == 'admin') {
    page = const AdminScreen();
  } else if (parts.length == 1 && parts[0] == 'settings') {
    page = const SettingsScreen();
  } else if (parts.length == 1 && parts[0] == 'library') {
    page = const SelectDeckScreen();
  } else if (parts.length == 1 && parts[0] == 'history') {
    page = const HistoryScreen();
  } else if (parts.length == 2 &&
      parts[0] == 'reading' &&
      parts[1] == 'new') {
    page = const NewReadingScreen();
  } else if (parts.length == 2 &&
      parts[0] == 'settings' &&
      parts[1] == 'about') {
    page = const AboutScreen();
  } else if (parts.length == 2 &&
      parts[0] == 'library' &&
      parts[1] == 'add') {
    page = const AddDeckScreen();
  } else if (parts.length == 3 &&
      parts[0] == 'deck' &&
      parts[1] == 'detail') {
    final deckId = int.tryParse(parts[2]);
    if (deckId != null) {
      page = _DeckDetailRoute(deckId: deckId, readOnly: false);
    }
  } else if (parts.length == 4 &&
      parts[0] == 'deck' &&
      parts[1] == 'detail' &&
      parts[3] == 'view') {
    final deckId = int.tryParse(parts[2]);
    if (deckId != null) {
      page = _DeckDetailRoute(deckId: deckId, readOnly: true);
    }
  } else if (parts.length == 3 &&
      parts[0] == 'deck' &&
      parts[1] == 'edit-card') {
    final deckId = int.tryParse(parts[2]);
    if (deckId != null) {
      page = EditCardScreen(deckId: deckId);
    }
  } else if (parts.length == 4 &&
      parts[0] == 'deck' &&
      parts[1] == 'edit-card') {
    final deckId = int.tryParse(parts[2]);
    final cardId = int.tryParse(parts[3]);
    if (deckId != null && cardId != null) {
      page = _EditCardRoute(deckId: deckId, cardId: cardId);
    }
  } else if (parts.length == 3 &&
      parts[0] == 'history' &&
      parts[1] == 'detail') {
    final readingId = int.tryParse(parts[2]);
    if (readingId != null) {
      page = _ReadingDetailRoute(readingId: readingId);
    }
  }
  if (page == null) return null;
  return MaterialPageRoute<dynamic>(
    settings: settings,
    builder: (_) => page!,
  );
}

/// URL lạ / không dựng được trang: về màn gốc (đăng nhập / trang
/// chính theo trạng thái) thay vì màn trắng.
Route<dynamic> _onUnknownRoute(RouteSettings settings) {
  return MaterialPageRoute<dynamic>(
    settings: settings,
    builder: (_) => const _AuthGate(),
  );
}

/// Màn chờ / không tìm thấy cho các route nạp theo ID: vòng xoay
/// trong lúc nạp; không tìm thấy thì thông báo + nút quay lại.
class _RouteLoading extends StatelessWidget {
  final bool notFound;
  final String message;

  const _RouteLoading({required this.notFound, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: notFound
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Quay lại'),
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}

/// Bọc DeckDetailScreen: nạp bộ bài theo ID từ DB rồi mới vẽ màn
/// chi tiết (để Forward / tải lại / deep link dựng lại được trang
/// từ URL).
class _DeckDetailRoute extends StatefulWidget {
  final int deckId;
  final bool readOnly;

  const _DeckDetailRoute({required this.deckId, required this.readOnly});

  @override
  State<_DeckDetailRoute> createState() => _DeckDetailRouteState();
}

class _DeckDetailRouteState extends State<_DeckDetailRoute> {
  TarotDeckModel? _deck;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final decks = await DatabaseHelper.instance.getDecks();
    final found = decks.where((d) => d.id == widget.deckId).toList();
    if (!mounted) return;
    setState(() {
      if (found.isEmpty) {
        _notFound = true;
      } else {
        _deck = found.first;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final deck = _deck;
    if (deck != null) {
      return DeckDetailScreen(deck: deck, readOnly: widget.readOnly);
    }
    return _RouteLoading(
      notFound: _notFound,
      message: 'Không tìm thấy bộ bài này.',
    );
  }
}

/// Bọc ReadingDetailScreen: nạp lượt trải bài theo ID từ DB.
class _ReadingDetailRoute extends StatefulWidget {
  final int readingId;

  const _ReadingDetailRoute({required this.readingId});

  @override
  State<_ReadingDetailRoute> createState() => _ReadingDetailRouteState();
}

class _ReadingDetailRouteState extends State<_ReadingDetailRoute> {
  TarotReadingModel? _reading;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final readings = await DatabaseHelper.instance.getReadings();
    final found =
        readings.where((r) => r.id == widget.readingId).toList();
    if (!mounted) return;
    setState(() {
      if (found.isEmpty) {
        _notFound = true;
      } else {
        _reading = found.first;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final reading = _reading;
    if (reading != null) {
      return ReadingDetailScreen(reading: reading);
    }
    return _RouteLoading(
      notFound: _notFound,
      message: 'Không tìm thấy lượt trải bài này.',
    );
  }
}

/// Bọc EditCardScreen (chế độ sửa lá): nạp lá bài theo ID từ DB.
class _EditCardRoute extends StatefulWidget {
  final int deckId;
  final int cardId;

  const _EditCardRoute({required this.deckId, required this.cardId});

  @override
  State<_EditCardRoute> createState() => _EditCardRouteState();
}

class _EditCardRouteState extends State<_EditCardRoute> {
  TarotCardModel? _card;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cards =
        await DatabaseHelper.instance.getCardsByDeckId(widget.deckId);
    final found = cards.where((c) => c.id == widget.cardId).toList();
    if (!mounted) return;
    setState(() {
      if (found.isEmpty) {
        _notFound = true;
      } else {
        _card = found.first;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    if (card != null) {
      return EditCardScreen(card: card, deckId: widget.deckId);
    }
    return _RouteLoading(
      notFound: _notFound,
      message: 'Không tìm thấy lá bài này.',
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
