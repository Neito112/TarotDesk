import 'dart:math';
import 'dart:ui'; // Cần thiết cho PointerDeviceKind và kéo thả bằng chuột
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/tarot_card.dart';
import '../../data/models/user_preferences.dart';
import '../../logic/deck_provider.dart';
import '../../logic/reading_provider.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';
import '../widgets/smoke_particle_effect.dart';
import '../widgets/tarot_card_image.dart';

/// Màn hình Nhật ký trải bài mới (Bàn bói bài, Khăn trải, Đá decor, Tương tác kéo thả nhạy bén, Bay động)
class NewReadingScreen extends StatefulWidget {
  const NewReadingScreen({Key? key}) : super(key: key);

  @override
  State<NewReadingScreen> createState() => _NewReadingScreenState();
}

class _NewReadingScreenState extends State<NewReadingScreen> {
  int _selectedCardIndex = -1; // Mặc định là -1 (Không hiển thị khung giải nghĩa khi bắt đầu để nhìn rõ bàn bói)
  bool _showSelectionPanel = false; // Trạng thái mở khay chọn bài từ xấp bài

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
      extendBodyBehindAppBar: true, // Cho phép hình nền trải rộng lên hết toàn màn hình
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _showEditTitleDialog(context, readingProvider),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  readingProvider.currentReadingTitle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.edit, size: 16, color: theme.primaryColor),
            ],
          ),
        ),
        backgroundColor: Colors.transparent, // Trong suốt để lộ thảm trải bàn
        foregroundColor: theme.primaryColor,
        elevation: 0,
        actions: [
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12.0, 56.0, 12.0, 12.0), // Chừa không gian cho AppBar trong suốt
              child: Column(
                children: [
                  // Vùng chính ở trên
                  Expanded(
                    child: _showSelectionPanel
                        ? _buildSelectionPanel(deckCards, readingProvider, theme)
                        : _buildMainInteractiveLayout(drawnCards, readingProvider, theme),
                  ),

                  const SizedBox(height: 10),

                  // Khay lịch sử bài đã rút ở dưới cùng (Hỗ trợ kéo thả thả nhận từ khay chọn)
                  _buildBottomTray(drawnCards, readingProvider, theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Giao diện chính chứa khung giải nghĩa chèn dưới xấp bài & lá bài đang chọn
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
        return Stack(
          children: [
            // Khung nội dung giải nghĩa kéo sát lên trên cùng (MẶC ĐỊNH ẨN NẾU CHƯA CHỌN LÁ NÀO để nhìn rõ bàn bói)
            if (activeCard != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 30,
                child: GlassPanel(
                  backgroundColor: Colors.black.withOpacity(0.35), // Độ mờ thấp hơn giúp hiển thị khăn trải bàn rõ ràng
                  borderColor: theme.glassBorderColor,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Tên lá bài có màu nổi bật hơn hẳn
                        Text(
                          activeCard.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(color: theme.primaryColor.withOpacity(0.5), blurRadius: 10)
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Cuộn văn bản giải nghĩa (được đệm khoảng trống ở dưới để không bị các lá bài che khuất)
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: 140.0),
                            child: SelectionArea(
                              child: Text(
                                activeCard.meaning,
                                style: TextStyle(color: theme.textColor, fontSize: 13, height: 1.5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              // Khi chưa chọn lá bài nào, hiện lời khuyên nhỏ hướng dẫn cách tương tác trên mặt thảm
              Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'Chạm vào xấp bài bên trái để bắt đầu chọn.\nKéo các lá bài từ khay lịch sử lên đây hoặc chạm để xem giải nghĩa.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.textColor.withOpacity(0.6),
                      fontSize: 13,
                      height: 1.6,
                      shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                  ),
                ),
              ),

            // Xấp bài cố định bên trên khay lịch sử, sát bên trái. Nhận kéo thả để loại bỏ bài
            Positioned(
              bottom: 0,
              left: 10,
              child: DragTarget<int>(
                onAccept: (cardIndex) {
                  readingProvider.removeCardFromReading(cardIndex);
                  setState(() {
                    _selectedCardIndex = -1;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã gỡ lá bài khỏi trải bài.'), duration: Duration(milliseconds: 600)),
                  );
                },
                builder: (context, candidateData, rejectedData) {
                  final isHovered = candidateData.isNotEmpty;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isHovered ? Colors.redAccent : Colors.transparent,
                        width: 2,
                      ),
                      color: isHovered ? Colors.red.withOpacity(0.25) : Colors.transparent,
                    ),
                    child: CardStackWidget(
                      onTap: () {
                        setState(() {
                          _showSelectionPanel = true;
                        });
                      },
                      theme: theme,
                    ),
                  );
                },
              ),
            ),

            // Lá bài đang được chọn ở mé bên phải (bay động bay lên, và có thể vuốt/kéo xuống dưới để tắt)
            if (activeCard != null)
              Positioned(
                bottom: 0,
                right: 15,
                child: TweenAnimationBuilder<double>(
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
                        child: Container(
                          width: 70,
                          height: 110,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: theme.primaryColor, width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: TarotCardImage(card: activeCard, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.1,
                        child: Container(
                          width: 70,
                          height: 110,
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      child: Container(
                        width: 70,
                        height: 110,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
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
                          borderRadius: BorderRadius.circular(8),
                          child: TarotCardImage(card: activeCard, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Khay chọn lá bài (Đã loại bỏ nút Đóng Khay ở dưới, chỉ giữ dấu X)
  Widget _buildSelectionPanel(List<TarotCardModel> deckCards, ReadingProvider readingProvider, dynamic theme) {
    final majorCards = deckCards.where((c) => _getCardSuit(c) == TarotSuit.major).toList();
    final wandsCards = deckCards.where((c) => _getCardSuit(c) == TarotSuit.wands).toList();
    final cupsCards = deckCards.where((c) => _getCardSuit(c) == TarotSuit.cups).toList();
    final swordsCards = deckCards.where((c) => _getCardSuit(c) == TarotSuit.swords).toList();
    final pentaclesCards = deckCards.where((c) => _getCardSuit(c) == TarotSuit.pentacles).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Chọn các lá bài đã rút ngoài đời:',
              style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70, size: 20),
              onPressed: () {
                setState(() {
                  _showSelectionPanel = false;
                });
              },
            ),
          ],
        ),

        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (majorCards.isNotEmpty) ...[
                  _buildSubCategoryTitle('Ẩn Chính (Major Arcana)', theme),
                  _buildHorizontalCardRow(majorCards, readingProvider, theme),
                ],
                if (wandsCards.isNotEmpty) ...[
                  _buildSubCategoryTitle('Bộ Gậy (Wands)', theme),
                  _buildHorizontalCardRow(wandsCards, readingProvider, theme),
                ],
                if (cupsCards.isNotEmpty) ...[
                  _buildSubCategoryTitle('Bộ Cốc (Cups)', theme),
                  _buildHorizontalCardRow(cupsCards, readingProvider, theme),
                ],
                if (swordsCards.isNotEmpty) ...[
                  _buildSubCategoryTitle('Bộ Kiếm (Swords)', theme),
                  _buildHorizontalCardRow(swordsCards, readingProvider, theme),
                ],
                if (pentaclesCards.isNotEmpty) ...[
                  _buildSubCategoryTitle('Bộ Xu (Pentacles)', theme),
                  _buildHorizontalCardRow(pentaclesCards, readingProvider, theme),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubCategoryTitle(String label, dynamic theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
      child: Text(
        label,
        style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
      ),
    );
  }

  /// Khay chọn bài: Hỗ trợ Kéo thả lá bài trực tiếp từ đây xuống khay lịch sử dưới cùng để bốc bài
  Widget _buildHorizontalCardRow(List<TarotCardModel> cards, ReadingProvider readingProvider, dynamic theme) {
    return SizedBox(
      height: 95,
      child: ScrollConfiguration(
        behavior: MouseDragScrollBehavior(),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final card = cards[index];
            final isAlreadyDrawn = readingProvider.drawnCards.any((dc) => dc.id == card.id);

            final cardItemWidget = Opacity(
              opacity: isAlreadyDrawn ? 0.35 : 1.0,
              child: Container(
                width: 55,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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

            // Cho phép kéo thả trực tiếp lá bài xuống khay lịch sử
            return Draggable<TarotCardModel>(
              data: card,
              feedback: Material(
                color: Colors.transparent,
                child: Container(
                  width: 55,
                  height: 85,
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
                    _selectedCardIndex = readingProvider.drawnCards.length - 1;
                  });
                },
                child: cardItemWidget,
              ),
            );
          },
        ),
      ),
    );
  }

  /// Khay bài lịch sử bên dưới. Hỗ trợ cuộn mượt mà bằng chuột, KÉO THẢ nhạy bén (delay 80ms) và ẩn lá đang chọn
  Widget _buildBottomTray(List<TarotCardModel> drawnCards, ReadingProvider readingProvider, dynamic theme) {
    return Container(
      height: 95,
      padding: const EdgeInsets.symmetric(vertical: 2),
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
                  // NẾU LÁ BÀI NÀY ĐANG ĐƯỢC CHỌN (BAY LÊN TRÊN): Ẩn hoàn toàn khỏi khay lịch sử
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
                          width: 55,
                          height: 85,
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
                      child: _buildBottomTrayItem(card, isSelected, theme),
                    ),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCardIndex = index;
                          _showSelectionPanel = false;
                        });
                      },
                      child: _buildBottomTrayItem(card, isSelected, theme),
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

  /// Thumbnail lá bài lịch sử (Đã loại bỏ chữ tên lá bài quá nhỏ thừa thãi theo yêu cầu)
  Widget _buildBottomTrayItem(TarotCardModel card, bool isSelected, dynamic theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 55,
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
        child: TarotCardImage(card: card, fit: BoxFit.cover),
      ),
    );
  }

  /// Dựng hình nền cái bàn bói bài, khăn trải và các vật trang trí tâm linh xếp chồng chuẩn lớp
  Widget _buildTableBackground(UserPreferencesModel prefs, Widget child) {
    BoxDecoration tableDec;
    if (prefs.tableStyle == 'Gỗ Sồi') {
      tableDec = const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF422818), Color(0xFF1F1109)],
        ),
      );
    } else if (prefs.tableStyle == 'Đá Cổ') {
      tableDec = const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF373B3E), Color(0xFF161819)],
        ),
      );
    } else {
      // Vũ Trụ
      tableDec = const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F0C1B), Color(0xFF05020A)],
        ),
      );
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

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: tableDec,
      child: Stack(
        children: [
          // Tấm khăn phủ bàn bói bài kéo rộng bao trùm màn hình
          Align(
            alignment: Alignment.center,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: clothColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: prefs.clothStyle == 'Lụa Vàng'
                      ? const Color(0xFFB09520)
                      : const Color(0xFF7C539A),
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ],
              ),
            ),
          ),

          // Lớp nội dung ứng dụng
          child,

          // Lớp Đồ Trang Trí phong thủy vẽ ĐÈ LÊN TRÊN để đảm bảo luôn nhìn thấy rõ
          ..._buildDecorWidgets(prefs.decorItems),
        ],
      ),
    );
  }

  /// Sinh các biểu tượng trang trí có phát sáng lung linh trên bàn trải bài
  List<Widget> _buildDecorWidgets(List<String> items) {
    final widgets = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      IconData icon;
      Color color;
      Color glowColor;

      if (item == 'Đá Thạch Anh') {
        icon = Icons.diamond;
        color = Colors.pinkAccent;
        glowColor = Colors.pink.withOpacity(0.5);
      } else if (item == 'Quả Cầu') {
        icon = Icons.lens;
        color = Colors.cyanAccent;
        glowColor = Colors.cyan.withOpacity(0.5);
      } else if (item == 'Hương Trầm') {
        icon = Icons.spa;
        color = Colors.amberAccent;
        glowColor = Colors.amber.withOpacity(0.5);
      } else {
        // Lá Khô
        icon = Icons.eco;
        color = Colors.orangeAccent;
        glowColor = Colors.orange.withOpacity(0.5);
      }

      // Đặt các món đồ ở vị trí thoáng đãng ngay dưới AppBar
      double top = 75;
      double? left;
      double? right;

      if (i == 0) {
        left = 24;
      } else if (i == 1) {
        right = 24;
      }

      if (i == 2) {
        widgets.add(
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 75.0),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: glowColor, blurRadius: 12, spreadRadius: 2)
                  ],
                ),
                child: Icon(icon, color: color, size: 26),
              ),
            ),
          ),
        );
      } else {
        widgets.add(
          Positioned(
            top: top,
            left: left,
            right: right,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: glowColor, blurRadius: 12, spreadRadius: 2)
                ],
              ),
              child: Icon(icon, color: color, size: 26),
            ),
          ),
        );
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
          backgroundColor: theme.cardBackgroundColor,
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

