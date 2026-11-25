/// Model đại diện cho một bộ bài Tarot
class TarotDeckModel {
  final int? id;
  final String name;
  final DateTime createdDate;
  // Ảnh mặt lưng của bộ bài (được up kèm khi tạo bộ bài). Xấp bài
  // trên bàn trải sẽ hiển thị ảnh này (scale khớp vào khung xấp
  // mặc định); nếu bộ bài chưa có ảnh lưng thì dùng ảnh lưng mặc
  // định (assets/images/deck_back_default.png).
  final String? backImageUrl;

  TarotDeckModel({
    this.id,
    required this.name,
    required this.createdDate,
    this.backImageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'created_date': createdDate.toIso8601String(),
      if (backImageUrl != null) 'back_image_url': backImageUrl,
    };
  }

  factory TarotDeckModel.fromMap(Map<String, dynamic> map) {
    return TarotDeckModel(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      createdDate: DateTime.tryParse(map['created_date'] as String? ?? '') ?? DateTime.now(),
      backImageUrl: map['back_image_url'] as String?,
    );
  }
}
