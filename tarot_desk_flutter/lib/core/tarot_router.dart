import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'tarot_router_api.dart';
import '../data/datasources/database_helper.dart';
import '../data/models/tarot_card.dart';
import '../data/models/tarot_deck.dart';
import '../data/models/tarot_reading.dart';
import '../logic/auth_provider.dart';
import '../logic/settings_provider.dart';
import '../presentation/screens/about_screen.dart';
import '../presentation/screens/add_deck_screen.dart';
import '../presentation/screens/admin_screen.dart';
import '../presentation/screens/deck_detail_screen.dart';
import '../presentation/screens/edit_card_screen.dart';
import '../presentation/screens/history_screen.dart';
import '../presentation/screens/home_screen.dart';
import '../presentation/screens/login_screen.dart';
import '../presentation/screens/new_reading_screen.dart';
import '../presentation/screens/reading_detail_screen.dart';
import '../presentation/screens/select_deck_screen.dart';
import '../presentation/screens/settings_screen.dart';

/// Router đầy đủ của TarotDesk (§19 — MaterialApp.router).
///
/// Vì sao phải là Router đầy đủ: Navigator 1.0 (§17 observer +
/// §18 onGenerateRoute) đều không giữ được Forward — sau khi bấm
/// Back, trình duyệt không còn mục Forward nào (Forward không đổi
/// URL lẫn màn hình). Chỉ Router (khai báo) mới đồng bộ stack
/// trang với lịch sử trình duyệt qua pushState/popstate, nên
/// Forward mới chạy.
///
/// Cách hoạt động: delegate giữ một stack đường dẫn (URL). Đẩy
/// trang = thêm đường dẫn vào stack + notifyListeners -> Router
/// cập nhật URL bằng pushState (trình duyệt ghi thêm một mục
/// lịch sử, nên Back/Forward có cái để đi). Trình duyệt Back /
/// Forward / deep link = setNewRoutePath(URL) -> dựng lại stack
/// từ URL (trang đích + các trang cha của nó). Mọi màn hình đều
/// đi qua tarotPush (tarot_router_api.dart) thay cho
/// Navigator.pushNamed.

/// Theo dõi route trên cùng — để ESC biết có hộp thoại /
/// bottom-sheet đang mở hay không (giữ nguyên từ §17).
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

/// Parser: URL (fragment sau #) <-> đường dẫn trang.
/// App dùng hash routing (#/library, #/deck/detail/1) nên đường
/// dẫn nằm trong fragment của Uri.
class TarotDeskRouteParser extends RouteInformationParser<String> {
  @override
  Future<String> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final fragment = routeInformation.uri.fragment;
    if (fragment.isEmpty) return '/';
    return fragment.startsWith('/') ? fragment : '/$fragment';
  }

  @override
  RouteInformation? restoreRouteInformation(String configuration) {
    // Chỉ fragment thay đổi (giữ nguyên path + query của trang),
    // nên trình duyệt chỉ cập nhật phần sau #.
    return RouteInformation(uri: Uri(fragment: configuration));
  }
}

/// Một mục trong stack điều hướng: đường dẫn (URL) + Completer để
/// trả kết quả khi trang được pop (như Navigator.push trả Future).
class _StackEntry {
  final String path;
  final Completer<dynamic>? completer;

  _StackEntry(this.path, [this.completer]);
}

