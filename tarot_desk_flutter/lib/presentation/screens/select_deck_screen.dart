import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/tarot_card.dart';
import '../../data/datasources/database_helper.dart';
import '../../logic/deck_provider.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';
import '../widgets/smoke_particle_effect.dart';
import '../widgets/tarot_card_image.dart';
import 'add_deck_screen.dart';
import 'deck_detail_screen.dart';

/// Màn hình chọn & quản lý danh sách bộ bài Tarot
class SelectDeckScreen extends StatelessWidget {
  const SelectDeckScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentThemeData;
    final deckProvider = context.watch<DeckProvider>();

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: const Text('Danh Sách Bộ Bài Tarot'),
        backgroundColor: Colors.transparent,
        foregroundColor: theme.primaryColor,
        elevation: 0,
      ),
      body: SmokeParticleEffect(
        enableSmoke: settings.userPrefs.enableSmokeParticles,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Expanded(
                  child: deckProvider.decks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.auto_stories, color: theme.secondaryTextColor, size: 56),
                              const SizedBox(height: 16),
                              Text(
                                'Chưa có bộ bài nào.\nHãy bấm "Thêm Bộ Bài Mới" bên dưới để tạo!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: theme.secondaryTextColor, fontSize: 15),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: deckProvider.decks.length,
                          itemBuilder: (context, index) {
                            final deck = deckProvider.decks[index];
                            final isSelected = deckProvider.selectedDeck?.id == deck.id;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: GlassPanel(
                                backgroundColor: isSelected
                                    ? theme.primaryColor.withOpacity(0.2)
                                    : theme.cardBackgroundColor,
                                borderColor: isSelected
                                    ? theme.primaryColor
                                    : theme.glassBorderColor,
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => DeckDetailScreen(deck: deck),
                                          ),
                                        );
                                      },
                                      child: _DeckThumbnail(deckId: deck.id!, theme: theme),
                                    ),
                                    const SizedBox(width: 12),
                                    // Thông tin bộ bài
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => DeckDetailScreen(deck: deck),
                                            ),
                                          );
                                        },
                                        behavior: HitTestBehavior.opaque,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              deck.name,
                                              style: TextStyle(
                                                color: theme.textColor,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Ngày tạo: ${deck.createdDate.day}/${deck.createdDate.month}/${deck.createdDate.year}',
                                              style: TextStyle(color: theme.secondaryTextColor, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Buttons
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (isSelected)
                                          Icon(Icons.check_circle, color: theme.primaryColor, size: 24)
                                        else
                                          SizedBox(
                                            height: 32,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: theme.primaryColor,
                                                foregroundColor: Colors.black,
                                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                                textStyle: const TextStyle(fontSize: 12),
                                              ),
                                              onPressed: () => deckProvider.selectDeck(deck),
                                              child: const Text('Chọn'),
                                            ),
                                          ),
                                        const SizedBox(height: 6),
                                        // Nút xóa - chỉ hiện nếu không phải bộ bài đang chọn
                                        if (!isSelected)
                                          SizedBox(
                                            height: 28,
                                            child: TextButton(
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.redAccent,
                                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                                textStyle: const TextStyle(fontSize: 11),
                                              ),
                                              onPressed: () => _confirmDelete(context, deckProvider, deck.id!, deck.name),
                                              child: const Text('Xóa'),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Thêm Bộ Bài Mới'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddDeckScreen()),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    DeckProvider deckProvider,
    int deckId,
    String deckName,
  ) async {
    final theme = context.read<SettingsProvider>().currentThemeData;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.backgroundColor,
        title: const Text('Xóa Bộ Bài'),
        content: Text('Bạn có chắc muốn xóa bộ bài "$deckName"?\nHành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await deckProvider.deleteDeck(deckId);
    }
  }
}

/// Widget thumbnail hiển thị hình ảnh lá bài đầu tiên của một bộ bài
class _DeckThumbnail extends StatefulWidget {
  final int deckId;
  final dynamic theme;

  const _DeckThumbnail({required this.deckId, required this.theme});

  @override
  State<_DeckThumbnail> createState() => _DeckThumbnailState();
}

class _DeckThumbnailState extends State<_DeckThumbnail> {
  TarotCardModel? _firstCard;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadFirstCard();
  }

  Future<void> _loadFirstCard() async {
    final cards = await DatabaseHelper.instance.getCardsByDeckId(widget.deckId);
    if (mounted) {
      setState(() {
        _firstCard = cards.isNotEmpty ? cards.first : null;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 52,
        height: 72,
        color: Colors.black26,
        child: !_loaded
            ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
            : _firstCard != null
                ? TarotCardImage(card: _firstCard!, width: 52, height: 72, fit: BoxFit.cover)
                : Icon(Icons.auto_stories, color: widget.theme.primaryColor, size: 28),
      ),
    );
  }
}
