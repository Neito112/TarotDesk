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

/// Màn hình chọn & quản lý danh sách bộ bài Tarot (KHO BỘ BÀI).
/// Điện thoại (Android, chính): lưới 2 cột, thumbnail lá bài 5:8.
/// iPad: 3 cột. PC: 4 cột, mật độ gọn (PC 4K), nội dung căn giữa theo
/// Responsive.maxContentWidth. Thumbnail luôn 5:8 như lá bài trên bàn
/// trải (bàn gỗ + khăn lớn + decor ảnh), trạng thái đã chọn rõ ràng:
/// viền vàng + nền vàng nhạt + huy hiệu check + chữ "Đang chọn".
/// Bấm vào một bộ bài → mở chi tiết bộ ở CHẾ ĐỘ QUẢN LÝ (đổi tên,
/// thêm/sửa lá) — khác với "Bộ bài hiện tại" ở Trang chủ (chỉ xem).
/// Nút PC gọn: hàng thao tác cao 32, nút xóa cao 36.
class SelectDeckScreen extends StatelessWidget {
  const SelectDeckScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentThemeData;
    final deckProvider = context.watch<DeckProvider>();
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        toolbarHeight: isDesktop ? 48 : null,
        title: Text(
          settings.tr('selectDeck.title'),
          style: TextStyle(fontSize: isDesktop ? 16 : 20),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: theme.primaryColor,
        elevation: 0,
      ),
      body: SmokeParticleEffect(
        enableSmoke: settings.userPrefs.enableSmokeParticles,
        child: SafeArea(
          child: ResponsiveCenter(
            padding: EdgeInsets.all(isDesktop ? 12 : 16),
            child: deckProvider.decks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_stories,
                          color: theme.secondaryTextColor,
                          size: isDesktop ? 44 : 56,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          settings.tr('selectDeck.emptyState'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.secondaryTextColor,
                            fontSize: isDesktop ? 14 : 15,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    itemCount: deckProvider.decks.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: Responsive.gridColumns(context),
                      crossAxisSpacing: isDesktop ? 10 : 12,
                      mainAxisSpacing: isDesktop ? 10 : 12,
                      childAspectRatio: isDesktop ? 0.47 : 0.44,
                    ),
                    itemBuilder: (context, index) {
                      final deck = deckProvider.decks[index];
                      final isSelected =
                          deckProvider.selectedDeck?.id == deck.id;
                      return _DeckCard(
                        deck: deck,
                        isSelected: isSelected,
                        theme: theme,
                        isDesktop: isDesktop,
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
        extendedPadding:
            EdgeInsets.symmetric(horizontal: isDesktop ? 12 : 16),
        icon: Icon(Icons.add, size: isDesktop ? 20 : 24),
        label: Text(
          settings.tr('selectDeck.addNewDeck'),
          style: TextStyle(fontSize: isDesktop ? 13 : 14),
        ),
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
    final settings = context.read<SettingsProvider>();
    final theme = settings.currentThemeData;
    final isDesktop = Responsive.isDesktop(context);
    // Nút PC gọn: cao 36 thay vì 48.
    final buttonHeight = isDesktop ? 36.0 : 48.0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.backgroundColor,
        title: Text(settings.tr('selectDeck.deleteTitle')),
        content: Text(settings.tr('selectDeck.deleteConfirm').replaceAll('{name}', deckName)),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: Size(88, buttonHeight)),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(settings.tr('common.cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              minimumSize: Size(88, buttonHeight),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(settings.tr('common.delete'), style: TextStyle(color: Colors.white)),
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
  final bool isDesktop;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  const _DeckCard({
    required this.deck,
    required this.isSelected,
    required this.theme,
    required this.isDesktop,
    required this.onSelect,
    required this.onDelete,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    // Chiều cao vùng thao tác: 48dp trên điện thoại, gọn 32dp trên PC 4K.
    final actionHeight = isDesktop ? 32.0 : 48.0;
    return GlassPanel(
      backgroundColor: isSelected
          ? theme.primaryColor.withOpacity(0.2)
          : theme.cardBackgroundColor,
      borderColor: isSelected ? theme.primaryColor : theme.glassBorderColor,
      padding: EdgeInsets.all(isDesktop ? 10 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: onOpen,
            child: Stack(
              children: [
                _DeckThumbnail(deckId: deck.id!, theme: theme),
                if (isSelected)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.45),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.black,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
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
                    fontSize: isDesktop ? 13 : 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  settings.tr('selectDeck.createdDate').replaceAll('{date}', '${deck.createdDate.day}/${deck.createdDate.month}/${deck.createdDate.year}'),
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: isDesktop ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            height: actionHeight,
            child: isSelected
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: theme.primaryColor,
                        size: isDesktop ? 20 : 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        settings.tr('selectDeck.currentlySelected'),
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontSize: isDesktop ? 13 : 14,
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
                            minimumSize: Size.fromHeight(actionHeight),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            textStyle: TextStyle(
                              fontSize: isDesktop ? 13 : 14,
                            ),
                          ),
                          onPressed: onSelect,
                          child: Text(settings.tr('selectDeck.select')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 56,
                        height: actionHeight,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            padding: EdgeInsets.zero,
                            textStyle: TextStyle(
                              fontSize: isDesktop ? 12 : 13,
                            ),
                          ),
                          onPressed: onDelete,
                          child: Text(settings.tr('common.delete')),
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
    // Thumbnail lá bài luôn tỉ lệ 5:8 như lá bài trên bàn trải.
    // Ảnh lá hiện trọn (contain, nền đen) — ảnh gốc 7:12, cover
    // cắt mất đầu/cuối tranh.
    return AspectRatio(
      aspectRatio: 5 / 8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: Colors.black,
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
                      child: TarotCardImage(card: _firstCard!, fit: BoxFit.contain),
                    )
                  : Icon(Icons.auto_stories, color: widget.theme.primaryColor, size: 28),
        ),
      ),
    );
  }
}
