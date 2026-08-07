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

/// Màn hình Nhật ký trải bài Tarot (Tách 3 lớp nền: Bàn - Khăn - Decor, Tương tác kéo thả nhạy, Bài bay động, Giải nghĩa đầy đủ)
class NewReadingScreen extends StatefulWidget {
  const NewReadingScreen({Key? key}) : super(key: key);

  @override
  State<NewReadingScreen> createState() => _NewReadingScreenState();
}

class _NewReadingScreenState extends State<NewReadingScreen> {
  int _selectedCardIndex = -1; // Mặc định là -1 (Không hiển thị khung giải nghĩa khi bắt đầu để nhìn rõ bàn bói)
  bool _showSelectionPanel = false; // Trạng thái mở khay chọn bài từ xấp bài
  TarotSuit _selectedSuit = TarotSuit.major; // Nhóm bài được chọn mặc định ban đầu là Ẩn Chính

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
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.45), // Nền trong suốt hiệu ứng glass
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.glassBorderColor, width: 0.5),
          ),
          child: GestureDetector(
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
                      fontSize: 14,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1))
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.edit, size: 14, color: theme.primaryColor),
              ],
            ),
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
                  // Vùng chính ở trên (Sử dụng AnimatedSwitcher để chuyển màn chọn bài cực kỳ mượt mà)
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

                  const SizedBox(height: 10),

                  // Khay lịch sử bài đã rút ở dưới cùng (Hỗ trợ kéo thả nhận từ khay chọn)
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
            // Khung nội dung giải nghĩa kéo sát lên trên cùng (Hiển thị khi chọn bài)
            if (activeCard != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 30,
                child: GlassPanel(
                  backgroundColor: Colors.black.withOpacity(0.65), // Đậm màu hơn để tạo tương phản tốt với text
                  borderColor: theme.primaryColor.withOpacity(0.5),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Tên lá bài có màu nổi bật vàng hoàng kim thắp sáng
                        Text(
                          activeCard.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(color: theme.primaryColor.withOpacity(0.6), blurRadius: 12)
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
                                style: const TextStyle(
                                  color: Colors.white, // Text trắng sáng tương phản cực cao trên nền tối
                                  fontSize: 13,
                                  height: 1.5,
                                  shadows: [
                                    Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1))
                                  ],
                                ),
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
              // Khi chưa chọn lá bài nào, hiện lời khuyên nhỏ hướng dẫn trong khung kính tối tương phản cao
              Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: GlassPanel(
                    backgroundColor: Colors.black.withOpacity(0.55),
                    borderColor: theme.primaryColor.withOpacity(0.3),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, color: theme.primaryColor, size: 28),
                          const SizedBox(height: 12),
                          const Text(
                            'Chạm vào xấp bài bên trái để bắt đầu chọn.\n\nKéo các lá bài từ khay lịch sử lên đây hoặc chạm để xem giải nghĩa.\n\nKéo lá bài đang chọn xuống hoặc vuốt xuống để thu hồi.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white, // Tương phản tốt
                              fontSize: 13,
                              height: 1.6,
                              fontWeight: FontWeight.w500,
                              shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1))],
                            ),
                          ),
                        ],
                      ),
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

  /// Khay chọn lá bài: Thiết kế dạng nhóm bài, hỗ trợ đổi nhóm bài bằng selector
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
      backgroundColor: Colors.black.withOpacity(0.7), // Tương phản rất cao
      borderColor: theme.primaryColor.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tiêu đề bảng chọn bài
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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

            // NÚT ĐỔI NHÓM BÀI: Dãy Chip đổi nhóm bài cuộn ngang mượt mà
            _buildSuitSelector(theme),

            const SizedBox(height: 8),

            // Tên nhóm bài hiện hành
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text(
                suitLabel,
                style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 11),
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

  /// Chip riêng cho từng nhóm bài
  Widget _buildSuitChip(TarotSuit suit, String label, dynamic theme) {
    final isSelected = _selectedSuit == suit;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
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
          fontSize: 11,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? theme.primaryColor : theme.glassBorderColor,
            width: 0.5,
          ),
        ),
      ),
    );
  }

  /// Lưới bài (Grid) 4 cột để nhìn bao quát toàn bộ bài của suit hiện hành.
  Widget _buildCardGrid(List<TarotCardModel> cards, ReadingProvider readingProvider, dynamic theme) {
    return ScrollConfiguration(
      behavior: MouseDragScrollBehavior(),
      child: GridView.builder(
        key: ValueKey(cards.hashCode),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.62,
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

  /// Khay bài lịch sử bên dưới. Hỗ trợ cuộn mượt mà bằng chuột, KÉO THẢ nhạy bén (delay 80ms)
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

  /// Thumbnail lá bài lịch sử
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

  /// Dựng hình nền tách biệt: Mặt bàn thực tế -> Thảm trải bàn -> Đồ Decor động tùy biến
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
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: clothColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: prefs.clothStyle == 'Lụa Vàng'
                        ? const Color(0xFFD4AF37) // Gold border
                        : const Color(0xFF9D4EDD), // Purple border
                    width: 2.0,
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

          // LỚP 3: Nội dung của ứng dụng (SafeArea, các lá bài, khay cuộn)
          child,

          // LỚP 4: Đồ Trang Trí phong thủy vẽ ĐÈ LÊN TRÊN, thay đổi động (Tùy chỉnh bật tắt)
          if (prefs.showDecor)
            ..._buildDynamicDecorWidgets(prefs.decorItems),
        ],
      ),
    );
  }

  /// Sinh các biểu tượng trang trí tách lớp có khói sương bay lên
  List<Widget> _buildDynamicDecorWidgets(List<String> items) {
    final widgets = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      Widget decorWidget;

      if (item == 'Đá Thạch Anh') {
        decorWidget = Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.pinkAccent.withOpacity(0.6), blurRadius: 20, spreadRadius: 4),
            ],
          ),
          child: const Icon(Icons.diamond, color: Colors.pinkAccent, size: 28),
        );
      } else if (item == 'Quả Cầu') {
        decorWidget = Container(
          width: 26,
          height: 26,
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
              child: const Icon(Icons.spa, color: Colors.amberAccent, size: 26),
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
          child: const Icon(Icons.eco, color: Colors.orangeAccent, size: 26),
        );
      }

      // Đặt vị trí các món đồ thoáng đãng ngay dưới AppBar
      double top = 75;
      double? left;
      double? right;

      if (i == 0) {
        left = 28;
      } else if (i == 1) {
        right = 28;
      }

      if (i == 2) {
        widgets.add(
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 75.0),
              child: decorWidget,
            ),
          ),
        );
      } else {
        widgets.add(
          Positioned(
            top: top,
            left: left,
            right: right,
            child: decorWidget,
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
