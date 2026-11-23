/// Widget nhúng trang hướng dẫn HTML (conditional export).
///
/// The app never imports `dart:html` directly: it imports this file,
/// which exports the web implementation on web and the stub
/// everywhere else — the same conditional-import pattern as
/// `web_redirect.dart` (`web_redirect_web.dart` / `web_redirect_stub.dart`).
///
/// - Web: [buildGuideView] trả về một iframe nhúng trang hướng dẫn
///   ([kGuideUrl], cùng origin với app trên GitHub Pages) qua
///   `HtmlElementView`.
/// - Nền tảng khác (Android / iOS / desktop): không có iframe, stub
///   trả về một widget thông báo ngắn + nút mở hướng dẫn bằng trình
///   duyệt ngoài.
///
/// Cả hai file đều khai báo cùng một hàm top-level
/// `Widget buildGuideView();` — không tham số — nên code gọi không
/// cần biết đang chạy nền tảng nào.
export 'guide_view_stub.dart' if (dart.library.html) 'guide_view_web.dart';
