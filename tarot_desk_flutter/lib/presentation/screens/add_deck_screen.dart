import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../data/models/tarot_card.dart';
import '../../logic/deck_provider.dart';
import '../../logic/settings_provider.dart';
import '../widgets/glass_panel.dart';

/// Màn hình Tạo Bộ Bài Mới & Nhập Từng Lá Bài Đầy Đủ
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

  /// Chọn hình ảnh lá bài từ thư viện
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

  /// Thêm lá bài vừa nhập vào danh sách nháp
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
        deckId: 0, // Sẽ được cập nhật khi lưu bộ bài
        name: name,
        meaning: meaning.isEmpty ? 'Chưa có giải nghĩa.' : meaning,
        imagePath: _selectedImagePath ?? 'assets/images/default_card.png',
      ));

      // Reset form nhập lá bài
      _cardNameController.clear();
      _cardMeaningController.clear();
      _selectedImagePath = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã thêm lá bài "$name"!')),
    );
  }

  /// Xóa 1 lá bài khỏi danh sách nháp
  void _removeCardFromDraft(int index) {
    setState(() {
      _draftCards.removeAt(index);
    });
  }

  /// Lưu toàn bộ bộ bài cùng danh sách các lá bài
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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentThemeData;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: const Text('Tạo Bộ Bài Tarot Mới'),
        backgroundColor: Colors.transparent,
        foregroundColor: theme.primaryColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // STEP 1: Nhập Tên Bộ Bài
                    GlassPanel(
                      backgroundColor: theme.cardBackgroundColor,
                      borderColor: theme.glassBorderColor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.collections, color: theme.primaryColor),
                              const SizedBox(width: 8),
                              Text(
                                '1. Đặt Tên Bộ Bài',
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _deckNameController,
                            style: TextStyle(color: theme.textColor),
                            decoration: InputDecoration(
                              labelText: 'Tên bộ bài',
                              labelStyle: TextStyle(color: theme.secondaryTextColor),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: theme.glassBorderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: theme.primaryColor),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // STEP 2: Nhập Chi Tiết Lá Bài (Không chứa ví dụ và giải nghĩa rườm rà)
                    GlassPanel(
                      backgroundColor: theme.cardBackgroundColor,
                      borderColor: theme.glassBorderColor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.add_photo_alternate, color: theme.accentColor),
                              const SizedBox(width: 8),
                              Text(
                                '2. Thêm Lá Bài',
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Khung Chọn / Xem trước Hình Ảnh Lá Bài
                          GestureDetector(
                            onTap: _pickCardImage,
                            child: Container(
                              height: 140,
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.primaryColor.withOpacity(0.5)),
                              ),
                              child: _selectedImagePath != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: kIsWeb
                                          ? Image.network(_selectedImagePath!, fit: BoxFit.cover, width: double.infinity)
                                          : Image.file(File(_selectedImagePath!), fit: BoxFit.cover, width: double.infinity),
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_a_photo, color: theme.primaryColor, size: 36),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Chọn ảnh',
                                          style: TextStyle(color: theme.secondaryTextColor, fontSize: 13),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Tên Lá Bài
                          TextField(
                            controller: _cardNameController,
                            style: TextStyle(color: theme.textColor),
                            decoration: InputDecoration(
                              labelText: 'Tên lá bài',
                              labelStyle: TextStyle(color: theme.secondaryTextColor),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: theme.glassBorderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: theme.primaryColor),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Nội dung / Ý nghĩa Lá Bài
                          TextField(
                            controller: _cardMeaningController,
                            maxLines: 5,
                            style: TextStyle(color: theme.textColor),
                            decoration: InputDecoration(
                              labelText: 'Nội dung giải nghĩa',
                              labelStyle: TextStyle(color: theme.secondaryTextColor),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: theme.glassBorderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: theme.primaryColor),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Nút Thêm vào bộ bài (không có icon trùng trong text)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.accentColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Thêm Lá Bài Vào Bộ Bài'),
                              onPressed: _addCardToDraft,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // STEP 3: Danh Sách Lá Bài Đã Nhập
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Danh sách lá bài đã nhập (${_draftCards.length}):',
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_draftCards.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _draftCards.clear();
                              });
                            },
                            child: const Text('Xóa Tất Cả', style: TextStyle(color: Colors.redAccent)),
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
                            style: TextStyle(color: theme.secondaryTextColor, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _draftCards.length,
                        itemBuilder: (context, index) {
                          final card = _draftCards[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: GlassPanel(
                              backgroundColor: theme.cardBackgroundColor,
                              borderColor: theme.glassBorderColor,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: card.imagePath.startsWith('assets')
                                      ? Icon(Icons.auto_stories, color: theme.primaryColor)
                                      : ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: kIsWeb
                                              ? Image.network(card.imagePath, fit: BoxFit.cover)
                                              : Image.file(File(card.imagePath), fit: BoxFit.cover),
                                        ),
                                ),
                                title: Text(
                                  '${index + 1}. ${card.name}',
                                  style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  card.meaning,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                  onPressed: () => _removeCardFromDraft(index),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            // FOOTER ACTION BUTTON: Lưu Toàn Bộ Bộ Bài (không dùng emoji trùng với icon)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.black,
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.save, size: 24),
                  label: Text(
                    'LƯU TOÀN BỘ BỘ BÀI (${_draftCards.length} LÁ)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _saveEntireDeck,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
