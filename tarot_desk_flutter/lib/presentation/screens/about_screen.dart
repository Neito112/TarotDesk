import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentThemeData;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: const Text('Giới thiệu & Hướng dẫn'),
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
                  'TarotDesk là gì?',
                  [
                    'TarotDesk là một công cụ — nơi bạn lưu trữ, sắp xếp '
                        'và tập luyện với bộ bài Tarot của mình.',
                    'TarotDesk KHÔNG phải là phần mềm giải nghĩa hay trải '
                        'bài tự động. App không bói toán, không đọc bài '
                        'thay bạn, và không thay thế được bộ bài vật lý. '
                        'Ý nghĩa của một lá bài đến từ việc bạn học, bạn '
                        'cảm và bạn suy ngẫm — app chỉ giúp bạn lưu lại '
                        'và xem lại những gì bạn đã học.',
                    'Bạn vẫn cần một bộ bài vật lý của riêng mình. Trải '
                        'bài thật là khi bạn cầm lá bài trên tay, xào bài, '
                        'rút bài, đặt bài lên bàn.',
                    'Trước khi mua bộ bài của riêng mình, bạn có thể vào '
                        'Kho bộ bài để xem có bộ nào mình muốn mua không '
                        '— rồi tập luyện với bộ đó trong app trước khi '
                        'quyết định mua. Thử trước, mua sau.',
                  ],
                ),
                const SizedBox(height: 16),
                _section(
                  theme,
                  'Hướng dẫn sử dụng',
                  const [],
                  steps: [
                    (
                      'Kho bộ bài',
                      'Duyệt các bộ bài có sẵn. Chạm vào một bộ để xem '
                          'các lá bài và đọc ý nghĩa từng lá. Tìm được bộ '
                          'mình thích thì tập luyện với nó trước khi mua '
                          'bản vật lý.'
                    ),
                    (
                      'Thêm bộ bài của bạn',
                      'Khi đã có bộ bài vật lý, hãy tạo bộ bài của riêng '
                          'mình trong app: đặt tên bộ bài, thêm từng lá '
                          '(ảnh + ý nghĩa). Bộ bài của bạn sẽ được lưu lại '
                          'để dùng cho mọi lần trải bài sau.'
                    ),
                    (
                      'Trải bài mới',
                      'Bấm "Trải bài mới" để bắt đầu. Chạm vào xấp bài để '
                          'rút lá. Lá vừa rút hiện lên sân khấu cùng ý '
                          'nghĩa của nó. Chạm vào lá trên sân khấu để thu '
                          'lá xuống khay. Chạm vào lá trong khay để xem '
                          'lại lá đó.'
                    ),
                    (
                      'Lá bài ngày',
                      'Mỗi ngày app chọn một lá cho bạn. Chạm vào lá để '
                          'đọc ý nghĩa của nó — một gợi ý nhỏ để suy ngẫm '
                          'trong ngày.'
                    ),
                    (
                      'Lịch sử trải bài',
                      'Các lần trải bài đã lưu nằm ở đây. Mở lại để xem '
                          'các lá đã rút và ý nghĩa của chúng.'
                    ),
                    (
                      'Tùy chỉnh bàn trải bài',
                      'Đổi khăn trải bàn, chọn phụ kiện (pha lê, quả cầu, '
                          'trầm, nến), bật/tắt nhạc huyền bí trong phần '
                          'Cài đặt. Bàn trải bài là không gian của riêng '
                          'bạn — hãy bày biện theo cách bạn thích.'
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _donateSection(context, theme),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Mục mời cà phê: mã QR VietQR (BIDV) + lời mời. Chạm vào mã
  /// để xem phóng to cho dễ quét. Đây là một liên kết/dạng chạm
  /// được, không chỉ là ảnh tĩnh.
  Widget _donateSection(BuildContext context, dynamic theme) {
    return GlassPanel(
      backgroundColor: theme.cardBackgroundColor,
      borderColor: theme.glassBorderColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Mời mình một tách cà phê',
              style: TextStyle(
                color: theme.primaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Nếu thấy hữu ích hãy mời mình một tách cafe <3',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textColor,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showDonateQrDialog(context, theme),
              child: Tooltip(
                message: 'Chạm để xem mã QR phóng to',
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
              'Chạm vào mã QR để phóng to • Quét bằng app ngân hàng',
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
  void _showDonateQrDialog(BuildContext context, dynamic theme) {
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
                'BIDV - CN Hà Nội',
                style: TextStyle(
                  color: theme.textColor.withOpacity(0.75),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'Đóng',
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
