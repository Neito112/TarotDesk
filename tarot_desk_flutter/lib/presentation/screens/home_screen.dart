import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/tarot_symbols.dart';
import '../../logic/deck_provider.dart';
import '../../logic/reading_provider.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';
import '../widgets/smoke_particle_effect.dart';
import '../widgets/twinkling_title.dart';
import 'select_deck_screen.dart';
import 'new_reading_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

/// Màn hình chính TarotDesk (Giao diện Tiếng Việt Tinh gọn)
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeckProvider>().fetchDecks();
      context.read<ReadingProvider>().fetchReadingsHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentThemeData;
    final deckProvider = context.watch<DeckProvider>();
    final readingProvider = context.watch<ReadingProvider>();

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/tarot_main_background.jpg'), // Thiết kế bằng stitch nền dải ngân hà
            fit: BoxFit.cover,
          ),
        ),
        child: SmokeParticleEffect(
          enableSmoke: settings.userPrefs.enableSmokeParticles,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Bar (Gồm Tên to lên, Icon bánh răng góc trên bên phải)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            TarotSymbols.pentacles,
                            style: const TextStyle(fontSize: 30),
                          ),
                          const SizedBox(width: 8),
                          settings.userPrefs.enableTwinklingText
                              ? TwinklingTitle(
                                  text: 'TarotDesk',
                                  fontSize: 32,
                                  primaryColor: theme.primaryColor,
                                )
                              : Text(
                                  'TarotDesk',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: theme.primaryColor,
                                  ),
                                ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.settings, color: theme.primaryColor, size: 24),
                        tooltip: 'Cài đặt giao diện',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SettingsScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                  
                  // Đã loại bỏ hoàn toàn mô tả phụ rườm rà dưới tên ứng dụng
                  const SizedBox(height: 16),

                  // Card Thẻ Bộ Bài Đang Chọn: click được vào CẢ thẻ chứ không chỉ có icon đổi, bỏ hẳn icon đổi
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SelectDeckScreen()),
                      );
                    },
                    child: GlassPanel(
                      blurAmount: settings.userPrefs.enableGlassmorphism ? 12 : 0,
                      backgroundColor: theme.cardBackgroundColor,
                      borderColor: theme.glassBorderColor,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.auto_stories, color: theme.primaryColor, size: 30),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bộ bài hiện tại:',
                                  style: TextStyle(color: theme.secondaryTextColor, fontSize: 11),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  deckProvider.selectedDeck?.name ?? 'Chưa chọn bộ bài',
                                  style: TextStyle(
                                    color: theme.textColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: theme.secondaryTextColor, size: 18),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Danh sách Chức năng Chính (Menu Buttons Tinh gọn, không có text phụ ghi chú và emoji thừa)
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildMenuCard(
                          context,
                          title: 'Trải bài mới',
                          icon: Icons.auto_awesome,
                          color: theme.primaryColor,
                          onTap: () {
                            if (deckProvider.currentDeckCards.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Vui lòng chọn hoặc thêm lá bài trước khi trải bài!'),
                                ),
                              );
                              return;
                            }
                            readingProvider.startManualReading('Lượt Trải Bài Mới');
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const NewReadingScreen()),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildMenuCard(
                          context,
                          title: 'Kho bộ bài',
                          icon: Icons.auto_stories,
                          color: theme.accentColor,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SelectDeckScreen()),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildMenuCard(
                          context,
                          title: 'Trải bài cũ',
                          icon: Icons.history_edu,
                          color: Colors.amberAccent,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const HistoryScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Footer Lần trải bài gần nhất (Nhỏ gọn hơn)
                  if (readingProvider.readingsHistory.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: GlassPanel(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        backgroundColor: theme.cardBackgroundColor,
                        borderColor: theme.glassBorderColor,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.bookmark_added, color: Colors.greenAccent, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Lần bói bài gần nhất: ${readingProvider.readingsHistory.first.name}',
                                  style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
                                ),
                              ],
                            ),
                            Icon(Icons.chevron_right, color: theme.secondaryTextColor, size: 18),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentThemeData;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: GlassPanel(
        blurAmount: settings.userPrefs.enableGlassmorphism ? 10 : 0,
        backgroundColor: theme.cardBackgroundColor,
        borderColor: theme.glassBorderColor,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: theme.secondaryTextColor, size: 14),
          ],
        ),
      ),
    );
  }
}
