import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../data/datasources/database_helper.dart';
import '../../data/models/tarot_card.dart';
import '../../data/models/tarot_reading.dart';
import '../../logic/reading_provider.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';
import '../widgets/smoke_particle_effect.dart';
import '../widgets/tarot_card_image.dart';
import 'reading_detail_screen.dart';

/// Màn hình lịch sử các lượt trải bài đã lưu (OldReadings).
/// Cùng ngôn ngữ với NewReading: mỗi lượt hiện lá bài đầu tiên ở tỉ lệ
/// 5:8 với cùng cỡ lá khay (~96 rộng), chạm vào tile để mở
/// ReadingDetail của lượt đó.
/// Bố cục: mobile-first Android (1 cột), tablet (2 cột), PC 4K gọn
/// (3 cột), nội dung căn giữa theo Responsive.maxContentWidth.
/// Logic, provider, navigation và text tiếng Việt giữ nguyên.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReadingProvider>().fetchReadingsHistory();
    });
  }

  // Lá khay dùng cùng cỡ với khay trong NewReading: ~96 rộng, 5:8.
  static const double _tileCardWidth = 96.0;

  /// Lá bài đầu tiên của một lượt trải bài, để hiện ở tile lịch sử.
  Future<TarotCardModel?> _firstCard(TarotReadingModel reading) async {
    if (reading.cardIds.isEmpty) return null;
    final cards =
        await DatabaseHelper.instance.getCardsByIds([reading.cardIds.first]);
    return cards.isEmpty ? null : cards.first;
  }

  Widget _readingTile(BuildContext context, TarotReadingModel reading,
      dynamic theme, ReadingProvider readingProvider) {
    return GlassPanel(
      backgroundColor: theme.cardBackgroundColor,
      borderColor: theme.glassBorderColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReadingDetailScreen(reading: reading),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lá bài đầu tiên của lượt, 5:8, cùng cỡ lá khay.
              SizedBox(
                width: _tileCardWidth,
                height: _tileCardWidth * 8 / 5,
                child: FutureBuilder<TarotCardModel?>(
                  future: _firstCard(reading),
                  builder: (context, snapshot) {
                    final card = snapshot.data;
                    if (card == null) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.glassBorderColor),
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.style,
                            color: theme.primaryColor, size: 28),
                      );
                    }
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.primaryColor, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: theme.primaryColor.withOpacity(0.3),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: TarotCardImage(card: card, fit: BoxFit.cover),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reading.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: theme.textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ngày bói: ${reading.date.day}/${reading.date.month}/${reading.date.year} ${reading.date.hour}:${reading.date.minute}',
                      style: TextStyle(
                          color: theme.secondaryTextColor, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${reading.cardIds.length} lá bài',
                      style: TextStyle(
                          color: theme.secondaryTextColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () {
                  if (reading.id != null) {
                    readingProvider.deleteReading(reading.id!);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentThemeData;
    final readingProvider = context.watch<ReadingProvider>();
    final isDesktop = Responsive.isDesktop(context);
    final isTablet = Responsive.isTablet(context);
    // Phone: 1 cột. Tablet: 2 cột. PC: 3 cột.
    final columns = isDesktop ? 3 : (isTablet ? 2 : 1);
    final readings = readingProvider.readingsHistory;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        toolbarHeight: isDesktop ? 44 : null,
        title: Text(
          'Lịch Sử Bói Bài',
          style: TextStyle(fontSize: isDesktop ? 15 : 18),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: theme.primaryColor,
        elevation: 0,
      ),
      body: SmokeParticleEffect(
        enableSmoke: settings.userPrefs.enableSmokeParticles,
        child: SafeArea(
          child: ResponsiveCenter(
            child: readings.isEmpty
                ? Center(
                    child: Text(
                      'Chưa có lịch sử bói bài nào được lưu.',
                      style:
                          TextStyle(color: theme.secondaryTextColor),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      // Lá 96 rộng -> cao 153.6, cộng padding tile 16.
                      mainAxisExtent: _tileCardWidth * 8 / 5 + 16,
                    ),
                    itemCount: readings.length,
                    itemBuilder: (context, index) => _readingTile(
                        context, readings[index], theme, readingProvider),
                  ),
          ),
        ),
      ),
    );
  }
}
