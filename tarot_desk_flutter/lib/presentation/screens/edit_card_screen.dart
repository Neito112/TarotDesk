import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../data/datasources/database_helper.dart';
import '../../data/models/tarot_card.dart';
import '../../logic/deck_provider.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';
import '../widgets/tarot_card_image.dart';

/// Màn hình Chỉnh sửa thông tin giải nghĩa và hình ảnh của một lá bài (Tối giản theo dạng Text thuần).
/// Hai chế độ, MỘT constructor duy nhất:
/// - Sửa lá đã có: EditCardScreen(card: lá, deckId: lá.deckId).
/// - Tạo lá MỚI trong một bộ đã có: EditCardScreen(deckId: idBộ)
///   (để `card` null), dùng từ kho bộ bài → chi tiết bộ → nút +.
/// `deckId` luôn do bên gọi truyền thẳng — không suy ra từ `card`
/// trong initializer (cách cũ dùng hai constructor + `deckId =
/// card.deckId` trong const nên build web gãy), nên constructor
/// này const được và không còn lỗi.
class EditCardScreen extends StatefulWidget {
  /// Lá cần sửa; null = tạo lá mới trong bộ `deckId`.
  final TarotCardModel? card;
  final int deckId;

  const EditCardScreen({Key? key, this.card, required this.deckId});

  @override
  State<EditCardScreen> createState() => _EditCardScreenState();
}

class _EditCardScreenState extends State<EditCardScreen> {
  final _nameController = TextEditingController();
  final _meaningController = TextEditingController();
  String? _selectedImagePath;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.card?.name ?? '';
    _meaningController.text = widget.card?.meaning ?? '';
    _selectedImagePath = widget.card?.imagePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _meaningController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
        });
      }
    } catch (e) {
      final settings = context.read<SettingsProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(settings
                .tr('editCard.imagePickerError')
                .replaceAll('{error}', '$e'))),
      );
    }
  }

  Future<void> _saveCard() async {
    final settings = context.read<SettingsProvider>();
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.tr('editCard.nameEmpty'))),
      );
      return;
    }

    final isNew = widget.card?.id == null;
    if (isNew) {
      // Tạo lá MỚI trong bộ đã có (kho bộ bài → chi tiết bộ → +).
      await DatabaseHelper.instance.insertCard(TarotCardModel(
        deckId: widget.deckId,
        name: name,
        meaning: _meaningController.text.trim(),
        imagePath: _selectedImagePath ?? '',
      ));
    } else {
      final updatedCard = TarotCardModel(
        id: widget.card!.id,
        deckId: widget.deckId,
        name: name,
        meaning: _meaningController.text.trim(),
        imagePath: _selectedImagePath ?? widget.card!.imagePath,
      );

      await DatabaseHelper.instance.updateCard(updatedCard);
    }

    // Refresh provider
    final deckProvider = context.read<DeckProvider>();
    if (deckProvider.selectedDeck?.id == widget.deckId) {
      await deckProvider.fetchCardsForSelectedDeck();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isNew
                ? settings
                    .tr('editCard.added')
                    .replaceAll('{name}', name)
                : settings.tr('editCard.updated'))),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentThemeData;
    final isDesktop = Responsive.isDesktop(context);
    final isNew = widget.card == null;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        toolbarHeight: isDesktop ? 48 : null,
        title: Text(
          isNew
              ? settings.tr('editCard.titleNew')
              : settings
                  .tr('editCard.titleEdit')
                  .replaceAll('{name}', widget.card!.name),
          style: TextStyle(fontSize: isDesktop ? 16 : 20),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: theme.primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: settings.tr('editCard.saveTooltip'),
            onPressed: _saveCard,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Xem trước hình ảnh & Nút thay ảnh
              Center(
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      width: 130,
                      height: 210,
                      decoration: BoxDecoration(
                        // Nền đen: ảnh lá hiện trọn (contain), không cắt.
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.primaryColor, width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, spreadRadius: 2)
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _selectedImagePath != null
                            ? TarotCardImage(
                                card: TarotCardModel(
                                  deckId: widget.deckId,
                                  name: '',
                                  meaning: '',
                                  imagePath: _selectedImagePath!,
                                ),
                                fit: BoxFit.contain,
                              )
                            : const Icon(Icons.auto_stories, size: 50, color: Colors.white24),
                      ),
                    ),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 130,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black87.withOpacity(0.7),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(14),
                            bottomRight: Radius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.camera_alt, color: Colors.amberAccent, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              settings.tr('editCard.changeImage'),
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Form chỉnh sửa Tên
              _buildSectionTitle(settings.tr('editCard.cardNameLabel'), theme),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: TextStyle(color: theme.textColor),
                decoration: _buildInputDecoration(settings.tr('editCard.cardNameHint'), theme),
              ),
              const SizedBox(height: 20),

              // Ý nghĩa dạng văn bản gộp duy nhất
              _buildSectionTitle(settings.tr('editCard.meaningLabel'), theme),
              const SizedBox(height: 8),
              TextField(
                controller: _meaningController,
                style: TextStyle(color: theme.textColor),
                maxLines: 15,
                decoration: _buildInputDecoration(settings.tr('editCard.meaningHint'), theme),
              ),
              const SizedBox(height: 32),

              // Button Lưu thay đổi ở cuối (PC gọn: cao ~40).
              ElevatedButton.icon(
                onPressed: _saveCard,
                icon: const Icon(Icons.save, color: Colors.black87),
                label: Text(
                  isNew
                      ? settings.tr('editCard.addButton')
                      : settings.tr('editCard.saveButton'),
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: isDesktop ? 14 : 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  padding: EdgeInsets.symmetric(vertical: isDesktop ? 10 : 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, dynamic theme) {
    return Text(
      title,
      style: TextStyle(color: theme.primaryColor, fontSize: 15, fontWeight: FontWeight.bold),
    );
  }

  InputDecoration _buildInputDecoration(String hint, dynamic theme) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: theme.secondaryTextColor.withOpacity(0.7)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.03),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.primaryColor),
      ),
    );
  }
}
