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
/// Hai chế độ: sửa lá đã có (EditCardScreen(card: ...)) và tạo lá
/// MỚI trong một bộ đã có (EditCardScreen.create(deckId: ...),
/// dùng từ kho bộ bài → chi tiết bộ → nút +).
class EditCardScreen extends StatefulWidget {
  /// Lá cần sửa; null = tạo lá mới trong bộ `deckId`.
  final TarotCardModel? card;
  final int deckId;

  // KHÔNG const: `deckId = card.deckId` không phải biểu thức hằng
  // (truy cập trường của tham số) nên constructor này không thể
  // const — để const là build web gãy ("Not a constant expression").
  EditCardScreen({Key? key, required TarotCardModel card})
      : card = card,
        deckId = card.deckId;

  /// Tạo lá bài MỚI trong bộ bài `deckId` (từ kho bộ bài).
  const EditCardScreen.create({Key? key, required this.deckId})
      : card = null;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể mở thư viện ảnh: $e')),
      );
    }
  }

  Future<void> _saveCard() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tên lá bài không được để trống!')),
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
        deckId: widget.card!.deckId,
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
                ? 'Đã thêm lá bài "$name" vào bộ bài!'
                : 'Đã cập nhật thông tin lá bài thành công!')),
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
          isNew ? 'Thêm Lá Bài Mới' : 'Sửa Lá Bài: ${widget.card!.name}',
          style: TextStyle(fontSize: isDesktop ? 16 : 20),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: theme.primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Lưu thay đổi',
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
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, color: Colors.amberAccent, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Đổi Ảnh',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
              _buildSectionTitle('Tên lá bài', theme),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: TextStyle(color: theme.textColor),
                decoration: _buildInputDecoration('Nhập tên lá bài...', theme),
              ),
              const SizedBox(height: 20),

              // Ý nghĩa dạng văn bản gộp duy nhất
              _buildSectionTitle('Nội dung giải nghĩa (toàn bộ)', theme),
              const SizedBox(height: 8),
              TextField(
                controller: _meaningController,
                style: TextStyle(color: theme.textColor),
                maxLines: 15,
                decoration: _buildInputDecoration('Nhập toàn bộ nội dung giải nghĩa của lá bài tại đây...', theme),
              ),
              const SizedBox(height: 32),

              // Button Lưu thay đổi ở cuối (PC gọn: cao ~40).
              ElevatedButton.icon(
                onPressed: _saveCard,
                icon: const Icon(Icons.save, color: Colors.black87),
                label: Text(
                  isNew ? 'Thêm Lá Bài' : 'Lưu Thay Đổi',
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
