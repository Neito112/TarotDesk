import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/reading_provider.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';
import '../widgets/smoke_particle_effect.dart';
import 'reading_detail_screen.dart';

/// Màn hình lịch sử các lượt trải bài đã lưu
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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentThemeData;
    final readingProvider = context.watch<ReadingProvider>();

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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: readingProvider.readingsHistory.isEmpty
                ? Center(
                    child: Text(
                      'Chưa có lịch sử bói bài nào được lưu.',
                      style: TextStyle(color: theme.secondaryTextColor),
                    ),
                  )
                : ListView.builder(
                    itemCount: readingProvider.readingsHistory.length,
                    itemBuilder: (context, index) {
                      final reading = readingProvider.readingsHistory[index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: GlassPanel(
                          backgroundColor: theme.cardBackgroundColor,
                          borderColor: theme.glassBorderColor,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.primaryColor.withOpacity(0.2),
                              child: Icon(Icons.history, color: theme.primaryColor),
                            ),
                            title: Text(
                              reading.name,
                              style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Ngày bói: ${reading.date.day}/${reading.date.month}/${reading.date.year} ${reading.date.hour}:${reading.date.minute}',
                              style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
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
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
