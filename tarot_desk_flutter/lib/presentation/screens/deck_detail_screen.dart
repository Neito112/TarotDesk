import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../data/datasources/database_helper.dart';
import '../../data/models/tarot_card.dart';
import '../../data/models/tarot_deck.dart';
import '../../logic/deck_provider.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';
import '../widgets/tarot_card_image.dart';
import '../widgets/localized_card_text.dart';
import '../widgets/localized_content_text.dart';
import 'edit_card_screen.dart';

/// Màn hình Chi tiết Bộ Bài (Hiển thị lưới lá bài xem bộ bài, Tìm kiếm bài, Học bài Ngẫu nhiên 1 lá).
///
/// Hai chế độ mở:
/// - Xem (readOnly: true) — từ "Bộ bài hiện tại" ở Trang chủ: chỉ
///   xem bộ bài, KHÔNG sửa được gì (không đổi tên, không thêm/sửa lá).
/// - Quản lý (mặc định) — từ "Kho bộ bài": đổi tên bộ, thêm lá mới
///   (nút +), sửa nội dung từng lá (nút Sửa trong hộp chi tiết lá).
/// PC gọn: lưới 5 cột, nội dung căn giữa tối đa 1080, chữ và nút nhỏ.
class DeckDetailScreen extends StatefulWidget {
  final TarotDeckModel deck;

  /// true = chỉ xem (bộ bài hiện tại); false = quản lý (kho bộ bài).
  final bool readOnly;

  const DeckDetailScreen({Key? key, required this.deck, this.readOnly = false})
      : super(key: key);

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