class TarotDeskRouterDelegate extends RouterDelegate<String>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<String>
    implements TarotRouter {
  @override
  final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final _RouteStackObserver _observer = _RouteStackObserver();

  final List<_StackEntry> _stack = <_StackEntry>[
    _StackEntry('/'),
  ];

  /// Đường dẫn hiện tại (trang trên cùng) — cũng là URL trên
  /// thanh địa chỉ.
  String get currentPath => _stack.isEmpty ? '/' : _stack.last.path;

  @override
  String get currentConfiguration => currentPath;

  /// Đẩy một trang mới (theo URL) lên stack. Trả về Future hoàn
  /// thành với kết quả khi trang được pop (null nếu Back/Forward
  /// của trình duyệt pop trang mà không có kết quả).
  @override
  Future<T?> push<T>(String path) {
    final completer = Completer<T?>();
    _stack.add(_StackEntry(path, completer));
    notifyListeners();
    return completer.future;
  }

  /// Pop trang hiện tại (như Navigator.pop). Kết quả được trả về
  /// cho Future của push(). Không làm gì nếu chỉ còn màn gốc.
  @override
  void pop<T>([T? result]) {
    final nav = navigatorKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop<T>(result);
    }
  }

  @override
  Future<void> setNewRoutePath(String configuration) async {
    // Trình duyệt Back/Forward hoặc deep link: dựng lại toàn bộ
    // stack từ URL (trang đích + các trang cha của nó). Các trang
    // bị bỏ khỏi stack coi như bị pop không kết quả (để bên gọi
    // push() đang await không treo mãi). Trang còn lại giữ nguyên
    // Completer của nó.
    final newPaths = _stackForPath(configuration);
    final newSet = newPaths.toSet();
    for (final entry in _stack) {
      if (!newSet.contains(entry.path)) {
        entry.completer?.complete(null);
      }
    }
    final byPath = <String, _StackEntry>{};
    for (final entry in _stack) {
      byPath.putIfAbsent(entry.path, () => entry);
    }
    _stack
      ..clear()
      ..addAll(newPaths.map((p) => byPath[p] ?? _StackEntry(p)));
    notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    // ESC thoát từng lớp giao diện (giữ nguyên §17): hộp thoại /
    // bottom-sheet đang mở thì để nó tự đóng bằng ESC có sẵn
    // (không pop thêm màn hình bên dưới); còn không thì ESC quay
    // lại màn hình trước (pop qua Router để stack + URL đồng bộ).
    // Nút Back/Forward của chuột gaming = Back/Forward của trình
    // duyệt — chạy được vì Router đồng bộ stack với lịch sử.
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          if (_observer.topIsPopup) {
            return KeyEventResult.ignored;
          }
          if (_stack.length > 1) {
            pop();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Navigator(
        key: navigatorKey,
        pages: _stack
            .map(
              (entry) => MaterialPage<dynamic>(
                key: ValueKey<String>(entry.path),
                name: entry.path,
                child: _buildPageForPath(entry.path),
              ),
            )
            .toList(),
        observers: [_observer],
        onPopPage: (route, result) {
          if (!route.didPop(result)) return false;
          if (route is PopupRoute) {
            // Hộp thoại / bottom-sheet — không nằm trong stack trang.
            return true;
          }
          if (_stack.isNotEmpty) {
            final entry = _stack.removeLast();
            entry.completer?.complete(result);
          }
          notifyListeners();
          return true;
        },
      ),
    );
  }

  @override
  Future<bool> popRoute() {
    // Nút Back hệ thống (Android): pop trang trên cùng nếu còn.
    if (_stack.length > 1) {
      pop();
      return Future.value(true);
    }
    return Future.value(false);
  }
}

/// Dựng lại toàn bộ stack (màn gốc + các trang cha + trang đích)
/// từ một URL — dùng khi trình duyệt Back/Forward hoặc deep link.
///
/// Ví dụ: /deck/detail/1 -> [/, /library, /deck/detail/1] (vào
/// chi tiết bộ bài từ kho); /deck/detail/1/view -> [/, .../view]
/// (xem bộ bài hiện tại từ trang chính, cha là màn gốc).
List<String> _stackForPath(String path) {
  final parts = path.split('/').where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return <String>['/'];
  if (parts.length == 1 && parts[0] == 'admin') {
    return <String>['/', '/admin'];
  }
  if (parts.length == 1 && parts[0] == 'settings') {
    return <String>['/', '/settings'];
  }
  if (parts.length == 1 && parts[0] == 'library') {
    return <String>['/', '/library'];
  }
  if (parts.length == 1 && parts[0] == 'history') {
    return <String>['/', '/history'];
  }
  if (parts.length == 2 && parts[0] == 'reading' && parts[1] == 'new') {
    return <String>['/', '/reading/new'];
  }
  if (parts.length == 2 &&
      parts[0] == 'settings' &&
      parts[1] == 'about') {
    return <String>['/', '/settings', '/settings/about'];
  }
  if (parts.length == 2 && parts[0] == 'library' && parts[1] == 'add') {
    return <String>['/', '/library', '/library/add'];
  }
  if (parts.length == 3 && parts[0] == 'deck' && parts[1] == 'detail') {
    return <String>['/', '/library', path];
  }
  if (parts.length == 4 &&
      parts[0] == 'deck' &&
      parts[1] == 'detail' &&
      parts[3] == 'view') {
    return <String>['/', path];
  }
  if (parts.length == 3 && parts[0] == 'deck' && parts[1] == 'edit-card') {
    return <String>[
      '/',
      '/library',
      '/deck/detail/${parts[2]}',
      path,
    ];
  }
  if (parts.length == 4 && parts[0] == 'deck' && parts[1] == 'edit-card') {
    return <String>[
      '/',
      '/library',
      '/deck/detail/${parts[2]}',
      path,
    ];
  }
  if (parts.length == 3 && parts[0] == 'history' && parts[1] == 'detail') {
    return <String>['/', '/history', path];
  }
  return <String>['/', path];
}

