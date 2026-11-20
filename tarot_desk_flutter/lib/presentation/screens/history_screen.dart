import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../data/models/tarot_reading.dart';
import '../../logic/reading_provider.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';
import '../widgets/smoke_particle_effect.dart';
import 'reading_detail_screen.dart';

/// Màn hình lịch sử các lượt trải bài đã lưu (OldReadings).
/// Bố cục: mobile-first Android (1 cột), iPad/PC (danh sách 2 cột,
/// nội dung căn giữa, rộng tối đa theo Responsive.maxContentWidth).
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

  Widget _readingTile(BuildContext context, TarotReadingModel reading,
      dynamic theme, ReadingProvider readingProvider) {
    return GlassPanel(
      backgroundColor: theme.cardBackgroundColor,
      borderColor: theme.glassBorderColor,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: theme.primaryColor.withOpacity(0.2),
          child: Icon(Icons.history, color: theme.primaryColor),
        ),
        title: Text(
          reading.name,
          style: TextStyle(
              color: theme.textColor, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Ngày bói: ${reading.date.day}/${reading.date.month}/${reading.date.year} ${reading.date.hour}:${reading.date.minute}',
          style:
              TextStyle(color: theme.secondaryTextColor, fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () {
            if (reading.id != null) {
              readingProvider.deleteReading(reading.id!);
            }
          },
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReadingDetailScreen(reading: reading),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentThemeData;
    final readingProvider = context.watch<ReadingProvider>();
    // Phone: 1 cột. Tablet/PC: 2 cột.
    final isWide = Responsive.isTablet(context) ||
        Responsive.isDesktop(context);
    final readings = readingProvider.readingsHistory;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: const Text('Lịch Sử Bói Bài'),
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
                : isWide
                    ? GridView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 2.8,
                        ),
                        itemCount: readings.length,
                        itemBuilder: (context, index) => _readingTile(
                            context, readings[index], theme,
                            readingProvider),
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        itemCount: readings.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: _readingTile(context, readings[index],
                              theme, readingProvider),
                        ),
                      ),
          ),
        ),
      ),
    );
  }
}
