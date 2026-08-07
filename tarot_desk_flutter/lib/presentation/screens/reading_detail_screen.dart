import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/datasources/database_helper.dart';
import '../../data/models/tarot_card.dart';
import '../../data/models/tarot_reading.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';
import '../widgets/tarot_card_image.dart';

/// Màn hình xem chi tiết lịch sử bốc bài cũ (Hiển thị to lá bài đang chọn sáng viền ở giữa, nghĩa gộp ở giữa, khay lịch sử dưới cùng)
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentThemeData;

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
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  children: [
                    // Thông tin ngày bốc
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        'Lịch sử ngày: ${widget.reading.date.day}/${widget.reading.date.month}/${widget.reading.date.year} ${widget.reading.date.hour}:${widget.reading.date.minute}',
                        style: TextStyle(color: theme.secondaryTextColor, fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),

                    // Phần nội dung chính ở giữa: Lá bài to sáng viền + ý nghĩa gộp
                    Expanded(
                      child: _cards.isEmpty
                          ? Center(
                              child: Text(
                                'Không tìm thấy dữ liệu các lá bài.',
                                style: TextStyle(color: theme.secondaryTextColor),
                              ),
                            )
                          : _buildActiveCardDetail(_cards[_selectedCardIndex], theme),
                    ),

                    const SizedBox(height: 12),

                    // Khay lịch sử các lá bài nằm dưới cùng
                    if (_cards.isNotEmpty)
                      _buildHistoryTray(_cards, theme),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildActiveCardDetail(TarotCardModel card, dynamic theme) {
    return Column(
      children: [
        // Lá bài phóng to nằm chính giữa, sáng viền rực rỡ (glow)
        Center(
          child: Container(
            width: 120,
            height: 190,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.primaryColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor.withOpacity(0.5),
                  blurRadius: 16,
                  spreadRadius: 2,
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: TarotCardImage(card: card, fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Tên lá bài
        Text(
          card.name,
          style: TextStyle(color: theme.textColor, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        // Khung cuộn hiển thị toàn bộ nội dung ý nghĩa
        Expanded(
          child: GlassPanel(
            backgroundColor: theme.cardBackgroundColor,
            borderColor: theme.glassBorderColor,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: SelectionArea(
                child: Text(
                  card.meaning,
                  style: TextStyle(color: theme.textColor, fontSize: 13, height: 1.5),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTray(List<TarotCardModel> cards, dynamic theme) {
    return Container(
      height: 110,
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

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCardIndex = index;
              });
            },
            child: Container(
              width: 65,
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      color: Colors.black87,
                      width: double.infinity,
                      child: Text(
                        card.name.split(' (').first,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? theme.primaryColor : Colors.white70,
                          fontSize: 8,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
