import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/tarot_symbols.dart';
import '../../core/responsive.dart';
import '../../data/models/tarot_card.dart';
import '../../logic/deck_provider.dart';
import '../../logic/reading_provider.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';
import '../widgets/smoke_particle_effect.dart';
import '../widgets/tarot_card_image.dart';
import '../widgets/twinkling_title.dart';
import 'select_deck_screen.dart';
import 'new_reading_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

/// Màn hình chính TarotDesk (Giao diện Tiếng Việt Tinh gọn)
///
/// Bố cục mobile-first, Android là chính:
/// - Điện thoại (<600dp): 1 cột, lá bài hero lớn ở trên, 1 CTA chính,
///   2 action phụ, thẻ bộ bài, footer lịch sử gọn.
/// - iPad / tablet (600–1024dp): 2 cột — hero bên trái, bộ bài + CTA +
///   action phụ bên phải.
/// - PC / desktop (>1024dp): như tablet nhưng căn giữa, rộng tối đa 1080dp,
///   hero lớn hơn.
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

  TarotCardModel? _dailyCard(List<TarotCardModel> cards) {
    if (cards.isEmpty) return null;
    final now = DateTime.now();
    final dayOfYear =
        now.difference(DateTime(now.year, 1, 1)).inDays;
    return cards[dayOfYear % cards.length];
  }

  void _startNewReading(BuildContext context) {
    final deckProvider = context.read<DeckProvider>();
    final readingProvider = context.read<ReadingProvider>();
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
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentThemeData;
    final deckProvider = context.watch<DeckProvider>();
    final readingProvider = context.watch<ReadingProvider>();
    final dailyCard = _dailyCard(deckProvider.currentDeckCards);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/tarot_main_background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SmokeParticleEffect(
          enableSmoke: settings.userPrefs.enableSmokeParticles,
          child: SafeArea(
            child: ResponsiveCenter(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(context, theme, settings),
                    const SizedBox(height: 20),
                    if (Responsive.isPhone(context))
                      _buildPhoneLayout(
                        context,
                        theme,
                        settings,
                        deckProvider,
                        dailyCard,
                      )
                    else
                      _buildWideLayout(
                        context,
                        theme,
                        settings,
                        deckProvider,
                        dailyCard,
                      ),
                    const SizedBox(height: 16),
                    _buildHistoryFooter(context, theme, readingProvider),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    dynamic theme,
    SettingsProvider settings,
  ) {
    return Row(
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
    );
  }

  Widget _buildPhoneLayout(
    BuildContext context,
    dynamic theme,
    SettingsProvider settings,
    DeckProvider deckProvider,
    TarotCardModel? dailyCard,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeroCard(context, theme, dailyCard),
        const SizedBox(height: 20),
        _buildPrimaryCta(context, theme),
        const SizedBox(height: 12),
        _buildDeckCard(context, theme, settings, deckProvider),
        const SizedBox(height: 12),
        _buildSecondaryActions(context, theme),
      ],
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    dynamic theme,
    SettingsProvider settings,
    DeckProvider deckProvider,
    TarotCardModel? dailyCard,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: _buildHeroCard(context, theme, dailyCard),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDeckCard(context, theme, settings, deckProvider),
              const SizedBox(height: 16),
              _buildPrimaryCta(context, theme),
              const SizedBox(height: 12),
              _buildSecondaryActions(context, theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    dynamic theme,
    TarotCardModel? dailyCard,
  ) {
    final heroWidth = Responsive.cardWidth(context);
    final heroHeight = heroWidth * 8 / 5;

    return Column(
      children: [
        Text(
          'Lá bài hôm nay',
          style: TextStyle(
            color: theme.secondaryTextColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _startNewReading(context),
          child: Container(
            width: heroWidth,
            height: heroHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.primaryColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor.withOpacity(0.35),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: dailyCard == null
                  ? Container(
                      color: theme.cardBackgroundColor,
                      child: const Center(
                        child: Icon(
                          Icons.auto_stories,
                          color: Colors.amberAccent,
                          size: 40,
                        ),
                      ),
                    )
                  : TarotCardImage(
                      card: dailyCard,
                      width: heroWidth,
                      height: heroHeight,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          dailyCard?.name ?? 'Chưa chọn bộ bài',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (dailyCard != null && dailyCard.keywordsUp.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            dailyCard.keywordsUp,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildPrimaryCta(BuildContext context, dynamic theme) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () => _startNewReading(context),
        icon: const Icon(Icons.auto_awesome, size: 22),
        label: const Text(
          'Trải bài mới',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryActions(BuildContext context, dynamic theme) {
    return Column(
      children: [
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
    );
  }

  Widget _buildDeckCard(
    BuildContext context,
    dynamic theme,
    SettingsProvider settings,
    DeckProvider deckProvider,
  ) {
    return GestureDetector(
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
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 11,
                    ),
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
            Icon(
              Icons.chevron_right,
              color: theme.secondaryTextColor,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryFooter(
    BuildContext context,
    dynamic theme,
    ReadingProvider readingProvider,
  ) {
    if (readingProvider.readingsHistory.isEmpty) {
      return const SizedBox.shrink();
    }
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      backgroundColor: theme.cardBackgroundColor,
      borderColor: theme.glassBorderColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(
                  Icons.bookmark_added,
                  color: Colors.greenAccent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lần bói bài gần nhất: ${readingProvider.readingsHistory.first.name}',
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: theme.secondaryTextColor,
            size: 18,
          ),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
            Icon(
              Icons.arrow_forward_ios,
              color: theme.secondaryTextColor,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}
