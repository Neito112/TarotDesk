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

  double _meaningFontSize() => _isDesktop ? 14.0 : 15.0;
  double _cardNameFontSize() => _isDesktop ? 17.0 : (_isPhone ? 20.0 : 19.0);

  /// Thu lá đang đọc xuống khay: lá vẫn nằm trong drawnCards (khay),
  /// chỉ bỏ chọn để nó hiện lại trong khay dưới cùng.
  void _collectCard() {
    setState(() => _selectedCardIndex = -1);
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

    return Row(
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
    );
  }

  String drawnCardsCountText() {
    final n = context.read<ReadingProvider>().drawnCards.length;
    return n == 0 ? 'Chưa rút lá nào' : 'Đã rút $n lá';
  }

  /// Bàn trải bài góc nhìn thứ nhất trên PC: xấp bài ở góc trên-trái,
  /// các lá đã rút nằm TRÊN bàn theo kiểu trải, panel giải nghĩa gọn
  /// ở bên phải. Decor do _buildTableBackground đặt ở các góc bàn.
  Widget _buildDesktopTable(List<TarotCardModel> drawnCards,
      ReadingProvider readingProvider, dynamic theme) {
    final activeCard = drawnCards.isNotEmpty &&
            _selectedCardIndex >= 0 &&
            _selectedCardIndex < drawnCards.length
        ? drawnCards[_selectedCardIndex]
        : null;

    return DragTarget<Object>(
      onAccept: (data) {
        if (data is int) {
          setState(() {
            _selectedCardIndex = data;
            _showSelectionPanel = false;
          });
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Stack(
          children: [
            // Các lá đã rút nằm trên bàn (hoặc bàn trống).
            Positioned.fill(
              child: drawnCards.isEmpty
                  ? _buildDesktopEmptyHint(theme)
                  : _buildSpread(drawnCards, theme),
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
            // Panel giải nghĩa gọn bên phải, chỉ khi đang đọc một lá.
            if (activeCard != null)
              Positioned(
                top: 4,
                right: 4,
                bottom: 4,
                width: 320,
                child: _buildDesktopMeaningPanel(activeCard, theme),
              ),
          ],
        );
      },
    );
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

  /// Các lá đã rút nằm trên bàn. 1 hàng: một hàng ngang cuộn được.
  /// Nhiều hàng: Wrap nhiều hàng, cuộn dọc. Lá vừa rút bay từ xấp
  /// bài (góc trên-trái) ra vị trí của nó trên bàn.
  Widget _buildSpread(List<TarotCardModel> drawnCards, dynamic theme) {
    final settings = context.read<SettingsProvider>();
    final isSingle = settings.userPrefs.spreadMode == 'single';
    // Chừa chỗ cho xấp bài góc trên-trái và panel giải nghĩa bên phải.
    const double spreadCardWidth = 104;
    final hasActive = _selectedCardIndex >= 0 &&
        _selectedCardIndex < drawnCards.length;

    Widget item(int index) {
      final card = drawnCards[index];
      final isSelected = index == _selectedCardIndex;
      final isNew = card.id == _lastDrawnId;
      Widget tile = _buildSpreadCard(card, index, isSelected, theme, spreadCardWidth);
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

    final content = isSingle
        ? ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 92, right: 336, top: 8, bottom: 8),
            itemCount: drawnCards.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: item(i),
            ),
          )
        : SingleChildScrollView(
            padding: EdgeInsets.only(
                left: 92, right: hasActive ? 336 : 16, top: 8, bottom: 8),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < drawnCards.length; i++) item(i),
              ],
            ),
          );
    return content;
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

  /// Panel giải nghĩa gọn trên PC: tên lá + nút "Thu xuống khay" + nội dung.
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
            SizedBox(
              height: 36,
              child: OutlinedButton.icon(
                onPressed: _collectCard,
                icon: const Icon(Icons.archive, size: 16),
                label: const Text('Thu xuống khay',
                    style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.primaryColor,
                  side: BorderSide(color: theme.primaryColor),
                ),
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
                    children: ['Đá Thạch Anh', 'Quả Cầu', 'Hương Trầm', 'Lá Khô'].map((item) {
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
        if (data is int) {
          setState(() {
            _selectedCardIndex = data;
            _showSelectionPanel = false;
          });
        }
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
          // Vuốt xuống dưới (delta y dương) để thu hồi lá bài về khay lịch sử
          if (details.delta.dy > 8) {
            setState(() {
              _selectedCardIndex = -1;
            });
          }
        },
        onTap: () {
          // Chạm vào để tắt/thu hồi lá bài về khay lịch sử
          setState(() {
            _selectedCardIndex = -1;
          });
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

  /// Panel giải nghĩa: tên lá bài + nút "Thu xuống khay" + nội dung cuộn
  /// được. PC: chữ 14pt, tên 17pt. Phone giữ 15pt / 20pt như cũ.
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
            // Thu lá đã đọc xuống khay: lá vẫn ở trong khay dưới cùng.
            SizedBox(
              height: _isPhone ? 48 : 36,
              child: OutlinedButton.icon(
                onPressed: _collectCard,
                icon: const Icon(Icons.archive, size: 16),
                label: Text('Thu xuống khay',
                    style: TextStyle(fontSize: _isDesktop ? 13 : 14)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.primaryColor,
                  side: BorderSide(color: theme.primaryColor),
                ),
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
  /// 104dp tablet, 84dp PC 4K. Hỗ trợ kéo thả nhận từ khay chọn và
  /// thu hồi lá đang chọn về đây.
  Widget _buildBottomTray(List<TarotCardModel> drawnCards, ReadingProvider readingProvider, dynamic theme) {
    final trayHeight = _isDesktop ? 84.0 : (_isPhone ? 124.0 : 104.0);
    final trayThumbWidth = _isDesktop ? 52.0 : 64.0;
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
          // 2. Nếu kéo thả lá bài đang bộc lộ ở trên về lại khay dưới để đóng
          else if (data is int) {
            setState(() {
              _selectedCardIndex = -1;
            });
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
                        setState(() {
                          _selectedCardIndex = index;
                          _showSelectionPanel = false;
                        });
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

  /// Thumbnail lá bài trong khay: 64 rộng, tỉ lệ 5:8.
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

  /// Nền bàn: ảnh bàn -> khăn -> lớp phủ tối (scrim) giúp chữ đọc được
  /// -> nội dung. PC 4K: scrim nhẹ hơn để thấy vân bàn (góc nhìn thứ
  /// nhất), khăn margin 8, decor đặt ở góc trên-phải bàn, lớn và phát
  /// sáng, không chặn chạm (IgnorePointer). Phone/tablet giữ như cũ.
  Widget _buildTableBackground(UserPreferencesModel prefs, Widget child) {
    String tableImage;
    if (prefs.tableStyle == 'Đá Cổ') {
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

    final isDesktop = Responsive.isDesktop(context);
    final decorSize = isDesktop ? 40.0 : 28.0;
    final decorWidgets =
        _buildDynamicDecorWidgets(prefs.decorItems, decorSize);

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
          if (prefs.showCloth)
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

          // Lớp phủ tối: chữ trắng đọc được trên mọi ảnh nền.
          // PC: nhẹ hơn để vân bàn / khăn vẫn thấy rõ.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDesktop
                    ? const [
                        Color(0x66000000),
                        Color(0x26000000),
                        Color(0x80000000),
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

          // LỚP 4: Đồ trang trí — PC: cụm ở góc trên-phải bàn (xấp bài
          // đã chiếm góc trên-trái), icon lớn 40 + glow. Phone/tablet:
          // hàng nhỏ ở trên cùng như cũ. Luôn IgnorePointer.
          if (prefs.showDecor)
            if (isDesktop)
              Positioned(
                top: 10,
                right: 16,
                child: IgnorePointer(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < decorWidgets.length; i++) ...[
                        if (i > 0) const SizedBox(width: 18),
                        decorWidgets[i],
                      ],
                    ],
                  ),
                ),
              )
            else
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

  /// Các biểu tượng trang trí: chỉ trả về widget, vị trí do hàng
  /// ở trên cùng / góc bàn của _buildTableBackground quyết định.
  /// Lưu ý: hiện chỉ có icon vẽ sẵn (không có ảnh đồ họa chân thật
  /// cho phụ kiện trong assets/images/), nên decor được vẽ lớn hơn
  /// và phát sáng để hiện diện trên bàn.
  List<Widget> _buildDynamicDecorWidgets(List<String> items, [double size = 28]) {
    final widgets = <Widget>[];
    for (final item in items) {
      Widget decorWidget;

      if (item == 'Đá Thạch Anh') {
        decorWidget = Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.pinkAccent.withOpacity(0.6), blurRadius: 20, spreadRadius: 4),
            ],
          ),
          child: Icon(Icons.diamond, color: Colors.pinkAccent, size: size),
        );
      } else if (item == 'Quả Cầu') {
        decorWidget = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Colors.white, Color(0xFF00E5FF), Color(0xFF006064)],
            ),
            boxShadow: [
              BoxShadow(color: Colors.cyanAccent.withOpacity(0.6), blurRadius: 20, spreadRadius: 4),
            ],
          ),
        );
      } else if (item == 'Hương Trầm') {
        decorWidget = Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.amberAccent.withOpacity(0.4), blurRadius: 16, spreadRadius: 2),
                ],
              ),
              child: Icon(Icons.spa, color: Colors.amberAccent, size: size * 0.9),
            ),
            // Khói trầm bay lên hướng lên trên
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
        );
      } else {
        // Lá Khô
        decorWidget = Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.orangeAccent.withOpacity(0.5), blurRadius: 16, spreadRadius: 2),
            ],
          ),
          child: Icon(Icons.eco, color: Colors.orangeAccent, size: size * 0.9),
        );
      }

      widgets.add(decorWidget);
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
