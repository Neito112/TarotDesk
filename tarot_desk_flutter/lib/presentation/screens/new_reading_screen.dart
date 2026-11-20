import 'dart:math';
import 'dart:ui'; // Cần thiết cho PointerDeviceKind và kéo thả bằng chuột
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../core/responsive.dart';
import '../../data/models/tarot_card.dart';
import '../../data/models/user_preferences.dart';
import '../../logic/deck_provider.dart';
import '../../logic/reading_provider.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';
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
  // Thanh cuộn của panel giải nghĩa (luôn hiện để thấy còn nội dung).
  final ScrollController _meaningScrollController = ScrollController();

  // Nhạc huyền bí (YouTube): controller + bài đang phát + ô nhập link.
  // Player YoutubePlayer nằm trong Offstage (giữ trong cây để nhạc
  // chạy nền khi đóng panel nhạc) — xem _buildMusicPlayer. Nhạc
  // KHÔNG tự phát khi mở màn (autoPlay: false) — người dùng chạm
  // một bài (hoặc nút phát) mới phát, đúng luật autoplay của trình
  // duyệt (phát tiếng phải sau cử chỉ của người dùng).
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
  /// khay và (phone) chạm vào lá đang xem. Lá đang trên sân khấu
  /// BAY về đúng vị trí của nó trong khay (liền mạch, không ngắt
  /// cảnh) rồi lá được chọn mới lên sân.
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

  /// Rút một lá từ bộ bài: lá hiện lên màn hình (lá đang đọc)
  /// và đồng thời hiện trong khay (khay chứa toàn bộ các lá đã
  /// rút). Lá đang trên sân khấu (nếu có) BAY về đúng vị trí của
  /// nó trong khay rồi lá mới bay từ xấp bài vào sân. Trả về
  /// false nếu lá đã rút rồi.
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
                child: Text(
                  readingProvider.currentReadingTitle,
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
                    ? 'Nhạc huyền bí: đang phát — chạm để đổi bài'
                    : 'Nhạc huyền bí',
                onPressed: () => _openMusicSheet(context, theme),
              );
            },
          ),
          // Đổi bàn / khăn / đồ decor ngay trong lúc trải bài.
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Đổi bàn, khăn, đồ decor',
            onPressed: () => _showTableSettingsDialog(context, settings, theme),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Xóa hết lá bài đang chọn',
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
            tooltip: 'Lưu lượt bói này',
            onPressed: () async {
              if (drawnCards.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng chọn ít nhất một lá bài trước khi lưu!')),
                );
                return;
              }
              if (deckProvider.selectedDeck?.id != null) {
                await readingProvider.saveCurrentReading(deckProvider.selectedDeck!.id!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã lưu kết quả trải bài vào Lịch Sử!')),
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
                          ? _buildSelectionPanel(deckCards, readingProvider, theme)
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
    // Player nhạc YouTube: ẩn (Offstage) nhưng giữ trong cây để
    // nhạc chạy nền khi đóng panel nhạc.
    Offstage(
      offstage: true,
      child: YoutubePlayer(
        controller: _musicController,
        aspectRatio: 16 / 9,
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
                          drawnCardsCountText(),
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
                        ? _buildSelectionPanel(deckCards, readingProvider, theme)
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

  String drawnCardsCountText() {
    final n = context.read<ReadingProvider>().drawnCards.length;
    return n == 0 ? 'Chưa rút lá nào' : 'Đã rút $n lá';
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
        Positioned(
          top: 4,
          left: 4,
          child: CardStackWidget(
            onTap: () {
              setState(() {
                _showSelectionPanel = true;
              });
            },
            theme: theme,
          ),
        ),
        // Lá đang đọc HIỆN TRÊN MÀN HÌNH: lá lớn 170 rộng ở
        // giữa-phía trước, panel giải nghĩa ngay BÊN CẠNH nó.
        // Đổi lá: lá MỚI lên sân từ dưới, lá CŨ BAY VỀ KHAY (về
        // đúng vị trí của nó trong khay, liền mạch, không ngắt
        // cảnh — xem _trayFlight; switcher không vẽ lá cũ nữa
        // để không hiện hai bản). Sân chỉ giữ một lá tại một
        // thời điểm. Lá vừa rút thì bay từ xấp bài (tween riêng),
        // không trượt thêm (hai chuyển động cùng lúc trên cùng
        // một lá = giật). Vào 250ms / ra 150ms (ra ngắn hơn ~40%).
        // Nếu đo rect để bay về khay không được (lá trong khay bị
        // cuộn ra ngoài) thì giữ hiệu ứng cũ: lá cũ trượt xuống +
        // mờ dần.
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
                        // không trượt thêm, chỉ mờ.
                        final isJustDrawn = isIncoming &&
                            activeCard.id == _lastDrawnId;
                        final slide = isJustDrawn
                            ? Tween<Offset>(
                                begin: Offset.zero, end: Offset.zero)
                            : Tween<Offset>(
                                begin: const Offset(0, 0.25),
                                end: Offset.zero);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: slide.animate(animation),
                            child: child,
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
  /// bàn. Trên bàn không còn lá nào.
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
    if (!isNew) return tile;
    // Hoạt ảnh rút bài: MỘT tween — bay từ hướng xấp bài vào vị
    // trí đọc, nhỏ->lớn dần, đáp mềm bằng easeOutCubic.
    return TweenAnimationBuilder<double>(
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

  /// Phụ kiện trên mép xa của bàn PC: các ảnh CẮT TRONG SUỐT (chỉ
  /// giữ vật thể, nền đã tách) đặt theo tọa độ phân số CỐ ĐỊNH
  /// trong code (xem _decorCutoutRect — một nguồn sự thật duy
  /// nhất, không đo ngược pixel), tính theo phân số của kích thước
  /// bàn (LayoutBuilder), cùng Stack với lớp khăn nên luôn khớp
  /// khăn ở mọi viewport. Bóng tiếp xúc vẽ bằng code ngay dưới
  /// chân mỗi vật (xem _buildDesktopDecorCutout): KHÔNG ClipOval,
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
  /// (xem _decorCutoutRect): neo góc trên-trái tại (x, y) phân số
  /// của bàn. KHUNG TÍNH THEO CHIỀU RỘNG (rộng = w bàn x w phân
  /// số), chiều cao suy từ TỈ LỆ THẬT của ảnh cắt (xem
  /// _decorCutoutAspect) — KHÔNG BAO GIỜ BoxFit.fill: khung phân
  /// số trên viewport 16:9 có tỉ lệ khác ảnh gốc nên vật bị kéo
  /// méo. Ảnh trong suốt vẽ bằng BoxFit.contain trong khung đúng
  /// tỉ lệ. Bóng tiếp xúc là một ellipse đen mờ vẽ bằng code NGAY
  /// DƯỚI CHÂN vật (dưới đáy khung) để vật "đứng trên" mặt gỗ.
  Widget _buildDesktopDecorCutout(String item, double w, double h) {
    final asset = _decorCutoutAsset(item);
    final rect = _decorCutoutRect(item);
    if (asset == null || rect == null) {
      // 'Lá Khô' chưa có ảnh cắt: icon fallback đặt ở ô của
      // Hương Trầm (x .52, y .10), 60 rộng.
      return Positioned(
        left: w * 0.52,
        top: h * 0.10,
        width: 60,
        height: 60,
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black54,
          ),
          child: const Icon(Icons.eco,
              color: Colors.orangeAccent, size: 54),
        ),
      );
    }
    // Rộng theo phân số của bàn; cao suy từ tỉ lệ thật của ảnh.
    final boxWidth = w * rect.width;
    final boxHeight = boxWidth * _decorCutoutAspect(item);
    return Positioned(
      left: w * rect.left,
      top: h * rect.top,
      width: boxWidth,
      height: boxHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Bóng ĐỔ: bóng hắt xuống-phải theo ánh sáng của bàn
          // (sáng từ trên-trái), kéo dài trên mặt bàn và mờ dần
          // — vật "đứng" trên bàn thay vì dán lên tranh. Vẽ bằng
          // code (chữ nhật xiên + gradient) nên đổi màu khăn vẫn
          // đúng. Cần Clip.none của Stack này để bóng tràn ra
          // ngoài khung vật, xuống-phải mặt khăn.
          Positioned(
            left: boxWidth * 0.10,
            top: boxHeight * 0.55,
            width: boxWidth * 1.15,
            height: boxHeight * 0.55,
            child: Transform(
              transform: Matrix4.skewX(0.45),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withOpacity(0.45),
                      Colors.black.withOpacity(0.0),
                    ],
                    stops: const [0.0, 0.85],
                  ),
                  borderRadius:
                      BorderRadius.circular(boxHeight * 0.18),
                ),
              ),
            ),
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
  /// null = không có ảnh cắt (dùng icon fallback).
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
        return null; // 'Lá Khô': chưa có ảnh cắt, dùng icon.
    }
  }

  /// Tọa độ LỚP (layout constants) của từng món decor — phân số
  /// của chiều rộng / chiều cao bàn, MỘT NGUỒN SỰ THẬT DUY NHẤT
  /// cho vị trí vật trên bàn (HyperFrames: bố cục định trong code
  /// trước, ảnh trong suốt chỉ đặt vào đúng tọa độ này). Chiều cao
  /// trong Rect này KHÔNG dùng để đặt khung nữa (khung tính từ
  /// chiều rộng + tỉ lệ thật của ảnh, xem _decorCutoutAspect);
  /// nó chỉ còn là vị trí gốc đã đo từ tranh master.
  Rect? _decorCutoutRect(String item) {
    switch (item) {
      case 'Đá Thạch Anh':
        return const Rect.fromLTWH(0.245, 0.12, 0.10, 0.16);
      case 'Quả Cầu':
        return const Rect.fromLTWH(0.368, 0.098, 0.09, 0.187);
      case 'Hương Trầm':
        return const Rect.fromLTWH(0.52, 0.0, 0.11, 0.27);
      case 'Nến Đen':
        return const Rect.fromLTWH(0.625, 0.03, 0.10, 0.24);
      default:
        return null;
    }
  }

  /// Một sprite phụ kiện: ảnh vẽ (painted) hiện TOÀN BỘ khung ảnh,
  /// không bo tròn như trước — cách bo tròn cũ cắt mất ngọn nến, khói trầm và các
  /// chi tiết cao của vật. Ảnh nền đen, đặt trên bàn tối nên hòa
  /// vào mặt bàn như một bức ảnh hoàn chỉnh. Món không có ảnh
  /// (Lá Khô) giữ icon cũ làm fallback. Vật thể BÁM SÁT mặt bàn:
  /// KHÔNG còn bóng đổ lơ lửng quanh sprite (boxShadow offset).
  /// Thay vào đó là một ellipse đen nằm NGAY DƯỚI CHÂN vật, chạm
  /// vào đáy sprite — vật "đứng trên" mặt gỗ/khăn, chân đặt đúng
  /// đường mặt bàn.
  Widget _buildDecorSprite(String item, double size) {
    final asset = _decorImageAsset(item);
    final body = asset != null
        ? Container(
            width: size,
            height: size,
            color: Colors.black,
            child: Image.asset(asset,
                fit: BoxFit.contain, width: size, height: size),
          )
        : Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black54,
            ),
            // Fallback: món không có ảnh thật (Lá Khô) giữ icon cũ.
            child: Icon(Icons.eco,
                color: Colors.orangeAccent, size: size * 0.9),
          );
    return SizedBox(
      width: size,
      height: size + 12,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
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

  /// Ảnh vẽ (painted) cho từng món decor, null = không có ảnh (dùng
  /// icon). Cùng cách vẽ với tranh bàn gỗ và khăn vẽ, để mọi vật
  /// trên bàn nhìn như một bức ảnh hoàn chỉnh. Ảnh nền đen, đặt
  /// trên bàn tối nên hòa nền.
  String? _decorImageAsset(String item) {
    switch (item) {
      case 'Đá Thạch Anh':
        return 'assets/images/decor_crystal_painted.png';
      case 'Quả Cầu':
        return 'assets/images/decor_crystal_ball_painted.png';
      case 'Hương Trầm':
        return 'assets/images/decor_incense_painted.png';
      case 'Nến Đen':
        return 'assets/images/decor_candle_painted.png';
      default:
        return null; // 'Lá Khô': chưa có ảnh thật, dùng icon.
    }
  }

  Widget _buildDesktopEmptyHint(dynamic theme) {
    return Center(
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
                  label: const Text('Chọn lá bài',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
                'Chạm vào xấp bài góc trên-trái để bắt đầu chọn.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      ),
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
            Text(
              activeCard.name,
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
                    child: Text(
                      activeCard.meaning,
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
  /// Dialog đổi bàn / khăn / decor ngay trong lúc trải bài (PC + phone).
  /// Bố cục lại: hai cột trên desktop (trái: bàn + khăn, phải:
  /// decor + lớp hiển thị), một cột trên phone; chọn bằng chip
  /// nhìn (không còn dropdown) cho nhanh; danh sách dùng chung
  /// hằng số trong UserPreferencesModel (không hard-code riêng
  /// nữa) để không lệch với màn Cài đặt.
  void _showTableSettingsDialog(
      BuildContext context, SettingsProvider settings, dynamic theme) {
    final prefs = settings.userPrefs;
    final isDesktop = Responsive.isDesktop(context);

    Widget sectionTitle(String title) => Text(title,
        style: TextStyle(
            color: theme.primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 13));

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
            label: Text(opt,
                style: TextStyle(
                    color:
                        isSelected ? Colors.black : theme.textColor,
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal)),
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
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: UserPreferencesModel.decorOptions.map((item) {
          final selected = prefs.decorItems.contains(item);
          return FilterChip(
            selectedColor: theme.primaryColor.withOpacity(0.3),
            checkmarkColor: theme.primaryColor,
            label: Text(item,
                style: TextStyle(
                    color: selected ? theme.primaryColor : theme.textColor,
                    fontSize: 12)),
            selected: selected,
            visualDensity: VisualDensity.compact,
            onSelected: (v) {
              final current = List<String>.from(prefs.decorItems);
              if (v) {
                if (current.length <
                    UserPreferencesModel.maxDecorItems) {
                  current.add(item);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Chỉ được chọn tối đa 3 món trang trí!'),
                        duration: Duration(seconds: 1)),
                  );
                }
              } else {
                current.remove(item);
              }
              settings.setDecorItems(current);
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
            style: TextStyle(color: theme.textColor, fontSize: 13)),
        value: value,
        activeColor: theme.primaryColor,
        onChanged: onChanged,
      );
    }

    final tableAndCloth = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        sectionTitle('Mặt bàn'),
        const SizedBox(height: 6),
        optionChips(
          options: UserPreferencesModel.tableStyles,
          selected: prefs.tableStyle,
          onSelected: (v) => settings.setTableStyle(v),
        ),
        const SizedBox(height: 4),
        Text(
          'Áp dụng trên điện thoại / máy tính bảng. Bản PC dùng tranh bàn gỗ trống.',
          style: TextStyle(
              color: theme.secondaryTextColor, fontSize: 11, height: 1.4),
        ),
        const SizedBox(height: 14),
        sectionTitle('Khăn trải bàn'),
        const SizedBox(height: 6),
        optionChips(
          options: UserPreferencesModel.clothStyles,
          selected: prefs.clothStyle,
          onSelected: (v) => settings.setClothStyle(v),
        ),
        const SizedBox(height: 4),
        Text(
          'Đổi ngay trên bàn: khăn là lớp riêng to và phẳng trên mặt gỗ.',
          style: TextStyle(
              color: theme.secondaryTextColor, fontSize: 11, height: 1.4),
        ),
      ],
    );

    final decorAndLayers = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        sectionTitle(
            'Đồ trang trí (tối đa ${UserPreferencesModel.maxDecorItems} món)'),
        const SizedBox(height: 6),
        decorChips(),
        const SizedBox(height: 14),
        sectionTitle('Hiển thị các lớp trên bàn'),
        layerSwitch(
          title: 'Hiện mặt bàn',
          value: prefs.showTable,
          onChanged: (v) => settings.toggleTable(v),
        ),
        layerSwitch(
          title: 'Hiện khăn trải bàn',
          value: prefs.showCloth,
          onChanged: (v) => settings.toggleCloth(v),
        ),
        layerSwitch(
          title: 'Hiện đồ decor',
          value: prefs.showDecor,
          onChanged: (v) => settings.toggleDecor(v),
        ),
      ],
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: theme.backgroundColor,
          title: Text('Đổi bàn trải bài',
              style: TextStyle(color: theme.textColor, fontSize: 16)),
          content: SizedBox(
            width: isDesktop ? 560 : 340,
            child: SingleChildScrollView(
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
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Bản PC là bàn vẽ nhiều lớp: nền gỗ trống, khăn là ảnh cắt trong suốt vẽ thẳng trên bàn (khớp điểm tụ và góc độ với bàn), phụ kiện là ảnh cắt trong suốt đặt đúng vị trí trên mép bàn. Đổi màu khăn hay phụ kiện ở đây sẽ đổi ngay trên bàn.',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 12, height: 1.5),
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Xong', style: TextStyle(color: theme.primaryColor)),
            ),
          ],
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
                label: const Text(
                  'Chọn lá bài',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 28),
                    SizedBox(height: 12),
                    Text(
                      'Chạm vào xấp bài bên trái để bắt đầu chọn.\n\nKéo các lá bài từ khay lịch sử lên đây hoặc chạm để xem giải nghĩa.\n\nKéo lá bài đang chọn xuống hoặc vuốt xuống để thu hồi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
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
  /// Lá vẫn nằm trong lượt trải (cả trong khay) — chạm vào lá
  /// trong khay là đổi lá đang xem. Không còn "thu lá" nữa.
  Widget _buildActiveCard(TarotCardModel activeCard, dynamic theme, double cardWidth) {
    final cardHeight = cardWidth * 8 / 5;
    return TweenAnimationBuilder<double>(
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
  /// chọn vẫn nằm trong khung của nó (trên bàn / trong khay) — panel
  /// chỉ hiện nội dung của lá đó.
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
            Text(
              activeCard.name,
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
                  child: Text(
                    activeCard.meaning,
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
  Widget _buildSelectionPanel(List<TarotCardModel> deckCards, ReadingProvider readingProvider, dynamic theme) {
    // Phân loại các lá bài theo Suit
    final List<TarotCardModel> activeCards;
    String suitLabel = '';
    switch (_selectedSuit) {
      case TarotSuit.major:
        activeCards = deckCards.where((c) => _getCardSuit(c) == TarotSuit.major).toList();
        suitLabel = 'Ẩn Chính (Major Arcana)';
        break;
      case TarotSuit.cups:
        activeCards = deckCards.where((c) => _getCardSuit(c) == TarotSuit.cups).toList();
        suitLabel = 'Bộ Cốc (Cups)';
        break;
      case TarotSuit.wands:
        activeCards = deckCards.where((c) => _getCardSuit(c) == TarotSuit.wands).toList();
        suitLabel = 'Bộ Gậy (Wands)';
        break;
      case TarotSuit.swords:
        activeCards = deckCards.where((c) => _getCardSuit(c) == TarotSuit.swords).toList();
        suitLabel = 'Bộ Kiếm (Swords)';
        break;
      case TarotSuit.pentacles:
        activeCards = deckCards.where((c) => _getCardSuit(c) == TarotSuit.pentacles).toList();
        suitLabel = 'Bộ Xu (Pentacles)';
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
                const Expanded(
                  child: Text(
                    'Chọn lá bài',
                    style: TextStyle(
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
                  tooltip: 'Đóng khay chọn bài',
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
    return ScrollConfiguration(
      behavior: MouseDragScrollBehavior(), // Tương tác trượt ngang bằng chuột/ngón tay
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildSuitChip(TarotSuit.major, 'Ẩn Chính', theme),
            _buildSuitChip(TarotSuit.cups, 'Bộ Cốc', theme),
            _buildSuitChip(TarotSuit.wands, 'Bộ Gậy', theme),
            _buildSuitChip(TarotSuit.swords, 'Bộ Kiếm', theme),
            _buildSuitChip(TarotSuit.pentacles, 'Bộ Xu', theme),
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
  Widget _buildBottomTray(List<TarotCardModel> drawnCards, ReadingProvider readingProvider, dynamic theme) {
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
          'Chưa rút lá nào — chạm vào xấp bài để chọn.',
          style: TextStyle(color: theme.secondaryTextColor, fontSize: _isDesktop ? 12 : 13),
        ),
      );
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
          // (hiện trên màn hình và trong khay).
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
                itemCount: drawnCards.length,
                itemBuilder: (context, index) {
                  final card = drawnCards[index];
                  final isSelected = _selectedCardIndex == index;

                  return GestureDetector(
                    onTap: () => _selectCard(index),
                    child: _buildBottomTrayItem(card, isSelected, theme, trayThumbWidth),
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
  /// lá đáp xuống (cùng rect nên không thấy ngắt cảnh).
  Widget _buildBottomTrayItem(
      TarotCardModel card, bool isSelected, dynamic theme, double width) {
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
            color: isSelected ? theme.primaryColor : theme.glassBorderColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 6, spreadRadius: 1)]
              : [],
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

  /// Nền bàn — PC: cảnh vẽ LỚP (HyperFrames, bố cục định trong
  /// code): LỚP 1 là bàn gỗ TRỐNG `table_bare_wood.png` (BoxFit.
  /// cover, chiếm toàn bộ viewport) — không còn gì vẽ sẵn trong
  /// nền. LỚP 2 là khăn CẮT TRONG SUỐT toàn khung (cả 3 màu, vẽ
  /// thẳng trên bàn gỗ trống rồi tách nền — xem _clothImageAsset),
  /// đặt ngay trong Stack này (Positioned.fill, BoxFit.cover, cùng
  /// box với nền) nên luôn khớp pixel với gỗ ở mọi viewport; đổi
  /// màu thì cross-fade ngay (AnimatedSwitcher, chỉ mờ, không
  /// scale). LỚP 3 phụ kiện cắt trong suốt (xem
  /// _buildDesktopDecorCutouts trong _buildDesktopTable). Trên bàn
  /// không còn lá nào — lá đang đọc hiện trên màn hình (xem
  /// _buildDesktopStage). KHÔNG còn lớp khăn màu phẳng cũ, KHÔNG còn lớp phủ tối toàn màn — chỉ một
  /// vệt tối nhẹ sát mép dưới (sau khay bài). Tắt "Hiện mặt bàn" thì
  /// tranh tắt, nền đen. Tắt "Hiện khăn" thì lớp khăn ẩn, chỉ còn
  /// gỗ trống. Phone/tablet giữ như cũ: ảnh bàn -> khăn màu phẳng
  /// -> scrim tối -> nội dung -> hàng icon decor trên cùng.
  Widget _buildTableBackground(UserPreferencesModel prefs, Widget child) {
    // PC: nền là bàn gỗ TRỐNG (HyperFrames LỚP 1) — khăn và decor
    // là các lớp riêng phía trên, trong cùng Stack của bàn
    // (_buildDesktopTable); các kiểu bàn/khăn cũ chỉ áp dụng
    // phone/tablet.
    final isDesktop = Responsive.isDesktop(context);
    String tableImage;
    if (isDesktop) {
      tableImage = 'assets/images/table_bare_wood.png';
    } else if (prefs.tableStyle == 'Đá Cổ') {
      tableImage = 'assets/images/table_stone_texture.jpg';
    } else if (prefs.tableStyle == 'Vũ Trụ') {
      tableImage = 'assets/images/tarot_main_background.jpg';
    } else {
      tableImage = 'assets/images/table_wood_texture.jpg';
    }

    Color clothColor;
    if (prefs.clothStyle == 'Nhung Tím') {
      clothColor = const Color(0xFF2E173C).withOpacity(0.85);
    } else if (prefs.clothStyle == 'Lụa Vàng') {
      clothColor = const Color(0xFF705A12).withOpacity(0.85);
    } else {
      // Thảm Đen
      clothColor = const Color(0xFF141414).withOpacity(0.85);
    }

    // PC: không build icon decor ở đây — phụ kiện là ảnh cắt trong
    // suốt, đặt theo tọa độ cố định trên mép xa của bàn (xem
    // _buildDesktopDecorCutouts trong _buildDesktopTable).
    // Phone/tablet giữ hàng icon như cũ.
    final decorWidgets = isDesktop
        ? const <Widget>[]
        : _buildDynamicDecorWidgets(prefs.decorItems, 28.0);

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
          // LỚP KHĂN (PC, HyperFrames): khăn là ảnh CẮT TRONG SUỐT
          // toàn khung (1920x1280) — vẽ thẳng trên bàn gỗ trống,
          // khớp điểm tụ và góc độ với bàn, rồi tách nền chỉ còn
          // khăn. Đặt ở ĐÂY (Positioned.fill, BoxFit.cover, cùng
          // box với DecorationImage nền gỗ) nên khăn và gỗ luôn
          // khớp pixel ở mọi viewport, không cần cắt hình thang
          // bằng code nữa. Chỉ mờ đổi khi đổi màu (không scale —
          // scale sẽ làm lệch khớp với gỗ trong lúc chuyển).
          if (prefs.showCloth && isDesktop)
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: Image.asset(
                  _clothImageAsset(prefs.clothStyle),
                  key: ValueKey('cloth-${prefs.clothStyle}'),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
            ),
          // LỚP 2: Tấm khăn thảm phủ bàn bói bài bo tròn kéo rộng (Tùy chỉnh bật tắt)
          // PC: bỏ qua — khăn nhung tím trải phẳng đã vẽ sẵn trong tranh.
          if (prefs.showCloth && !isDesktop)
            Align(
              alignment: Alignment.center,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                margin: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 8 : 14,
                    vertical: isDesktop ? 8 : 14),
                decoration: BoxDecoration(
                  color: clothColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: prefs.clothStyle == 'Lụa Vàng'
                        ? const Color(0xFFD4AF37) // Gold border
                        : const Color(0xFF9D4EDD), // Purple border
                    width: isDesktop ? 1.5 : 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.7),
                      blurRadius: 20,
                      spreadRadius: 2,
                    )
                  ],
                ),
              ),
            ),

          // Lớp phủ tối: chữ trắng đọc được trên mọi ảnh nền.          // Lớp phủ tối: chữ trắng đọc được trên mọi ảnh nền.
          // PC: KHÔNG làm tối cả bức tranh — chỉ một vệt tối nhẹ ở
          // sát mép dưới (phía sau khay bài). Tranh giữ nguyên độ
          // sáng và màu. Panel giải nghĩa đã có nền đen 0.72 riêng.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: isDesktop ? const [0.0, 0.78, 1.0] : null,
                colors: isDesktop
                    ? const [
                        Color(0x00000000),
                        Color(0x00000000),
                        Color(0x66000000),
                      ]
                    : const [
                        Color(0x8A000000),
                        Color(0x40000000),
                        Color(0xA6000000),
                      ],
              ),
            ),
          ),

          // LỚP 3: Nội dung của ứng dụng
          child,

          // LỚP 4: Đồ trang trí — chỉ phone/tablet: hàng icon nhỏ ở
          // trên cùng, luôn IgnorePointer. PC: không có gì ở đây,
          // phụ kiện là ảnh cắt đặt đúng vị trí trên mép xa của bàn
          // (xem _buildDesktopDecorCutouts trong _buildDesktopTable).
          if (prefs.showDecor && !isDesktop)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: decorWidgets,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

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

  /// Các biểu tượng trang trí: chỉ trả về widget, vị trí do hàng
  /// ở trên cùng của _buildTableBackground quyết định.
  /// Món nào có ảnh vẽ (thạch anh, quả cầu, trầm, nến) dùng
  /// sprite ảnh vẽ (_buildDecorSprite); món không có ảnh
  /// (Lá Khô) giữ icon cũ làm fallback. Bản PC dùng ảnh cắt đặt
  /// đúng vị trí (xem _buildDesktopDecorCutouts).
  List<Widget> _buildDynamicDecorWidgets(List<String> items, [double size = 28]) {
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
          title: Text('Đổi tên lượt trải bài', style: TextStyle(color: theme.textColor)),
          content: TextField(
            controller: controller,
            style: TextStyle(color: theme.textColor),
            decoration: InputDecoration(
              hintText: 'Nhập tên lượt trải bài...',
              hintStyle: TextStyle(color: theme.secondaryTextColor),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.primaryColor)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Hủy', style: TextStyle(color: theme.secondaryTextColor)),
            ),
            TextButton(
              onPressed: () {
                readingProvider.updateTitle(controller.text);
                Navigator.pop(context);
              },
              child: Text('Lưu', style: TextStyle(color: theme.primaryColor)),
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

class CardStackWidget extends StatelessWidget {
  final VoidCallback onTap;
  final dynamic theme;

  const CardStackWidget({Key? key, required this.onTap, required this.theme}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Xấp bài ở góc bàn — to và rõ để thấy và chạm: PC 84 rộng
    // (trước 60), tablet 100, phone 84.
    final stackWidth = Responsive.isDesktop(context)
        ? 84.0
        : Responsive.isTablet(context)
            ? 100.0
            : 84.0;
    final backWidth = stackWidth * 0.86;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(8, 12),
                ),
              ],
            ),
            child: SizedBox(
              width: stackWidth,
              child: AspectRatio(
                aspectRatio: 5 / 8,
                child: Stack(
                children: [
                  // Lá bài thứ 3 dưới cùng
                  Transform.translate(
                    offset: const Offset(-5, 3),
                    child: Transform.rotate(
                      angle: -0.06,
                      child: _buildCardBack(backWidth),
                    ),
                  ),
                  // Lá bài thứ 2 ở giữa
                  Transform.translate(
                    offset: const Offset(3, 1),
                    child: Transform.rotate(
                      angle: 0.05,
                      child: _buildCardBack(backWidth),
                    ),
                  ),
                  // Lá bài trên cùng
                  _buildCardBack(backWidth),
                ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'XẤP BÀI',
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

  Widget _buildCardBack(double width) {
    return Container(
      width: width,
      height: width * 8 / 5,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.primaryColor.withOpacity(0.4), width: 1),
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [
            theme.primaryColor.withOpacity(0.15),
            Colors.black87,
          ],
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 2, offset: Offset(1, 1))
        ],
      ),
      child: const Center(
        child: Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 16),
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
