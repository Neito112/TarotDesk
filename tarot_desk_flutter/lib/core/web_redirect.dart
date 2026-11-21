/// Web-only redirect helpers (conditional export).
///
/// The app never imports `dart:html` directly: it imports this file,
/// which exports the web implementation on web and the stub
/// everywhere else — the same conditional-import pattern as
/// `db_init_stub.dart` / `db_init_web.dart` for the database factory.
export 'web_redirect_stub.dart' if (dart.library.html) 'web_redirect_web.dart';
