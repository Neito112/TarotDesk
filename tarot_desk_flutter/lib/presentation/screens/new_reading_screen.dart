import 'dart:math';
import 'dart:ui'; // Cần thiết cho PointerDeviceKind và kéo thả bằng chuột
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../data/models/tarot_card.dart';
import '../../data/models/user_preferences.dart';
import '../../logic/deck_provider.dart';
import '../../logic/reading_provider.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';
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
/// PC (desktop): bàn là một BỨC TRANH VẼ 3D (HyperFrames-style —
/// tranh vẽ phối cảnh góc nhìn thứ nhất, KHÔNG phải engine 3D thời
/// gian thực, KHÔNG dùng Matrix4 nghiêng mặt phẳng). Nền là bàn gỗ
/// trống `assets/images/table_wood_only.png` (BoxFit.cover, toàn bộ
/// viewport); KHĂN là một LỚP RIÊNG trên mặt gỗ — tấm nhung phẳng
/// TO (85% chiều rộng, 70% chiều cao bàn), màu theo Khăn trải bàn
/// đã chọn (Nhung Tím / Lụa Vàng / Thảm Đen), đổi trong lúc trải
/// bài hoặc trong Cài đặt là đổi ngay (cross-fade, không nhảy).
/// Phụ kiện là các sprite ảnh thật RIÊNG BIỆT, đặt trên mép xa
/// của bàn, đổi được và cập nhật ngay. Các lá bài trải nằm TRÊN
/// lớp khăn to đó. Lá đang đọc hiện TO ở giữa-phía trước của khăn,
/// panel giải nghĩa ngay BÊN CẠNH nó; chạm vào lá đang hiện để
/// thu xuống khay (có hoạt ảnh bay xuống khay). Mọi thao tác đều
/// có hoạt ảnh di chuyển mượt (rút / chọn / thu / đổi khăn /
/// đổi decor / đổi kiểu trải). Phone/tablet giữ bản đơn giản đã có.
///
/// Bám sát mặt bàn: khăn là hình thang phối cảnh với bóng tiếp xúc,
/// phụ kiện có bóng tiếp xúc dưới chân và vẽ nhỏ lại ở mép xa.
/// Lá đã thu xuống khay thì biến mất khỏi bàn hoàn toàn, chỉ còn
/// trong khay (khay PC: lá 100 rộng, cao 176).
class NewReadingScreen extends StatefulWidget {
  const NewReadingScreen({Key? key}) : super(key: key);

  @override
  State<NewReadingScreen> createState() => _NewReadingScreenState();
}

class _NewReadingScreenState extends State<NewReadingScreen> {
  int _selectedCardIndex = -1; // Mặc định là -1 (Không hiển thị khung giải nghĩa khi bắt đầu để nhìn rõ bàn bói)
  bool _showSelectionPanel = false; // Trạng thái mở khay chọn bài từ xấp bài
  TarotSuit _selectedSuit = TarotSuit.major; // Nhóm bài được chọn mặc định ban đầu là Ẩn Chính
  int? _lastDrawnId; // Lá vừa rút: bay từ xấp bài ra bàn (desktop) / bay lên (phone)
  bool _isCollecting = false; // Đang chạy hoạt ảnh thu lá lớn xuống khay (desktop)

  // Lá ĐÃ THU xuống khay: chỉ còn trong khay, KHÔNG còn trên bàn
  // (không ở vùng trải, không ở sân khấu). Tách riêng khỏi
  // drawnCards của ReadingProvider — lá vẫn nằm trong drawnCards
  // (để khay + lưới chọn bài còn biết nó đã rút), nhưng bàn thì
  // không hiện gì cho nó nữa.
  final Set<int> _collectedIds = {};

  // Mật độ gọn cho PC 4K: mọi thứ nhỏ lại, bàn chiếm toàn bộ khung hình.
  bool get _isDesktop => Responsive.isDesktop(context);
  bool get _isPhone => Responsive.isPhone(context);

  // Chiều rộng lá bài đang chọn theo từng loại thiết bị (tỉ lệ 5:8).
  // PC 4K: 150 (gọn, không phải 240). Tablet ở giữa: 200. Phone giữ 180.
  double _activeCardWidth(BuildContext context) {
    if (Responsive.isDesktop(context)) return 150;
    if (Responsive.isTablet(context)) return 200;
    return 180;
  }

  // Lá đang đọc trên bàn PC hiện TO ở phía trước khăn: 175 rộng.
  double get _desktopStageCardWidth => 175.0;

  double _meaningFontSize() => _isDesktop ? 14.0 : 15.0;
  double _cardNameFontSize() => _isDesktop ? 17.0 : (_isPhone ? 20.0 : 19.0);

  /// Thu lá đang đọc xuống khay: lá rời khỏi bàn HOÀN TOÀN (không
  /// còn ở vùng trải hay sân khấu) và chỉ còn trong khay dưới cùng.
  /// Lá vẫn nằm trong drawnCards của ReadingProvider, chỉ được đánh
  /// dấu đã thu — bàn lọc nó ra, khay vẫn hiện nó.
  void _collectCard() {
    if (_selectedCardIndex < 0) return;
    _collectIndex(_selectedCardIndex);
  }

