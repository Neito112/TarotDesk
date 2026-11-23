// Web implementation of the guide view (dart:html + dart:ui_web).
//
// Nhúng trang hướng dẫn HTML ([kGuideUrl]) vào trong app bằng một
// iframe cùng origin (cùng site GitHub Pages với app), qua
// `HtmlElementView` — cùng pattern `dart:html` như
// `web_redirect_web.dart` trong codebase này.
//
// NOTE về `dart:ui_web`: `platformViewRegistry` đã bị XÓA khỏi
// `dart:ui` từ Flutter 3.50 (chỉ còn trong `dart:ui_web`, có từ
// Dart 3.4 / Flutter 3.22) — nên file này BẮT BUỘC dùng
// `dart:ui_web`, và `pubspec.yaml` đã nâng SDK tối thiểu lên
// `>=3.4.0` cho khớp. Dùng `dart:ui` ở đây là lỗi biên dịch,
// không phải chỉ cảnh báo deprecated.
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import 'guide_url.dart';

/// Tên view type đăng ký với `platformViewRegistry`. Đăng ký MỘT
/// LẦN duy nhất (cờ [_registered]): đăng ký lại cùng tên sẽ ném lỗi.
const String _guideViewType = 'tarotdesk-guide-view';
bool _registered = false;

/// Trả về widget nhúng trang hướng dẫn: một iframe toàn khung
/// (100% × 100%, không viền) trỏ tới [kGuideUrl]. Cùng chữ ký với
/// stub ([guide_view_stub.dart]) — xem [guide_view.dart].
Widget buildGuideView() {
  if (!_registered) {
    _registered = true;
    ui_web.platformViewRegistry.registerViewFactory(
      _guideViewType,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..src = kGuideUrl
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%';
        return iframe;
      },
    );
  }
  return const HtmlElementView(viewType: _guideViewType);
}
