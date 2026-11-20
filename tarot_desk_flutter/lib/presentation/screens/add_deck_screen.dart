import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../data/models/tarot_card.dart';
import '../../logic/deck_provider.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';

/// Màn hình Tạo Bộ Bài Mới & Nhập Từng Lá Bài Đầy Đủ
/// Bố cục: mobile-first Android (1 cột), iPad/PC (Bước 1 + Bước 2 cạnh nhau,
/// danh sách lá bài nháp 2 cột, nội dung căn giữa, rộng tối đa theo
/// Responsive.maxContentWidth). Logic, provider và text tiếng Việt giữ nguyên.
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
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể mở thư viện ảnh: $e')),
      );
    }
  }

  void _addCardToDraft() {
    final name = _cardNameController.text.trim();
    final meaning = _cardMeaningController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập Tên lá bài!')),
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
      SnackBar(content: Text('Đã thêm lá bài "$name"!')),
    );
  }

  void _removeCardFromDraft(int index) {
    setState(() {
      _draftCards.removeAt(index);
    });
  }

  Future<void> _saveEntireDeck() async {
    final deckName = _deckNameController.text.trim();
    if (deckName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập Tên bộ bài!')),
      );
      return;
    }

    if (_draftCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng thêm ít nhất 1 lá bài trước khi lưu!')),
      );
      return;
    }

    final deckProvider = context.read<DeckProvider>();
    await deckProvider.createFullDeckWithCards(deckName, _draftCards);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã lưu bộ bài "$deckName"!')),
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

  Widget _step1Panel(dynamic theme, bool isDesktop) {
    return GlassPanel(
      backgroundColor: theme.cardBackgroundColor,
      borderColor: theme.glassBorderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(theme,
              icon: Icons.collections,
              iconColor: theme.primaryColor,
              title: '1. Đặt Tên Bộ Bài',
              isDesktop: isDesktop),
          const SizedBox(height: 12),
          TextField(
            controller: _deckNameController,
            style: TextStyle(color: theme.textColor),
            decoration: _fieldDecoration(theme, 'Tên bộ bài'),
          ),
        ],
      ),
    );
  }

  Widget _step2Panel(BuildContext context, dynamic theme, bool isDesktop) {
    final imageHeight = Responsive.isPhone(context) ? 140.0 : 180.0;
    return GlassPanel(
      backgroundColor: theme.cardBackgroundColor,
      borderColor: theme.glassBorderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(theme,
              icon: Icons.add_photo_alternate,
              iconColor: theme.accentColor,
              title: '2. Thêm Lá Bài',
              isDesktop: isDesktop),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickCardImage,
            child: Container(
              height: imageHeight,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: theme.primaryColor.withOpacity(0.5)),
              ),
              child: _selectedImagePath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: kIsWeb
                          ? Image.network(_selectedImagePath!,
                              fit: BoxFit.contain, width: double.infinity)
                          : Image.file(File(_selectedImagePath!),
                              fit: BoxFit.contain, width: double.infinity),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo,
                            color: theme.primaryColor, size: 36),
                        const SizedBox(height: 8),
                        Text(
                          'Chọn ảnh',
                          style: TextStyle(
                              color: theme.secondaryTextColor, fontSize: 13),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cardNameController,
            style: TextStyle(color: theme.textColor),
            decoration: _fieldDecoration(theme, 'Tên lá bài'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cardMeaningController,
            maxLines: 5,
            style: TextStyle(color: theme.textColor),
            decoration: _fieldDecoration(theme, 'Nội dung giải nghĩa'),
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
                'Thêm Lá Bài Vào Bộ Bài',
                style: TextStyle(fontSize: isDesktop ? 13 : 14),
              ),
              onPressed: _addCardToDraft,
            ),
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
                      Text(
                        '${index + 1}. ${card.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        card.meaning,
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
          'Tạo Bộ Bài Tarot Mới',
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
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _step1Panel(theme, isDesktop)),
                            const SizedBox(width: 16),
                            Expanded(
                                child:
                                    _step2Panel(context, theme, isDesktop)),
                          ],
                        )
                      else ...[
                        _step1Panel(theme, isDesktop),
                        const SizedBox(height: 20),
                        _step2Panel(context, theme, isDesktop),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Danh sách lá bài đã nhập (${_draftCards.length}):',
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
                              child: const Text('Xóa Tất Cả',
                                  style:
                                      TextStyle(color: Colors.redAccent)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_draftCards.isEmpty)
                        GlassPanel(
                          backgroundColor: theme.cardBackgroundColor,
                          borderColor: theme.glassBorderColor,
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'Chưa có lá bài nào được thêm.',
                              style: TextStyle(
                                  color: theme.secondaryTextColor,
                                  fontSize: 13),
                            ),
                          ),
                        )
                      else
                        // Danh sách lá nháp là lưới thẻ 5:8 như lá bài
                        // trên bàn trải: 2 cột điện thoại, 3 iPad, 4 PC.
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: Responsive.gridColumns(context),
                            crossAxisSpacing: isDesktop ? 10 : 12,
                            mainAxisSpacing: isDesktop ? 10 : 12,
                            childAspectRatio: 5 / 8,
                          ),
                          itemCount: _draftCards.length,
                          itemBuilder: (context, index) => _draftCardItem(
                              theme, _draftCards[index], index),
                        ),
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
                        'LƯU TOÀN BỘ BỘ BÀI (${_draftCards.length} LÁ)',
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