/// Widget mô phỏng Xấp bài Tarot úp rực rỡ
class CardStackWidget extends StatelessWidget {
  final VoidCallback onTap;
  final dynamic theme;

  const CardStackWidget({Key? key, required this.onTap, required this.theme}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 70,
            height: 105,
            child: Stack(
              children: [
                // Lá bài thứ 3 dưới cùng
                Transform.translate(
                  offset: const Offset(-5, 3),
                  child: Transform.rotate(
                    angle: -0.06,
                    child: _buildCardBack(),
                  ),
                ),
                // Lá bài thứ 2 ở giữa
                Transform.translate(
                  offset: const Offset(3, 1),
                  child: Transform.rotate(
                    angle: 0.05,
                    child: _buildCardBack(),
                  ),
                ),
                // Lá bài trên cùng
                _buildCardBack(),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'XẤP BÀI',
            style: TextStyle(
              color: theme.primaryColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack() {
    return Container(
      width: 60,
      height: 95,
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

enum TarotSuit { all, major, wands, cups, swords, pentacles }

TarotSuit _getCardSuit(TarotCardModel card) {
  final path = card.imagePath.toLowerCase();
  if (RegExp(r'm\d+').hasMatch(path)) return TarotSuit.major;
  if (RegExp(r'w\d+').hasMatch(path)) return TarotSuit.wands;
  if (RegExp(r'c\d+').hasMatch(path)) return TarotSuit.cups;
  if (RegExp(r's\d+').hasMatch(path)) return TarotSuit.swords;
  if (RegExp(r'p\d+').hasMatch(path)) return TarotSuit.pentacles;
  return TarotSuit.all;
}
