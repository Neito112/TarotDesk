import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../data/models/tarot_card.dart';
import '../../data/datasources/database_helper.dart';
import '../../logic/deck_provider.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';
import '../widgets/smoke_particle_effect.dart';
import '../widgets/tarot_card_image.dart';
import 'add_deck_screen.dart';
import 'deck_detail_screen.dart';

/// Màn hình chọn & quản lý danh sách bộ bài Tarot.
/// Điện thoại (Android, chính): lưới 2 cột, thumbnail lá bài 5:8.
/// iPad: 3 cột. PC: 4 cột, nội dung căn giữa theo Responsive.maxContentWidth.
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
          child: ResponsiveCenter(
            padding: const EdgeInsets.all(16),
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
                : GridView.builder(
                    itemCount: deckProvider.decks.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: Responsive.gridColumns(context),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.44,
                    ),
                    itemBuilder: (context, index) {
                      final deck = deckProvider.decks[index];
                      final isSelected = deckProvider.selectedDeck?.id == deck.id;
                      return _DeckCard(
                        deck: deck,
                        isSelected: isSelected,
                        theme: theme,
                        onSelect: () => deckProvider.selectDeck(deck),
                        onDelete: () => _confirmDelete(
                          context,
                          deckProvider,
                          deck.id!,
                          deck.name,
                        ),
                        onOpen: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DeckDetailScreen(deck: deck),
                            ),
                          );
                        },
                      );
                    },
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
            style: TextButton.styleFrom(minimumSize: const Size(88, 48)),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              minimumSize: const Size(88, 48),
            ),
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

class _DeckCard extends StatelessWidget {
  final dynamic deck;
  final bool isSelected;
  final dynamic theme;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  const _DeckCard({
    required this.deck,
    required this.isSelected,
    required this.theme,
    required this.onSelect,
    required this.onDelete,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      backgroundColor: isSelected
          ? theme.primaryColor.withOpacity(0.2)
          : theme.cardBackgroundColor,
      borderColor: isSelected ? theme.primaryColor : theme.glassBorderColor,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: onOpen,
            child: _DeckThumbnail(deckId: deck.id!, theme: theme),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onOpen,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deck.name,
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Ngày tạo: ${deck.createdDate.day}/${deck.createdDate.month}/${deck.createdDate.year}',
                  style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 48,
            child: isSelected
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: theme.primaryColor, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Đang chọn',
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.black,
                            minimumSize: const Size.fromHeight(48),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            textStyle: const TextStyle(fontSize: 14),
                          ),
                          onPressed: onSelect,
                          child: const Text('Chọn'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 56,
                        height: 48,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            padding: EdgeInsets.zero,
                            textStyle: const TextStyle(fontSize: 13),
                          ),
                          onPressed: onDelete,
                          child: const Text('Xóa'),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

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
    return AspectRatio(
      aspectRatio: 5 / 8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: Colors.black26,
          child: !_loaded
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _firstCard != null
                  ? SizedBox.expand(
                      child: TarotCardImage(card: _firstCard!, fit: BoxFit.cover),
                    )
                  : Icon(Icons.auto_stories, color: widget.theme.primaryColor, size: 28),
        ),
      ),
    );
  }
}
