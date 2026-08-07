/// Model đại diện cho một bộ bài Tarot
class TarotDeckModel {
  final int? id;
  final String name;
  final DateTime createdDate;

  TarotDeckModel({
    this.id,
    required this.name,
    required this.createdDate,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'created_date': createdDate.toIso8601String(),
    };
  }

  factory TarotDeckModel.fromMap(Map<String, dynamic> map) {
    return TarotDeckModel(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      createdDate: DateTime.tryParse(map['created_date'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
