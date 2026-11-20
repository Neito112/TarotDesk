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
///   action phụ bên phải, căn giữa tối đa 720dp.
/// - PC / desktop (>1024dp): KHÔNG còn cột 1080 căn giữa. Dùng trọn chiều
///   rộng màn hình: hero gọn bên trái, bộ bài + CTA + action phụ bên phải,
///   nền bàn gỗ (cùng thế giới bàn trải bài góc nhìn thứ nhất), chữ và lá
///   bài thu nhỏ cho gọn ở 4K. Hero desktop 160 rộng (bằng cỡ lá bài trên
///   bàn), tiêu đề 24, CTA cao 48.
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
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            // Desktop: nền bàn gỗ trơn — cùng thế giới bàn trải bài góc
            // nhìn thứ nhất với màn Trải bài mới. Điện thoại/tablet giữ
            // nền sao như cũ.
            image: AssetImage(isDesktop
                ? 'assets/images/table_wood_only.png'
                : 'assets/images/tarot_main_background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          // Lớp tối để chữ đọc được trên nền gỗ; đậm hơn ở trên cùng.
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.backgroundColor.withOpacity(isDesktop ? 0.82 : 0.55),
                theme.backgroundColor.withOpacity(isDesktop ? 0.72 : 0.45),
              ],
            ),
          ),
          child: SmokeParticleEffect(
            enableSmoke: settings.userPrefs.enableSmokeParticles,
            child: SafeArea(
              child: isDesktop
                  ? _buildDesktopBody(
                      context,
                      theme,
                      settings,
                      deckProvider,
                      readingProvider,
                      dailyCard,
                    )
                  : ResponsiveCenter(
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
                            _buildHistoryFooter(
                                context, theme, readingProvider),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// Thân trang desktop: dùng trọn chiều rộng, không bọc ResponsiveCenter.
  Widget _buildDesktopBody(
    BuildContext context,
    dynamic theme,
    SettingsProvider settings,
    DeckProvider deckProvider,
    ReadingProvider readingProvider,
    TarotCardModel? dailyCard,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 56.0, vertical: 20.0),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, theme, settings, compact: true),
            const SizedBox(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero gọn bên trái, cố định chiều rộng.
                SizedBox(
                  width: 300,
                  child: _buildHeroCard(
                    context,
                    theme,
                    dailyCard,
                    heroWidth: 160,
                    nameFontSize: 16,
                  ),
                ),
                const SizedBox(width: 48),
                // Bộ bài + CTA + action phụ bên phải, dùng hết chiều rộng.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildDeckCard(context, theme, settings, deckProvider),
                      const SizedBox(height: 14),
                      _buildPrimaryCta(context, theme, compact: true),
                      const SizedBox(height: 12),
                      _buildSecondaryActions(context, theme, horizontal: true),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Vạch vàng mảnh ngăn với footer lịch sử.
            Container(
              height: 1,
              color: theme.primaryColor.withOpacity(0.25),
            ),
            const SizedBox(height: 12),
            _buildHistoryFooter(context, theme, readingProvider),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    dynamic theme,
    SettingsProvider settings, {
    bool compact = false,
  }) {
    final titleSize = compact ? 24.0 : 32.0;
    final symbolSize = compact ? 24.0 : 30.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              TarotSymbols.pentacles,
              style: TextStyle(fontSize: symbolSize),
            ),
            const SizedBox(width: 8),
            settings.userPrefs.enableTwinklingText
                ? TwinklingTitle(
                    text: 'TarotDesk',
                    fontSize: titleSize,
                    primaryColor: theme.primaryColor,
                  )
                : Text(
                    'TarotDesk',
                    style: TextStyle(
                      fontSize: titleSize,
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
    TarotCardModel? dailyCard, {
    double? heroWidth,
    double nameFontSize = 18,
  }) {
    final width = heroWidth ?? Responsive.cardWidth(context);
    final height = width * 8 / 5;

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
            width: width,
            height: height,
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
                      child: Center(
                        child: Icon(
                          Icons.auto_stories,
                          color: theme.primaryColor,
                          size: 40,
                        ),
                      ),
                    )
                  : TarotCardImage(
                      card: dailyCard,
                      width: width,
                      height: height,
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
            fontSize: nameFontSize,
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

  Widget _buildPrimaryCta(
    BuildContext context,
    dynamic theme, {
    bool compact = false,
  }) {
    return SizedBox(
      height: compact ? 48 : 56,
      child: ElevatedButton.icon(
        onPressed: () => _startNewReading(context),
        icon: const Icon(Icons.auto_awesome, size: 22),
        label: Text(
          'Trải bài mới',
          style: TextStyle(
            fontSize: compact ? 15 : 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          // Chữ tối trên nền vàng: dùng màu nền của theme đang chọn.
          foregroundColor: theme.backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryActions(
    BuildContext context,
    dynamic theme, {
    bool horizontal = false,
  }) {
    final khoBoBai = _buildMenuCard(
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
    );
    final traiBaiCu = _buildMenuCard(
      context,
      title: 'Trải bài cũ',
      icon: Icons.history_edu,
      color: theme.primaryColor,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HistoryScreen()),
        );
      },
    );
    if (horizontal) {
      return Row(
        children: [
          Expanded(child: khoBoBai),
          const SizedBox(width: 12),
          Expanded(child: traiBaiCu),
        ],
      );
    }
    return Column(
      children: [
        khoBoBai,
        const SizedBox(height: 12),
        traiBaiCu,
      ],
    );
  }

  Widget _buildDeckCard(
    BuildContext context,
    dynamic theme,
    SettingsProvider settings,
    DeckProvider deckProvider,
  ) {
    final cardCount = deckProvider.currentDeckCards.length;
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
                  if (cardCount > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '$cardCount lá bài',
                      style: TextStyle(
                        color: theme.secondaryTextColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
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
    final count = readingProvider.readingsHistory.length;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HistoryScreen()),
        );
      },
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        backgroundColor: theme.cardBackgroundColor,
        borderColor: theme.glassBorderColor,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    Icons.bookmark_added,
                    color: theme.accentColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đã lưu $count lượt trải bài · Gần nhất: ${readingProvider.readingsHistory.first.name}',
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
