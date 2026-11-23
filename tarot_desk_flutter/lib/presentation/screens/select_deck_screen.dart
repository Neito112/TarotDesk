import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../core/translation_service.dart';
import '../../data/datasources/database_helper.dart';
import '../../data/datasources/tarotdesk_api_service.dart';
import '../../data/models/tarot_card.dart';
import '../../data/models/tarot_deck.dart';
import '../../logic/auth_provider.dart';
import '../../logic/deck_provider.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';
import '../widgets/smoke_particle_effect.dart';
import '../widgets/tarot_card_image.dart';
import '../widgets/localized_card_text.dart';
import '../widgets/localized_content_text.dart';
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
/// THỨ TỰ MỤC: "Bộ bài chung" Ở TRÊN, "Bộ bài của tôi" Ở DƯỚI.
/// Bộ bài cơ bản (id=1, deck_key 'base') LÀ bộ bài chung — nó hiện
/// trong mục chung (đầu mục, từ dữ liệu local) cùng các bộ chung từ
/// server (chỉ xem + sao chép về kho của mình); mục "Bộ bài của tôi"
/// chỉ gồm các bộ do người dùng tạo/sao chép nên mặc định TRỐNG.
/// Mỗi bộ bài của mình có thêm nút gửi lên server để chờ duyệt.
/// Mỗi nhóm có một tiêu đề mục màu vàng + số lượng, cùng kiểu với
/// tiêu đề nhóm bài ("Ẩn Chính (Major Arcana)") trong panel chọn lá
/// ở màn trải bài: "Bộ bài chung (n)" trên danh sách chung (số lượng
/// chỉ hiện khi đã tải xong danh sách chung), "Bộ bài của tôi (n)"
/// trên lưới của mình.
class SelectDeckScreen extends StatelessWidget {
  const SelectDeckScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentThemeData;
    final deckProvider = context.watch<DeckProvider>();
    final isDesktop = Responsive.isDesktop(context);
    // "Bộ bài của tôi" chỉ gồm các bộ do người dùng tạo/sao chép.
    // Bộ bài cơ bản (id=1, deck_key 'base') LÀ bộ bài chung nên không
    // nằm trong mục này — mặc định mục này TRỐNG.
    final myDecks = deckProvider.decks.where((d) => d.id != 1).toList();

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
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Mục chung Ở TRÊN: bộ bài cơ bản + các bộ chung từ server.
                  const _SharedDecksSection(),
                  const SizedBox(height: 24),
                  // Mục của tôi Ở DƯỚI, mặc định trống.
                  if (deckProvider.decks.isEmpty)
                    Center(
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
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionHeader(
                          label: settings
                              .tr('library.myTitle')
                              .replaceAll(
                                  '{count}', '${myDecks.length}'),
                        ),
                        const SizedBox(height: 8),
                        if (myDecks.isEmpty)
                          Text(
                            settings.tr('library.myEmpty'),
                            style: TextStyle(
                              color: theme.secondaryTextColor,
                              fontSize: isDesktop ? 13 : 14,
                            ),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: myDecks.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: Responsive.gridColumns(context),
                              crossAxisSpacing: isDesktop ? 10 : 12,
                              mainAxisSpacing: isDesktop ? 10 : 12,
                              childAspectRatio: isDesktop ? 0.47 : 0.44,
                            ),
                            itemBuilder: (context, index) {
                              final deck = myDecks[index];
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
                                      builder: (_) =>
                                          DeckDetailScreen(deck: deck),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                      ],
                    ),
                  // Khoảng trống cuối để FAB không che mất mục cuối.
                  const SizedBox(height: 80),
                ],
              ),
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
        content: Text.rich(
          TextSpan(
            children: templateWithLocalizedName(
              template: settings.tr('selectDeck.deleteConfirm'),
              placeholder: '{name}',
              nameWidget: LocalizedDeckName.fromName(name: deckName),
            ),
          ),
        ),
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

