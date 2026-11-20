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
/// Điện thoại (Android, chính): lá bài lớn 5:8 ở trên, panel ý nghĩa ở dưới,
/// khay lịch sử ở dưới cùng.
/// iPad / PC: lá bài + ý nghĩa đặt cạnh nhau, nội dung căn giữa theo
/// Responsive.maxContentWidth.
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

  double _cardWidth(BuildContext context) {
    if (Responsive.isDesktop(context)) return 260;
    if (Responsive.isTablet(context)) return 240;
    return 200;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentThemeData;
    final isWide = !Responsive.isPhone(context);

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.reading.name),
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
    final meaningFontSize = isWide ? 16.0 : 15.0;
    final nameFontSize = isWide ? 22.0 : 20.0;

    final cardWidget = _buildCard(card, theme);
    final meaningWidget = Expanded(
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

    if (!isWide) {
      return Column(
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
          meaningWidget,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            cardWidget,
            const SizedBox(height: 12),
            SizedBox(
              width: _cardWidth(context),
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
        const SizedBox(width: 24),
        meaningWidget,
      ],
    );
  }

  Widget _buildCard(TarotCardModel card, dynamic theme) {
    return Center(
      child: SizedBox(
        width: _cardWidth(context),
        child: AspectRatio(
          aspectRatio: 5 / 8,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.primaryColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor.withOpacity(0.5),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: TarotCardImage(card: card, fit: BoxFit.cover),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTray(List<TarotCardModel> cards, dynamic theme) {
    final isWide = !Responsive.isPhone(context);
    final itemWidth = isWide ? 84.0 : 76.0;
    final trayHeight = isWide ? 128.0 : 116.0;

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
