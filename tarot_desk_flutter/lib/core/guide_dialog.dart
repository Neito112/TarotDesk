import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/settings_provider.dart';
import 'guide_view.dart';

/// Hộp thoại bảng hướng dẫn dùng chung cho cả app.
///
/// Hiện bảng hướng dẫn 15 chương NGAY TRONG APP: tiêu đề + trang
/// hướng dẫn HTML nhúng (web: iframe cùng origin; nền tảng khác:
/// nút mở link ngoài) + chân dialog có checkbox "Không hiện nữa"
/// và nút Đóng. Bấm ngoài dialog vẫn đóng được
/// (barrierDismissible).
///
/// Dùng ở cả ba chỗ mở bảng hướng dẫn:
/// - Pop-up tự động khi vào app (HomeScreen._maybeShowGuidePopup).
/// - Nút ⓘ trên màn Home.
/// - Link hướng dẫn trong màn Giới thiệu (AboutScreen).
///
/// Checkbox "Không hiện nữa" chỉ tắt pop-up TỰ ĐỘNG khi đăng nhập
/// hoặc tải lại app (cờ showGuidePopup) — mở bằng tay (nút ⓘ,
/// link Giới thiệu) vẫn mở được bảng hướng dẫn bất cứ lúc nào.
Future<void> showGuideDialog(BuildContext context) async {
  final settings = context.read<SettingsProvider>();
  final theme = settings.currentThemeData;
  final screenSize = MediaQuery.of(context).size;
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      // watch để checkbox vẽ lại ngay khi bấm (lưu ngay qua
      // provider, xem chú thích ở Checkbox bên dưới).
      final dialogSettings = dialogContext.watch<SettingsProvider>();
      return Dialog(
        backgroundColor: Colors.black.withOpacity(0.94),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: theme.primaryColor.withOpacity(0.5), width: 1),
        ),
        insetPadding: EdgeInsets.symmetric(
          horizontal: screenSize.width * 0.05,
          vertical: screenSize.height * 0.075,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 1000,
            maxHeight: screenSize.height * 0.85,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  dialogSettings.tr('guide.popupTitle'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: buildGuideView(
                    // ESC bấm bên trong iframe hướng dẫn: iframe gửi
                    // message về, đóng hộp thoại (xem guide_view_web).
                    onEscape: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    // Cờ lưu là showGuidePopup (true = hiện);
                    // nhãn checkbox là "không hiện nữa" nên giá
                    // trị hiển thị là NGƯỢC lại. Bấm là lưu ngay
                    // qua provider — đóng dialog bằng cách bấm
                    // ngoài cũng không mất lựa chọn.
                    value: !dialogSettings.userPrefs.showGuidePopup,
                    activeColor: theme.primaryColor,
                    onChanged: (value) => dialogSettings
                        .setShowGuidePopup(!(value ?? false)),
                  ),
                  Expanded(
                    child: GestureDetector(
                      // Bấm cả vào nhãn chữ cũng đổi như bấm ô tick.
                      onTap: () => dialogSettings.setShowGuidePopup(
                          !dialogSettings.userPrefs.showGuidePopup),
                      child: Text(
                        dialogSettings.tr('guide.popupDontShow'),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(dialogSettings.tr('common.close')),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