/// Tiêu đề mục màu vàng, cùng kiểu với tên nhóm bài trong panel chọn
/// lá ở màn trải bài ("Ẩn Chính (Major Arcana)": chữ vàng đậm 15,
/// đệm dọc 4 — xem _buildSelectionPanel trong new_reading_screen).
/// Dùng cho cả hai nhóm của kho: bộ bài của mình và bộ bài chung.
/// Không có chip lọc: bộ bài không có trường loại/nguồn để lọc
/// (TarotDeckModel chỉ có id, tên, ngày tạo), nên chỉ có tiêu đề.
class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentThemeData;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        label,
        style: TextStyle(
          color: theme.primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
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
                LocalizedDeckName(
                  deck: deck,
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
                      _SubmitDeckButton(
                        deck: deck,
                        theme: theme,
                        isDesktop: isDesktop,
                      ),
                      const SizedBox(width: 4),
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

/// Mục "Bộ bài chung" từ server, hiện dưới lưới bộ bài của mình.
/// Chỉ xem + sao chép về kho của mình, không sửa được bộ bài chung.
/// Khách (chưa đăng nhập) vẫn xem được; chỉ gửi bài mới cần đăng nhập.
class _SharedDecksSection extends StatefulWidget {
  const _SharedDecksSection();

  @override
  State<_SharedDecksSection> createState() => _SharedDecksSectionState();
}

class _SharedDecksSectionState extends State<_SharedDecksSection> {
  // One Worker entry: {"id","name","deck":{...},"cards":[...]}.
  // Guests (null session token) can still browse: the Worker allows
  // public reads of the shared library.
  List<Map<String, dynamic>>? _decks;
  String? _error;
  bool _isLoading = true;
  // Bộ bài cơ bản (id=1, deck_key 'base') LÀ bộ bài chung — hiện đầu
  // mục chung từ dữ liệu local, cùng các bộ chung từ server.
  TarotDeckModel? _basicDeck;
  List<TarotCardModel> _basicCards = [];

  @override
  void initState() {
    super.initState();
    _loadBasicDeck();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final decks = await TarotdeskApiService()
          .listSharedDecks(auth.sessionToken);
      if (!mounted) return;
      setState(() {
        _decks = decks;
        _isLoading = false;
      });
    } on TarotdeskApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  /// Bộ bài cơ bản (id=1) từ dữ liệu local — nó LÀ bộ bài chung
  /// (deck_key 'base', bản dịch owner 'shared'), nên hiện đầu mục
  /// chung thay vì nằm trong "Bộ bài của tôi". Nạp riêng, không chờ
  /// mạng, để mục chung có nội dung ngay cả khi server chậm.
  Future<void> _loadBasicDeck() async {
    final decks = await DatabaseHelper.instance.getDecks();
    final basic = decks.where((d) => d.id == 1).toList();
    if (basic.isEmpty) return;
    final cards = await DatabaseHelper.instance.getCardsByDeckId(1);
    if (!mounted) return;
    setState(() {
      _basicDeck = basic.first;
      _basicCards = cards;
    });
  }

  Future<void> _openSharedDeck(Map<String, dynamic> entry) async {
    final settings = context.read<SettingsProvider>();
    try {
      final deck = _parseSharedDeck(entry);
      final cards = _parseSharedCards(entry);
      if (!mounted) return;
      // WIRING (V2 display path): nạp bản dịch vĩnh viễn đã lưu
      // của bộ bài chung này (ngôn ngữ hiện tại) TRƯỚC khi hiện
      // hộp xem trước, để các lá trong hộp vẽ từ bản đã lưu thay
      // vì dịch theo yêu cầu từng lá. Dùng id máy chủ của bộ bài
      // (entry['id']) — Worker tự đổi ra deck_key. Chờ có giới
      // hạn (timeout ngắn trong service); bộ chưa có bản dịch lưu
      // sẵn hoặc Worker chậm thì các lá dịch theo yêu cầu như
      // trước. Công khai nên khách chưa đăng nhập cũng nạp được.
      final sharedId = entry['id']?.toString();
      if (sharedId != null && sharedId.isNotEmpty) {
        await context.read<TranslationService>().preloadDeckTranslations(
              sharedId: sharedId,
              cards: cards,
              deckName: deck.name,
            );
      }
      if (!mounted) return;
      await _showSharedDeckDialog(deck, cards);
    } on TarotdeskApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${settings.tr('library.loadFailed')} ${e.message}'),
        ),
      );
    }
  }

  /// Mở hộp xem trước của bộ bài cơ bản (đã có sẵn local): nạp bản
  /// dịch vĩnh viễn đã lưu theo deck_key 'base' rồi hiện hộp — nút
  /// hành động là "Chọn" thay vì "Sao chép" (đã có trong kho).
  Future<void> _openBasicDeck() async {
    final deck = _basicDeck;
    if (deck == null) return;
    final cards = _basicCards;
    await context.read<TranslationService>().preloadDeckTranslations(
          deckKey: kBaseDeckKey,
          cards: cards,
          deckName: deck.name,
        );
    if (!mounted) return;
    await _showSharedDeckDialog(deck, cards, alreadyLocal: true);
  }

  /// Deck name shown in the shared list: the nested deck's name,
  /// falling back to the entry's own name.
  String _sharedDeckName(Map<String, dynamic> entry) {
    final deck = entry['deck'];
    if (deck is Map) {
      final name = deck['name'];
      if (name is String && name.isNotEmpty) return name;
    }
    final name = entry['name'];
    return name is String ? name : '';
  }

  int _sharedCardCount(Map<String, dynamic> entry) {
    final cards = entry['cards'];
    return cards is List ? cards.length : 0;
  }

  TarotDeckModel _parseSharedDeck(Map<String, dynamic> entry) {
    final deckRaw = entry['deck'];
    if (deckRaw is! Map) {
      throw TarotdeskApiException('server', 'Shared deck has the wrong shape');
    }
    try {
      return TarotDeckModel.fromMap(Map<String, dynamic>.from(deckRaw));
    } catch (_) {
      throw TarotdeskApiException('server', 'Shared deck has an invalid deck');
    }
  }

  List<TarotCardModel> _parseSharedCards(Map<String, dynamic> entry) {
    final cardsRaw = entry['cards'];
    if (cardsRaw is! List) {
      throw TarotdeskApiException('server', 'Shared deck has the wrong shape');
    }
    final cards = <TarotCardModel>[];
    for (final rawCard in cardsRaw) {
      if (rawCard is! Map) {
        throw TarotdeskApiException('server', 'Shared deck has an invalid card');
      }
      final cardMap = Map<String, dynamic>.from(rawCard);
      // Shared decks must not carry local ids; the caller re-assigns
      // deck_id on insert, so it is 0 here by definition.
      cardMap.remove('id');
      cardMap['deck_id'] = 0;
      try {
        cards.add(TarotCardModel.fromMap(cardMap));
      } catch (_) {
        throw TarotdeskApiException('server', 'Shared deck has an invalid card');
      }
    }
    return cards;
  }

  Future<void> _showSharedDeckDialog(
    TarotDeckModel deck,
    List<TarotCardModel> cards, {
    bool alreadyLocal = false,
  }) async {
    final settings = context.read<SettingsProvider>();
    final theme = settings.currentThemeData;
    final deckProvider = context.read<DeckProvider>();
    // Bộ đã có sẵn local (bộ cơ bản): nút hành động là "Chọn" thay vì
    // "Sao chép"; nếu đã đang chọn thì nút bị vô hiệu hoá.
    final isSelected = deckProvider.selectedDeck?.id == deck.id;
    final actionLabel = alreadyLocal
        ? (isSelected
            ? settings.tr('selectDeck.currentlySelected')
            : settings.tr('selectDeck.select'))
        : settings.tr('library.copyDeck');
    final copy = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.backgroundColor,
        title: LocalizedDeckName(deck: deck),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                settings
                    .tr('library.cardCount')
                    .replaceAll('{count}', '${cards.length}'),
                style: TextStyle(color: theme.secondaryTextColor),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: cards.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: LocalizedCardName(
                      card: cards[index],
                      style: TextStyle(color: theme.textColor),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(settings.tr('common.close')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.black,
            ),
            onPressed: (alreadyLocal && isSelected)
                ? null
                : () => Navigator.pop(ctx, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    if (copy != true) return;
    if (alreadyLocal) {
      // Bộ cơ bản đã có sẵn local: chỉ chọn nó, không sao chép.
      deckProvider.selectDeck(deck);
      return;
    }
    try {
      // Bộ bài mới hoàn toàn: id mới, lá bài gán lại deck_id khi insert
      // (insertFullDeckWithCards tự gán deck_id thật cho từng lá).
      final newDeck =
          TarotDeckModel(name: deck.name, createdDate: DateTime.now());
      final newCards = cards
          .map((c) => TarotCardModel(
                deckId: 0,
                name: c.name,
                meaning: c.meaning,
                imagePath: c.imagePath,
              ))
          .toList();
      await DatabaseHelper.instance.insertFullDeckWithCards(newDeck, newCards);
      await deckProvider.fetchDecks();
      if (!mounted) return;
      if (deckProvider.decks.isEmpty) return;
      final created = deckProvider.decks.firstWhere(
        (d) => d.name == deck.name,
        orElse: () => deckProvider.decks.first,
      );
      deckProvider.selectDeck(created);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.tr('library.copySuccess'))),
      );
    } on TarotdeskApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${settings.tr('library.copyFailed')} ${e.message}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentThemeData;
    final isDesktop = Responsive.isDesktop(context);
    // Tổng số bộ chung = bộ cơ bản (local) + các bộ từ server.
    final sharedCount =
        (_basicDeck != null ? 1 : 0) + (_decks?.length ?? 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cùng kiểu tiêu đề mục vàng như nhóm "Bộ bài của tôi" phía
        // dưới. Số lượng chỉ hiện khi đã tải xong (đang tải / lỗi /
        // rỗng thì chưa biết có bao nhiêu bộ).
        _SectionHeader(
          label: _decks == null
              ? settings.tr('library.sharedTitle')
              : '${settings.tr('library.sharedTitle')} ($sharedCount)',
        ),
        const SizedBox(height: 8),
        // Bộ bài cơ bản (local, deck_key 'base') — đầu mục chung.
        if (_basicDeck != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: LocalizedDeckName(
              deck: _basicDeck!,
              style: TextStyle(color: theme.textColor),
            ),
            subtitle: Text(
              settings
                  .tr('library.cardCount')
                  .replaceAll('{count}', '${_basicCards.length}'),
              style: TextStyle(color: theme.secondaryTextColor),
            ),
            trailing: TextButton(
              onPressed: _openBasicDeck,
              child: Text(settings.tr('library.view')),
            ),
          ),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_error != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: isDesktop ? 13 : 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _load,
                child: Text(settings.tr('library.retry')),
              ),
            ],
          )
        else if ((_decks == null || _decks!.isEmpty) && _basicDeck == null)
          Text(
            settings.tr('library.sharedEmpty'),
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: isDesktop ? 13 : 14,
            ),
          )
        else if (_decks != null && _decks!.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _decks!.length,
            itemBuilder: (context, index) {
              final info = _decks![index];
              final cardCount = _sharedCardCount(info);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: LocalizedDeckName.fromName(
                  name: _sharedDeckName(info),
                  style: TextStyle(color: theme.textColor),
                ),
                subtitle: Text(
                  settings
                      .tr('library.cardCount')
                      .replaceAll('{count}', '$cardCount'),
                  style: TextStyle(color: theme.secondaryTextColor),
                ),
                trailing: TextButton(
                  onPressed: () => _openSharedDeck(info),
                  child: Text(settings.tr('library.view')),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Nút gửi một bộ bài của mình lên server (chờ admin duyệt).
/// Trạng thái đang gửi: hiện spinner nhỏ, nút bị vô hiệu hoá.
class _SubmitDeckButton extends StatefulWidget {
  final dynamic deck;
  final dynamic theme;
  final bool isDesktop;

  const _SubmitDeckButton({
    required this.deck,
    required this.theme,
    required this.isDesktop,
  });

  @override
  State<_SubmitDeckButton> createState() => _SubmitDeckButtonState();
}

class _SubmitDeckButtonState extends State<_SubmitDeckButton> {
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final settings = context.read<SettingsProvider>();
    final auth = context.read<AuthProvider>();
    final sessionToken = auth.sessionToken;
    if (sessionToken == null || sessionToken.isEmpty) {
      // Guests cannot submit: readable error, no crash.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.tr('library.loginRequired'))),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final cards =
          await DatabaseHelper.instance.getCardsByDeckId(widget.deck.id!);
      // Shared files must not carry local ids, so `id` is stripped
      // from the deck map and from every card map before sending.
      final deckMap = (widget.deck as TarotDeckModel).toMap()..remove('id');
      final cardMaps = cards
          .map((card) => card.toMap()..remove('id'))
          .toList();
      final submissionId = await TarotdeskApiService().submitDeck(
        sessionToken,
        <String, dynamic>{'deck': deckMap, 'cards': cardMaps},
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: settings.currentThemeData.backgroundColor,
          title: Text(settings.tr('library.submitSuccess')),
          content: SelectableText(submissionId),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(settings.tr('common.close')),
            ),
          ],
        ),
      );
    } on TarotdeskApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${settings.tr('library.submitFailed')} ${e.message}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 32),
      iconSize: widget.isDesktop ? 20 : 22,
      color: widget.theme.primaryColor,
      tooltip: settings.tr('library.submitDeck'),
      onPressed: _isSubmitting ? null : _submit,
      icon: _isSubmitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.cloud_upload_outlined),
    );
  }
}