  /// Thu một lá (theo index trong drawnCards) xuống khay.
  void _collectIndex(int index) {
    final drawnCards = context.read<ReadingProvider>().drawnCards;
    if (index < 0 || index >= drawnCards.length) return;
    setState(() {
      final id = drawnCards[index].id;
      if (id != null) _collectedIds.add(id);
      if (_selectedCardIndex == index) _selectedCardIndex = -1;
      _lastDrawnId = null; // Không chạy lại hoạt ảnh rút cho lá đã thu.
    });
  }

  /// Chọn lại một lá từ khay: lá quay lại bàn (bỏ khỏi tập đã thu)
  /// và hiện ở sân khấu để đọc.
  void _selectFromTray(int index) {
    final drawnCards = context.read<ReadingProvider>().drawnCards;
    if (index < 0 || index >= drawnCards.length) return;
    setState(() {
      _collectedIds.remove(drawnCards[index].id);
      _selectedCardIndex = index;
      _showSelectionPanel = false;
    });
  }

  /// Thu lá đang đọc xuống khay KÈM hoạt ảnh mượt (chỉ dùng trên
  /// bàn PC): lá bay nhỏ dần xuống khay dưới trong 450ms rồi mới
  /// rời khỏi bàn — kết quả giống hệt chạm vào lá lớn để thu.
  void _collectCardAnimated() {
    if (_isCollecting || _selectedCardIndex < 0) return;
    final index = _selectedCardIndex;
    final cardId =
        context.read<ReadingProvider>().drawnCards[index].id;
    setState(() => _isCollecting = true);
    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() {
        _isCollecting = false;
        // Chỉ đánh dấu đã thu nếu lá vẫn còn trong lượt trải (người
        // dùng có thể đã bấm "Xóa hết" trong lúc hoạt ảnh đang chạy).
        if (context
            .read<ReadingProvider>()
            .drawnCards
            .any((c) => c.id == cardId)) {
          if (cardId != null) _collectedIds.add(cardId);
        }
        if (_selectedCardIndex == index) _selectedCardIndex = -1;
        _lastDrawnId = null; // Không chạy lại hoạt ảnh rút cho lá đã thu.
      });
    });
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
                _collectedIds.clear();
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
      body: SmokeParticleEffect(
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
    );
  }

  /// Thân màn hình riêng cho PC: thanh công cụ kiểu trải + bàn trải bài
  /// chiếm toàn bộ chiều rộng, khay ở dưới cùng. Không ResponsiveCenter.
  Widget _buildDesktopBody(List<TarotCardModel> deckCards,
      ReadingProvider readingProvider, dynamic theme) {
    final drawnCards = readingProvider.drawnCards;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            _buildSpreadToolbar(theme),
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
      ),
    );
  }

  /// Thanh công cụ kiểu trải bài trên PC: "1 hàng" / "Nhiều hàng",
  /// đổi trực tiếp ngay trong lúc trải (lưu vào SettingsProvider).
  Widget _buildSpreadToolbar(dynamic theme) {
    final settings = context.read<SettingsProvider>();
    final mode = settings.userPrefs.spreadMode;
    Widget chip(String value, String label) {
      final selected = mode == value;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (v) {
          if (v) settings.setSpreadMode(value);
        },
        selectedColor: theme.primaryColor,
        backgroundColor: Colors.black45,
        labelStyle: TextStyle(
          color: selected ? Colors.black87 : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        visualDensity: VisualDensity.compact,
      );
    }

    // Thanh công cụ nổi trên bức tranh vẽ: nền tối mờ nhẹ để chữ
    // đọc được, không làm tối cả bức tranh.
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
      children: [
        Text(
          'Kiểu trải:',
          style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 12,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        chip('single', '1 hàng'),
        const SizedBox(width: 6),
        chip('multi', 'Nhiều hàng'),
        const Spacer(),
        Text(
          '${drawnCardsCountText()}',
          style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
        ),
      ],
      ),
    );
  }

  String drawnCardsCountText() {
    final n = context.read<ReadingProvider>().drawnCards.length;
    return n == 0 ? 'Chưa rút lá nào' : 'Đã rút $n lá';
  }

  /// Bàn trải bài góc nhìn thứ nhất trên PC: xấp bài ở góc trên-trái,
  /// phụ kiện (ảnh thật, đổi được) xếp đều trên mép xa của bàn, các
  /// lá đã rút KHÁC nằm thành hàng gọn TRÊN lớp khăn to, còn lá đang
  /// đọc hiện TO ở giữa-phía trước của khăn (175 rộng) với panel
  /// giải nghĩa ngay BÊN CẠNH nó. Chạm vào lá lớn để thu xuống khay.
  Widget _buildDesktopTable(List<TarotCardModel> drawnCards,
      ReadingProvider readingProvider, dynamic theme) {
    final activeCard = drawnCards.isNotEmpty &&
            _selectedCardIndex >= 0 &&
            _selectedCardIndex < drawnCards.length
        ? drawnCards[_selectedCardIndex]
        : null;
    final prefs = context.read<SettingsProvider>().userPrefs;
    final hasActive = activeCard != null;

    return DragTarget<Object>(
      onAccept: (data) {
        // Kéo một lá từ khay lên bàn: lá quay lại bàn để đọc.
        if (data is int) _selectFromTray(data);
      },
      builder: (context, candidateData, rejectedData) {
        return Stack(
          children: [
            // Các lá đã rút KHÁC nằm trên lớp khăn to (lá đang đọc
            // không nằm ở đây nữa — nó ở sân khấu phía trước).
            // Đẩy vùng trải xuống ~15% chiều cao bàn để lá bài nằm
            // đúng trên khăn hình thang (mép trên khăn ở 15%), thay
            // vì ở chính giữa màn.
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Padding(
                    padding: EdgeInsets.only(
                        top: constraints.maxHeight * 0.15),
                    child: drawnCards.isEmpty
                        ? _buildDesktopEmptyHint(theme)
                        : _buildSpread(drawnCards, theme),
                  );
                },
              ),
            ),
            // Phụ kiện: ảnh thật đặt riêng trên mép xa của bàn — một
            // hàng xếp đều trên viền gỗ phía trên khăn, sau xấp bài,
            // chân đặt SÁT mặt gỗ (bóng tiếp xúc dưới mỗi món, xem
            // _buildDecorSprite), vẽ nhỏ lại ở hàng xa (0.75×).
            // IgnorePointer nên không bao giờ chặn lá bài. Đổi trong
            // dialog/Cài đặt cập nhật ngay với hiệu ứng mờ dần
            // (AnimatedSwitcher theo danh sách decor đã chọn).
            if (prefs.showDecor && prefs.decorItems.isNotEmpty)
              Positioned(
                top: 0,
                left: 120,
                right: 24,
                height: 76,
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
                    child: _buildDesktopDecorSprites(prefs.decorItems),
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
            // Sân khấu phía trước khăn: lá đang đọc TO (175 rộng) ở
            // giữa-phía trước, panel giải nghĩa ngay BÊN CẠNH nó.
            // Đổi lá chọn thì cả cụm mờ/trượt đổi mượt (AnimatedSwitcher
            // theo id lá). Chạm vào lá lớn để thu xuống khay.
            if (activeCard != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 4,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, 0.08),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                            parent: animation, curve: Curves.easeInOut)),
                        child: child,
                      ),
                    );
                  },
                  child: _buildDesktopStage(activeCard, theme),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Sân khấu phía trước khăn (PC): lá đang đọc TO + gợi ý chạm để
  /// thu + panel giải nghĩa ngay bên cạnh, tất cả căn giữa trên khăn.
  Widget _buildDesktopStage(TarotCardModel activeCard, dynamic theme) {
    final stageCardWidth = _desktopStageCardWidth;
    final stageCardHeight = stageCardWidth * 8 / 5;
    return Center(
      key: ValueKey('stage-${activeCard.id}'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lá lớn + gợi ý chạm để thu xuống khay.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDesktopStageCard(activeCard, theme, stageCardWidth),
              const SizedBox(height: 6),
              const Text(
                'Chạm vào lá bài để thu xuống khay',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Panel giải nghĩa ngay bên cạnh lá lớn, cao bằng lá + gợi ý.
          SizedBox(
            width: 320,
            height: stageCardHeight + 24,
            child: _buildDesktopMeaningPanel(activeCard, theme),
          ),
        ],
      ),
    );
  }

  /// Lá lớn trên sân khấu PC: 175 rộng, viền vàng + glow. Lá vừa rút
  /// bay từ xấp bài (góc trên-trái) ra vị trí này trong 450ms
  /// (easeOutBack, giống trước). Đang thu thì bay nhỏ dần xuống khay
  /// dưới trong 450ms (easeInOut). Chạm vào lá để thu xuống khay.
  Widget _buildDesktopStageCard(
      TarotCardModel activeCard, dynamic theme, double width) {
    final isNew = activeCard.id == _lastDrawnId;
    final tile = GestureDetector(
      onTap: _collectCardAnimated,
      child: SizedBox(
        width: width,
        height: width * 8 / 5,
        child: _cardFrame(activeCard, theme, width),
      ),
    );
    if (_isCollecting) {
      // Thu lá xuống khay: bay xuống + nhỏ dần + mờ dần về phía khay.
      return TweenAnimationBuilder<double>(
        key: ValueKey('collect-${activeCard.id}'),
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
        builder: (context, v, child) {
          return Opacity(
            opacity: 1.0 - v,
            child: Transform.translate(
              offset: Offset(0, 280 * v),
              child: Transform.scale(
                scale: 1.0 - 0.65 * v,
                child: child,
              ),
            ),
          );
        },
        child: tile,
      );
    }
    if (!isNew) return tile;
    // Hoạt ảnh rút bài: bay từ xấp bài ra sân khấu, scale từ 0.6 lên 1.
    return TweenAnimationBuilder<double>(
      key: ValueKey('draw-${activeCard.id}'),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, v, child) {
        return Transform.translate(
          offset: Offset(-160 * (1 - v), -120 * (1 - v)),
          child: Transform.scale(scale: 0.6 + 0.4 * v, child: child),
        );
      },
      child: tile,
    );
  }

  /// Hàng phụ kiện trên mép xa của bàn PC: mỗi món đã chọn là một
  /// sprite ảnh thật (xem _decorImageAsset), chân đặt SÁT mặt gỗ
  /// (bóng tiếp xúc dưới mỗi món, xem _buildDecorSprite). Xếp đều
  /// nhau, không chồng lên lá bài hay xấp bài. Hàng xa vẽ ở 0.75×
  /// so với cỡ gần (80) — vật ở mép xa nhỏ lại theo phối cảnh.
  Widget _buildDesktopDecorSprites(List<String> items) {
    // Key theo danh sách món đã chọn để AnimatedSwitcher ở trên
    // nhận ra khi decor đổi và chạy hiệu ứng mờ/scale.
    const farSize = 60.0;
    return Row(
      key: ValueKey(items.join(',')),
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items) _buildDecorSprite(item, farSize),
      ],
    );
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

  /// Các lá đã rút KHÁC (không tính lá đang đọc — lá đó ở sân khấu
  /// phía trước) nằm trên lớp khăn to. 1 hàng: một hàng ngang duy
  /// nhất, căn giữa trên khăn, các lá cùng một cỡ (104 rộng), cùng
  /// một đường chân (căn đáy), khoảng cách đều, chồng nhẹ lên nhau
  /// 8px như xòe bài thật; nhiều lá thì cuộn ngang. Nhiều hàng: lưới
  /// căn giữa, tối đa 5 lá mỗi hàng, khoảng cách đều 12px, các hàng
  /// căn giữa, cuộn dọc. Đổi kiểu trải thì cả vùng trải mờ đổi mượt
  /// (AnimatedSwitcher theo kiểu trải). Chừa khoảng trống phía dưới
  /// cho sân khấu lá lớn + panel khi đang đọc một lá. Lá vừa rút bay
  /// từ xấp bài (góc trên-trái) ra vị trí của nó trên bàn.
  Widget _buildSpread(List<TarotCardModel> drawnCards, dynamic theme) {
    final settings = context.read<SettingsProvider>();
    final isSingle = settings.userPrefs.spreadMode == 'single';
    // Lá đang đọc ở sân khấu phía trước, không nằm trong vùng trải
    // này; lá ĐÃ THU xuống khay cũng không nằm ở đây nữa — bàn
    // không hiện gì cho lá đã thu, nó chỉ còn trong khay.
    final others = [
      for (var i = 0; i < drawnCards.length; i++)
        if (i != _selectedCardIndex &&
            !_collectedIds.contains(drawnCards[i].id))
          i,
    ];
    if (others.isEmpty) return const SizedBox.shrink();
    // Chừa chỗ phía dưới cho sân khấu (lá lớn 175 + gợi ý + panel)
    // khi đang đọc một lá, để vùng trải không bị sân khấu che.
    final hasActive = _selectedCardIndex >= 0 &&
        _selectedCardIndex < drawnCards.length;
    final bottomReserve = hasActive ? 320.0 : 8.0;

    Widget item(int index) {
      final card = drawnCards[index];
      final isNew = card.id == _lastDrawnId;
      // Các lá trong vùng trải đều 104 rộng (lá đang đọc to 175 ở
      // sân khấu phía trước, không ở đây).
      const width = 104.0;
      Widget tile = _buildSpreadCard(card, index, false, theme, width);
      if (!isNew) return tile;
      // Hoạt ảnh rút bài: bay từ xấp bài ra bàn, scale từ 0.6 lên 1.
      return TweenAnimationBuilder<double>(
        key: ValueKey('draw-${card.id}'),
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutBack,
        builder: (context, v, child) {
          return Transform.translate(
            offset: Offset(-160 * (1 - v), -120 * (1 - v)),
            child: Transform.scale(scale: 0.6 + 0.4 * v, child: child),
          );
        },
        child: tile,
      );
    }

    // Đổi kiểu trải: mờ đổi mượt giữa 1 hàng và nhiều hàng.
    final spread = isSingle ? _buildSpreadSingleRow(others, item) : _buildSpreadMultiRow(others, item, bottomReserve);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: KeyedSubtree(
        key: ValueKey('spread-$isSingle-$hasActive'),
        child: spread,
      ),
    );
  }

  /// Vùng trải 1 hàng: một hàng ngang duy nhất, căn giữa trên khăn,
  /// các lá cùng đường chân (căn đáy), chồng nhẹ 8px; rộng hơn vùng
  /// trải thì cuộn ngang.
  Widget _buildSpreadSingleRow(List<int> others, Widget Function(int) item) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availWidth = constraints.maxWidth - 16 - 16;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: availWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var j = 0; j < others.length; j++)
                  // Chồng nhẹ 8px lên lá trước (padding âm), như xòe bài thật.
                  Padding(
                    padding: EdgeInsets.only(left: j == 0 ? 0 : -8),
                    child: item(others[j]),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Vùng trải nhiều hàng: chia thành từng hàng tối đa 5 lá, mỗi hàng
  /// là một Row căn giữa, các lá cùng đường chân; các hàng cách đều
  /// 12px; chừa khoảng trống phía dưới cho sân khấu lá lớn.
  Widget _buildSpreadMultiRow(
      List<int> others, Widget Function(int) item, double bottomReserve) {
    const maxPerRow = 5;
    final rows = <List<int>>[];
    for (var start = 0; start < others.length; start += maxPerRow) {
      final end = (start + maxPerRow).clamp(0, others.length);
      rows.add([
        for (var i = start; i < end; i++) others[i],
      ]);
    }
    return SingleChildScrollView(
      padding:
          EdgeInsets.only(left: 16, right: 16, top: 8, bottom: bottomReserve),
      child: Column(
        children: [
          for (var r = 0; r < rows.length; r++)
            Padding(
              padding: EdgeInsets.only(bottom: r == rows.length - 1 ? 0 : 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var j = 0; j < rows[r].length; j++)
                    Padding(
                      padding: EdgeInsets.only(left: j == 0 ? 0 : 12),
                      child: item(rows[r][j]),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpreadCard(TarotCardModel card, int index, bool isSelected,
      dynamic theme, double width) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCardIndex = index;
          _showSelectionPanel = false;
        });
      },
      child: Draggable<int>(
        data: index,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: width,
            height: width * 8 / 5,
            child: _cardFrame(card, theme, width),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.25,
          child: SizedBox(
            width: width,
            height: width * 8 / 5,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        child: SizedBox(
          width: width,
          height: width * 8 / 5,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isSelected ? theme.primaryColor : Colors.transparent,
                  width: 2),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: theme.primaryColor.withOpacity(0.5),
                          blurRadius: 12,
                          spreadRadius: 1)
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: TarotCardImage(card: card, fit: BoxFit.cover),
            ),
          ),
        ),
      ),
    );
  }

  /// Panel giải nghĩa gọn trên PC: tên lá + nội dung. Thu lá bằng
  /// cách chạm vào lá lớn trên sân khấu (xem _collectCardAnimated).
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
              child: SingleChildScrollView(
                child: SelectionArea(
                  child: Text(
                    activeCard.meaning,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, height: 1.6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog đổi bàn / khăn / decor ngay trong lúc trải bài (PC + phone).
  void _showTableSettingsDialog(
      BuildContext context, SettingsProvider settings, dynamic theme) {
    final prefs = settings.userPrefs;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: theme.backgroundColor,
          title: Text('Đổi bàn trải bài',
              style: TextStyle(color: theme.textColor, fontSize: 16)),
          content: SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PC: nền là bàn gỗ trống, khăn là một lớp riêng
                  // TO và phẳng trên mặt gỗ — đổi màu khăn ở đây sẽ
                  // đổi ngay trên bàn (cross-fade); phụ kiện là các
                  // sprite ảnh thật đặt riêng trên mép xa của bàn,
                  // đổi ở đây cũng hiện ngay trên bàn.
                  if (Responsive.isDesktop(context))
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Bản PC dùng bàn gỗ trống: khăn là lớp riêng to và phẳng trên mặt gỗ — đổi màu khăn ở đây sẽ đổi ngay trên bàn. Phụ kiện là ảnh thật đặt riêng trên mép bàn, đổi ở đây sẽ hiện ngay.',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 12, height: 1.5),
                      ),
                    ),
                  Text('Mặt bàn', style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    dropdownColor: theme.cardBackgroundColor,
                    isExpanded: true,
                    value: prefs.tableStyle,
                    items: ['Gỗ Sồi', 'Đá Cổ', 'Vũ Trụ'].map((s) {
                      return DropdownMenuItem<String>(
                          value: s,
                          child: Text(s, style: TextStyle(color: theme.textColor)));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) settings.setTableStyle(v);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text('Khăn trải bàn', style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    dropdownColor: theme.cardBackgroundColor,
                    isExpanded: true,
                    value: prefs.clothStyle,
                    items: ['Nhung Tím', 'Lụa Vàng', 'Thảm Đen'].map((s) {
                      return DropdownMenuItem<String>(
                          value: s,
                          child: Text(s, style: TextStyle(color: theme.textColor)));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) settings.setClothStyle(v);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text('Đồ trang trí (tối đa 3 món)', style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: ['Đá Thạch Anh', 'Quả Cầu', 'Hương Trầm', 'Nến Đen', 'Lá Khô'].map((item) {
                      final selected = prefs.decorItems.contains(item);
                      return FilterChip(
                        selectedColor: theme.primaryColor.withOpacity(0.3),
                        checkmarkColor: theme.primaryColor,
                        label: Text(item,
                            style: TextStyle(
                                color: selected ? theme.primaryColor : theme.textColor,
                                fontSize: 12)),
                        selected: selected,
                        onSelected: (v) {
                          final current = List<String>.from(prefs.decorItems);
                          if (v) {
                            if (current.length < 3) current.add(item);
                          } else {
                            current.remove(item);
                          }
                          settings.setDecorItems(current);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Hiện mặt bàn', style: TextStyle(color: theme.textColor, fontSize: 13)),
                    value: prefs.showTable,
                    activeColor: theme.primaryColor,
                    onChanged: (v) => settings.toggleTable(v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Hiện khăn trải bàn', style: TextStyle(color: theme.textColor, fontSize: 13)),
                    value: prefs.showCloth,
                    activeColor: theme.primaryColor,
                    onChanged: (v) => settings.toggleCloth(v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Hiện đồ decor', style: TextStyle(color: theme.textColor, fontSize: 13)),
                    value: prefs.showDecor,
                    activeColor: theme.primaryColor,
                    onChanged: (v) => settings.toggleDecor(v),
                  ),
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

    return DragTarget<Object>(
      onAccept: (data) {
        // Kéo một lá từ khay lên đây: lá quay lại bàn để đọc.
        if (data is int) _selectFromTray(data);
      },
      builder: (context, candidateData, rejectedData) {
        if (activeCard == null) return _buildEmptyTable(theme);
        return _buildActiveCardLayout(activeCard, theme);
      },
    );
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

  /// Lá bài đang chọn: vào bằng animation bay lên, chạm hoặc vuốt
  /// xuống để thu hồi, kéo thả được về khay.
  Widget _buildActiveCard(TarotCardModel activeCard, dynamic theme, double cardWidth) {
    final cardHeight = cardWidth * 8 / 5;
    return TweenAnimationBuilder<double>(
      key: ValueKey(activeCard.id),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, animValue, child) {
        return Transform.translate(
          offset: Offset(0, 120 * (1.0 - animValue)),
          child: Transform.scale(
            scale: 0.6 + (0.4 * animValue),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          // Vuốt xuống dưới (delta y dương) để thu hồi lá bài về khay
          // lịch sử — lá rời khỏi bàn, chỉ còn trong khay.
          if (details.delta.dy > 8) _collectCard();
        },
        onTap: () {
          // Chạm vào để thu hồi lá bài về khay lịch sử.
          _collectCard();
        },
        child: Draggable<int>(
          data: _selectedCardIndex,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: _cardFrame(activeCard, theme, cardWidth),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.1,
            child: SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          child: SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: _cardFrame(activeCard, theme, cardWidth),
          ),
        ),
      ),
    );
  }

  /// Khung lá bài: viền vàng + glow, tỉ lệ 5:8.
  Widget _cardFrame(TarotCardModel card, dynamic theme, double cardWidth) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primaryColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.6),
            blurRadius: 16,
            spreadRadius: 2,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: TarotCardImage(card: card, fit: BoxFit.cover),
      ),
    );
  }

  /// Panel giải nghĩa: tên lá bài + nội dung cuộn được. Thu lá bằng
  /// cách chạm / vuốt xuống trên lá đang đọc (xem _collectCard).
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
        padding: const EdgeInsets.all(16.0),
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
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 24),
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

  /// Lưới bài: phone 4 cột, tablet 5 cột, desktop 8 cột (gọn ở 4K),
  /// tỉ lệ 5:8.
  Widget _buildCardGrid(List<TarotCardModel> cards, ReadingProvider readingProvider, dynamic theme) {
    final crossAxisCount = Responsive.isDesktop(context)
        ? 8
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
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isAlreadyDrawn ? Colors.white24 : theme.glassBorderColor,
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: TarotCardImage(card: card, fit: BoxFit.cover),
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
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.primaryColor, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: TarotCardImage(card: card, fit: BoxFit.cover),
                ),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.35, child: cardItemWidget),
            child: GestureDetector(
              onTap: () {
                readingProvider.addCardToReading(card);
                setState(() {
                  _lastDrawnId = card.id;
                  _selectedCardIndex = readingProvider.drawnCards.length - 1;
                  _showSelectionPanel = false; // Đóng khay để lá bài bay lên bàn bói hiển thị giải nghĩa
                });
              },
              child: cardItemWidget,
            ),
          );
        },
      ),
    );
  }

  /// Khay bài đã rút ở dưới cùng — section riêng, cao 124dp phone,
  /// 104dp tablet, 176dp PC 4K. Lá trong khay TO gần bằng lá trên
  /// bàn: PC 100 rộng (lá sân khấu 175) thay vì 52 như trước, tỉ
  /// lệ 5:8, xem rõ mặt lá. Hỗ trợ kéo thả nhận từ khay chọn và
  /// thu hồi lá đang chọn về đây. Lá ĐÃ THU chỉ còn ở khay này
  /// (không còn trên bàn); chạm vào một lá trong khay để đưa nó
  /// trở lại bàn.
  Widget _buildBottomTray(List<TarotCardModel> drawnCards, ReadingProvider readingProvider, dynamic theme) {
    final trayHeight = _isDesktop ? 176.0 : (_isPhone ? 124.0 : 104.0);
    final trayThumbWidth = _isDesktop ? 100.0 : 64.0;
    if (drawnCards.isEmpty) {
      return Container(
        height: _isDesktop ? 36 : 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
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
        border: Border(top: BorderSide(color: theme.glassBorderColor, width: 0.5)),
      ),
      child: DragTarget<Object>(
        onWillAccept: (data) => true,
        onAccept: (data) {
          // 1. Nếu kéo thả 1 lá bài mới từ khay chọn bài xuống
          if (data is TarotCardModel) {
            final isAlreadyDrawn = readingProvider.drawnCards.any((dc) => dc.id == data.id);
            if (isAlreadyDrawn) return;
            readingProvider.addCardToReading(data);
            setState(() {
              _lastDrawnId = data.id;
              _selectedCardIndex = readingProvider.drawnCards.length - 1;
            });
          }
          // 2. Nếu kéo thả lá bài đang bộc lộ ở trên về lại khay dưới:
          // lá rời khỏi bàn hoàn toàn, chỉ còn trong khay.
          else if (data is int) {
            _collectIndex(data);
          }
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
                  // NẾU LÁ BÀI NÀY ĐANG ĐƯỢC CHỌN (BAY LÊN TRÊN): Ẩn khỏi khay lịch sử
                  if (index == _selectedCardIndex) {
                    return const SizedBox.shrink();
                  }

                  final card = drawnCards[index];
                  final isSelected = _selectedCardIndex == index;

                  return LongPressDraggable<int>(
                    data: index,
                    delay: const Duration(milliseconds: 80), // Nhạy bén hơn rất nhiều (mặc định 500ms quá lâu)
                    dragAnchorStrategy: pointerDragAnchorStrategy,
                    feedback: Material(
                      color: Colors.transparent,
                      child: Opacity(
                        opacity: 0.85,
                        child: Container(
                          width: trayThumbWidth,
                          height: trayThumbWidth * 8 / 5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.primaryColor, width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: TarotCardImage(card: card, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.2,
                      child: _buildBottomTrayItem(card, isSelected, theme, trayThumbWidth),
                    ),
                    child: GestureDetector(
                      onTap: () {
                        // Chạm vào lá trong khay: đưa lá trở lại bàn
                        // để đọc (lá đã thu cũng quay lại bàn).
                        _selectFromTray(index);
                      },
                      child: _buildBottomTrayItem(card, isSelected, theme, trayThumbWidth),
                    ),
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
  /// bàn), phone/tablet 64 rộng, tỉ lệ 5:8.
  Widget _buildBottomTrayItem(
      TarotCardModel card, bool isSelected, dynamic theme, double width) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
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
          child: TarotCardImage(card: card, fit: BoxFit.cover),
        ),
      ),
    );
  }

  /// Nền bàn — PC: bức tranh vẽ 3D góc nhìn thứ nhất
  /// (`table_wood_only.png`, BoxFit.cover, chiếm toàn bộ viewport):
  /// bàn gỗ chạm khắc TRỐNG, không khăn, không phụ kiện trong tranh.
  /// KHĂN là một LỚP RIÊNG trên mặt gỗ: tấm nhung phẳng TO (85%
  /// chiều rộng, 70% chiều cao bàn), màu theo Khăn trải bàn đã chọn
  /// (Nhung Tím / Lụa Vàng / Thảm Đen), đổi trong dialog hoặc Cài
  /// đặt thì cross-fade ngay (AnimatedSwitcher, không nhảy). Các lá
  /// bài trải nằm TRÊN lớp khăn to này. Phụ kiện là các sprite ảnh
  /// thật riêng biệt trên mép xa của bàn (xem _buildDesktopDecorSprites
  /// trong _buildDesktopTable), đổi được và cập nhật ngay. KHÔNG còn
  /// lớp khăn màu phẳng cũ, KHÔNG còn lớp phủ tối toàn màn — chỉ một
  /// vệt tối nhẹ sát mép dưới (sau khay bài). Tắt "Hiện mặt bàn" thì
  /// tranh tắt, nền đen. Tắt "Hiện khăn" thì lớp khăn ẩn, chỉ còn
  /// gỗ trống. Phone/tablet giữ như cũ: ảnh bàn -> khăn màu phẳng
  /// -> scrim tối -> nội dung -> hàng icon decor trên cùng.
  Widget _buildTableBackground(UserPreferencesModel prefs, Widget child) {
    // PC: nền là bàn gỗ trống — khăn là lớp riêng phía trên, màu
    // theo clothStyle; các kiểu bàn/khăn cũ chỉ áp dụng phone/tablet.
    final isDesktop = Responsive.isDesktop(context);
    String tableImage;
    if (isDesktop) {
      tableImage = 'assets/images/table_wood_only.png';
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

    // PC: không build icon decor ở đây — phụ kiện là sprite ảnh thật
    // trên mép xa của bàn (xem _buildDesktopDecorSprites trong
    // _buildDesktopTable). Phone/tablet giữ hàng icon như cũ.
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

          // LỚP KHĂN RIÊNG (chỉ PC): tấm nhung phẳng TO nằm trên mặt
          // gỗ trống — 85% chiều rộng, 70% chiều cao bàn, căn giữa.
          // Khăn là HÌNH THANG phối cảnh (mép xa hẹp hơn mép gần,
          // xem _buildDesktopCloth) với bóng tiếp xúc sát dưới mép,
          // để đọc là nhung phẳng đặt TRÊN gỗ chứ không phải hình
          // chữ nhật lơ lửng. Màu theo clothStyle đã chọn; đổi khăn
          // thì cross-fade + scale nhẹ (AnimatedSwitcher), không
          // nhảy. Tắt "Hiện khăn" thì lớp này ẩn.
          if (prefs.showCloth && isDesktop)
            Align(
              alignment: Alignment.center,
              child: FractionallySizedBox(
                widthFactor: 0.85,
                heightFactor: 0.70,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.985, end: 1.0)
                            .animate(CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOut)),
                        child: child,
                      ),
                    );
                  },
                  child: _buildDesktopCloth(prefs.clothStyle),
                ),
              ),
            ),

          // Lớp phủ tối: chữ trắng đọc được trên mọi ảnh nền.
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
          // phụ kiện là sprite ảnh thật trên mép xa của bàn (xem
          // _buildDesktopDecorSprites trong _buildDesktopTable).
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

  /// Tấm khăn riêng trên bàn PC: khăn VẼ (painted) BÁM SÁT mặt gỗ,
  /// KHÔNG còn là hình chữ nhật lơ lửng. Khăn là một HÌNH THANG
  /// phối cảnh (ClipPath: mép xa/trên hẹp hơn mép gần/dưới, khớp
  /// phối cảnh của tranh bàn gỗ), với bóng tiếp xúc nằm SÁT dưới
  /// mép khăn (hình thang đen mờ lệch xuống 7px) và viền vẽ theo
  /// đúng hình thang — khăn vẽ cùng cách vẽ với tranh bàn gỗ và
  /// phụ kiện vẽ, đặt lên bàn như một bức ảnh hoàn chỉnh. Key theo
  /// kiểu khăn để AnimatedSwitcher ở trên nhận ra khi đổi khăn và
  /// chạy cross-fade.
  Widget _buildDesktopCloth(String clothStyle) {
    final borderColor = _clothBorderColor(clothStyle);
    return Container(
      key: ValueKey('cloth-$clothStyle'),
      child: Padding(
        // Chừa 8px quanh khăn để bóng tiếp xúc (lệch xuống 7px)
        // không bị cắt ở mép.
        padding: const EdgeInsets.all(8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Bóng tiếp xúc: hình thang đen mờ, lệch xuống 7px, nằm
            // sát dưới mép khăn — phần lộ ra quanh mép là bóng của
            // khăn trên mặt gỗ.
            Transform.translate(
              offset: const Offset(0, 7),
              child: ClipPath(
                clipper: _TablePlaneClipper(),
                child: Container(color: Colors.black.withOpacity(0.55)),
              ),
            ),
            // Khăn vẽ (painted) hình thang phối cảnh — cùng cách vẽ
            // với tranh bàn gỗ, phủ kín hình thang (BoxFit.cover).
            ClipPath(
              clipper: _TablePlaneClipper(),
              child: SizedBox.expand(
                child: Image.asset(
                  _clothImageAsset(clothStyle),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Viền theo đúng hình thang (Border.all sẽ bị ClipPath
            // cắt mất ở hai cạnh xiên, nên vẽ viền bằng CustomPaint).
            Positioned.fill(
              child: CustomPaint(
                painter: _TablePlaneBorderPainter(borderColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ảnh khăn vẽ (painted) theo kiểu đã chọn — cùng cách vẽ với
  /// tranh bàn gỗ, để khăn đặt lên bàn như một bức ảnh hoàn chỉnh.
  String _clothImageAsset(String clothStyle) {
    switch (clothStyle) {
      case 'Lụa Vàng':
        return 'assets/images/cloth_gold_painted.png';
      case 'Thảm Đen':
        return 'assets/images/cloth_black_painted.png';
      case 'Nhung Tím':
      default:
        return 'assets/images/cloth_purple_painted.png';
    }
  }

  /// Màu viền khăn theo kiểu đã chọn. Nhung Tím = tím, Lụa Vàng =
  /// vàng gold, Thảm Đen = xám.
  Color _clothBorderColor(String clothStyle) {
    switch (clothStyle) {
      case 'Lụa Vàng':
        return const Color(0xFFD4AF37);
      case 'Thảm Đen':
        return const Color(0xFF5A5A5A);
      case 'Nhung Tím':
      default:
        return const Color(0xFF9D4EDD);
    }
  }

  /// Các biểu tượng trang trí: chỉ trả về widget, vị trí do hàng
  /// ở trên cùng của _buildTableBackground quyết định.
  /// Món nào có ảnh vẽ (thạch anh, quả cầu, trầm, nến) dùng
  /// sprite ảnh vẽ (_buildDecorSprite); món không có ảnh
  /// (Lá Khô) giữ icon cũ làm fallback. Bản PC dùng sprite ảnh
  /// trên mép xa của bàn (xem _buildDesktopDecorSprites).
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

/// Đường hình thang phối cảnh của mặt bàn nhìn từ góc nhìn thứ nhất:
/// mép xa (trên) hẹp hơn mép gần (dưới) — vật đặt trên mặt bàn dùng
/// chung hình này để "nằm trên" gỗ thay vì lơ lửng. Khăn và bóng
/// tiếp xúc của nó cùng dùng một đường này.
Path _tablePlanePath(Size size) {
  final insetTop = size.width * 0.09;
  final insetBottom = size.width * 0.02;
  return Path()
    ..moveTo(insetTop, 0)
    ..lineTo(size.width - insetTop, 0)
    ..lineTo(size.width - insetBottom, size.height)
    ..lineTo(insetBottom, size.height)
    ..close();
}

/// Cắt một widget thành hình thang phối cảnh của mặt bàn.
class _TablePlaneClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => _tablePlanePath(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Vẽ viền theo đúng hình thang phối cảnh của mặt bàn.
class _TablePlaneBorderPainter extends CustomPainter {
  final Color color;
  _TablePlaneBorderPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(_tablePlanePath(size), paint);
  }

  @override
  bool shouldRepaint(covariant _TablePlaneBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Widget mô phỏng Xấp bài Tarot úp rực rỡ (tỉ lệ 5:8, theo breakpoint).
class CardStackWidget extends StatelessWidget {
  final VoidCallback onTap;
  final dynamic theme;

  const CardStackWidget({Key? key, required this.onTap, required this.theme}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final stackWidth = Responsive.isDesktop(context)
        ? 60.0
        : Responsive.isTablet(context)
            ? 88.0
            : 72.0;
    final backWidth = stackWidth * 0.86;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
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
          const SizedBox(height: 6),
          Text(
            'XẤP BÀI',
            style: TextStyle(
              color: theme.primaryColor,
              fontSize: Responsive.isDesktop(context) ? 10 : 12,
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
