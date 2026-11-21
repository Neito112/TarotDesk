import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/tarot_symbols.dart';
import '../../core/responsive.dart';
import '../../data/models/tarot_card.dart';
import '../../logic/auth_provider.dart';
import '../../logic/deck_provider.dart';
import '../../logic/reading_provider.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';
import '../widgets/smoke_particle_effect.dart';
import '../widgets/tarot_card_image.dart';
import '../widgets/twinkling_title.dart';
import 'select_deck_screen.dart';
import 'deck_detail_screen.dart';
import 'new_reading_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'about_screen.dart';
import 'admin_screen.dart';

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
///   bàn), tiêu đề 24, CTA cao 40.
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Lá ngày đổi theo ngày: nếu app mở xuyên đêm qua 0h thì lá phải
  // đổi theo ngày mới mà không cần tải lại trang — hẹn giờ kiểm tra
  // mỗi phút, ngày đổi thì build lại (tính lại _dailyCard).
  Timer? _dayRolloverTimer;
  int _dailyCardDay = -1;

  static int _dayIndex(DateTime d) =>
      d.difference(DateTime(d.year, 1, 1)).inDays;

  @override
  void initState() {
    super.initState();
    _dailyCardDay = _dayIndex(DateTime.now());
    _dayRolloverTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final today = _dayIndex(DateTime.now());
      if (today != _dailyCardDay && mounted) {
        setState(() => _dailyCardDay = today);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeckProvider>().fetchDecks();
      context.read<ReadingProvider>().fetchReadingsHistory();
    });
  }

  @override
  void dispose() {
    _dayRolloverTimer?.cancel();
    super.dispose();
  }

  TarotCardModel? _dailyCard(List<TarotCardModel> cards) {
    if (cards.isEmpty) return null;
    final dayOfYear = _dayIndex(DateTime.now());
    return cards[dayOfYear % cards.length];
  }

  void _startNewReading(BuildContext context) {
    final deckProvider = context.read<DeckProvider>();
    final readingProvider = context.read<ReadingProvider>();
    final settings = context.read<SettingsProvider>();
    if (deckProvider.currentDeckCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(settings.tr('home.selectCardsFirst')),
        ),
      );
      return;
    }
    readingProvider.startManualReading(settings.tr('home.newReadingSession'));
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewReadingScreen()),
    );
  }

  /// Nội dung lá bài hôm nay: ảnh lớn + tên + toàn bộ ý nghĩa
  /// (cuộn được). Mở bằng hộp thoại — bấm ngoài hoặc nút Đóng để
  /// tắt, không vào trải bài, không đổi lá ngày.
  void _showDailyCardDetail(
      BuildContext context, TarotCardModel card, dynamic theme) {
    final width = Responsive.isPhone(context) ? 180.0 : 200.0;
    final settings = context.read<SettingsProvider>();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.94),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color: theme.primaryColor.withOpacity(0.5), width: 1),
          ),
          title: Text(
            card.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.primaryColor,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: width,
                  height: width * 8 / 5,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.primaryColor, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: TarotCardImage(card: card, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 12),
                SelectionArea(
                  child: Text(
                    card.meaning,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(settings.tr('common.close')),
            ),
          ],
        );
      },
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
                ? 'assets/images/table_bare_wood.png'
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
                                context, theme, settings, readingProvider),
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
                    settings,
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
                      _buildPrimaryCta(context, theme, settings, compact: true),
                      const SizedBox(height: 12),
                      _buildSecondaryActions(context, theme, settings,
                          horizontal: true),
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
            _buildHistoryFooter(context, theme, settings, readingProvider),
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.info_outline,
                  color: theme.primaryColor, size: 24),
              tooltip: settings.tr('home.aboutTooltip'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                );
              },
            ),
            if (context.watch<AuthProvider>().isAdmin)
              IconButton(
                icon: Icon(Icons.admin_panel_settings,
                    color: theme.primaryColor, size: 24),
                tooltip: settings.tr('home.adminTooltip'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminScreen()),
                  );
                },
              ),
            IconButton(
              icon: Icon(Icons.settings, color: theme.primaryColor, size: 24),
              tooltip: settings.tr('home.settingsTooltip'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
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
        _buildHeroCard(context, theme, settings, dailyCard),
        const SizedBox(height: 20),
        _buildPrimaryCta(context, theme, settings),
        const SizedBox(height: 12),
        _buildDeckCard(context, theme, settings, deckProvider),
        const SizedBox(height: 12),
        _buildSecondaryActions(context, theme, settings),
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
          child: _buildHeroCard(context, theme, settings, dailyCard),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDeckCard(context, theme, settings, deckProvider),
              const SizedBox(height: 16),
              _buildPrimaryCta(context, theme, settings),
              const SizedBox(height: 12),
              _buildSecondaryActions(context, theme, settings),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    dynamic theme,
    SettingsProvider settings,
    TarotCardModel? dailyCard, {
    double? heroWidth,
    double nameFontSize = 18,
  }) {
    final width = heroWidth ?? Responsive.cardWidth(context);
    final height = width * 8 / 5;

    return Column(
      children: [
        Text(
          settings.tr('home.dailyCardTitle'),
          style: TextStyle(
            color: theme.secondaryTextColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          // Ấn vào lá ngày: hiện NỘI DUNG lá (ảnh + tên + ý nghĩa),
          // KHÔNG vào trải bài. Muốn trải bài thì bấm nút
          // "Trải bài mới" (CTA chính) — nút đó mới bắt đầu lượt trải.
          onTap: dailyCard == null
              ? null
              : () => _showDailyCardDetail(context, dailyCard, theme),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              // Nền đen: ảnh lá 7:12 hiện trọn (contain) trong khung 5:8.
              color: Colors.black,
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
                      fit: BoxFit.contain,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          dailyCard?.name ?? settings.tr('home.noDeckSelected'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.textColor,
            fontSize: nameFontSize,
            fontWeight: FontWeight.bold,
          ),
          // Tên lá dài (VD "XII. Người Treo Ngược (The Hanged Man)")
          // cho xuống 2 dòng thay vì cắt "..." — trước đây maxLines 1
          // nên tên bị cắt ngay cả ở màn hình rộng, càng tệ trên điện thoại.
          maxLines: 2,
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
    dynamic theme,
    SettingsProvider settings, {
    bool compact = false,
  }) {
    // PC gọn: nút cao 40 thay vì 48, chữ 14, icon 20.
    final height = compact ? 40.0 : 56.0;
    return SizedBox(
      height: height,
      child: ElevatedButton.icon(
        onPressed: () => _startNewReading(context),
        icon: Icon(Icons.auto_awesome, size: compact ? 20 : 22),
        label: Text(
          settings.tr('home.newReading'),
          style: TextStyle(
            fontSize: compact ? 14 : 17,
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
    dynamic theme,
    SettingsProvider settings, {
    bool horizontal = false,
  }) {
    final khoBoBai = _buildMenuCard(
      context,
      title: settings.tr('home.deckLibrary'),
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
      title: settings.tr('home.pastReadings'),
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
        // "Bộ bài hiện tại": mở CHẾ ĐỘ XEM (chỉ xem, không sửa) —
        // khác hẳn "Kho bộ bài" (quản lý: thêm/sửa). Chưa chọn bộ
        // nào thì mở kho để chọn.
        final deck = deckProvider.selectedDeck;
        if (deck == null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SelectDeckScreen()),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DeckDetailScreen(deck: deck, readOnly: true),
          ),
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
                    settings.tr('home.currentDeck'),
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    deckProvider.selectedDeck?.name ??
                        settings.tr('home.noDeckSelected'),
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
                      settings
                          .tr('home.cardCount')
                          .replaceAll('{n}', '$cardCount'),
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
    SettingsProvider settings,
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
                      settings
                          .tr('home.historyFooter')
                          .replaceAll('{count}', '$count')
                          .replaceAll('{name}',
                              readingProvider.readingsHistory.first.name),
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
    // PC gọn: đệm dọc 12 thay vì 16, icon 20, chữ 14.
    final isDesktop = Responsive.isDesktop(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: GlassPanel(
        blurAmount: settings.userPrefs.enableGlassmorphism ? 10 : 0,
        backgroundColor: theme.cardBackgroundColor,
        borderColor: theme.glassBorderColor,
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: isDesktop ? 12 : 16),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isDesktop ? 8 : 10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(icon, color: color, size: isDesktop ? 20 : 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: isDesktop ? 14 : 15,
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