  /// Thêm lá bài MỚI vào bộ này (chỉ ở chế độ quản lý — kho bộ
  /// bài). Mở màn sửa lá ở chế độ tạo (card null), lưu xong tải lại lưới.
  Future<void> _addCard() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditCardScreen(deckId: widget.deck.id!),
      ),
    );
    if (changed == true) _loadCards();
  }

  void _showRandomCardDialog(dynamic theme) {
    final settings = context.read<SettingsProvider>();
    if (_cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.tr('deckDetail.emptyDeckStudy'))),
      );
      return;
    }

    // 1. Nhận diện các lá bài theo ID
    final cardIds = _cards.map((c) => c.id).whereType<int>().toList();
    if (cardIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.tr('deckDetail.noValidCardIds'))),
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
          title: Text(settings.tr('deckDetail.renameTitle'), style: TextStyle(color: theme.textColor)),
          content: TextField(
            controller: controller,
            style: TextStyle(color: theme.textColor),
            decoration: InputDecoration(
              hintText: settings.tr('deckDetail.renameHint'),
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
              child: Text(settings.tr('common.save'), style: TextStyle(color: theme.primaryColor)),
            ),
          ],
        );
      },
    );
  }

  /// Mở hộp xem chi tiết lá bài (Chế độ xem - Read-only) để không bị nhầm lẫn với sửa nội dung bộ bài.
  /// Ở chế độ quản lý (kho bộ bài) có thêm nút Sửa để sửa nội dung
  /// lá; ở chế độ xem (bộ bài hiện tại) chỉ có nút Đóng.
  void _showCardDetailDialog(BuildContext context, TarotCardModel card, dynamic theme) {
    final settings = context.read<SettingsProvider>();
    final isDesktop = Responsive.isDesktop(context);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 420 : 560),
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
                          Text(
                            settings.tr('deckDetail.cardDetailTitle'),
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 16),

                  // Hình ảnh lá bài lớn
                  Container(
                    width: isDesktop ? 96 : 110,
                    height: isDesktop ? 160 : 180,
                    decoration: BoxDecoration(
                      // Nền đen: ảnh lá hiện trọn (contain), không cắt.
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.primaryColor, width: 1.5),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: TarotCardImage(card: card, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tên lá bài
                  card.name.isNotEmpty
                      ? LocalizedCardName(
                          card: card,
                          style: TextStyle(color: theme.primaryColor, fontSize: 16, fontWeight: FontWeight.bold),
                        )
                      : Text(
                          settings.tr('deckDetail.unnamedCard'),
                          style: TextStyle(color: theme.primaryColor, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                  const SizedBox(height: 12),

                  // Luận giải chi tiết (Read-only)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(dialogContext).size.height * 0.4),
                    child: SingleChildScrollView(
                      child: SelectionArea(
                        child: card.meaning.isNotEmpty
                            ? LocalizedCardMeaning(
                                card: card,
                                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                              )
                            : Text(
                                settings.tr('deckDetail.noMeaning'),
                                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (!widget.readOnly)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              Navigator.pop(dialogContext);
                              final changed = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditCardScreen(
                                      card: card, deckId: card.deckId),
                                ),
                              );
                              if (changed == true) _loadCards();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.primaryColor,
                              side: BorderSide(color: theme.primaryColor),
                              padding: EdgeInsets.symmetric(vertical: isDesktop ? 10 : 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(settings.tr('common.edit'), style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      if (!widget.readOnly) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            padding: EdgeInsets.symmetric(vertical: isDesktop ? 10 : 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(settings.tr('common.close'), style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
    final isDesktop = Responsive.isDesktop(context);
    final isTablet = Responsive.isTablet(context);

    final filteredCards = _cards.where((card) {
      return card.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        toolbarHeight: isDesktop ? 48 : null,
        // Chế độ xem (bộ bài hiện tại): tên chỉ để xem, không bấm
        // đổi được. Chế độ quản lý (kho bộ bài): bấm tên để đổi tên.
        title: widget.readOnly
            ? LocalizedDeckName.fromName(
                name: _currentDeckName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: isDesktop ? 16 : 20),
              )
            : GestureDetector(
          onTap: () => _showEditDeckNameDialog(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: LocalizedDeckName.fromName(
                  name: _currentDeckName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: isDesktop ? 16 : 20),
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
            icon: Icon(Icons.school, size: isDesktop ? 16 : 18),
            label: Text(
              settings.tr('deckDetail.randomCard'),
              style: TextStyle(fontSize: isDesktop ? 12 : 14),
            ),
            style: TextButton.styleFrom(
              foregroundColor: theme.primaryColor,
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 8 : 12),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () => _showRandomCardDialog(theme),
          ),
          // Thêm lá mới: chỉ ở chế độ quản lý (kho bộ bài).
          if (!widget.readOnly)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: settings.tr('deckDetail.addNewCard'),
              onPressed: _addCard,
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ResponsiveCenter(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 12 : 16),
                child: Column(
                  children: [
                    // Thanh Tìm kiếm lá bài trong bộ
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: TextStyle(color: theme.textColor, fontSize: isDesktop ? 13 : 15),
                      decoration: InputDecoration(
                        hintText: settings.tr('deckDetail.searchHint'),
                        hintStyle: TextStyle(color: theme.secondaryTextColor),
                        prefixIcon: Icon(Icons.search, color: theme.primaryColor, size: isDesktop ? 20 : 24),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isDesktop ? 10 : 14),
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
                    SizedBox(height: isDesktop ? 12 : 16),

                    // Lưới hiển thị 78 lá bài — PC 5 cột cho gọn.
                    Expanded(
                      child: filteredCards.isEmpty
                          ? Center(
                              child: Text(
                                settings.tr('deckDetail.noMatchingCards'),
                                style: TextStyle(color: theme.secondaryTextColor),
                              ),
                            )
                          : GridView.builder(
                              physics: const BouncingScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isDesktop ? 5 : (isTablet ? 4 : 3),
                                childAspectRatio: 0.62,
                                crossAxisSpacing: isDesktop ? 10 : 12,
                                mainAxisSpacing: isDesktop ? 10 : 12,
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
                                            // Ảnh lá hiện trọn (contain) — ảnh gốc 7:12, cover cắt mất tên lá.
                                            child: TarotCardImage(card: card, fit: BoxFit.contain),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                            color: Colors.black87,
                                            child: LocalizedCardName(
                                              card: card,
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
    final settings = context.watch<SettingsProvider>();
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isDesktop ? 420 : 560),
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
                      Text(
                        settings.tr('deckDetail.studyCardTitle'),
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
                width: isDesktop ? 96 : 110,
                height: isDesktop ? 160 : 180,
                decoration: BoxDecoration(
                  // Nền đen: ảnh lá hiện trọn (contain), không cắt.
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.primaryColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: TarotCardImage(card: card, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 16),

              // Tên và toàn bộ ý nghĩa bên dưới đầy đủ chi tiết
              card.name.isNotEmpty
                  ? LocalizedCardName(
                      card: card,
                      style: TextStyle(color: theme.primaryColor, fontSize: 16, fontWeight: FontWeight.bold),
                    )
                  : Text(
                      settings.tr('deckDetail.unnamedCard'),
                      style: TextStyle(color: theme.primaryColor, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
              const SizedBox(height: 12),

              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                child: SingleChildScrollView(
                  child: SelectionArea(
                    child: card.meaning.isNotEmpty
                        ? LocalizedCardMeaning(
                            card: card,
                            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                          )
                        : Text(
                            settings.tr('deckDetail.noMeaning'),
                            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Nút đóng ở dưới cùng (PC gọn: cao ~40).
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    padding: EdgeInsets.symmetric(vertical: isDesktop ? 10 : 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(settings.tr('deckDetail.finishStudy'), style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
