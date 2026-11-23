import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/guide_dialog.dart';
import '../../core/responsive.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';

/// Màn hình Giới thiệu & Hướng dẫn sử dụng TarotDesk.
///
/// Nội dung cốt lõi (triết lý của app):
/// - TarotDesk chỉ là CÔNG CỤ để lưu trữ và tập luyện với bộ bài
///   Tarot — KHÔNG phải phần mềm giải nghĩa / trải bài tự động,
///   không bói toán, không thay bạn đọc bài.
/// - Bạn vẫn cần một bộ bài VẬT LÝ của riêng mình. Trải bài thật
///   là khi bạn cầm lá bài trên tay, xào bài, rút bài.
/// - Trước khi mua bộ bài của riêng mình, bạn có thể vào Kho bộ
///   bài xem có bộ nào mình muốn mua không — rồi tập luyện với bộ
///   đó trong app trước khi quyết định mua.
class AboutScreen extends StatelessWidget {
  const AboutScreen({Key? key}) : super(key: key);

  /// Mục hướng dẫn trong màn này mở bảng hướng dẫn NGAY TRONG
  /// APP (cùng dialog với pop-up khi vào app và nút ⓘ trên màn
  /// Home) — không nhảy sang link ngoài.
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentThemeData;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: Text(settings.tr('about.title')),
        backgroundColor: Colors.transparent,
        foregroundColor: theme.primaryColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _section(
                  theme,
                  settings.tr('about.whatIsTitle'),
                  [
                    settings.tr('about.para1'),
                    settings.tr('about.para2'),
                    settings.tr('about.para3'),
                    settings.tr('about.para4'),
                  ],
                ),
                const SizedBox(height: 16),
                _section(
                  theme,
                  settings.tr('about.guideTitle'),
                  const [],
                  steps: [
                    (
                      settings.tr('about.step1Title'),
                      settings.tr('about.step1Body')
                    ),
                    (
                      settings.tr('about.step2Title'),
                      settings.tr('about.step2Body')
                    ),
                    (
                      settings.tr('about.step3Title'),
                      settings.tr('about.step3Body')
                    ),
                    (
                      settings.tr('about.step4Title'),
                      settings.tr('about.step4Body')
                    ),
                    (
                      settings.tr('about.step5Title'),
                      settings.tr('about.step5Body')
                    ),
                    (
                      settings.tr('about.step6Title'),
                      settings.tr('about.step6Body')
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _guideSection(context, theme, settings),
                const SizedBox(height: 16),
                _donateSection(context, theme, settings),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Mục mở bảng hướng dẫn 15 chương (kèm ảnh chụp thực tế của
  /// app) NGAY TRONG APP qua [showGuideDialog] — không nhảy sang
  /// link ngoài, không mở tab trình duyệt mới.
  Widget _guideSection(
      BuildContext context, dynamic theme, SettingsProvider settings) {
    return GlassPanel(
      backgroundColor: theme.cardBackgroundColor,
      borderColor: theme.glassBorderColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              settings.tr('about.guideLinkTitle'),
              style: TextStyle(
                color: theme.primaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              settings.tr('about.guideLinkBody'),
              style: TextStyle(
                color: theme.textColor,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => showGuideDialog(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book, color: theme.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      settings.tr('about.guideLinkLabel'),
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: theme.primaryColor, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mục mời cà phê: mã QR VietQR (BIDV) + lời mời. Chạm vào mã
  /// để xem phóng to cho dễ quét. Đây là một liên kết/dạng chạm
  /// được, không chỉ là ảnh tĩnh.
  Widget _donateSection(
      BuildContext context, dynamic theme, SettingsProvider settings) {
    return GlassPanel(
      backgroundColor: theme.cardBackgroundColor,
      borderColor: theme.glassBorderColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              settings.tr('about.coffeeTitle'),
              style: TextStyle(
                color: theme.primaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              settings.tr('about.coffeeText'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textColor,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showDonateQrDialog(context, theme, settings),
              child: Tooltip(
                message: settings.tr('about.qrTooltip'),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/donate_qr.png',
                    width: 260,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              settings.tr('about.qrHint'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textColor.withOpacity(0.7),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hộp thoại phóng to mã QR để quét cho dễ, kèm thông tin tài
  /// khoản để chuyển khoản thủ công nếu cần.
  void _showDonateQrDialog(
      BuildContext context, dynamic theme, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black.withOpacity(0.94),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.primaryColor, width: 1.5),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/donate_qr.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'TRAN VAN TIEN',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                '21110001575517',
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                settings.tr('about.bankBranch'),
                style: TextStyle(
                  color: theme.textColor.withOpacity(0.75),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  settings.tr('common.close'),
                  style: TextStyle(color: theme.primaryColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Một mục nội dung: tiêu đề vàng + các đoạn văn (hoặc các bước
  /// đánh số). Dùng GlassPanel tối để chữ trắng đọc được.
  Widget _section(
    dynamic theme,
    String title,
    List<String> paragraphs, {
    List<(String, String)> steps = const [],
  }) {
    return GlassPanel(
      backgroundColor: theme.cardBackgroundColor,
      borderColor: theme.glassBorderColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: theme.primaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            for (final p in paragraphs) ...[
              Text(
                p,
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 10),
            ],
            for (var i = 0; i < steps.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.primaryColor,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].$1,
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          steps[i].$2,
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (i < steps.length - 1) const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}
