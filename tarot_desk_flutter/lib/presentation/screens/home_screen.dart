import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/tarot_symbols.dart';
import '../../core/guide_dialog.dart';
import '../../core/guide_view.dart';
import '../../core/responsive.dart';
import '../../data/datasources/preferences_service.dart';
import '../../data/models/tarot_card.dart';
import '../../logic/auth_provider.dart';
import '../../logic/deck_provider.dart';
import '../../logic/reading_provider.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';
import '../widgets/localized_card_text.dart';
import '../widgets/localized_content_text.dart';
import '../widgets/smoke_particle_effect.dart';
import '../widgets/tarot_card_image.dart';
import '../widgets/twinkling_title.dart';
import 'select_deck_screen.dart';
import 'deck_detail_screen.dart';
import 'new_reading_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
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

  /// Chặn pop-up hướng dẫn hiện quá một lần trong một lần mount
  /// của HomeScreen: bật ngay khi [_maybeShowGuidePopup] chạy lần
  /// đầu, dù cờ cài đặt có cho hiện hay không.
  bool _guidePopupShown = false;

  /// Seed ổn định cho khách (không đăng nhập): một UUID lưu trong
  /// SharedPreferences, tạo một lần duy nhất ở lần chạy đầu tiên và
  /// không bao giờ tạo lại trừ khi người dùng xóa dữ liệu app. Nhờ
  /// đó lá ngày của khách ổn định cả ngày, đổi lúc 0h, và khác nhau
  /// giữa các thiết bị.
  static const String _guestSeedKey = 'tarotdesk_guest_device_seed';
  String? _guestSeed;

  static int _dayIndex(DateTime d) =>
      d.difference(DateTime(d.year, 1, 1)).inDays;

  @override
  void initState() {
    super.initState();
    _dailyCardDay = _dayIndex(DateTime.now());
    _ensureGuestSeed();
    _dayRolloverTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final today = _dayIndex(DateTime.now());
      if (today != _dailyCardDay && mounted) {
        setState(() => _dailyCardDay = today);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeckProvider>().fetchDecks();
      context.read<ReadingProvider>().fetchReadingsHistory();
      _maybeShowGuidePopup();
    });
  }

  @override
  void dispose() {
    _dayRolloverTimer?.cancel();
    super.dispose();
  }

  /// Đọc / tạo seed thiết bị cho khách. Chỉ đọc-ghi SharedPreferences,
  /// không bao giờ ném lỗi ra ngoài: lỗi lưu trữ thì _guestSeed giữ
  /// null và lá ngày dùng seed tạm 'guest:pending' (xem [_dailyCardSeed]).
  Future<void> _ensureGuestSeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var seed = prefs.getString(_guestSeedKey);
      if (seed == null || seed.isEmpty) {
        final random = Random.secure();
        seed = List<int>.generate(16, (_) => random.nextInt(256))
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        await prefs.setString(_guestSeedKey, seed);
      }
      if (mounted && seed != _guestSeed) {
        setState(() => _guestSeed = seed);
      } else {
        _guestSeed = seed;
      }
    } catch (_) {
      // Lưu trữ lỗi: giữ _guestSeed == null, lá ngày dùng seed tạm.
    }
  }

  /// FNV-1a 32-bit — hàm băm xác định, phân bố đều, không phụ thuộc
  /// platform (không dùng Object.hashCode / Random không seed, vì
  /// chúng không ổn định giữa các lần chạy / nền tảng).
  static int _fnv1a32(String input) {
    var hash = 0x811c9dc5; // offset basis
    for (final byte in input.codeUnits) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF; // prime, giữ 32-bit
    }
    return hash;
  }

  /// Seed cho lá ngày của tài khoản hiện tại.
  ///
  /// - Đã đăng nhập: `'account:<sub>'` — `sub` là Google account id
  ///   ổn định của [AuthProvider.user] (không đổi khi đổi email);
  ///   nếu `sub` trống thì dùng email. KHÔNG dùng session token làm
  ///   seed: token xoay vòng / bị thu hồi, lá ngày sẽ đổi giữa ngày.
  /// - Khách / chưa có identity (đang loading, token hết hạn, lỗi
  ///   khôi phục session): dùng seed thiết bị `'guest:<uuid>'`;
  ///   nếu seed thiết bị chưa tải xong thì tạm dùng
  ///   `'guest:pending'` — lá vẫn hiện, không crash, và đổi sang lá
  ///   đúng ngay khi seed tải xong (setState trong [_ensureGuestSeed]).
  String _dailyCardSeed(AuthProvider auth) {
    final user = auth.user;
    if (auth.isLoggedIn && user != null) {
      final id = user.sub.isNotEmpty ? user.sub : user.email;
      if (id.isNotEmpty) return 'account:$id';
    }
    return 'guest:${_guestSeed ?? 'pending'}';
  }

  /// Lá ngày: băm (seed tài khoản/thiết bị + ngày đầy đủ) rồi lấy
  /// modulo số lá. Cùng tài khoản + cùng ngày => cùng lá cả ngày;
  /// khác tài khoản (hoặc khác thiết bị khách) + cùng ngày => lá
  /// khác nhau; qua 0h (ngày đổi) => lá đổi (timer 1 phút đã có
  /// sẵn ở [initState] sẽ build lại). Danh sách rỗng => null như cũ.
  TarotCardModel? _dailyCard(List<TarotCardModel> cards, String seed) {
    if (cards.isEmpty) return null;
    final now = DateTime.now();
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final index = _fnv1a32('$seed|$dateKey') % cards.length;
    return cards[index];
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
      MaterialPageRoute(
        settings: const RouteSettings(name: '/reading/new'),
        builder: (_) => const NewReadingScreen(),
      ),
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
          title: LocalizedCardName(
            card: card,
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
                  child: LocalizedCardMeaning(
                    card: card,
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


  /// Pop-up hướng dẫn sử dụng: hiện MỘT LẦN duy nhất ở lần mount
  /// đầu tiên của HomeScreen sau khi vào app — đăng nhập Google,
  /// tải lại trang với session đã lưu, hoặc vào bằng khách
  /// ("Dùng offline"). Không hiện lại khi đi lại trong app: Home
  /// chỉ mount lại khi quay về từ màn khác qua pop (không tạo
  /// HomeScreen mới), và cờ [_guidePopupShown] chặn lần gọi thứ
  /// hai trong cùng một mount.
  ///
  /// Đọc thẳng từ SharedPreferences thay vì provider: hàm
  /// [SettingsProvider.initSettings] chạy bất đồng bộ (fire-and-
  /// forget) nên lúc Home mount xong, cờ trong bộ nhớ có thể chưa
  /// tải xong — đọc một lần trực tiếp là cách tránh race này.
  /// Không bao giờ ném lỗi ra ngoài: lỗi lưu trữ thì pop-up chỉ
  /// đơn giản là không hiện, màn chính vẫn chạy bình thường.
  Future<void> _maybeShowGuidePopup() async {
    try {
      if (!mounted || _guidePopupShown) return;
      _guidePopupShown = true;
      final prefs = await PreferencesService().loadPreferences();
      if (!mounted || !prefs.showGuidePopup) return;
      await showGuideDialog(context);
    } catch (_) {
      // Lỗi lưu trữ: bỏ qua, không làm hỏng màn chính.
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentThemeData;
    final deckProvider = context.watch<DeckProvider>();
    final readingProvider = context.watch<ReadingProvider>();
    // Watch AuthProvider để lá ngày đổi ngay khi tài khoản đổi
    // (đăng nhập / đăng xuất / liên kết Google) mà không cần reload.
    final dailyCard = _dailyCard(
      deckProvider.currentDeckCards,
      _dailyCardSeed(context.watch<AuthProvider>()),
    );
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
              tooltip: settings.tr('home.guideTooltip'),
              onPressed: () {
                showGuideDialog(context);
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
                    MaterialPageRoute(
                      settings: const RouteSettings(name: '/admin'),
                      builder: (_) => const AdminScreen(),
                    ),
                  );
                },
              ),
            IconButton(
              icon: Icon(Icons.settings, color: theme.primaryColor, size: 24),
              tooltip: settings.tr('home.settingsTooltip'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings: const RouteSettings(name: '/settings'),
                    builder: (_) => const SettingsScreen(),
                  ),
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
        // Tên lá dài (VD "XII. Người Treo Ngược (The Hanged Man)")
        // cho xuống 2 dòng thay vì cắt "..." — trước đây maxLines 1
        // nên tên bị cắt ngay cả ở màn hình rộng, càng tệ trên điện thoại.
        dailyCard == null
            ? Text(
                settings.tr('home.noDeckSelected'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: nameFontSize,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : LocalizedCardName(
                card: dailyCard,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: nameFontSize,
                  fontWeight: FontWeight.bold,
                ),
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
          MaterialPageRoute(
            settings: const RouteSettings(name: '/library'),
            builder: (_) => const SelectDeckScreen(),
          ),
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
          MaterialPageRoute(
            settings: const RouteSettings(name: '/history'),
            builder: (_) => const HistoryScreen(),
          ),
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
            MaterialPageRoute(
              settings: const RouteSettings(name: '/library'),
              builder: (_) => const SelectDeckScreen(),
            ),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: '/deck/detail'),
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
                  deckProvider.selectedDeck == null
                      ? Text(
                          settings.tr('home.noDeckSelected'),
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : LocalizedDeckName(
                          deck: deckProvider.selectedDeck!,
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
          MaterialPageRoute(
            settings: const RouteSettings(name: '/history'),
            builder: (_) => const HistoryScreen(),
          ),
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
                    child: Text.rich(
                      TextSpan(
                        children: templateWithLocalizedName(
                          template: settings
                              .tr('home.historyFooter')
                              .replaceAll('{count}', '$count'),
                          placeholder: '{name}',
                          nameWidget: LocalizedReadingName(
                            name: readingProvider
                                .readingsHistory.first.name,
                            style: TextStyle(
                              color: theme.secondaryTextColor,
                              fontSize: 12,
                            ),
                          ),
                          style: TextStyle(
                            color: theme.secondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
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
