// Stub for non-web platforms (desktop/mobile).
//
// Nhúng iframe chỉ có trên web. Trên nền tảng khác, [buildGuideView]
// trả về một widget thông báo ngắn + nút mở hướng dẫn bằng trình
// duyệt ngoài — cùng pattern `launchUrl` + `LaunchMode.externalApplication`
// như mục hướng dẫn trong AboutScreen. File này KHÔNG import
// `dart:html`, và khai báo cùng chữ ký với bản web
// ([guide_view_web.dart]) — xem [guide_view.dart].
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'guide_url.dart';

/// Widget thay thế iframe trên nền tảng không phải web: thông báo
/// ngắn + nút mở hướng dẫn ở trình duyệt ngoài. Cùng chữ ký với
/// bản web ([guide_view_web.dart]) — tham số onEscape (chỉ có tác
/// dụng trên web) ở đây được bỏ qua.
Widget buildGuideView({VoidCallback? onEscape}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Hướng dẫn sử dụng mở trong trình duyệt trên nền tảng này.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Mở hướng dẫn'),
            onPressed: () async {
              final uri = Uri.parse(kGuideUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    ),
  );
}
