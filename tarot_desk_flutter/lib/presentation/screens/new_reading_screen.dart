import 'dart:async';
import 'dart:math';
import 'dart:ui'; // Cần thiết cho PointerDeviceKind và kéo thả bằng chuột
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../core/display_labels.dart';
import '../../core/responsive.dart';
import '../../core/translation_service.dart';
import '../../data/models/tarot_card.dart';
import '../../data/models/user_preferences.dart';
import '../../logic/deck_provider.dart';
import '../../logic/reading_provider.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';
import '../widgets/localized_card_text.dart';
import '../widgets/localized_content_text.dart';
import '../widgets/mystic_music_player.dart';
import '../widgets/smoke_particle_effect.dart';
import '../widgets/tarot_card_image.dart';

/// Màn hình Trải bài Tarot — bố cục mobile-first (Android là chính),
/// thích ứng cho iPad (tablet) và PC (desktop).
///
/// Luồng bố cục (không còn Stack/Positioned chắp vá):
///   nền bàn + lớp phủ tối (scrim) -> lá bài lớn ở giữa (tỉ lệ 5:8)
///   -> panel giải nghĩa ở dưới (phone) hoặc bên cạnh (tablet/desktop),
///   không chồng lên nhau -> khay bài đã rút ở dưới cùng (section riêng).
/// Panel chọn bài là một section riêng (dạng bottom-sheet) thay thế
/// vùng chính, không đè lên khay bài.
///
/// PC (desktop): bàn là một CẢNH VẼ LỚP (HyperFrames-style —
/// tranh vẽ phối cảnh góc nhìn thứ nhất, KHÔNG phải engine 3D thời
/// gian thực). Bố cục định TRƯỚC trong code (một nguồn sự thật
/// duy nhất), không đo ngược pixel từ ảnh: LỚP 1 nền là bàn gỗ
/// trống `table_bare_wood.png` (BoxFit.cover, toàn bộ viewport); LỚP 2 khăn — ảnh cắt TRONG
/// SUỐT toàn khung (1920x1280), vẽ thẳng trên bàn gỗ trống rồi
/// tách nền, khớp điểm tụ và góc độ với bàn; cả 3 màu khăn đều
/// vẽ trên cùng một bàn nên đổi màu không bao giờ lộ màu cũ
/// bên dưới; LỚP 3 phụ kiện là các ảnh cắt TRONG SUỐT (chỉ giữ vật
/// thể, đã tách nền) đặt theo tọa độ phân số cố định trong code,
/// bóng tiếp xúc vẽ bằng code ngay dưới chân vật. Khăn sống trong
/// cùng Stack với nền gỗ (cùng box, cùng BoxFit.cover) nên luôn
/// khớp pixel với gỗ ở mọi viewport; phụ kiện sống trong Stack
/// của bàn.
/// Trên bàn KHÔNG còn lá nào: bàn chỉ là không gian (gỗ, khăn,
/// phụ kiện, xấp bài ở góc). Lá đang đọc HIỆN TRÊN MÀN HÌNH —
/// lá lớn 150 rộng + panel giải nghĩa ngay bên cạnh, ở giữa-phía
/// trước: đó là lá vừa rút hoặc lá được chọn từ khay. Khay dưới
/// chứa TOÀN BỘ các lá đã rút, cao cố định 176 (PC) kể cả khi
/// chưa rút lá nào (không co giãn làm bàn nhảy khung hình).
/// Hoạt ảnh (HyperFrames + nghiên cứu hoạt ảnh mượt 2026-11-20):
/// rút bài = MỘT tween duy nhất, chỉ transform (dịch + scale),
/// easeOutCubic 500ms, đáp xuống đứng yên hẳn; đổi lá: lá mới
/// lên sân từ dưới, lá cũ xuống khay (trượt + mờ, 250ms vào /
/// 150ms ra); tranh bàn lớn nạp trước + lá bay bọc
/// RepaintBoundary. Phone/tablet giữ bản đơn giản đã có.
///
/// Bám sát mặt bàn: khăn vẽ thẳng trên bàn rồi tách nền (bóng tiếp
/// xúc vẽ sẵn trong ảnh), phụ kiện là ảnh cắt trong suốt + bóng
/// tiếp xúc vẽ bằng code. Khay PC: lá 100 rộng, cao 176.
class NewReadingScreen extends StatefulWidget {
  const NewReadingScreen({Key? key}) : super(key: key);

  @override
  State<NewReadingScreen> createState() => _NewReadingScreenState();
}

/// MÔ HÌNH MÀN HÌNH ĐỌC BÀI (không phải UI giả tạo):
/// - Trên bàn KHÔNG còn lá nào: bàn chỉ là không gian (gỗ, khăn,
///   phụ kiện, xấp bài ở góc). Lá đang đọc HIỆN TRÊN MÀN HÌNH —
///   lá lớn 150 rộng + panel giải nghĩa ngay bên cạnh, ở
///   giữa-phía trước: đó là lá vừa rút hoặc lá được chọn từ khay.
/// - Khay dưới chứa TOÀN BỘ các lá đã rút (cùng thứ tự). Chạm vào
///   một lá trong khay là chọn nó để đọc trên màn hình.
/// - Hoạt ảnh (HyperFrames + nghiên cứu hoạt ảnh mượt 2026-11-20):
///   rút bài = MỘT tween duy nhất (dịch + scale, easeOutCubic
///   500ms — power3.out, bắt đầu nhanh đuôi dài đáp mềm, không
///   nảy); đổi lá: lá mới LÊN sân từ dưới, lá cũ BAY VỀ KHAY
///   (về đúng vị trí của nó trong khay, một tween dịch + scale,
///   easeOutCubic 500ms, liền mạch, tuyệt đối không ngắt cảnh —
///   lá trong khay ẩn đi trong lúc bay, hiện lại đúng lúc đáp;
///   nếu đo rect không được thì giữ trượt xuống + mờ dần);
///   khay cao CỐ ĐỊNH (không co giãn làm bàn nhảy khung hình);
///   không đo layout khi bay, không hai hoạt ảnh cùng lúc trên
///   cùng một thuộc tính; tranh bàn lớn nạp trước (precacheImage)
///   + lá bay bọc RepaintBoundary để không vẽ lại cả bàn theo
///   từng khung hình.
class _NewReadingScreenState extends State<NewReadingScreen> {
  // Lá đang được đọc (panel giải nghĩa bên phải hiện nội dung của
  // lá này). -1 = chưa chọn lá nào, chỉ nhìn bàn.
  int _selectedCardIndex = -1;
  bool _showSelectionPanel = false; // Trạng thái mở khay chọn bài từ xấp bài
  TarotSuit _selectedSuit = TarotSuit.major; // Nhóm bài được chọn mặc định ban đầu là Ẩn Chính
  int? _lastDrawnId; // Lá vừa rút: bay từ xấp bài vào vị trí đọc trên màn hình (desktop) / bay lên (phone)
  bool _tableArtPrecached = false; // Tranh bàn (gỗ/khăn/decor) đã nạp trước chưa.
  // WIRING (V2 display path): id bộ bài đã nạp bản dịch vĩnh viễn
  // (để không nạp lại mỗi lần didChangeDependencies chạy).
  int? _preloadedDeckId;
  // Thanh cuộn của panel giải nghĩa (luôn hiện để thấy còn nội dung).
  final ScrollController _meaningScrollController = ScrollController();

  // Nhạc huyền bí (YouTube): controller + bài đang phát + ô nhập link.
  // Player YoutubePlayer nằm trong hộp 1×1 ở góc trên-trái của Stack
  // thân màn hình (giữ trong cây để nhạc chạy nền khi đóng panel
  // nhạc) — KHÔNG dùng Offstage vì iframe YouTube trong Offstage
  // không gắn được vào DOM trên Flutter web (làm trống cả thân màn
  // hình và lệnh phát không tới được). Nhạc KHÔNG tự phát khi mở
  // màn (autoPlay: false) — người dùng chạm một bài (hoặc nút phát)
  // mới phát, đúng luật autoplay của trình duyệt (phát tiếng phải
  // sau cử chỉ của người dùng).
  late final YoutubePlayerController _musicController =
      YoutubePlayerController.fromVideoId(
    videoId: kMysticTracks[0].videoId,
    autoPlay: false,
    params: const YoutubePlayerParams(
      showControls: false,
      showFullscreenButton: false,
      mute: false,
    ),
  );
  int _musicTrackIndex = 0; // -1 = đang phát link YouTube tự nhập
  String _musicTitle = kMysticTracks[0].title;
  final TextEditingController _ytLinkController = TextEditingController();
  double _musicVolume = 80; // 0..100

  // Bay về khay: lá rời sân khấu bay LIỀN MẠCH về đúng vị trí của
  // nó trong khay (không ngắt cảnh, không mờ dần rồi hiện). Một
  // flight tại một thời điểm. Lá trong khay ẩn đi trong lúc bay rồi
  // hiện lại đúng lúc đáp xuống (cùng rect nên không thấy nhảy).
  // Chỉ chạy trên desktop (sân khấu + khay cùng trong body PC);
  // phone giữ trượt xuống + mờ dần như cũ.
  final GlobalKey _flightLayerKey = GlobalKey();
  // Key sân khấu theo id lá (không dùng một GlobalKey chung: trong
  // lúc AnimatedSwitcher chuyển lá, lá cũ + lá mới cùng nằm trong
  // cây — một key chung là trùng key, Flutter báo lỗi).
  // Khóa là int? (không phải int) vì TarotCardModel.id là int?
  // (null với lá chưa vào DB) — map khóa int là sai kiểu, build
  // web gãy ("int? can't be assigned to int").
  final Map<int?, GlobalKey> _stageCardKeys = {};
  final Map<int?, GlobalKey> _trayItemKeys = {};
  _TrayFlight? _trayFlight;

  /// Lá đang hiển thị trên sân khấu (null = chưa rút lá nào).
  TarotCardModel? _currentStageCard() {
    final drawnCards = context.read<ReadingProvider>().drawnCards;
    if (drawnCards.isEmpty ||
        _selectedCardIndex < 0 ||
        _selectedCardIndex >= drawnCards.length) {
      return null;
    }
    return drawnCards[_selectedCardIndex];
  }

