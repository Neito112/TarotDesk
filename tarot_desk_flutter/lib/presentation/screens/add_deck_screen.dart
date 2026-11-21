import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../core/translation_service.dart';
import '../../data/datasources/tarotdesk_api_service.dart';
import '../../data/models/tarot_card.dart';
import '../../logic/auth_provider.dart';
import '../../logic/deck_provider.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';
import '../widgets/localized_card_text.dart';

/// Màn hình Tạo Bộ Bài Mới & Nhập Từng Lá Bài Đầy Đủ
/// Bố cục: tên bộ bài một hàng full-width ở trên cùng; màn rộng
/// (iPad/PC) thì form thêm lá (trái) + danh sách lá nháp (phải)
/// cạnh nhau để vừa nhập vừa thấy; điện thoại xếp dọc một cột.
/// Chọn ảnh gọn (thumbnail 5:8 + nút chọn, không còn hộp trống
/// lớn). Logic, provider và text tiếng Việt giữ nguyên.
class AddDeckScreen extends StatefulWidget {
  const AddDeckScreen({Key? key}) : super(key: key);

  @override
  State<AddDeckScreen> createState() => _AddDeckScreenState();
}

class _AddDeckScreenState extends State<AddDeckScreen> {
  final _deckNameController = TextEditingController();
  final _cardNameController = TextEditingController();
  final _cardMeaningController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  String? _selectedImagePath;
  final List<TarotCardModel> _draftCards = [];

  @override
  void dispose() {
    _deckNameController.dispose();
    _cardNameController.dispose();
    _cardMeaningController.dispose();
    super.dispose();
  }

