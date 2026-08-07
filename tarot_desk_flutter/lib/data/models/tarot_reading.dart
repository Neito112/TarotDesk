import 'dart:convert';

/// Model đại diện cho một lượt bói/trải bài Tarot
class TarotReadingModel {
  final int? id;
  final int deckId;
  final String name;
  final DateTime date;
  final List<int> cardIds;
  final List<bool> isReversedList; // Bổ sung chiều xuôi/ngược cho từng lá bài

  TarotReadingModel({
    this.id,
    required this.deckId,
    required this.name,
    required this.date,
    required this.cardIds,
    required this.isReversedList,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'deck_id': deckId,
      'name': name,
      'date': date.toIso8601String(),
      'card_ids': jsonEncode(cardIds),
      'is_reversed_list': jsonEncode(isReversedList),
    };
  }

  factory TarotReadingModel.fromMap(Map<String, dynamic> map) {
    List<int> parsedCardIds = [];
    final jsonStr = map['card_ids'] as String?;
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          parsedCardIds = decoded.map((e) => int.parse(e.toString())).toList();
        }
      } catch (_) {}
    }

    List<bool> parsedReversed = [];
    final revStr = map['is_reversed_list'] as String?;
    if (revStr != null && revStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(revStr);
        if (decoded is List) {
          parsedReversed = decoded.map((e) => e as bool).toList();
        }
      } catch (_) {}
    }
    // Fallback nếu thiếu (mặc định là xuôi)
    if (parsedReversed.length < parsedCardIds.length) {
      parsedReversed.addAll(List.generate(parsedCardIds.length - parsedReversed.length, (_) => false));
    }

    return TarotReadingModel(
      id: map['id'] as int?,
      deckId: map['deck_id'] as int,
      name: map['name'] as String? ?? 'Trải Bài Không Tên',
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      cardIds: parsedCardIds,
      isReversedList: parsedReversed,
    );
  }
}