  /// Rect của một widget (theo key) đổi sang tọa độ của lớp bay
  /// (Stack bọc body desktop). Null = widget chưa build / không
  /// đo được (lá trong khay bị cuộn ra ngoài) → bỏ flight.
  Rect? _rectInFlightLayer(GlobalKey key) {
    final ctx = key.currentContext;
    final layerCtx = _flightLayerKey.currentContext;
    if (ctx == null || layerCtx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    final layerBox = layerCtx.findRenderObject() as RenderBox?;
    if (box == null || layerBox == null || !box.hasSize) return null;
    final topLeft =
        layerBox.globalToLocal(box.localToGlobal(Offset.zero));
    return topLeft & box.size;
  }

  /// Chuẩn bị flight cho lá `outgoing` (đang trên sân khấu): đo
  /// rect sân khấu (điểm đi) và rect ô của nó trong khay (điểm
  /// đến). Trả về flight, hoặc null nếu đo không được → bên gọi
  /// giữ hiệu ứng cũ (trượt xuống + mờ dần).
  _TrayFlight? _prepareTrayFlight(TarotCardModel outgoing) {
    final stageKey = _stageCardKeys[outgoing.id];
    final from = stageKey == null ? null : _rectInFlightLayer(stageKey);
    final trayKey = _trayItemKeys[outgoing.id];
    final to = trayKey == null ? null : _rectInFlightLayer(trayKey);
    if (from == null || to == null) return null;
    return _TrayFlight(card: outgoing, from: from, to: to);
  }

  @override
  void dispose() {
    _meaningScrollController.dispose();
    _musicController.close();
    _ytLinkController.dispose();
    super.dispose();
  }

  // Mật độ gọn cho PC 4K: mọi thứ nhỏ lại, bàn chiếm toàn bộ khung hình.
  bool get _isDesktop => Responsive.isDesktop(context);
  bool get _isPhone => Responsive.isPhone(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Nạp trước tranh bàn LỚN (gỗ 2.6MB, khăn 1.3MB, decor) để
    // giải mã + đưa lên GPU TRƯỚC khung hình đầu tiên, không phải
    // giữa hoạt ảnh rút bài (giải mã giữa chuyến bay = giật).
    // Chỉ nạp 1 lần; tranh lá bài đã ấm sẵn qua lưới chọn bài.
    if (!_tableArtPrecached) {
      _tableArtPrecached = true;
      for (final asset in const [
        'assets/images/table_bare_wood.png',
        'assets/images/cloth_purple_cut.png',
        'assets/images/cloth_gold_cut.png',
        'assets/images/cloth_black_cut.png',
        'assets/images/cut_crystal.png',
        'assets/images/cut_ball.png',
        'assets/images/cut_incense.png',
        'assets/images/cut_candle.png',
      ]) {
        precacheImage(AssetImage(asset), context);
      }
    }
    // WIRING (V2 display path): nạp bản dịch vĩnh viễn đã lưu của
    // bộ bài đang trải (ngôn ngữ hiện tại) để các lá vẽ từ bản đã
    // lưu thay vì dịch theo yêu cầu từng lá. Chỉ nạp một lần cho
    // mỗi bộ bài; nếu lá chưa tải xong (danh sách rỗng) thì để lần
    // didChangeDependencies sau (khi DeckProvider báo lá đã tải)
    // nạp lại. Nạp nền, không chặn màn hình — bàn phải hiện ngay;
    // bản đã lưu sẽ kịp cho các lá rút/chọn sau đó và cho lần mở
    // sau. (Khác deck_detail — ở đó chờ trước khi hiện lưới vì
    // lưới là toàn bộ nội dung màn hình.) Khách chưa đăng nhập
    // vẫn nạp được bộ bài cơ bản (dữ liệu chung, công khai).
    final deckProvider = context.read<DeckProvider>();
    final deck = deckProvider.selectedDeck;
    final deckCards = deckProvider.currentDeckCards;
    if (deck?.id != null &&
        deckCards.isNotEmpty &&
        _preloadedDeckId != deck!.id) {
      _preloadedDeckId = deck.id;
      unawaited(context.read<TranslationService>().preloadLocalDeck(
            deckId: deck.id,
            deckName: deck.name,
            cards: deckCards,
          ));
    }
  }

  // Chiều rộng lá bài đang chọn theo từng loại thiết bị (tỉ lệ 5:8).
  // PC 4K: 150 (gọn, không phải 240). Tablet ở giữa: 200. Phone giữ 180.
  double _activeCardWidth(BuildContext context) {
    if (Responsive.isDesktop(context)) return 150;
    if (Responsive.isTablet(context)) return 200;
    return 180;
  }

  double _meaningFontSize() => _isDesktop ? 14.0 : 15.0;
  double _cardNameFontSize() => _isDesktop ? 17.0 : (_isPhone ? 20.0 : 19.0);

  /// Chọn một lá để đọc: lá hiện trên màn hình (lá lớn + panel
  /// giải nghĩa ngay bên cạnh). Dùng chung cho chạm vào lá trong
  /// khay và (phone) chạm vào lá đang xem. BẢO TOÀN SỐ LƯỢNG LÁ:
  /// lá được chọn RỜI KHAY lên sân khấu, lá đang trên sân khấu
  /// (nếu có) THU XUỐNG KHAY — một lá chỉ ở đúng một nơi tại một
  /// thời điểm, không bao giờ hiện cả hai chỗ cùng lúc.
  void _selectCard(int index) {
    final drawnCards = context.read<ReadingProvider>().drawnCards;
    if (index < 0 || index >= drawnCards.length) return;
    if (index == _selectedCardIndex) return; // Đang đọc lá này rồi.
    final outgoing = _currentStageCard();
    final flight =
        outgoing == null ? null : _prepareTrayFlight(outgoing);
    setState(() {
      _trayFlight = flight;
      _selectedCardIndex = index;
      _showSelectionPanel = false;
      _lastDrawnId = null; // Hết trạng thái "vừa rút".
    });
  }

  /// Thu lá đang trên sân khấu xuống khay: ấn vào hình ảnh lá bài
  /// đang hiện giữa màn hình thì lá đó thu xuống khay, sân khấu
  /// trống (không còn lá nào đang đọc). Lá đó sau đó hiện trong
  /// khay — ấn vào nó trong khay thì nó lại lên sân khấu.
  /// Không làm gì nếu sân khấu đang trống.
  void _collectStageCard() {
    if (_currentStageCard() == null) return;
    setState(() {
      _selectedCardIndex = -1;
      _lastDrawnId = null;
    });
  }

  /// Rút một lá từ bộ bài: lá hiện lên sân khấu (lá đang đọc) và
  /// KHÔNG hiện trong khay (bảo toàn số lượng lá — một lá chỉ ở
  /// đúng một nơi). Lá đang trên sân khấu (nếu có) THU XUỐNG KHAY
  /// rồi lá mới bay từ xấp bài vào sân. Trả về false nếu lá đã rút rồi.
  bool _drawCardModel(TarotCardModel card) {
    final readingProvider = context.read<ReadingProvider>();
    if (readingProvider.drawnCards.any((dc) => dc.id == card.id)) {
      return false;
    }
    final outgoing = _currentStageCard();
    final flight =
        outgoing == null ? null : _prepareTrayFlight(outgoing);
    readingProvider.addCardToReading(card);
    setState(() {
      _trayFlight = flight;
      _lastDrawnId = card.id;
      _selectedCardIndex = readingProvider.drawnCards.length - 1;
    });
    // Sau khi hoạt ảnh rút xong (~500ms), bỏ dấu "vừa rút" để lá
    // không chạy lại hoạt ảnh khi màn hình build lại (đổi khăn...).
    final drawnId = card.id;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _lastDrawnId == drawnId) {
        setState(() => _lastDrawnId = null);
      }
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentThemeData;
    final readingProvider = context.watch<ReadingProvider>();
    final deckProvider = context.watch<DeckProvider>();

    final drawnCards = readingProvider.drawnCards;
    final deckCards = deckProvider.currentDeckCards;
    final prefs = settings.userPrefs;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        toolbarHeight: _isDesktop ? 44 : null,
        title: GestureDetector(
          onTap: () => _showEditTitleDialog(context, readingProvider),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: LocalizedReadingName(
                  name: readingProvider.currentReadingTitle,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: _isDesktop ? 15 : 16,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.edit, size: _isDesktop ? 15 : 18, color: theme.primaryColor),
            ],
          ),
        ),
        backgroundColor: theme.backgroundColor,
        foregroundColor: theme.primaryColor,
        elevation: 0,
        actions: [
          // Nhạc huyền bí: mở panel chọn bài / nhập link YouTube.
          // Nốt nhạc vàng khi đang phát, vàng nhạt khi dừng.
          YoutubeValueBuilder(
            controller: _musicController,
            builder: (context, value) {
              final playing =
                  value.playerState == PlayerState.playing;
              return IconButton(
                icon: Icon(
                  Icons.music_note,
                  color: playing ? Colors.amber : theme.primaryColor,
                ),
                tooltip: playing
                    ? settings.tr('reading.musicPlaying')
                    : settings.tr('reading.music'),
                onPressed: () => _openMusicSheet(context, theme),
              );
            },
          ),
          // Đổi bàn / khăn / đồ decor ngay trong lúc trải bài.
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: settings.tr('reading.changeTable'),
            onPressed: () => _showTableSettingsDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: settings.tr('reading.clearCards'),
            onPressed: () {
              readingProvider.startManualReading(readingProvider.currentReadingTitle);
              setState(() {
                _selectedCardIndex = -1;
                _showSelectionPanel = false;
                _lastDrawnId = null;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: settings.tr('reading.saveReading'),
            onPressed: () async {
              if (drawnCards.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(settings.tr('reading.saveNeedsCard'))),
                );
                return;
              }
              if (deckProvider.selectedDeck?.id != null) {
                await readingProvider.saveCurrentReading(deckProvider.selectedDeck!.id!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(settings.tr('reading.savedToHistory'))),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: SmokeParticleEffect(
        enableSmoke: settings.userPrefs.enableSmokeParticles,
        child: _buildTableBackground(
          prefs,
          // PC 4K: bàn chiếm toàn bộ viewport, KHÔNG bọc ResponsiveCenter
          // (không giới hạn 1080). Phone/tablet giữ bản đơn giản đã có.
          _isDesktop ? _buildDesktopBody(deckCards, readingProvider, theme) : SafeArea(
            child: ResponsiveCenter(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // Vùng chính: chọn bài hoặc xem lá bài + giải nghĩa.
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.04),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
                            child: child,
                          ),
                        );
                      },
                      child: _showSelectionPanel
                          ? _buildSelectionPanelWithEsc(deckCards, readingProvider, theme)
                          : _buildMainInteractiveLayout(drawnCards, readingProvider, theme),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Khay bài đã rút ở dưới cùng — section riêng, không
                  // bị panel giải nghĩa hay lá bài che khuất.
                  _buildBottomTray(drawnCards, readingProvider, theme),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    // Player nhạc YouTube: KHÔNG dùng Offstage — trên Flutter web,
    // HtmlElementView (iframe YouTube) nằm trong Offstage không gắn
    // được vào DOM nên widget YoutubePlayer lỗi ngay lúc build,
    // làm CẢ THÂN màn hình trải bài trống (chỉ còn AppBar) và lệnh
    // phát không tới được iframe (trạng thái không bao giờ thành
    // "đang phát", nút vẫn ▶, nốt nhạc không vàng). Thay vào đó
    // giữ player trong cây với kích thước 1×1 ở góc trên-trái
    // (gần như vô hình) để iframe được tạo và nhạc chạy nền khi
    // đóng panel nhạc.
    Positioned(
      left: 0,
      top: 0,
      child: SizedBox(
        width: 1,
        height: 1,
        child: YoutubePlayer(
          controller: _musicController,
          aspectRatio: 16 / 9,
        ),
      ),
    ),
  ],
      ),
    );
  }

  /// Thân màn hình riêng cho PC: bàn trải bài chiếm toàn bộ chiều
  /// rộng, khay ở dưới cùng. Không ResponsiveCenter.
  /// Bọc trong Stack (lớp bay) để lá rời sân khấu bay về khay ngay
  /// trên lớp này — Positioned theo tọa độ của Stack.
  Widget _buildDesktopBody(List<TarotCardModel> deckCards,
      ReadingProvider readingProvider, dynamic theme) {
    final settings = context.watch<SettingsProvider>();
    final drawnCards = readingProvider.drawnCards;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Stack(
          key: _flightLayerKey,
          children: [
            Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          drawnCardsCountText(settings),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: theme.secondaryTextColor, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _showSelectionPanel
                        ? _buildSelectionPanelWithEsc(deckCards, readingProvider, theme)
                        : _buildDesktopTable(drawnCards, readingProvider, theme),
                  ),
                ),
                const SizedBox(height: 8),
                _buildBottomTray(drawnCards, readingProvider, theme),
              ],
            ),
            // Lá bay về khay: phủ lên trên, không chặn chạm.
            if (_trayFlight != null) _buildTrayFlightOverlay(theme),
          ],
        ),
      ),
    );
  }

  /// Lớp bay về khay: lá rời sân khấu bay từ rect sân khấu về
  /// đúng rect ô của nó trong khay, MỘT tween duy nhất, chỉ
  /// transform (dịch + scale, easeOutCubic 500ms — cùng nhịp với
  /// flight rút bài), đáp xuống là đứng yên. Không đo layout khi
  /// bay, không hai hoạt ảnh cùng lúc trên cùng một thuộc tính.
  /// Lá trong khay ẩn đi trong lúc bay, hiện lại đúng lúc đáp
  /// (cùng rect) nên không thấy ngắt cảnh.
  Widget _buildTrayFlightOverlay(dynamic theme) {
    final flight = _trayFlight!;
    final toScale = flight.to.width / flight.from.width;
    final dx = flight.to.left - flight.from.left;
    final dy = flight.to.top - flight.from.top;
    return Positioned(
      left: flight.from.left,
      top: flight.from.top,
      width: flight.from.width,
      height: flight.from.height,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          onEnd: () {
            if (mounted && _trayFlight == flight) {
              setState(() => _trayFlight = null);
            }
          },
          builder: (context, v, child) {
            return Transform(
              alignment: Alignment.topLeft,
              transform: Matrix4.identity()
                ..translate(dx * v, dy * v)
                ..scale(1 + (toScale - 1) * v),
              child: child,
            );
          },
          child: RepaintBoundary(
            child: SizedBox(
              width: flight.from.width,
              height: flight.from.height,
              child: _cardFrame(flight.card, theme, flight.from.width),
            ),
          ),
        ),
      ),
    );
  }

  String drawnCardsCountText(SettingsProvider settings) {
    final n = context.read<ReadingProvider>().drawnCards.length;
    return n == 0
        ? settings.tr('reading.noCardsDrawn')
        : settings.tr('reading.drawnCount').replaceAll('{n}', '$n');
  }

  /// Bàn trải bài góc nhìn thứ nhất trên PC (HyperFrames, các lớp
  /// trong CÙNG Stack này): nền gỗ trống ở dưới, khăn là ảnh cắt
  /// trong suốt toàn khung (đặt trong _buildTableBackground, khớp
  /// pixel với nền gỗ) ở giữa, phụ kiện là ảnh cắt
  /// TRONG SUỐT đặt theo tọa độ cố định trên mép xa của bàn (đổi
  /// được) với bóng tiếp xúc vẽ bằng code, xấp bài ở góc trên-trái.
  /// Trên bàn KHÔNG còn lá nào: bàn chỉ là không gian. Lá đang
  /// đọc HIỆN TRÊN MÀN HÌNH (lá lớn 150 rộng + panel giải nghĩa
  /// ngay bên cạnh, ở giữa-phía trước) — đó là lá vừa rút hoặc
  /// lá được chọn từ khay. Khay dưới chứa TOÀN BỘ các lá đã rút.
  Widget _buildDesktopTable(List<TarotCardModel> drawnCards,
      ReadingProvider readingProvider, dynamic theme) {
    final activeCard = drawnCards.isNotEmpty &&
            _selectedCardIndex >= 0 &&
            _selectedCardIndex < drawnCards.length
        ? drawnCards[_selectedCardIndex]
        : null;
    final prefs = context.read<SettingsProvider>().userPrefs;

    return Stack(
      children: [
        // Chưa rút lá nào: gợi ý ở giữa bàn. Đã rút thì bàn chỉ
        // còn không gian (không còn lá nào nằm trên bàn nữa).
        if (drawnCards.isEmpty)
          Positioned.fill(
            child: _buildDesktopEmptyHint(theme),
          ),
        // Đã rút lá nhưng sân khấu đang trống (đã thu hết lá xuống
        // khay): gợi ý chạm vào lá trong khay để xem lại, hoặc
        // chạm xấp bài để rút thêm — bàn không trống trơn khó hiểu.
        if (activeCard == null && drawnCards.isNotEmpty)
          Positioned.fill(
            child: _buildDesktopEmptyHint(theme, hasDrawnCards: true),
          ),
        // Phụ kiện: ảnh CẮT TRONG SUỐT (chỉ giữ vật thể, nền
        // đã tách) đặt theo tọa độ phân số cố định trong code
        // (xem _buildDesktopDecorCutouts), cùng Stack với lớp
        // khăn nên luôn khớp khăn ở mọi viewport. Bóng tiếp xúc
        // vẽ bằng code ngay dưới chân mỗi vật. Đổi trong
        // dialog/Cài đặt cập nhật ngay với hiệu ứng mờ dần
        // (AnimatedSwitcher theo danh sách decor đã chọn).
        // IgnorePointer nên không bao giờ chặn lá bài.
        if (prefs.showDecor && prefs.decorItems.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.96, end: 1.0)
                          .animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut)),
                      child: child,
                    ),
                  );
                },
                child: _buildDesktopDecorCutouts(prefs.decorItems),
              ),
            ),
          ),
        // Xấp bài ở MỘT góc bàn: góc trên-trái, luôn hiện diện.
        // Neo vào góc trên-trái CỦA TRANH (phân số tranh 0.25,
        // 0.30), qua phép cover — bám đúng mặt gỗ khi co kéo
        // màn hình, thay vì neo cứng vào góc màn hình (rơi ra
        // vùng tối ngoài bàn). Neo ở 0.22 (sát mép trên của bàn)
        // làm đỉnh xấp bị CẮT ở màn hình thấp/toàn màn hình
        // (mép bàn nằm sát mép trên màn hình nên xấp cao 155px
        // chìa ra ngoài, bị Stack cắt); hạ xuống 0.30 thì cả xấp
        // luôn hiện đủ, vẫn trên mặt gỗ, không chạm thạch anh
        // (xấp x=480–564, thạch anh từ x=586).
        // Xấp bài CO DÃN CÙNG BÀN — scale thông thường, neo cứng
        // vào MỘT tọa độ trên tranh (phân số 0.25, 0.30): bọc
        // Transform.scale theo đúng tỉ lệ cover của tranh
        // (t.scale), neo góc trên-trái vào tọa độ đó. Khi co kéo
        // màn hình, bàn to ra/nhỏ lại thì xấp bài cũng to ra/nhỏ
        // lại theo đúng tỉ lệ đó, vị trí và kích thước tương quan
        // với bàn không đổi — như dán cứng lên mặt bàn. KHÔNG
        // kẹp tỉ lệ nữa: các kẹp 0.86 (§26) rồi 1.0 (§27) làm
        // xấp đứng yên một chỗ trong khi bàn co dãn — như tờ
        // giấy trên khay cát, khay mở rộng mà giấy vẫn đứng yên.
        // Scale thường, neo một điểm, là đủ.
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final t = _paintingCoverTransform(
                  constraints.maxWidth, constraints.maxHeight);
              return Stack(
                children: [
                  Positioned(
                    left: 0.25 * 1920 * t.scale + t.dx,
                    top: 0.30 * 1280 * t.scale + t.dy,
                    child: Transform.scale(
                      scale: t.scale,
                      alignment: Alignment.topLeft,
                      child: CardStackWidget(
                        onTap: () {
                          setState(() {
                            _showSelectionPanel = true;
                          });
                        },
                        theme: theme,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        // Lá đang đọc HIỆN TRÊN MÀN HÌNH: lá lớn 170 rộng ở
        // giữa-phía trước, panel giải nghĩa ngay BÊN CẠNH nó.
        // Đổi lá: lá MỚI lên sân từ dưới, lá CŨ THU XUỐNG KHAY
        // (trượt xuống + nhỏ dần + mờ dần, liền mạch — xem
        // _trayFlight; switcher không vẽ lá cũ nữa để không hiện
        // hai bản). Sân chỉ giữ một lá tại một thời điểm, và lá
        // trên sân KHÔNG hiện trong khay (bảo toàn số lượng lá).
        // Ấn vào lá trên sân: thu lá xuống khay (xem
        // _collectStageCard). Lá vừa rút thì bay từ xấp bài
        // (tween riêng), không trượt thêm (hai chuyển động cùng
        // lúc trên cùng một lá = giật). Vào 250ms / ra 150ms
        // (ra ngắn hơn ~40%). Nếu đo rect để bay về khay không
        // được (lá trong khay bị cuộn ra ngoài) thì giữ hiệu ứng
        // cũ: lá cũ trượt xuống + mờ dần.
        if (activeCard != null)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Nâng đáy sân khấu lên 10% chiều cao bàn để lá
                // + panel nằm hẳn trên khăn mà không chạm hàng
                // decor ở mép xa (14% đã để lá chạm đế quả cầu).
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(
                        bottom: constraints.maxHeight * 0.10),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      reverseDuration:
                          const Duration(milliseconds: 150),
                      // Mặc định của AnimatedSwitcher là linear
                      // (nhìn máy móc) — đặt rõ: vào easeOut, ra
                      // easeIn, theo nghiên cứu hoạt ảnh mượt.
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        // Lá ra mà đang bay về khay: switcher
                        // KHÔNG vẽ nó nữa (lớp bay vẽ nó rồi) —
                        // không hiện hai bản của cùng một lá.
                        final isIncoming = child.key ==
                            ValueKey('stage-${activeCard.id}');
                        if (!isIncoming &&
                            _trayFlight != null &&
                            child.key ==
                                ValueKey(
                                    'stage-${_trayFlight!.card.id}')) {
                          return const SizedBox.shrink();
                        }
                        // Lá vào (animation 0→1): trượt LÊN từ
                        // dưới (offset 0.25 → 0). Lá ra (animation
                        // 1→0): CÙNG tween đó chạy ngược nên trượt
                        // XUỐNG (0 → 0.25) + mờ dần. Lá vừa rút
                        // (bay từ xấp bài bằng tween riêng) thì
                        // không trượt thêm, chỉ mờ. Lá ra còn NHỎ
                        // DẦN (1.0 → 0.55) để đọc rõ là "thu xuống
                        // khay" chứ không phải biến mất; lá vào giữ
                        // nguyên cỡ.
                        final isJustDrawn = isIncoming &&
                            activeCard.id == _lastDrawnId;
                        final slide = isJustDrawn
                            ? Tween<Offset>(
                                begin: Offset.zero, end: Offset.zero)
                            : Tween<Offset>(
                                begin: const Offset(0, 0.25),
                                end: Offset.zero);
                        final scale = isIncoming
                            ? Tween<double>(begin: 1.0, end: 1.0)
                            : Tween<double>(begin: 0.55, end: 1.0);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: slide.animate(animation),
                            child: ScaleTransition(
                              scale: scale.animate(animation),
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: _buildDesktopStage(activeCard, theme),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  /// Lá đang đọc HIỆN TRÊN MÀN HÌNH (PC): lá lớn 190 rộng + panel
  /// giải nghĩa ngay bên cạnh (500 rộng — khung văn bản lớn để đọc
  /// thoải mái, hiện nhiều chữ cùng lúc), căn giữa phía trước bàn. Đây là lá HIỂN THỊ để
  /// đọc (phần tử màn hình), KHÔNG phải vật nằm trên mặt bàn — nên
  /// lá đứng thẳng facing màn hình, không nghiêng theo điểm tụ của
  /// bàn. Trên bàn không còn lá nào. Ấn vào lá: thu lá xuống khay
  /// (bảo toàn số lượng lá — lá trên sân không hiện trong khay).
  Widget _buildDesktopStage(TarotCardModel activeCard, dynamic theme) {
    const stageCardWidth = 190.0;
    final stageCardHeight = stageCardWidth * 8 / 5;
    return Center(
      key: ValueKey('stage-${activeCard.id}'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDesktopStageCard(activeCard, theme, stageCardWidth),
          const SizedBox(width: 16),
          // Panel giải nghĩa ngay bên cạnh lá lớn, cao bằng lá + 24.
          SizedBox(
            width: 500,
            height: stageCardHeight + 24,
            child: _buildDesktopMeaningPanel(activeCard, theme),
          ),
        ],
      ),
    );
  }

  /// Lá lớn trên màn hình PC: 150 rộng, viền vàng + glow, đứng
  /// thẳng (lá hiển thị để đọc, không nằm trên bàn). Lá vừa rút
  /// bay từ xấp bài (góc trên-trái) vào vị trí này trong 500ms:
  /// MỘT tween duy nhất, chỉ transform (dịch + scale), ease
  /// easeOutCubic (power3.out — nghiên cứu tổng hợp: bắt đầu
  /// nhanh, đuôi dài đáp mềm, không nảy) — không còn easeOutBack
  /// (nảy quá đà = giật) và không đo layout khi bay. Lá bọc
  /// RepaintBoundary để bàn/khay không vẽ lại theo từng khung
  /// hình bay. Đáp xuống là đứng yên hẳn, không còn chuyển
  /// động nào nữa.
  Widget _buildDesktopStageCard(
      TarotCardModel activeCard, dynamic theme, double width) {
    final settings = context.watch<SettingsProvider>();
    final isNew = activeCard.id == _lastDrawnId;
    final tile = RepaintBoundary(
      child: SizedBox(
        // Key riêng theo id lá để đo rect lá trên sân khấu (điểm
        // đi của flight về khay). Dùng key theo id (không dùng
        // một key chung) vì lá cũ + lá mới cùng nằm trong cây
        // trong lúc AnimatedSwitcher chuyển lá.
        key: _stageCardKeys.putIfAbsent(activeCard.id, () => GlobalKey()),
        width: width,
        height: width * 8 / 5,
        child: _cardFrame(activeCard, theme, width),
      ),
    );
    final Widget animated;
    if (!isNew) {
      animated = tile;
    } else {
      // Hoạt ảnh rút bài: MỘT tween — bay từ hướng xấp bài vào vị
      // trí đọc, nhỏ->lớn dần, đáp mềm bằng easeOutCubic.
      animated = TweenAnimationBuilder<double>(
        key: ValueKey('draw-${activeCard.id}'),
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, v, child) {
          return Transform.translate(
            offset: Offset(-360 * (1 - v), -240 * (1 - v)),
            child: Transform.scale(scale: 0.6 + 0.4 * v, child: child),
          );
        },
        child: tile,
      );
    }
    // Ấn vào lá trên sân khấu: thu lá xuống khay (bảo toàn số
    // lượng lá — một lá chỉ ở đúng một nơi). Tooltip hiện khi
    // rê chuột qua lá.
    return Tooltip(
      message: settings.tr('reading.tapToCollect'),
      child: GestureDetector(
        onTap: _collectStageCard,
        child: animated,
      ),
    );
  }

  /// Bóng đổ THẬT (cast shadow) của một vật: lấy đúng hình dáng
  /// (silhouette) của vật, chiếu xuống-phải theo hướng đèn.
  ///
  /// Cách tính — ánh sáng chính ấm từ trên-trái, bóng hắt
  /// xuống-phải. Một điểm trên vật ở độ cao h so với mặt bàn thì
  /// bóng của nó dời (h*kx, h*ky) theo hướng đèn: điểm càng cao
  /// thì bóng càng xa chân vật. Trong tọa độ widget (y tăng xuống
  /// dưới), điểm ở đỉnh vật (y nhỏ) dời nhiều hơn điểm ở chân
  /// (y lớn). Ma trận thực hiện đúng hình chiếu đó: neo ở
  /// bottomCenter (chân vật đứng yên), nghiêng setEntry(0, 1, -kx)
  /// để đỉnh vật ngả sang phải, rồi dịch cả bóng xuống-phải.
  /// (Matrix4 của vector_math không có skewX — nghiêng bằng
  /// setEntry(0, 1, s) cho x' = x + s*y.)
  /// Silhouette lấy từ chính ảnh cắt của vật (ColorFiltered đen,
  /// BlendMode.srcIn) nên bóng có đúng hình dáng vật — gai thạch
  /// anh, thân nến, lư hương, đế cầu — không phải ellipse chung
  /// chung. Làm mờ bằng ImageFiltered (blur) cho viền mềm (bán
  /// dạ). Quả cầu pha lê trong suốt nên bóng nhạt hơn (vật trong
  /// suốt cho ánh sáng xuyên qua, chỉ đế và viền đổ bóng đậm).
  /// Độ mờ và độ sắc: bóng thật trên bàn là một vùng tối MỀM
  /// và NHẠT — ánh sáng bị chặn một phần, vân gỗ/vân vải vẫn
  /// thấy qua, viền loang dần chứ không phải mảng đen đặc.
  /// Blur sigma 5.0 cho viền thật mềm (ánh sáng khuếch tán),
  /// độ mờ 0.25 để bóng chỉ là vùng tối nhẹ, không thành vệt
  /// mực đen. Nghiêng rất nhẹ (kx 0.10) và chiếu NGẮN
  /// (dịch 0.18w, 0.09h): bóng của vật nhỏ trên bàn, dưới đèn
  /// ấm treo cao, là một vùng tối ngắn sát chân vật, hình dáng
  /// gần như vật — không phải vệt dài kéo lê. Bóng dài + đậm
  /// (§29–§31) trông như vết mực loang trên khăn sáng, xấu.
  /// Quả cầu 0.18 (vẫn nhạt nhất vì trong suốt).
  /// Trả về một Positioned.fill để đặt trong Stack của vật
  /// (Stack phải có clipBehavior: Clip.none để bóng tràn ra
  /// ngoài khung vật, xuống-phải mặt khăn).
  Widget _realCastShadow({
    required String asset,
    required double boxWidth,
    required double boxHeight,
    double opacity = 0.25,
  }) {
    const kx = 0.10; // nghiêng rất nhẹ theo hướng đèn (giữ hình dáng)
    return Positioned.fill(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.identity()
            ..translate(boxWidth * 0.18, boxHeight * 0.09)
            ..setEntry(0, 1, -kx) // nghiêng: x' = x - kx*y (đỉnh ngả phải)
            ..scale(1.06, 0.96),
          child: Opacity(
            opacity: opacity,
            child: ColorFiltered(
              colorFilter:
                  const ColorFilter.mode(Colors.black, BlendMode.srcIn),
              child: Image.asset(asset, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  /// Phụ kiện trên mép xa của bàn PC: các ảnh CẮT TRONG SUỐT (chỉ
  /// giữ vật thể, nền đã tách) đặt theo tọa độ phân số CỐ ĐỊNH
  /// trong code (xem _decorCutoutRect — một nguồn sự thật duy
  /// nhất, không đo ngược pixel), tính theo PHÂN SỐ CỦA TRANH
  /// GỐC (1920x1280) rồi qua _paintingCoverTransform (đúng phép
  /// cover của nền gỗ/khăn) nên luôn khớp khăn ở mọi viewport,
  /// kể cả khi co kéo đổi tỉ lệ màn hình. Bóng tiếp xúc vẽ bằng
  /// code ngay dưới chân mỗi vật (xem _buildDesktopDecorCutout): KHÔNG ClipOval,
  /// KHÔNG nền đen sau ảnh, KHÔNG xếp hàng đều, KHÔNG thu nhỏ
  /// theo chiều sâu. Khung của mỗi vật tính theo CHIỀU RỘNG, chiều
  /// cao suy từ tỉ lệ thật của ảnh — KHÔNG BoxFit.fill (khung phân
  /// số trên viewport 16:9 có tỉ lệ khác ảnh gốc nên vật bị kéo
  /// méo).
  Widget _buildDesktopDecorCutouts(List<String> items) {
    // Key theo danh sách món đã chọn để AnimatedSwitcher ở trên
    // nhận ra khi decor đổi và chạy hiệu ứng mờ/scale.
    return LayoutBuilder(
      key: ValueKey(items.join(',')),
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          children: [
            for (final item in items)
              _buildDesktopDecorCutout(item, w, h),
          ],
        );
      },
    );
  }

  /// Một món decor đặt theo tọa độ phân số cố định trong code
  /// (xem _decorCutoutRect — PHÂN SỐ CỦA TRANH GỐC, qua
  /// _paintingCoverTransform mới ra tọa độ widget): neo góc
  /// trên-trái tại (x, y) phân số của tranh. KHUNG TÍNH THEO
  /// CHIỀU RỘNG (rộng = w phân số tranh x 1920 x scale cover),
  /// _decorCutoutAspect) — KHÔNG BAO GIỜ BoxFit.fill: khung phân
  /// số trên viewport 16:9 có tỉ lệ khác ảnh gốc nên vật bị kéo
  /// méo. Ảnh trong suốt vẽ bằng BoxFit.contain trong khung đúng
  /// tỉ lệ. Bóng tiếp xúc là một ellipse đen mờ vẽ bằng code NGAY
  /// DƯỚI CHÂN vật (dưới đáy khung) để vật "đứng trên" mặt gỗ.
  Widget _buildDesktopDecorCutout(String item, double w, double h) {
    final asset = _decorCutoutAsset(item);
    final rect = _decorCutoutRect(item);
    if (asset == null || rect == null) {
      // Món chưa có ảnh cắt vẽ (hiện là 'Lá Khô'): KHÔNG vẽ gì cả.
      // Tuyệt đối không dùng icon phẳng (Icons.eco) làm fallback —
      // người dùng đã từ chối icon Material cho decor, và icon cũ
      // còn đè đúng ô của Hương Trầm (x .52, y .10) nên hai món
      // chồng lên nhau khi chọn cả hai. Muốn hiện món này thì vẽ
      // ảnh cắt thật rồi thêm vào _decorCutoutAsset/_decorCutoutRect.
      return const SizedBox.shrink();
    }
    // Tọa độ trong Rect là PHÂN SỐ CỦA TRANH GỐC — phải qua
    // _paintingCoverTransform (đúng phép cover của nền gỗ/khăn)
    // thì vật mới bám đúng mặt bàn ở mọi tỉ lệ màn hình.
    // Rộng theo phân số tranh; cao suy từ tỉ lệ thật của ảnh.
    final t = _paintingCoverTransform(w, h);
    final boxWidth = rect.width * 1920 * t.scale;
    final boxHeight = boxWidth * _decorCutoutAspect(item);
    return Positioned(
      left: rect.left * 1920 * t.scale + t.dx,
      top: rect.top * 1280 * t.scale + t.dy,
      width: boxWidth,
      height: boxHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Bóng ĐỔ THẬT: silhouette của chính vật, chiếu
          // xuống-phải theo hướng đèn (xem _realCastShadow).
          // Ellipse radial-gradient cũ là đốm mờ chung chung,
          // không khớp hình dáng vật nên nhìn xấu. Quả cầu pha
          // lê trong suốt nên bóng nhạt hơn.
          _realCastShadow(
            asset: asset,
            boxWidth: boxWidth,
            boxHeight: boxHeight,
            opacity: item == 'Quả Cầu' ? 0.18 : 0.25,
          ),
          // Bóng tiếp xúc vẽ bằng code: ellipse đen mờ nằm NGAY
          // DƯỚI CHÂN vật, chạm vào đáy khung — vật "đứng trên"
          // mặt gỗ thay vì lơ lửng. (Ảnh cắt trong suốt nên bóng
          // cũ trong tranh đã mất theo nền khi tách.)
          Positioned(
            left: boxWidth * 0.08,
            right: boxWidth * 0.08,
            bottom: 0,
            height: boxHeight * 0.16,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.black.withOpacity(0.55),
                    Colors.black.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          // Ảnh cắt trong suốt: chỉ vật thể, không nền, không
          // hộp đen sau lưng — đặt lên bàn là hòa vào tranh.
          Positioned.fill(
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }

  /// Tỉ lệ cao/rộng của ảnh cắt từng món — dùng để tính chiều cao
  /// khung từ chiều rộng (KHÔNG dùng BoxFit.fill: khung phân số
  /// trên viewport 16:9 có tỉ lệ khác ảnh gốc nên vật bị kéo méo).
  double _decorCutoutAspect(String item) {
    switch (item) {
      case 'Đá Thạch Anh':
        return 205 / 221; // cut_crystal.png 221x205
      case 'Quả Cầu':
        return 239 / 206; // cut_ball.png 206x239
      case 'Hương Trầm':
        return 345 / 250; // cut_incense.png 250x345
      case 'Nến Đen':
        return 307 / 220; // cut_candle.png 220x307
      default:
        return 1.0;
    }
  }

  /// Ảnh cắt (cut-out) của từng món decor trong tranh bàn gốc,
  /// null = chưa có ảnh cắt: món đó không được chọn trong dialog
  /// và không vẽ gì trên bàn (tuyệt đối không dùng icon fallback).
  String? _decorCutoutAsset(String item) {
    switch (item) {
      case 'Đá Thạch Anh':
        return 'assets/images/cut_crystal.png';
      case 'Quả Cầu':
        return 'assets/images/cut_ball.png';
      case 'Hương Trầm':
        return 'assets/images/cut_incense.png';
      case 'Nến Đen':
        return 'assets/images/cut_candle.png';
      default:
        return null; // 'Lá Khô': chưa có ảnh cắt.
    }
  }

  /// Phép biến đổi BoxFit.cover của tranh bàn gốc (1920x1280)
  /// trong một khung w x h — ĐÚNG phép mà nền gỗ (DecorationImage)
  /// và khăn (Image cover) đang dùng. Trả về tỉ lệ scale và độ
  /// dời (dx, dy) để đổi một điểm phân số của tranh sang tọa độ
  /// widget: x = fx*1920*scale + dx, y = fy*1280*scale + dy.
  /// Dùng phép này thì decor + xấp bài + ô gợi ý luôn bám đúng
  /// mặt bàn khi co kéo màn hình (tỉ lệ khung hình đổi → tranh
  /// bị cắt khác đi, vật dời theo đúng tỉ lệ đó), thay vì neo
  /// cứng vào góc/khung màn hình rồi rơi ra ngoài bàn.
  ({double scale, double dx, double dy}) _paintingCoverTransform(
      double w, double h) {
    const pw = 1920.0;
    const ph = 1280.0;
    final scale = w / pw > h / ph ? w / pw : h / ph;
    final dx = (w - pw * scale) / 2;
    final dy = (h - ph * scale) / 2;
    return (scale: scale, dx: dx, dy: dy);
  }

  /// Tọa độ LỚP (layout constants) của từng món decor — PHÂN SỐ
  /// CỦA TRANH GỐC (1920x1280), MỘT NGUỒN SỰ THẬT DUY NHẤT cho
  /// vị trí vật trên bàn (HyperFrames: bố cục định trong code
  /// trước, ảnh trong suốt chỉ đặt vào đúng tọa độ này). Đáy khung
  /// (chân vật) neo vào mép xa của khăn, hàng decor dời sang phải
  /// một chút để nhường góc trên-trái cho xấp bài. Chiều cao
  /// trong Rect này KHÔNG dùng để đặt khung nữa (khung tính từ
  /// chiều rộng + tỉ lệ thật của ảnh, xem _decorCutoutAspect);
  /// nó chỉ còn là vị trí gốc đã đo từ tranh master. Khi vẽ
  /// (_buildDesktopDecorCutout) phải qua _paintingCoverTransform
  /// thì vật mới bám đúng mặt bàn ở mọi tỉ lệ màn hình.
  Rect? _decorCutoutRect(String item) {
    // Đáy của cả 4 món CÙNG nằm trên một đường sâu (y=0.43 của
    // tranh) — vật nào cũng đứng trên cùng một mặt bàn, hàng decor
    // thẳng hàng, không món nào lún cao/thấp hơn món khác. (Trước
    // đây đáy lệch nhau 0.423–0.443 nên hàng nhìn hơi xộc xệch.)
    // Top = 0.43 − chiều cao khung (khung tính từ chiều rộng +
    // tỉ lệ thật của ảnh, xem _decorCutoutAspect).
    switch (item) {
      case 'Đá Thạch Anh':
        return const Rect.fromLTWH(0.305, 0.291, 0.10, 0.139);
      case 'Quả Cầu':
        return const Rect.fromLTWH(0.428, 0.273, 0.09, 0.157);
      case 'Hương Trầm':
        return const Rect.fromLTWH(0.58, 0.202, 0.11, 0.228);
      case 'Nến Đen':
        return const Rect.fromLTWH(0.685, 0.221, 0.10, 0.209);
      default:
        return null;
    }
  }

  /// Một sprite phụ kiện: ảnh CẮT VẼ (cut_*.png, trong suốt) như
  /// PC — không còn sprite cũ (decor_*_painted.png) trong ô đen.
  /// Ảnh cắt trong suốt nên KHÔNG có nền đen sau ảnh; vật hòa vào
  /// mặt bàn như một bức ảnh hoàn chỉnh. Món chưa có ảnh cắt
  /// (Lá Khô) KHÔNG vẽ gì cả — tuyệt đối không dùng icon phẳng
  /// làm fallback. Vật thể BÁM SÁT mặt bàn:
  /// KHÔNG còn bóng đổ lơ lửng quanh sprite (boxShadow offset).
  /// Thay vào đó là một ellipse đen nằm NGAY DƯỚI CHÂN vật, chạm
  /// vào đáy sprite — vật "đứng trên" mặt gỗ/khăn, chân đặt đúng
  /// đường mặt bàn.
  Widget _buildDecorSprite(String item, double size) {
    final asset = _decorCutoutAsset(item);
    if (asset == null) {
      // Món chưa có ảnh cắt vẽ (hiện là 'Lá Khô'): không vẽ gì —
      // không icon phẳng, không ô đen (xem _buildDesktopDecorCutout).
      return const SizedBox.shrink();
    }
    final body = Image.asset(asset,
        fit: BoxFit.contain, width: size, height: size);
    return SizedBox(
      width: size,
      height: size + 12,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Bóng đổ THẬT: silhouette của chính vật, chiếu
          // xuống-phải theo hướng đèn (xem _realCastShadow).
          // Ellipse radial-gradient cũ là đốm mờ chung chung,
          // không khớp hình dáng vật nên nhìn xấu. Quả cầu pha
          // lê trong suốt nên bóng nhạt hơn.
          _realCastShadow(
            asset: asset,
            boxWidth: size,
            boxHeight: size,
            opacity: item == 'Quả Cầu' ? 0.18 : 0.25,
          ),
          // Bóng tiếp xúc: ellipse đen ngay dưới chân vật.
          Positioned(
            left: size * 0.05,
            right: size * 0.05,
            bottom: 0,
            height: 12,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.55),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          Positioned(top: 0, left: 0, child: body),
        ],
      ),
    );
  }

  Widget _buildDesktopEmptyHint(dynamic theme, {bool hasDrawnCards = false}) {
    final settings = context.watch<SettingsProvider>();
    // Ô gợi ý đặt ở TÂM TẤM KHĂN (phân số tranh 0.5, 0.55),
    // không phải tâm màn hình — bám theo tranh khi co kéo
    // (xem _paintingCoverTransform). Nhờ đó ô nằm giữa khăn,
    // không đè lên lư hương ở mép xa.
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final t = _paintingCoverTransform(w, h);
        final cx = 0.5 * 1920 * t.scale + t.dx;
        final cy = 0.55 * 1280 * t.scale + t.dy;
        final align = Alignment(
          (cx - w / 2) / (w / 2),
          (cy - h / 2) / (h / 2),
        );
        return Align(
          alignment: align,
          child: GlassPanel(
            backgroundColor: Colors.black.withOpacity(0.55),
            borderColor: theme.primaryColor.withOpacity(0.3),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 22),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showSelectionPanel = true;
                        });
                      },
                      icon: const Icon(Icons.style, size: 18),
                      label: Text(settings.tr('reading.selectCard'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasDrawnCards
                        ? settings.tr('reading.emptyHintCollected')
                        : settings.tr('reading.emptyHintDesktop'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white, fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Panel giải nghĩa gọn trên PC: tên lá + nội dung. Lá đang
  /// chọn hiện trên màn hình; panel chỉ hiện nội dung của lá
  /// đang chọn (xem _buildDesktopTable).
  Widget _buildDesktopMeaningPanel(TarotCardModel activeCard, dynamic theme) {
    return GlassPanel(
      backgroundColor: Colors.black.withOpacity(0.72),
      borderColor: theme.primaryColor.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LocalizedCardName(
              card: activeCard,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.primaryColor,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Scrollbar(
                controller: _meaningScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _meaningScrollController,
                  child: SelectionArea(
                    child: LocalizedCardMeaning(
                      card: activeCard,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14, height: 1.6),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mở panel nhạc huyền bí (bottom sheet): bài đang phát + phát/dừng,
  /// âm lượng, danh sách 5 bài có sẵn, ô nhập link YouTube để phát nhạc.
  /// Panel là một route riêng (bottom sheet) nên nó giữ state hiện
  /// tại của riêng nó (bài đang chọn, âm lượng) và báo về màn hình
  /// qua callback để đổi bài / đổi âm lượng thật trên controller.
  void _openMusicSheet(BuildContext context, dynamic theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return MysticMusicSheet(
          controller: _musicController,
          tracks: kMysticTracks,
          currentIndex: _musicTrackIndex,
          currentTitle: _musicTitle,
          volume: _musicVolume,
          linkController: _ytLinkController,
          onSelectTrack: (index) {
            final track = kMysticTracks[index];
            _musicController.loadVideoById(videoId: track.videoId);
            setState(() {
              _musicTrackIndex = index;
              _musicTitle = track.title;
            });
          },
          onPlayCustom: (videoId, title) {
            _musicController.loadVideoById(videoId: videoId);
            setState(() {
              _musicTrackIndex = -1;
              _musicTitle = title;
            });
          },
          onVolumeChanged: (v) {
            _musicController.setVolume(v.round());
            setState(() => _musicVolume = v);
          },
        );
      },
    );
  }

  /// Dialog đổi bàn / khăn / decor ngay trong lúc trải bài (PC + phone).
  /// Bố cục: hai cột trên desktop (trái: bàn + khăn, phải:
  /// decor + lớp hiển thị), một cột trên phone; chọn bằng chip
  /// nhìn (không còn dropdown) cho nhanh; danh sách dùng chung
  /// hằng số trong UserPreferencesModel (không hard-code riêng
  /// nữa) để không lệch với màn Cài đặt.
  ///
  /// Nội dung dialog VẼ LẠI theo SettingsProvider (Consumer trong
  /// builder của showDialog): trước đây các cột chip/toggle được
  /// dựng MỘT LẦN từ `prefs` chụp lúc mở dialog, còn builder
  /// không watch provider, nên chạm chọn gì cũng không đổi trạng
  /// thái hiển thị trong dialog (chip không tick, toggle không
  /// gạt, đổi ngôn ngữ/theme lúc dialog mở cũng không cập nhật)
  /// — chỉ mở lại dialog mới thấy đúng. Bàn phía sau thì vẫn đổi
  /// ngay vì màn hình chính có watch, nên dialog trông như "chọn
  /// mà không ăn".
  ///
  /// Chỉ món/kiểu CÓ TRANH VẼ mới được chọn ở đây (xem
  /// _tableStyleHasPaintedArt / _decorCutoutAsset): 'Đá Cổ' /
  /// 'Vũ Trụ' chưa có tranh bàn vẽ, 'Lá Khô' chưa có ảnh cắt —
  /// chọn chúng cũng không đổi được gì trên bàn, nên không hiện
  /// làm lựa chọn. Danh sách gốc trong UserPreferencesModel giữ
  /// nguyên (không đổi tên giá trị đã lưu).
/// Chip labels for the table / cloth / decor option ids shown in
/// the in-reading table dialog use the shared mapping in
/// `core/display_labels.dart` (Worker A) — see `optionLabel` below.
/// The option ids themselves ('Gỗ Sồi', 'Nhung Tím', …) are STORED
/// values and are never changed; only the chip LABEL is localized.
/// Selection, callbacks and stored values compare against the raw
/// id, never the label.

  void _showTableSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Consumer<SettingsProvider>(
          builder: (context, settings, _) {
            final theme = settings.currentThemeData;
            final prefs = settings.userPrefs;
            final isDesktop = Responsive.isDesktop(context);

            Widget sectionTitle(String title) => Text(title,
                style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13));

            // Localized chip label for a table/cloth/decor option id,
            // via the shared mapping in `core/display_labels.dart`
            // (same keys as the old local map: table.oak, cloth.*,
            // decor.*). Each helper returns the id unchanged when it
            // does not know it, so the three are tried in turn; an
            // unknown id (e.g. 'Đá Cổ' / 'Vũ Trụ' / 'Lá Khô', which
            // are filtered out of the chip lists today) falls back to
            // the raw id, exactly as before.
            String optionLabel(String opt) {
              var key = tableStyleDisplayKey(opt);
              if (key == opt) key = clothDisplayKey(opt);
              if (key == opt) key = decorDisplayKey(opt);
              return key == opt ? opt : settings.tr(key);
            }

            Widget optionChips({
              required List<String> options,
              required String selected,
              required ValueChanged<String> onSelected,
            }) {
              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: options.map((opt) {
                  final isSelected = opt == selected;
                  return ChoiceChip(
                    label: Text(optionLabel(opt),
                        style: TextStyle(
                            color: isSelected
                                ? Colors.black
                                : theme.textColor,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal)),
                    selected: isSelected,
                    selectedColor: theme.primaryColor,
                    backgroundColor: Colors.white10,
                    side: BorderSide(
                        color: isSelected
                            ? theme.primaryColor
                            : theme.glassBorderColor),
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => onSelected(opt),
                  );
                }).toList(),
              );
            }

            Widget decorChips() {
              // Chỉ món có ảnh cắt vẽ thật mới hiện làm lựa chọn
              // ('Lá Khô' chưa có ảnh cắt nên không có ở đây).
              final availableDecor = UserPreferencesModel.decorOptions
                  .where((item) => _decorCutoutAsset(item) != null)
                  .toList();
              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: availableDecor.map((item) {
                  final selected = prefs.decorItems.contains(item);
                  return FilterChip(
                    selectedColor: theme.primaryColor.withOpacity(0.3),
                    checkmarkColor: theme.primaryColor,
                    label: Text(optionLabel(item),
                        style: TextStyle(
                            color: selected
                                ? theme.primaryColor
                                : theme.textColor,
                            fontSize: 12)),
                    selected: selected,
                    visualDensity: VisualDensity.compact,
                    onSelected: (v) {
                      // Bỏ món không có ảnh vẽ ra khỏi danh sách đã
                      // lưu TRƯỚC khi đếm: món đó không hiện trong
                      // dialog và không vẽ trên bàn, nhưng vẫn chiếm
                      // 1 trong 3 suất nếu còn sót trong decorItems
                      // đã lưu (vd. đã chọn 'Lá Khô' từ bản cũ) —
                      // không lọc thì người dùng không thêm được món
                      // mới dù trên dialog chỉ thấy 2 món đã chọn.
                      final current = prefs.decorItems
                          .where((i) => _decorCutoutAsset(i) != null)
                          .toList();
                      if (v) {
                        if (current.length <
                            UserPreferencesModel.maxDecorItems) {
                          current.add(item);
                          settings.setDecorItems(current);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(settings
                                    .tr('reading.maxDecor')
                                    .replaceAll('{n}',
                                        '${UserPreferencesModel.maxDecorItems}')),
                                duration: const Duration(seconds: 1)),
                          );
                          // Danh sách không đổi -> không gọi setter
                          // (trước đây vẫn gọi setDecorItems với
                          // danh sách cũ, gây notify + ghi lại vô ích).
                        }
                      } else {
                        current.remove(item);
                        settings.setDecorItems(current);
                      }
                    },
                  );
                }).toList(),
              );
            }

            Widget layerSwitch({
              required String title,
              required bool value,
              required ValueChanged<bool> onChanged,
            }) {
              return SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text(title,
                    style:
                        TextStyle(color: theme.textColor, fontSize: 13)),
                value: value,
                activeColor: theme.primaryColor,
                onChanged: onChanged,
              );
            }

            // Kiểu bàn đang HIỆU LỰC trên bàn: giá trị đã lưu mà
            // chưa có tranh vẽ ('Đá Cổ' / 'Vũ Trụ') thì bàn thực tế
            // vẫn là gỗ vẽ, nên chip 'Gỗ Sồi' phải hiện là đã chọn
            // chứ không phải không có chip nào được chọn.
            final effectiveTableStyle =
                _tableStyleHasPaintedArt(prefs.tableStyle)
                    ? prefs.tableStyle
                    : 'Gỗ Sồi';

            final tableAndCloth = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                sectionTitle(settings.tr('reading.tableSurface')),
                const SizedBox(height: 6),
                optionChips(
                  options: UserPreferencesModel.tableStyles
                      .where(_tableStyleHasPaintedArt)
                      .toList(),
                  selected: effectiveTableStyle,
                  onSelected: (v) => settings.setTableStyle(v),
                ),
                // KHÔNG còn ghi chú reading.tableNote ở đây: nó nói
                // "áp dụng trên điện thoại / máy tính bảng, bản PC
                // dùng tranh bàn gỗ trống" — sai cả hai vế, vì
                // _buildTableBackground dùng tranh gỗ vẽ cho MỌI
                // thiết bị và tableStyle không đổi được mặt bàn nào.
                // Chỉ còn một kiểu bàn có tranh vẽ nên cũng không
                // còn gì để giải thích thêm.
                const SizedBox(height: 14),
                sectionTitle(settings.tr('reading.tablecloth')),
                const SizedBox(height: 6),
                optionChips(
                  options: UserPreferencesModel.clothStyles,
                  selected: prefs.clothStyle,
                  onSelected: (v) => settings.setClothStyle(v),
                ),
                const SizedBox(height: 4),
                Text(
                  settings.tr('reading.clothNote'),
                  style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 11,
                      height: 1.4),
                ),
              ],
            );

            final decorAndLayers = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                sectionTitle(settings
                    .tr('reading.decor')
                    .replaceAll(
                        '{n}', '${UserPreferencesModel.maxDecorItems}')),
                const SizedBox(height: 6),
                decorChips(),
                const SizedBox(height: 14),
                sectionTitle(settings.tr('reading.showLayers')),
                layerSwitch(
                  title: settings.tr('reading.showTable'),
                  value: prefs.showTable,
                  onChanged: (v) => settings.toggleTable(v),
                ),
                layerSwitch(
                  title: settings.tr('reading.showCloth'),
                  value: prefs.showCloth,
                  onChanged: (v) => settings.toggleCloth(v),
                ),
                layerSwitch(
                  title: settings.tr('reading.showDecor'),
                  value: prefs.showDecor,
                  onChanged: (v) => settings.toggleDecor(v),
                ),
              ],
            );

            return AlertDialog(
              // scrollable: true để nút "Xong" (actions) luôn nằm
              // ngoài vùng cuộn và chạm được, kể cả khi viewport
              // thấp (điện thoại xoay ngang, cửa sổ PC lùn).
              scrollable: true,
              backgroundColor: theme.backgroundColor,
              title: Text(settings.tr('reading.changeTableTitle'),
                  style:
                      TextStyle(color: theme.textColor, fontSize: 16)),
              content: SizedBox(
                width: isDesktop ? 560 : 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // PC: bàn là cảnh vẽ lớp — nền gỗ trống, khăn là
                    // một ảnh cắt trong suốt toàn khung (vẽ thẳng trên
                    // bàn gỗ rồi tách nền, khớp điểm tụ với bàn), phụ
                    // kiện là ảnh cắt trong suốt đặt theo tọa độ cố
                    // định. Đổi ở đây sẽ đổi ngay trên bàn (cross-fade).
                    if (isDesktop)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          settings.tr('reading.desktopTableIntro'),
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.5),
                        ),
                      ),
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: tableAndCloth),
                          const SizedBox(width: 20),
                          Expanded(child: decorAndLayers),
                        ],
                      )
                    else ...[
                      tableAndCloth,
                      const SizedBox(height: 16),
                      decorAndLayers,
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(settings.tr('common.done'),
                      style: TextStyle(color: theme.primaryColor)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Vùng chính: lá bài lớn ở giữa + panel giải nghĩa bên dưới (phone)
  /// hoặc bên cạnh (tablet/desktop). Kéo một lá từ khay lên đây để xem.
  Widget _buildMainInteractiveLayout(
    List<TarotCardModel> drawnCards,
    ReadingProvider readingProvider,
    dynamic theme,
  ) {
    final activeCard = drawnCards.isNotEmpty &&
            _selectedCardIndex >= 0 &&
            _selectedCardIndex < drawnCards.length
        ? drawnCards[_selectedCardIndex]
        : null;

    if (activeCard == null) return _buildEmptyTable(theme);
    return _buildActiveCardLayout(activeCard, theme);
  }

  /// Khi chưa chọn lá bài nào: xấp bài ở giữa, nút chọn rõ ràng,
  /// hướng dẫn ngắn gọn — không còn lá bài bay đè lên khung chữ.
  Widget _buildEmptyTable(dynamic theme) {
    final settings = context.watch<SettingsProvider>();
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CardStackWidget(
              onTap: () {
                setState(() {
                  _showSelectionPanel = true;
                });
              },
              theme: theme,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showSelectionPanel = true;
                  });
                },
                icon: const Icon(Icons.style, size: 20),
                label: Text(
                  settings.tr('reading.selectCard'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            GlassPanel(
              backgroundColor: Colors.black.withOpacity(0.55),
              borderColor: theme.primaryColor.withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 28),
                    const SizedBox(height: 12),
                    Text(
                      settings.tr('reading.emptyHintPhone'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lá bài lớn + panel giải nghĩa. Phone: xếp dọc. Tablet/desktop:
  /// lá bài bên trái, giải nghĩa bên phải, cùng một chiều cao.
  Widget _buildActiveCardLayout(TarotCardModel activeCard, dynamic theme) {
    final cardWidth = _activeCardWidth(context);
    final cardHeight = cardWidth * 8 / 5; // Tỉ lệ lá Tarot 5:8.
    final cardWidget = _buildActiveCard(activeCard, theme, cardWidth);
    final meaningPanel = _buildMeaningPanel(activeCard, theme);

    if (Responsive.isPhone(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: cardWidget),
          const SizedBox(height: 16),
          Expanded(child: meaningPanel),
        ],
      );
    }

    return SizedBox(
      height: cardHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cardWidget,
          const SizedBox(width: 24),
          Expanded(child: meaningPanel),
        ],
      ),
    );
  }

  /// Lá bài đang chọn (phone/tablet): vào bằng animation bay lên.
  /// Ấn vào lá: thu lá xuống khay (bảo toàn số lượng lá — lá trên
  /// sân không hiện trong khay). Ấn vào lá trong khay: lá đó lên sân.
  Widget _buildActiveCard(TarotCardModel activeCard, dynamic theme, double cardWidth) {
    final settings = context.watch<SettingsProvider>();
    final cardHeight = cardWidth * 8 / 5;
    // Ấn vào lá trên sân khấu: thu lá xuống khay (bảo toàn số
    // lượng lá — một lá chỉ ở đúng một nơi).
    return Tooltip(
      message: settings.tr('reading.tapToCollect'),
      child: GestureDetector(
        onTap: _collectStageCard,
        child: TweenAnimationBuilder<double>(
      key: ValueKey(activeCard.id),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, animValue, child) {
        return Transform.translate(
          offset: Offset(0, 120 * (1.0 - animValue)),
          child: Transform.scale(
            scale: 0.6 + (0.4 * animValue),
            child: child,
          ),
        );
      },
      child: RepaintBoundary(
        child: SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: _cardFrame(activeCard, theme, cardWidth),
        ),
      ),
        ),
      ),
    );
  }

  /// Khung lá bài: viền vàng + glow, tỉ lệ 5:8. Ảnh lá hiện TRỌN
  /// (BoxFit.contain, nền đen) vì ảnh gốc 7:12 hẹp hơn khung 5:8
  /// — cover cắt mất đầu/cuối tranh và chữ tên lá ở chân lá.
  Widget _cardFrame(TarotCardModel card, dynamic theme, double cardWidth) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primaryColor, width: 2),
        boxShadow: [
          // Bóng đổ xuống-phải lên mặt khăn (ánh sáng từ trên-trái):
          // lá bài "nằm" trên bàn thay vì lơ lửng phát sáng.
          BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 14,
            spreadRadius: 1,
            offset: const Offset(8, 14),
          ),
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.6),
            blurRadius: 16,
            spreadRadius: 2,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: TarotCardImage(card: card, fit: BoxFit.contain),
      ),
    );
  }

  /// Panel giải nghĩa: tên lá bài + nội dung cuộn được. Lá đang
  /// đọc hiện trên sân khấu (không nằm trong khay — bảo toàn số
  /// lượng lá) — panel chỉ hiện nội dung của lá đó.
  /// PC: chữ 14pt, tên 17pt. Phone giữ 15pt / 20pt như cũ.
  Widget _buildMeaningPanel(TarotCardModel activeCard, dynamic theme) {
    return GlassPanel(
      backgroundColor: Colors.black.withOpacity(0.65),
      borderColor: theme.primaryColor.withOpacity(0.5),
      child: Padding(
        padding: EdgeInsets.all(_isDesktop ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LocalizedCardName(
              card: activeCard,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.primaryColor,
                fontSize: _cardNameFontSize(),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: SelectionArea(
                  child: LocalizedCardMeaning(
                    card: activeCard,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _meaningFontSize(),
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Khay chọn lá bài: section riêng dạng bottom-sheet — có tay kéo,
  /// tiêu đề + nút đóng 48dp, chip chọn nhóm bài, lưới bài.
  /// Khay chọn bài + ESC: khi khay đang mở, ESC đóng khay (lớp trong
  /// cùng) thay vì thoát cả màn trải bài. Focus autofocus để phím
  /// ESC tới được khay ngay khi nó mở; đóng khay thì Focus biến mất
  /// và phím ESC lại tới được màn hình (thoát màn).
  Widget _buildSelectionPanelWithEsc(List<TarotCardModel> deckCards, ReadingProvider readingProvider, dynamic theme) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          setState(() {
            _showSelectionPanel = false;
          });
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: _buildSelectionPanel(deckCards, readingProvider, theme),
    );
  }

  Widget _buildSelectionPanel(List<TarotCardModel> deckCards, ReadingProvider readingProvider, dynamic theme) {
    final settings = context.watch<SettingsProvider>();
    // Phân loại các lá bài theo Suit
    final List<TarotCardModel> activeCards;
    String suitLabel = '';
    switch (_selectedSuit) {
      case TarotSuit.major:
        activeCards = deckCards.where((c) => _getCardSuit(c) == TarotSuit.major).toList();
        suitLabel = settings.tr('reading.suitMajorLabel');
        break;
      case TarotSuit.cups:
        activeCards = deckCards.where((c) => _getCardSuit(c) == TarotSuit.cups).toList();
        suitLabel = settings.tr('reading.suitCupsLabel');
        break;
      case TarotSuit.wands:
        activeCards = deckCards.where((c) => _getCardSuit(c) == TarotSuit.wands).toList();
        suitLabel = settings.tr('reading.suitWandsLabel');
        break;
      case TarotSuit.swords:
        activeCards = deckCards.where((c) => _getCardSuit(c) == TarotSuit.swords).toList();
        suitLabel = settings.tr('reading.suitSwordsLabel');
        break;
      case TarotSuit.pentacles:
        activeCards = deckCards.where((c) => _getCardSuit(c) == TarotSuit.pentacles).toList();
        suitLabel = settings.tr('reading.suitPentaclesLabel');
        break;
    }

    return GlassPanel(
      backgroundColor: Colors.black.withOpacity(0.7),
      borderColor: theme.primaryColor.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tay kéo của bottom-sheet
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Tiêu đề + nút đóng
            Row(
              children: [
                Expanded(
                  child: Text(
                    settings.tr('reading.selectCard'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                // Nút đóng gọn (IconButton mặc định 48×48 ăn mất
                // chiều cao của lưới — thu về 32×32 để 2 hàng lá hiện trọn).
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 32, height: 32),
                  tooltip: settings.tr('reading.closeSelectionPanel'),
                  onPressed: () {
                    setState(() {
                      _showSelectionPanel = false;
                    });
                  },
                ),
              ],
            ),

            // NÚT ĐỔI NHÓM BÀI: Dãy Chip đổi nhóm bài cuộn ngang mượt mà
            _buildSuitSelector(theme),

            const SizedBox(height: 8),

            // Tên nhóm bài hiện hành
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text(
                suitLabel,
                style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),

            // Lưới bài (Grid View) của nhóm hiện hành. Hỗ trợ trượt cuộn bằng chuột kéo thả
            Expanded(
              child: AnimatedSwitcher(
                key: ValueKey(_selectedSuit),
                duration: const Duration(milliseconds: 250),
                child: _buildCardGrid(activeCards, readingProvider, theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bộ chọn nhóm bài gồm các chip nằm ngang
  Widget _buildSuitSelector(dynamic theme) {
    final settings = context.watch<SettingsProvider>();
    return ScrollConfiguration(
      behavior: MouseDragScrollBehavior(), // Tương tác trượt ngang bằng chuột/ngón tay
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildSuitChip(TarotSuit.major, settings.tr('reading.suitMajor'), theme),
            _buildSuitChip(TarotSuit.cups, settings.tr('reading.suitCups'), theme),
            _buildSuitChip(TarotSuit.wands, settings.tr('reading.suitWands'), theme),
            _buildSuitChip(TarotSuit.swords, settings.tr('reading.suitSwords'), theme),
            _buildSuitChip(TarotSuit.pentacles, settings.tr('reading.suitPentacles'), theme),
          ],
        ),
      ),
    );
  }

  /// Chip riêng cho từng nhóm bài. Phone giữ 48dp; PC gọn 38dp, chữ 12.
  Widget _buildSuitChip(TarotSuit suit, String label, dynamic theme) {
    final isSelected = _selectedSuit == suit;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: SizedBox(
        height: _isPhone ? 48 : 38,
        child: Center(
          child: ChoiceChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (val) {
              if (val) {
                setState(() {
                  _selectedSuit = suit;
                });
              }
            },
            selectedColor: theme.primaryColor,
            backgroundColor: Colors.black38,
            labelStyle: TextStyle(
              color: isSelected ? Colors.black87 : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: _isDesktop ? 12 : 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isSelected ? theme.primaryColor : theme.glassBorderColor,
                width: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Lưới bài: phone 4 cột, tablet 5 cột, desktop 12 cột (gọn ở 4K),
  /// tỉ lệ 5:8. Desktop 12 cột để 2 hàng lá hiện trọn trong panel:
  /// 10 cột thì lá cao ~200px, 2 hàng ~407px, vượt chiều cao lưới
  /// (~400px) nên hàng 2 bị cắt ở đáy; 12 cột thì lá ~164px,
  /// 2 hàng ~336px, vừa thoải mái (nhóm Ẩn Chính 22 lá cũng vừa
  /// hết trong 2 hàng).
  Widget _buildCardGrid(List<TarotCardModel> cards, ReadingProvider readingProvider, dynamic theme) {
    final crossAxisCount = Responsive.isDesktop(context)
        ? 12 // PC: 12 cột để 2 hàng lá hiện trọn.
        : Responsive.isTablet(context)
            ? 5
            : 4;
    return ScrollConfiguration(
      behavior: MouseDragScrollBehavior(),
      child: GridView.builder(
        key: ValueKey(cards.hashCode),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.625, // 5:8
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: cards.length,
        itemBuilder: (context, index) {
          final card = cards[index];
          final isAlreadyDrawn = readingProvider.drawnCards.any((dc) => dc.id == card.id);

          final cardItemWidget = Opacity(
            opacity: isAlreadyDrawn ? 0.35 : 1.0,
            child: Container(
              decoration: BoxDecoration(
                // Nền đen: ảnh lá 7:12 hiện trọn (contain) trong ô 5:8.
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isAlreadyDrawn ? Colors.white24 : theme.glassBorderColor,
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: TarotCardImage(card: card, fit: BoxFit.contain),
              ),
            ),
          );

          if (isAlreadyDrawn) {
            return cardItemWidget;
          }

          // Cho phép bốc bài và kéo thả trực tiếp lá bài xuống khay lịch sử
          return Draggable<TarotCardModel>(
            data: card,
            feedback: Material(
              color: Colors.transparent,
              child: Container(
                width: 64,
                height: 102,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.primaryColor, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: TarotCardImage(card: card, fit: BoxFit.contain),
                ),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.35, child: cardItemWidget),
            child: GestureDetector(
              onTap: () {
                if (_drawCardModel(card)) {
                  setState(() {
                    _showSelectionPanel = false; // Đóng khay để lá bài bay vào khung trên bàn, hiện giải nghĩa
                  });
                }
              },
              child: cardItemWidget,
            ),
          );
        },
      ),
    );
  }

  /// Khay bài đã rút ở dưới cùng — section riêng, cao CỐ ĐỊNH
  /// 124dp phone, 104dp tablet, 176dp PC 4K (kể cả khi chưa rút
  /// lá nào: khay là vật cố định trên bàn, không co giãn — co
  /// giãn khay làm cả bàn nhảy lên/xuống một khung hình = giật).
  /// Lá trong khay TO gần bằng lá trên màn hình: PC 100 rộng,
  /// tỉ lệ 5:8, xem rõ mặt lá. Khay chứa TOÀN BỘ các lá đã rút
  /// (cùng thứ tự rút); chạm vào một lá trong khay là chọn nó
  /// để đọc trên màn hình. Kéo thả một lá từ khay chọn bài
  /// xuống đây là rút lá đó.
  /// Khay bài đã rút — BẢO TOÀN SỐ LƯỢNG LÁ: lá đang trên sân khấu
  /// KHÔNG hiện trong khay (một lá chỉ ở đúng một nơi tại một thời
  /// điểm). Khay chỉ hiện các lá đã rút mà không đang trên sân khấu.
  /// Ấn vào lá trong khay: lá đó lên sân khấu (rời khay), lá đang
  /// trên sân khấu (nếu có) thu xuống khay. Ấn vào lá trên sân khấu:
  /// lá đó thu xuống khay (xem _collectStageCard).
  Widget _buildBottomTray(List<TarotCardModel> drawnCards, ReadingProvider readingProvider, dynamic theme) {
    final settings = context.watch<SettingsProvider>();
    // Cao cố định — không đổi theo số lá (xem doc ở trên).
    final trayHeight = _isDesktop ? 176.0 : (_isPhone ? 124.0 : 104.0);
    final trayThumbWidth = _isDesktop ? 100.0 : 64.0;
    if (drawnCards.isEmpty) {
      return Container(
        height: trayHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // Nền tối riêng của khay: lá trong khay không còn nổi
          // lơ lửng trên viền gỗ — khay là một vật riêng, nhìn rõ.
          color: Colors.black.withOpacity(0.55),
          border: Border(top: BorderSide(color: theme.glassBorderColor, width: 0.5)),
        ),
        child: Text(
          settings.tr('reading.trayEmpty'),
          style: TextStyle(color: theme.secondaryTextColor, fontSize: _isDesktop ? 12 : 13),
        ),
      );
    }

    // Chỉ các lá KHÔNG trên sân khấu mới hiện trong khay.
    final trayIndices = <int>[];
    for (var i = 0; i < drawnCards.length; i++) {
      if (i != _selectedCardIndex) trayIndices.add(i);
    }

    return Container(
      height: trayHeight,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        border: Border(top: BorderSide(color: theme.glassBorderColor, width: 0.5)),
      ),
      child: DragTarget<TarotCardModel>(
        onWillAccept: (data) => data != null,
        onAccept: (data) {
          // Kéo thả 1 lá bài mới từ khay chọn bài xuống: rút lá đó
          // (lên sân khấu — không hiện trong khay khi đang đọc).
          _drawCardModel(data);
        },
        builder: (context, candidateData, rejectedData) {
          final isHovered = candidateData.isNotEmpty;
          return Container(
            color: isHovered ? theme.primaryColor.withOpacity(0.08) : Colors.transparent,
            child: ScrollConfiguration(
              behavior: MouseDragScrollBehavior(), // Hỗ trợ kéo chuột để trượt ngang mượt mà
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: trayIndices.length,
                itemBuilder: (context, index) {
                  final card = drawnCards[trayIndices[index]];

                  return GestureDetector(
                    onTap: () => _selectCard(trayIndices[index]),
                    child: _buildBottomTrayItem(card, theme, trayThumbWidth),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  /// Thumbnail lá bài trong khay: PC 100 rộng (gần bằng lá trên
  /// bàn), phone/tablet 64 rộng, tỉ lệ 5:8. Ảnh lá hiện TRỌN
  /// (contain, nền đen) — ảnh gốc 7:12, cover cắt mất tên lá.
  /// Mỗi ô có key riêng (theo id lá) để đo rect làm điểm đến của
  /// flight về khay; ô đang bay về thì ẩn đi, hiện lại đúng lúc
  /// lá đáp xuống (cùng rect nên không thấy ngắt cảnh). Khay KHÔNG
  /// có lá nào được chọn (lá trên sân khấu không nằm trong khay) nên
  /// mọi ô đều dùng viền thường, không viền vàng.
  Widget _buildBottomTrayItem(
      TarotCardModel card, dynamic theme, double width) {
    // Mỗi lá trong khay có display list riêng: đổi lá chọn /
    // cuộn khay không vẽ lại các lá còn lại.
    final isFlyingToTray = _trayFlight?.card.id == card.id;
    return RepaintBoundary(
      key: _trayItemKeys.putIfAbsent(card.id, () => GlobalKey()),
      child: Opacity(
        opacity: isFlyingToTray ? 0.0 : 1.0,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          // Nền đen cho contain: hai viền đen mỏng hai bên lá.
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.glassBorderColor,
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: AspectRatio(
            aspectRatio: 5 / 8,
            child: TarotCardImage(card: card, fit: BoxFit.contain),
          ),
        ),
        ),
      ),
    );
  }

  /// Nền bàn — cảnh vẽ LỚP (HyperFrames, bố cục định trong
  /// code), cho MỌI thiết bị (PC + phone/tablet dùng chung tranh
  /// vẽ): LỚP 1 là bàn gỗ TRỐNG `table_bare_wood.png` (BoxFit.
  /// cover, chiếm toàn bộ viewport) — không còn gì vẽ sẵn trong
  /// nền. LỚP 2 là khăn CẮT TRONG SUỐT toàn khung (cả 3 màu, vẽ
  /// thẳng trên bàn gỗ trống rồi tách nền — xem _clothImageAsset),
  /// đặt ngay trong Stack này (Positioned.fill, BoxFit.cover, cùng
  /// box với nền) nên luôn khớp pixel với gỗ ở mọi viewport; đổi
  /// màu thì cross-fade ngay (AnimatedSwitcher, chỉ mờ, không
  /// scale). LỚP 3 phụ kiện cắt trong suốt (PC: xem
  /// _buildDesktopDecorCutouts trong _buildDesktopTable;
  /// phone/tablet: hàng ảnh cắt ở trên cùng). Trên bàn
  /// không còn lá nào — lá đang đọc hiện trên màn hình (xem
  /// _buildDesktopStage). KHÔNG còn ảnh bàn cũ, khăn màu phẳng cũ,
  /// lớp phủ tối nặng cũ. Chỉ một vệt tối nhẹ sát mép dưới (sau khay
  /// bài). Tắt "Hiện mặt bàn" thì tranh tắt, nền đen. Tắt "Hiện khăn"
  /// thì lớp khăn ẩn, chỉ còn gỗ trống.
  Widget _buildTableBackground(UserPreferencesModel prefs, Widget child) {
    // Nền bàn VẼ (HyperFrames) cho MỌI thiết bị — phone/tablet
    // dùng đúng tranh vẽ như PC (gỗ trống + khăn cắt + decor cắt),
    // KHÔNG còn ảnh cũ (ảnh chụp vân gỗ/đá/nền sao, khăn màu phẳng,
    // sprite decor cũ trong ô đen). Kiểu bàn cũ (Đá Cổ / Vũ Trụ)
    // không còn ảnh vẽ tương ứng nên mọi máy đều dùng bàn gỗ vẽ.
    final isDesktop = Responsive.isDesktop(context);
    // Ảnh nền bàn theo kiểu đã chọn; kiểu chưa có tranh vẽ thì
    // RƠI VỀ gỗ vẽ (xem _tableImageAsset) — dialog chỉ cho chọn
    // kiểu có tranh vẽ nên đây chỉ là lưới an toàn, không phải
    // lựa chọn lặng lẽ.
    final tableImage = _tableImageAsset(prefs.tableStyle) ??
        'assets/images/table_bare_wood.png';

    // PC: không build icon decor ở đây — phụ kiện là ảnh cắt trong
    // suốt, đặt theo phân số tranh trên mép xa của bàn (xem
    // _buildDesktopDecorCutouts trong _buildDesktopTable).
    // Phone/tablet: decor đặt TRÊN BÀN (lớp 4 bên dưới, dùng phép
    // cover để tìm mép trên của bàn) — không còn hàng sprite 40px
    // ở sát mép trên màn hình (bé tí, bay trong vùng tối trên bàn).

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: prefs.showTable
          ? BoxDecoration(
              image: DecorationImage(
                image: AssetImage(tableImage),
                fit: BoxFit.cover,
              ),
            )
          : const BoxDecoration(
              color: Colors.black87, // Hiển thị màu đen tối giản nếu tắt lớp Mặt Bàn
            ),
      child: Stack(
        children: [
          // LỚP KHĂN (HyperFrames, mọi thiết bị): khăn là ảnh CẮT
          // TRONG SUỐT toàn khung (1920x1280) — vẽ thẳng trên bàn
          // gỗ trống, khớp điểm tụ và góc độ với bàn, rồi tách nền
          // chỉ còn khăn. Đặt ở ĐÂY (Positioned.fill, BoxFit.cover,
          // cùng box với DecorationImage nền gỗ) nên khăn và gỗ luôn
          // khớp pixel ở mọi viewport, không cần cắt hình thang
          // bằng code nữa. Chỉ mờ đổi khi đổi màu (không scale —
          // scale sẽ làm lệch khớp với gỗ trong lúc chuyển).
          // KHÔNG còn khăn màu phẳng cũ (khối màu đặc bo tròn).
          if (prefs.showCloth)
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                // Khăn TO RA (×1.45, giữ mép trên sát mép xa):
                // khăn vẽ gốc chỉ chiếm 74% rộng × 51% cao của
                // tranh nên nhìn bé tí, lọt thỏm giữa bàn. Phóng
                // to 1.45 thì khăn phủ ~108% rộng × 73% cao — tràn
                // nhẹ ra hai mép bàn như khăn thật rủ xuống, mép
                // dưới xuống sát khung chạm khắc dưới. Scale
                // quanh tâm đẩy mép trên lên QUÁ mép xa của bàn
                // nên dịch xuống đúng phần vượt đó (tính qua phép
                // cover) để mép trên vẫn sát mép xa, khăn mọc
                // xuống và sang hai bên, mép dưới vẫn trên mặt
                // bàn. Decor và ô gợi ý neo theo phân số tranh gỗ
                // nên vẫn nằm trên khăn (xem _paintingCoverTransform).
                child: LayoutBuilder(
                  key: ValueKey('cloth-${prefs.clothStyle}'),
                  builder: (context, constraints) {
                    final t = _paintingCoverTransform(
                        constraints.maxWidth, constraints.maxHeight);
                    // Khăn neo theo TỌA ĐỘ TRANH (§37): hộp khăn =
                    // hộp tranh (t.dx, t.dy, 1920*t.scale,
                    // 1280*t.scale) phóng 1.45× quanh TÂM TRANH,
                    // rồi dịch xuống để mép trên khăn vẫn sát mép
                    // xa của bàn (0.218). Trước đây khăn dùng
                    // BoxFit.cover + Transform.scale quanh TÂM MÀN
                    // HÌNH nên khi đổi tỉ lệ màn hình, khăn lệch
                    // khỏi bàn — cứng đờ, không co dãn theo mặt
                    // bàn. Giờ khăn co dãn CÙNG mặt bàn ở mọi tỉ
                    // lệ màn hình, dính cố định vào bàn.
                    const clothScale = 1.45;
                    final pw = 1920.0 * t.scale;
                    final ph = 1280.0 * t.scale;
                    final cx = t.dx + pw / 2;
                    final cy = t.dy + ph / 2;
                    final cw = pw * clothScale;
                    final ch = ph * clothScale;
                    final topY = 0.5 - 0.232 * clothScale;
                    final over = 0.218 - topY; // > 0 khi vượt mép xa
                    final shiftY = over > 0 ? over * 1280 * t.scale : 0.0;
                    return Stack(
                      children: [
                        Positioned(
                          left: cx - cw / 2,
                          top: cy - ch / 2 + shiftY,
                          width: cw,
                          height: ch,
                          child: Image.asset(
                            _clothImageAsset(prefs.clothStyle),
                            fit: BoxFit.fill,
                            gaplessPlayback: true,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

          // Lớp phủ tối: KHÔNG làm tối cả bức tranh — chỉ một vệt
          // tối nhẹ ở sát mép dưới (phía sau khay bài), cho MỌI
          // thiết bị (trước đây phone/tablet phủ tối nặng cả màn,
          // làm tranh vẽ bị mờ xỉn). Tranh giữ nguyên độ sáng và
          // màu. Panel giải nghĩa đã có nền đen 0.72 riêng.
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.78, 1.0],
                colors: [
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0x66000000),
                ],
              ),
            ),
          ),

          // LỚP 4: Đồ trang trí — chỉ phone/tablet. Đặt TRƯỚC
          // nội dung (LỚP 3) để decor nằm DƯỚI giao diện — decor
          // là đồ trên mặt bàn (nền), không phải lớp phủ UI.
          // Trước đây decor ở SAU nội dung nên khi mở khay chọn
          // bài trên điện thoại, decor đè lên nút lọc bộ bài và
          // thẻ bài trong khay. Ẩn decor khi khay chọn bài đang
          // mở để nó không lộ qua panel kính (GlassPanel chỉ mờ
          // 0.7, decor vẫn thấy mờ mờ sau panel). Trước đây là
          // hàng sprite 40px ở sát mép trên màn hình (top: 0) nên
          // đồ bé tí và bay trong vùng tối PHÍA TRÊN bàn (mép trên
          // của bàn nằm sâu hơn, khoảng y=0.218 của tranh). Giờ đặt
          // đồ TRÊN BÀN: dùng đúng phép cover để tìm mép trên của
          // bàn, đặt đáy hàng decor ngay dưới mép đó (trên mặt gỗ).
          // Đồ CO DÃN CÙNG BÀN: cỡ món tính theo tỉ lệ cover của
          // tranh (t.scale) — khi co kéo màn hình, bàn to ra/nhỏ
          // lại thì đồ cũng to ra/nhỏ lại theo đúng tỉ lệ đó, vị
          // trí và kích thước tương quan với bàn không đổi. Trước
          // đây cỡ món chỉ theo chiều rộng màn hình nên đổi chiều
          // cao thì bàn đổi mà đồ không đổi, trông lệch hẳn.
          // PC: không có gì ở đây, phụ kiện là ảnh cắt đặt theo
          // phân số tranh trên mép xa của bàn (xem
          // _buildDesktopDecorCutouts trong _buildDesktopTable).
          if (prefs.showDecor && !isDesktop && !_showSelectionPanel)
            Positioned.fill(
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final t = _paintingCoverTransform(
                        constraints.maxWidth, constraints.maxHeight);
                    // Mép trên của bàn trong tranh (0.218) đổi sang
                    // tọa độ widget; đáy hàng decor đặt ngay dưới
                    // mép đó 10px, trên mặt gỗ.
                    final tableTopY = 0.218 * 1280 * t.scale + t.dy;
                    final itemSize = (106.0 * t.scale)
                        .clamp(56.0, 120.0)
                        .toDouble();
                    final rowTop = tableTopY + 10 - (itemSize + 12);
                    return Stack(
                      children: [
                        Positioned(
                          top: rowTop < 0 ? 0.0 : rowTop,
                          left: 0,
                          right: 0,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: _buildDynamicDecorWidgets(
                                  prefs.decorItems, itemSize),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

          // LỚP 3: Nội dung của ứng dụng
          child,
        ],
      ),
    );
  }

  /// Ảnh nền bàn theo kiểu đã chọn, null = kiểu đó chưa có tranh
  /// vẽ. Hiện chỉ 'Gỗ Sồi' có tranh vẽ (`table_bare_wood.png`);
  /// 'Đá Cổ' / 'Vũ Trụ' chưa có tranh vẽ tương ứng nên chọn cũng
  /// không đổi được mặt bàn — đó là lý do dialog chỉ cho chọn
  /// kiểu có tranh vẽ (xem _tableStyleHasPaintedArt).
  String? _tableImageAsset(String tableStyle) {
    switch (tableStyle) {
      case 'Gỗ Sồi':
        return 'assets/images/table_bare_wood.png';
      default:
        return null; // 'Đá Cổ' / 'Vũ Trụ': chưa có tranh vẽ.
    }
  }

  /// Kiểu mặt bàn nào CÓ tranh vẽ: chỉ 'Gỗ Sồi'. Dùng để lọc lựa
  /// chọn trong dialog đổi bàn (xem _showTableSettingsDialog).
  bool _tableStyleHasPaintedArt(String style) => style == 'Gỗ Sồi';

  /// Ảnh khăn theo kiểu đã chọn: khăn CẮT TRONG SUỐT toàn khung,
  /// vẽ thẳng trên bàn gỗ trống rồi tách nền — chỉ còn khăn, khớp
  /// điểm tụ và góc độ với bàn.
  String _clothImageAsset(String clothStyle) {
    switch (clothStyle) {
      case 'Lụa Vàng':
        return 'assets/images/cloth_gold_cut.png';
      case 'Thảm Đen':
        return 'assets/images/cloth_black_cut.png';
      case 'Nhung Tím':
      default:
        return 'assets/images/cloth_purple_cut.png';
    }
  }

  /// Các món trang trí (phone/tablet): chỉ trả về widget, vị trí
  /// do hàng ở trên cùng của _buildTableBackground quyết định.
  /// Món nào có ảnh cắt vẽ (thạch anh, quả cầu, trầm, nến) dùng
  /// ảnh CẮT trong suốt (_buildDecorSprite + _decorCutoutAsset,
  /// như PC); món chưa có ảnh cắt (Lá Khô) không vẽ gì.
  /// Bản PC dùng ảnh cắt đặt đúng vị trí (xem
  /// _buildDesktopDecorCutouts).
  List<Widget> _buildDynamicDecorWidgets(List<String> items, [double size = 40]) {
    final widgets = <Widget>[];
    for (final item in items) {
      if (item == 'Hương Trầm') {
        // Trầm: ảnh thật + khói bay lên phía trên.
        widgets.add(Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            _buildDecorSprite(item, size),
            Positioned(
              top: -30,
              child: SizedBox(
                width: 40,
                height: 50,
                child: SmokeParticleEffect(
                  enableSmoke: true,
                  child: const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ));
      } else {
        widgets.add(_buildDecorSprite(item, size));
      }
    }
    return widgets;
  }

  void _showEditTitleDialog(BuildContext context, ReadingProvider readingProvider) {
    final controller = TextEditingController(text: readingProvider.currentReadingTitle);
    showDialog(
      context: context,
      builder: (context) {
        final settings = context.watch<SettingsProvider>();
        final theme = settings.currentThemeData;
        return AlertDialog(
          backgroundColor: theme.backgroundColor, // Sửa lỗi bị hòa vào text nền bằng cách dùng nền đục
          title: Text(settings.tr('reading.renameReading'), style: TextStyle(color: theme.textColor)),
          content: TextField(
            controller: controller,
            style: TextStyle(color: theme.textColor),
            decoration: InputDecoration(
              hintText: settings.tr('reading.renameHint'),
              hintStyle: TextStyle(color: theme.secondaryTextColor),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.primaryColor)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(settings.tr('common.cancel'), style: TextStyle(color: theme.secondaryTextColor)),
            ),
            TextButton(
              onPressed: () {
                readingProvider.updateTitle(controller.text);
                Navigator.pop(context);
              },
              child: Text(settings.tr('common.save'), style: TextStyle(color: theme.primaryColor)),
            ),
          ],
        );
      },
    );
  }
}

/// Widget mô phỏng Xấp bài Tarot úp rực rỡ (tỉ lệ 5:8, theo breakpoint).
/// Một chuyến bay về khay: lá nào, bay từ rect nào (sân khấu) về
/// rect nào (ô của nó trong khay). Rect tính theo tọa độ của lớp
/// bay (Stack bọc body desktop).
class _TrayFlight {
  final TarotCardModel card;
  final Rect from;
  final Rect to;
  const _TrayFlight({required this.card, required this.from, required this.to});
}

/// Khung xấp bài (§37): một khung hình thang phối cảnh bám sát
/// mép lá bài (tỉ lệ bộ bài cơ bản 5:8, cạnh xa ngắn hơn cạnh
/// gần), bên trong là ẢNH MẶT LƯNG của bộ bài đang chọn — scale
/// khớp vào khung mặc định. Mỗi bộ bài up lên kèm 1 ảnh mặt lưng
/// (TarotDeckModel.backImageUrl); chọn bộ nào thì xấp hiện lưng
/// bộ đó. Chưa có ảnh lưng thì dùng ảnh lưng mặc định
/// (deck_back_default.png). Mép giấy kem + bóng đổ mềm làm xấp
/// có khối, đặt thật trên bàn.
class _DeckStackFrame extends StatelessWidget {
  final double width;
  final String? backImageUrl;

  const _DeckStackFrame({required this.width, this.backImageUrl});

  @override
  Widget build(BuildContext context) {
    final w = width;
    final fh = w * 8 / 5 * 0.55; // Mặt trên: lá bài cơ bản 5:8,
    // nhưng chiều cao (hướng sâu của bàn) bị phối cảnh nén mạnh
    // 0.55 — bàn nhìn xiên nên xấp bài NẰM PHẲNG, cao/rộng ≈ 0.9,
    // không còn đọc như lá bài dựng đứng (0.85 nén quá nhẹ).
    const dx = 7.0; // Chiều dày xấp lộ sang phải.
    const dy = 12.0; // Chiều dày xấp lộ xuống dưới.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          // Bóng đổ mềm, nhạt như bóng thật (§32).
          BoxShadow(
            color: Colors.black.withOpacity(0.40),
            blurRadius: 14,
            spreadRadius: 2,
            offset: const Offset(10, 12),
          ),
        ],
      ),
      child: SizedBox(
        width: w + dx,
        height: fh + dy,
        child: Stack(
          children: [
            // Mép giấy kem (cạnh xấp): dải trước + dải phải.
            Positioned.fill(
              child: CustomPaint(
                painter: _DeckEdgePainter(w, fh, dx, dy),
              ),
            ),
            // Mặt trên: ảnh mặt lưng, cắt theo hình thang phối cảnh.
            Positioned(
              left: 0,
              top: 0,
              width: w,
              height: fh,
              child: ClipPath(
                clipper: _DeckTopClipper(),
                child: _backImage(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // BoxFit.fill: ÉP DẸT ảnh lưng theo đúng phối cảnh nằm phẳng.
  // (BoxFit.cover chỉ crop ảnh nên vòng tròn/ngôi sao vẫn tròn —
  // xấp đọc như dựng đứng. Fill ép dọc 0.55 nên sao thành ellipse dẹt.)
  Widget _backImage() {
    final url = backImageUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.fill,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/images/deck_back_default.png',
          fit: BoxFit.fill,
        ),
      );
    }
    return Image.asset(
      'assets/images/deck_back_default.png',
      fit: BoxFit.fill,
    );
  }
}

/// Cắt ảnh mặt lưng theo hình thang phối cảnh: cạnh xa (trên)
/// ngắn hơn cạnh gần (dưới) — 68% chiều rộng đáy.
class _DeckTopClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final topW = w * 0.68;
    final x0 = (w - topW) / 2;
    return Path()
      ..moveTo(x0, 0)
      ..lineTo(x0 + topW, 0)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Vẽ mép giấy của xấp bài: dải trước (dưới) + dải phải, màu kem,
/// có vạch ngang gợi các lớp bài xếp chồng.
class _DeckEdgePainter extends CustomPainter {
  final double w;
  final double fh;
  final double dx;
  final double dy;

  _DeckEdgePainter(this.w, this.fh, this.dx, this.dy);

  @override
  void paint(Canvas canvas, Size size) {
    final topW = w * 0.68;
    final x0 = (w - topW) / 2;
    // Dải trước (dưới): hình thang kem.
    final front = Path()
      ..moveTo(0, fh)
      ..lineTo(w, fh)
      ..lineTo(w + dx, fh + dy)
      ..lineTo(dx, fh + dy)
      ..close();
    canvas.drawPath(front, Paint()..color = const Color(0xFFD9CDB4));
    // Dải phải: hình thang kem sẫm hơn một chút.
    final right = Path()
      ..moveTo(x0 + topW, 0)
      ..lineTo(w, fh)
      ..lineTo(w + dx, fh + dy)
      ..lineTo(x0 + topW + dx, dy)
      ..close();
    canvas.drawPath(right, Paint()..color = const Color(0xFFBFAF90));
    // Vạch lớp bài trên dải trước.
    final linePaint = Paint()
      ..color = const Color(0xFF8A7F68)
      ..strokeWidth = 1.0;
    for (final f in [0.3, 0.55, 0.8]) {
      final y = fh + dy * f;
      canvas.drawLine(Offset(dx * f, y), Offset(w + dx * f, y), linePaint);
    }
    // Vạch lớp bài trên dải phải (song song mép phải).
    for (final f in [0.3, 0.55, 0.8]) {
      canvas.drawLine(
        Offset(x0 + topW + dx * f, dy * f),
        Offset(w + dx * f, fh + dy * f),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DeckEdgePainter old) =>
      old.w != w || old.fh != fh || old.dx != dx || old.dy != dy;
}

class CardStackWidget extends StatelessWidget {
  final VoidCallback onTap;
  final dynamic theme;

  const CardStackWidget({Key? key, required this.onTap, required this.theme}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    // Xấp bài ở góc bàn — to và rõ để thấy và chạm: PC 84 rộng,
    // tablet 100, phone 84. Đây là CỠ MẶT TRÊN của xấp bài; chiều
    // dày (cạnh xấp) vẽ thêm sang phải/xuống dưới trong painter.
    final stackWidth = Responsive.isDesktop(context)
        ? 96.0
        : Responsive.isTablet(context)
            ? 108.0
            : 84.0;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Xấp bài = KHUNG + ẢNH MẶT LƯNG (§37): khung là hình
          // thang phối cảnh bám sát mép lá bài (tỉ lệ bộ bài cơ
          // bản 5:8, cạnh xa ngắn hơn cạnh gần), bên trong khung
          // là ẢNH MẶT LƯNG của bộ bài đang chọn — scale khớp vào
          // khung mặc định. Mỗi bộ bài up lên kèm 1 ảnh mặt lưng;
          // chọn bộ nào thì xấp hiện lưng bộ đó. Chưa có ảnh lưng
          // thì dùng ảnh lưng mặc định (deck_back_default.png).
          // Mép giấy kem + bóng đổ mềm làm xấp có khối, đặt thật
          // trên bàn. Không còn vẽ mặt lưng bằng code nữa.
          _DeckStackFrame(
            width: stackWidth,
            backImageUrl: context
                .watch<DeckProvider>()
                .selectedDeck
                ?.backImageUrl,
          ),
          const SizedBox(height: 6),
          Text(
            settings.tr('reading.deckStack'),
            style: TextStyle(
              color: theme.primaryColor,
              fontSize: Responsive.isDesktop(context) ? 11 : 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom ScrollBehavior hỗ trợ kéo cuộn bằng chuột trên Web & Desktop
class MouseDragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

enum TarotSuit { major, wands, cups, swords, pentacles }

TarotSuit _getCardSuit(TarotCardModel card) {
  final path = card.imagePath.toLowerCase();
  if (RegExp(r'm\d+').hasMatch(path)) return TarotSuit.major;
  if (RegExp(r'w\d+').hasMatch(path)) return TarotSuit.wands;
  if (RegExp(r'c\d+').hasMatch(path)) return TarotSuit.cups;
  if (RegExp(r's\d+').hasMatch(path)) return TarotSuit.swords;
  if (RegExp(r'p\d+').hasMatch(path)) return TarotSuit.pentacles;
  return TarotSuit.major; // Fallback
}
