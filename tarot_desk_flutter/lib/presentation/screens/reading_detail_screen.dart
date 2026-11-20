import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../data/datasources/database_helper.dart';
import '../../data/models/tarot_card.dart';
import '../../data/models/tarot_reading.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';
import '../widgets/tarot_card_image.dart';

/// Màn hình xem chi tiết lịch sử bốc bài cũ.
/// Cùng ngôn ngữ bố cục với sân khấu trong NewReading: lá bài lớn 5:8
/// với panel giải nghĩa ngay bên cạnh trên tablet/PC, khay lịch sử ở
/// dưới cùng dùng cùng cỡ lá khay (~96 rộng) để lá bài nhìn giống nhau
/// ở mọi nơi.
/// Điện thoại (Android, chính): lá bài lớn 5:8 ở trên, panel ý nghĩa
/// ở dưới, khay lịch sử ở dưới cùng.
/// PC 4K gọn: lá bài ~190 rộng, chữ giải nghĩa 14, tên lá 18.
class ReadingDetailScreen extends StatefulWidget {
  final TarotReadingModel reading;

  const ReadingDetailScreen({Key? key, required this.reading}) : super(key: key);

  @override
  State<ReadingDetailScreen> createState() => _ReadingDetailScreenState();
}

class _ReadingDetailScreenState extends State<ReadingDetailScreen> {
  List<TarotCardModel> _cards = [];
  bool _isLoading = true;
  int _selectedCardIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    setState(() => _isLoading = true);
    final loaded = await DatabaseHelper.instance.getCardsByIds(widget.reading.cardIds);
    if (mounted) {
      setState(() {
        _cards = loaded;
        _isLoading = false;
        _selectedCardIndex = 0;
      });
    }
  }

  // Cùng cỡ sân khấu trong NewReading (lá lớn 175) nhưng gọn cho PC 4K:
  // desktop 190, tablet 200, phone 180 — đều 5:8.
  double _cardWidth(BuildContext context) {
    if (Responsive.isDesktop(context)) return 190;
    if (Responsive.isTablet(context)) return 200;
    return 180;
  }

  // Lá khay dùng cùng cỡ với khay trong NewReading: ~96 rộng ở mọi nơi.
  static const double _trayCardWidth = 96.0;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentThemeData;
    final isWide = !Responsive.isPhone(context);
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        toolbarHeight: isDesktop ? 44 : null,
        title: Text(
          widget.reading.name,
          style: TextStyle(fontSize: isDesktop ? 15 : 18),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: theme.primaryColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ResponsiveCenter(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 12),
                      child: Text(
                        'Lịch sử ngày: ${widget.reading.date.day}/${widget.reading.date.month}/${widget.reading.date.year} ${widget.reading.date.hour}:${widget.reading.date.minute}',
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: isWide ? 13 : 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _cards.isEmpty
                          ? Center(
                              child: Text(
                                'Không tìm thấy dữ liệu các lá bài.',
                                style: TextStyle(color: theme.secondaryTextColor),
                              ),
                            )
                          : _buildActiveCardDetail(
                              _cards[_selectedCardIndex.clamp(0, _cards.length - 1)],
                              theme,
                            ),
                    ),
                    const SizedBox(height: 12),
                    if (_cards.isNotEmpty) _buildHistoryTray(_cards, theme),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildActiveCardDetail(TarotCardModel card, dynamic theme) {
    final isWide = !Responsive.isPhone(context);
    final isDesktop = Responsive.isDesktop(context);
    // PC 4K gọn: giải nghĩa 14, tên lá 18; tablet 15/17; phone 15/16.
    final meaningFontSize = isDesktop ? 14.0 : 15.0;
    final nameFontSize = isDesktop ? 18.0 : (isWide ? 17.0 : 16.0);
    final cardWidth = _cardWidth(context);
    final cardHeight = cardWidth * 8 / 5;

    final cardWidget = _buildCard(card, theme, cardWidth);
    // Panel giải nghĩa ngay bên cạnh lá lớn, cao bằng lá — cùng ngôn ngữ
    // với panel bên cạnh sân khấu trong NewReading.
    final meaningWidget = SizedBox(
      height: cardHeight,
      child: GlassPanel(
        backgroundColor: theme.cardBackgroundColor,
        borderColor: theme.glassBorderColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: SelectionArea(
            child: Text(
              card.meaning,
              style: TextStyle(
                color: theme.textColor,
                fontSize: meaningFontSize,
                height: 1.6,
              ),
            ),
          ),
        ),
      ),
    );

    // Đổi lá: sân khấu + panel chuyển cảnh mượt (fade + trượt nhẹ),
    // cùng kiểu AnimatedSwitcher với sân khấu trong NewReading.
    final stage = AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey('detail-${card.id}'),
        child: isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      cardWidget,
                      const SizedBox(height: 12),
                      SizedBox(
                        width: cardWidth,
                        child: Text(
                          card.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: nameFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: meaningWidget),
                ],
              )
            : Column(
                children: [
                  cardWidget,
                  const SizedBox(height: 12),
                  Text(
                    card.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: nameFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: meaningWidget),
                ],
              ),
      ),
    );

    return stage;
  }

  /// Khung lá bài: viền vàng + glow — cùng ngôn ngữ với _cardFrame
  /// trong NewReading.
  Widget _buildCard(TarotCardModel card, dynamic theme, double width) {
    return Center(
      child: SizedBox(
        width: width,
        child: AspectRatio(
          aspectRatio: 5 / 8,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.primaryColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor.withOpacity(0.6),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: TarotCardImage(card: card, fit: BoxFit.cover),
            ),
          ),
        ),
      ),
    );
  }

  /// Khay lịch sử ở dưới cùng: cùng cỡ lá khay với NewReading
  /// (~96 rộng, 5:8), chạm vào lá trong khay để xem lá đó.
  Widget _buildHistoryTray(List<TarotCardModel> cards, dynamic theme) {
    final itemWidth = _trayCardWidth;
    // 96 rộng -> cao 153.6, cộng tên lá ~26 và padding -> khay ~186.
    final trayHeight = itemWidth * 8 / 5 + 32;

    return Container(
      height: trayHeight,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.glassBorderColor, width: 0.5)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        itemBuilder: (context, index) {
          final card = cards[index];
          final isSelected = _selectedCardIndex == index;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _selectedCardIndex = index),
              child: Container(
                width: itemWidth,
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
                  child: Column(
                    children: [
                      Expanded(
                        child: TarotCardImage(card: card, fit: BoxFit.cover),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        color: Colors.black87,
                        width: double.infinity,
                        child: Text(
                          card.name.split(' (').first,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected ? theme.primaryColor : Colors.white70,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