  Future<void> _pickCardImage() async {
    final settings = context.read<SettingsProvider>();
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.tr('addDeck.cannotOpenGallery').replaceAll('{error}', '$e'))),
      );
    }
  }

  void _addCardToDraft() {
    final settings = context.read<SettingsProvider>();
    final name = _cardNameController.text.trim();
    final meaning = _cardMeaningController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.tr('addDeck.enterCardName'))),
      );
      return;
    }

    setState(() {
      _draftCards.add(TarotCardModel(
        deckId: 0,
        name: name,
        meaning: meaning.isEmpty ? 'Chưa có giải nghĩa.' : meaning,
        imagePath: _selectedImagePath ?? 'assets/images/default_card.png',
      ));
      _cardNameController.clear();
      _cardMeaningController.clear();
      _selectedImagePath = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(settings.tr('addDeck.cardAdded').replaceAll('{name}', name))),
    );
  }

  void _removeCardFromDraft(int index) {
    setState(() {
      _draftCards.removeAt(index);
    });
  }

  Future<void> _saveEntireDeck() async {
    final settings = context.read<SettingsProvider>();
    final deckName = _deckNameController.text.trim();
    if (deckName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.tr('addDeck.enterDeckName'))),
      );
      return;
    }

    if (_draftCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.tr('addDeck.addAtLeastOneCard'))),
      );
      return;
    }

    final deckProvider = context.read<DeckProvider>();
    // Read before the await below (no context use after an
    // async gap): the warm-up after saving only needs the
    // session token, captured here via the provider reference.
    final auth = context.read<AuthProvider>();
    await deckProvider.createFullDeckWithCards(deckName, _draftCards);

    // NORMALISATION (i18n): the deck the user just typed may be
    // in any language. Warm the translation cache for it in the
    // background (fire-and-forget, best-effort) so it already
    // displays in the active system language when the user opens
    // it. The saved deck keeps exactly what the user typed —
    // translations live only in the Worker D1 cache + memory
    // (see TranslationService). Guests (no session token) are
    // served under the Worker's anonymous cap.
    final targetLang = settings.language.code;
    final sourceLang = detectDeckLanguage(deckName, _draftCards);
    if (sourceLang == null || sourceLang != targetLang) {
      final translator = TranslationService(
        TarotdeskApiService(),
        sessionToken: () => auth.sessionToken,
        targetLanguageCode: () => targetLang,
      );
      unawaited(
        translator.warmCache(
          List<TarotCardModel>.of(_draftCards),
          deckName: deckName,
          sourceLang: sourceLang,
          targetLang: targetLang,
        ),
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.tr('addDeck.deckSaved').replaceAll('{name}', deckName))),
      );
      Navigator.pop(context);
    }
  }

  InputDecoration _fieldDecoration(dynamic theme, String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: theme.secondaryTextColor),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: theme.glassBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: theme.primaryColor),
      ),
    );
  }

  Widget _stepHeader(dynamic theme,
      {required IconData icon,
      required Color iconColor,
      required String title,
      required bool isDesktop}) {
    return Row(
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: TextStyle(
              color: theme.primaryColor,
              fontSize: isDesktop ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// Tên bộ bài — đặt riêng một hàng full-width ở trên cùng (đây
  /// là định danh của bộ, không nhét chung cột với form thêm lá).
  Widget _deckNamePanel(dynamic theme, bool isDesktop) {
    final settings = context.watch<SettingsProvider>();
    return GlassPanel(
      backgroundColor: theme.cardBackgroundColor,
      borderColor: theme.glassBorderColor,
      child: Row(
        children: [
          Icon(Icons.collections, color: theme.primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _deckNameController,
              style: TextStyle(color: theme.textColor),
              decoration: _fieldDecoration(theme, settings.tr('addDeck.deckName')),
            ),
          ),
          const SizedBox(width: 10),
          Chip(
            label: Text(settings.tr('addDeck.cardCount').replaceAll('{n}', '${_draftCards.length}'),
                style: TextStyle(
                    color: theme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            backgroundColor: theme.primaryColor.withOpacity(0.15),
            side: BorderSide(color: theme.primaryColor.withOpacity(0.4)),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  /// Form thêm một lá bài: ảnh chọn gọn (thumbnail 5:8 + nút chọn,
  /// không còn hộp trống lớn), tên lá, giải nghĩa, nút thêm.
  /// Trên màn rộng form này nằm cột trái, danh sách lá nháp nằm
  /// cột phải để vừa nhập vừa thấy các lá đã thêm.
  Widget _addCardPanel(BuildContext context, dynamic theme, bool isDesktop) {
    final settings = context.watch<SettingsProvider>();
    return GlassPanel(
      backgroundColor: theme.cardBackgroundColor,
      borderColor: theme.glassBorderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(theme,
              icon: Icons.add_photo_alternate,
              iconColor: theme.accentColor,
              title: settings.tr('addDeck.addCardTitle'),
              isDesktop: isDesktop),
          const SizedBox(height: 12),
          // Hàng chọn ảnh gọn: thumbnail 5:8 bên trái, nút + gợi ý
          // bên phải (thay hộp trống cao 140/180).
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _pickCardImage,
                child: Container(
                  width: 84,
                  height: 134,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: theme.primaryColor.withOpacity(0.5)),
                  ),
                  child: _selectedImagePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: kIsWeb
                              ? Image.network(_selectedImagePath!,
                                  fit: BoxFit.contain)
                              : Image.file(File(_selectedImagePath!),
                                  fit: BoxFit.contain),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo,
                                color: theme.primaryColor, size: 28),
                            const SizedBox(height: 6),
                            Text(
                              settings.tr('addDeck.chooseImage'),
                              style: TextStyle(
                                  color: theme.secondaryTextColor,
                                  fontSize: 11),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: isDesktop ? 36 : 44,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: Text(
                          _selectedImagePath != null
                              ? settings.tr('addDeck.changeImage')
                              : settings.tr('addDeck.chooseFromGallery'),
                          style: TextStyle(fontSize: isDesktop ? 12 : 13),
                        ),
                        onPressed: _pickCardImage,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      settings.tr('addDeck.imageHint'),
                      style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 11,
                          height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cardNameController,
            style: TextStyle(color: theme.textColor),
            decoration: _fieldDecoration(theme, settings.tr('addDeck.cardName')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cardMeaningController,
            maxLines: 3,
            style: TextStyle(color: theme.textColor),
            decoration: _fieldDecoration(theme, settings.tr('addDeck.cardMeaning')),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: isDesktop ? 36 : 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accentColor,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add),
              label: Text(
                settings.tr('addDeck.addCardToDeck'),
                style: TextStyle(fontSize: isDesktop ? 13 : 14),
              ),
              onPressed: _addCardToDraft,
            ),
          ),
        ],
      ),
    );
  }

  /// Danh sách lá bài nháp đã nhập: tiêu đề + số lượng + nút xóa
  /// tất cả, rồi lưới thẻ 5:8. Panel riêng để đặt cạnh form thêm
  /// lá trên màn rộng (vừa nhập vừa thấy).
  Widget _draftListPanel(dynamic theme, bool isDesktop) {
    final settings = context.watch<SettingsProvider>();
    return GlassPanel(
      backgroundColor: theme.cardBackgroundColor,
      borderColor: theme.glassBorderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  settings.tr('addDeck.draftListTitle').replaceAll('{n}', '${_draftCards.length}'),
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: isDesktop ? 14 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_draftCards.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _draftCards.clear();
                    });
                  },
                  child: Text(settings.tr('addDeck.clearAll'),
                      style: TextStyle(color: Colors.redAccent)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_draftCards.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  settings.tr('addDeck.noDraftCards'),
                  style: TextStyle(
                      color: theme.secondaryTextColor, fontSize: 13),
                ),
              ),
            )
          else
            // Danh sách lá nháp là lưới thẻ 5:8 như lá bài
            // trên bàn trải: 2 cột điện thoại, 3 iPad, 4 PC.
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: Responsive.gridColumns(context),
                crossAxisSpacing: isDesktop ? 10 : 12,
                mainAxisSpacing: isDesktop ? 10 : 12,
                childAspectRatio: 5 / 8,
              ),
              itemCount: _draftCards.length,
              itemBuilder: (context, index) =>
                  _draftCardItem(theme, _draftCards[index], index),
            ),
        ],
      ),
    );
  }

  /// Một lá bài nháp hiển thị như một lá bài Tarot thật: tỉ lệ 5:8,
  /// ảnh hiện trọn (contain, không cắt), tên + giải nghĩa trên lớp
  /// phủ tối ở chân lá, nút xóa 36dp (PC) / 48dp ở góc trên-phải.
  /// Cùng ngôn ngữ 5:8 với lá bài trên bàn trải (bàn gỗ + khăn lớn
  /// + decor ảnh).
  Widget _draftCardItem(dynamic theme, TarotCardModel card, int index) {
    final isDesktop = Responsive.isDesktop(context);
    final deleteSize = isDesktop ? 36.0 : 48.0;
    return AspectRatio(
      aspectRatio: 5 / 8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: theme.cardBackgroundColor,
          child: Stack(
            fit: StackFit.expand,
            children: [
              card.imagePath.startsWith('assets')
                  ? Container(
                      color: theme.primaryColor.withOpacity(0.2),
                      child: Icon(
                        Icons.auto_stories,
                        color: theme.primaryColor,
                        size: 32,
                      ),
                    )
                  : kIsWeb
                      ? Image.network(card.imagePath, fit: BoxFit.contain)
                      : Image.file(File(card.imagePath), fit: BoxFit.contain),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 18, 10, 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0),
                        Colors.black.withOpacity(0.85),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${index + 1}. ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Expanded(
                            child: LocalizedCardName(
                              card: card,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      LocalizedCardMeaning(
                        card: card,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: deleteSize,
                  height: deleteSize,
                  alignment: Alignment.center,
                  child: IconButton(
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: deleteSize,
                      minHeight: deleteSize,
                    ),
                    onPressed: () => _removeCardFromDraft(index),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentThemeData;
    final isWide = Responsive.isTablet(context) ||
        Responsive.isDesktop(context);
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        toolbarHeight: isDesktop ? 48 : null,
        title: Text(
          settings.tr('addDeck.title'),
          style: TextStyle(fontSize: isDesktop ? 16 : 20),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: theme.primaryColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: ResponsiveCenter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Tên bộ bài: một hàng full-width ở trên cùng.
                      _deckNamePanel(theme, isDesktop),
                      const SizedBox(height: 16),
                      // Màn rộng: form thêm lá (trái) + danh sách
                      // lá nháp (phải) cạnh nhau — vừa nhập vừa
                      // thấy các lá đã thêm. Điện thoại: xếp dọc.
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child:
                                    _addCardPanel(context, theme, isDesktop)),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _draftListPanel(theme, isDesktop)),
                          ],
                        )
                      else ...[
                        _addCardPanel(context, theme, isDesktop),
                        const SizedBox(height: 16),
                        _draftListPanel(theme, isDesktop),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: Responsive.maxContentWidth(context),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: isDesktop ? 40 : 54,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.black,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.save, size: 24),
                      label: Text(
                        settings.tr('addDeck.saveEntireDeck').replaceAll('{n}', '${_draftCards.length}'),
                        style: TextStyle(
                            fontSize: isDesktop ? 13 : 16,
                            fontWeight: FontWeight.bold),
                      ),
                      onPressed: _saveEntireDeck,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
