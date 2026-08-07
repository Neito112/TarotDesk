import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/datasources/database_helper.dart';
import '../../data/models/tarot_card.dart';
import '../../data/models/tarot_deck.dart';
import '../../logic/deck_provider.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';
import '../widgets/tarot_card_image.dart';

/// Màn hình Chi tiết Bộ Bài (Hiển thị lưới lá bài xem bộ bài, Tìm kiếm bài, Học bài Ngẫu nhiên 1 lá)
class DeckDetailScreen extends StatefulWidget {
  final TarotDeckModel deck;

  const DeckDetailScreen({Key? key, required this.deck}) : super(key: key);

  @override
  State<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends State<DeckDetailScreen> {
  List<TarotCardModel> _cards = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _currentDeckName = '';

  @override
  void initState() {
    super.initState();
    _currentDeckName = widget.deck.name;
    _loadCards();
  }

  Future<void> _loadCards() async {
    setState(() => _isLoading = true);
    final loaded = await DatabaseHelper.instance.getCardsByDeckId(widget.deck.id!);
    if (mounted) {
      setState(() {
        _cards = loaded;
        _isLoading = false;
      });
    }
  }

  void _showRandomCardDialog(dynamic theme) {
    if (_cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bộ bài này trống, không có lá nào để học.')),
      );
      return;
    }

    // 1. Nhận diện các lá bài theo ID
    final cardIds = _cards.map((c) => c.id).whereType<int>().toList();
    if (cardIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy danh sách ID lá bài hợp lệ.')),
      );
      return;
    }

    // 2. Thuật toán random gọi ra một số (ID của lá bài)
    final random = Random();
    final randomId = cardIds[random.nextInt(cardIds.length)];

    // 3. Truy xuất lá bài tương ứng
    final randomCard = _cards.firstWhere((c) => c.id == randomId);

    showDialog(
      context: context,
      builder: (context) {
        return _RandomCardStudyDialog(card: randomCard, theme: theme);
      },
    );
  }

  void _showEditDeckNameDialog(BuildContext context) {
    final controller = TextEditingController(text: _currentDeckName);
    showDialog(
      context: context,
      builder: (context) {
        final settings = context.watch<SettingsProvider>();
        final theme = settings.currentThemeData;
        return AlertDialog(
          backgroundColor: theme.backgroundColor, // Thay thế cardBackgroundColor đục hoàn toàn để không lỗi trộn text
          title: Text('Đổi tên bộ bài', style: TextStyle(color: theme.textColor)),
          content: TextField(
            controller: controller,
            style: TextStyle(color: theme.textColor),
            decoration: InputDecoration(
              hintText: 'Nhập tên bộ bài mới...',
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
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  await context.read<DeckProvider>().updateDeckName(widget.deck.id!, newName);
                  setState(() {
                    _currentDeckName = newName;
                  });
                }
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: Text('Lưu', style: TextStyle(color: theme.primaryColor)),
            ),
          ],
        );
      },
    );
  }

  /// Mở hộp xem chi tiết lá bài (Chế độ xem - Read-only) để không bị nhầm lẫn với sửa nội dung bộ bài
  void _showCardDetailDialog(BuildContext context, TarotCardModel card, dynamic theme) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: GlassPanel(
            backgroundColor: theme.backgroundColor, // Nền đục vững chãi tránh trộn text dưới nền
            borderColor: theme.primaryColor,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_stories, color: theme.primaryColor),
                          const SizedBox(width: 8),
                          const Text(
                            'Chi tiết lá bài',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 16),

                  // Hình ảnh lá bài lớn
                  Container(
                    width: 110,
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.primaryColor, width: 1.5),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: TarotCardImage(card: card, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tên lá bài
                  Text(
                    card.name.isNotEmpty ? card.name : 'Lá bài chưa đặt tên',
                    style: TextStyle(color: theme.primaryColor, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // Luận giải chi tiết (Read-only)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                    child: SingleChildScrollView(
                      child: SelectionArea(
                        child: Text(
                          card.meaning.isNotEmpty ? card.meaning : 'Chưa có ý nghĩa/nội dung chi tiết cho lá bài này.',
                          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Đóng', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentThemeData;

    final filteredCards = _cards.where((card) {
      return card.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _showEditDeckNameDialog(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _currentDeckName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.edit, size: 16, color: theme.primaryColor),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: theme.primaryColor,
        elevation: 0,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.school, size: 18),
            label: const Text('Ngẫu nhiên 1 lá'),
            style: TextButton.styleFrom(
              foregroundColor: theme.primaryColor,
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () => _showRandomCardDialog(theme),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    // Thanh Tìm kiếm lá bài trong bộ
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: TextStyle(color: theme.textColor),
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm lá bài...',
                        hintStyle: TextStyle(color: theme.secondaryTextColor),
                        prefixIcon: Icon(Icons.search, color: theme.primaryColor),
                        filled: true,
                        fillColor: theme.cardBackgroundColor.withOpacity(0.4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.glassBorderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.primaryColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Lưới hiển thị 78 lá bài
                    Expanded(
                      child: filteredCards.isEmpty
                          ? Center(
                              child: Text(
                                'Không tìm thấy lá bài nào khớp.',
                                style: TextStyle(color: theme.secondaryTextColor),
                              ),
                            )
                          : GridView.builder(
                              physics: const BouncingScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 0.62,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: filteredCards.length,
                              itemBuilder: (context, index) {
                                final card = filteredCards[index];
                                return GestureDetector(
                                  onTap: () {
                                    // Bấm vào lá bài là vào chế độ xem bộ bài (Read-only) chứ không phải sửa nội dung
                                    _showCardDetailDialog(context, card, theme);
                                  },
                                  child: GlassPanel(
                                    padding: EdgeInsets.zero,
                                    backgroundColor: theme.cardBackgroundColor,
                                    borderColor: theme.glassBorderColor,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: TarotCardImage(card: card, fit: BoxFit.cover),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                            color: Colors.black87,
                                            child: Text(
                                              card.name,
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: theme.textColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
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
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Dialog Học Bài: Hiển thị lá bài ngẫu nhiên kèm theo ý nghĩa đầy đủ chi tiết (Nền đực vững chãi)
class _RandomCardStudyDialog extends StatelessWidget {
  final TarotCardModel card;
  final dynamic theme;

  const _RandomCardStudyDialog({Key? key, required this.card, required this.theme}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: GlassPanel(
        backgroundColor: theme.backgroundColor, // Dùng màu nền vững chãi hoàn toàn đục để không bị trùng text dưới
        borderColor: theme.primaryColor,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.school, color: theme.primaryColor),
                      const SizedBox(width: 8),
                      const Text(
                        'Học thuộc lá bài',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 16),

              // Thẻ bài
              Container(
                width: 110,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.primaryColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: TarotCardImage(card: card, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 16),

              // Tên và toàn bộ ý nghĩa bên dưới đầy đủ chi tiết
              Text(
                card.name.isNotEmpty ? card.name : 'Lá bài chưa đặt tên',
                style: TextStyle(color: theme.primaryColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                child: SingleChildScrollView(
                  child: SelectionArea(
                    child: Text(
                      card.meaning.isNotEmpty ? card.meaning : 'Chưa có ý nghĩa/nội dung chi tiết cho lá bài này.',
                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Nút đóng ở dưới cùng
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Hoàn Thành Học', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