/// Bảng route theo tên — dựng đúng màn hình từ URL.
///
/// Mọi màn hình có dữ liệu đều mã hoá ID vào URL, và các
/// _...Route bọc ngoài nạp dữ liệu theo ID đó (hiện vòng xoay
/// trong lúc nạp). Nhờ vậy Back, Forward, tải lại trang và deep
/// link đều khôi phục đúng màn hình.
Widget _buildPageForPath(String path) {
  // Tách đường dẫn, bỏ các đoạn rỗng (dấu / đầu/cuối).
  final parts = path.split('/').where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return const _AuthGate();
  if (parts.length == 1 && parts[0] == 'admin') {
    return const AdminScreen();
  }
  if (parts.length == 1 && parts[0] == 'settings') {
    return const SettingsScreen();
  }
  if (parts.length == 1 && parts[0] == 'library') {
    return const SelectDeckScreen();
  }
  if (parts.length == 1 && parts[0] == 'history') {
    return const HistoryScreen();
  }
  if (parts.length == 2 && parts[0] == 'reading' && parts[1] == 'new') {
    return const NewReadingScreen();
  }
  if (parts.length == 2 && parts[0] == 'settings' && parts[1] == 'about') {
    return const AboutScreen();
  }
  if (parts.length == 2 && parts[0] == 'library' && parts[1] == 'add') {
    return const AddDeckScreen();
  }
  if (parts.length == 3 && parts[0] == 'deck' && parts[1] == 'detail') {
    final deckId = int.tryParse(parts[2]);
    if (deckId != null) {
      return _DeckDetailRoute(deckId: deckId, readOnly: false);
    }
  }
  if (parts.length == 4 &&
      parts[0] == 'deck' &&
      parts[1] == 'detail' &&
      parts[3] == 'view') {
    final deckId = int.tryParse(parts[2]);
    if (deckId != null) {
      return _DeckDetailRoute(deckId: deckId, readOnly: true);
    }
  }
  if (parts.length == 3 && parts[0] == 'deck' && parts[1] == 'edit-card') {
    final deckId = int.tryParse(parts[2]);
    if (deckId != null) {
      return EditCardScreen(deckId: deckId);
    }
  }
  if (parts.length == 4 && parts[0] == 'deck' && parts[1] == 'edit-card') {
    final deckId = int.tryParse(parts[2]);
    final cardId = int.tryParse(parts[3]);
    if (deckId != null && cardId != null) {
      return _EditCardRoute(deckId: deckId, cardId: cardId);
    }
  }
  if (parts.length == 3 && parts[0] == 'history' && parts[1] == 'detail') {
    final readingId = int.tryParse(parts[2]);
    if (readingId != null) {
      return _ReadingDetailRoute(readingId: readingId);
    }
  }
  // URL lạ / không dựng được trang: về màn gốc (đăng nhập / trang
  // chính theo trạng thái) thay vì màn trắng.
  return const _AuthGate();
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
                    onPressed: () => tarotPop(context),
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
