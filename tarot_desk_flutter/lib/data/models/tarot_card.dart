import 'dart:convert';

/// Model đại diện cho một lá bài Tarot
class TarotCardModel {
  final int? id;
  final int deckId;
  final String name;
  final String meaning;
  final String imagePath;

  TarotCardModel({
    this.id,
    required this.deckId,
    required this.name,
    required this.meaning,
    required this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'deck_id': deckId,
      'name': name,
      'meaning': meaning,
      'image_path': imagePath,
    };
  }

  factory TarotCardModel.fromMap(Map<String, dynamic> map) {
    return TarotCardModel(
      id: map['id'] as int?,
      deckId: map['deck_id'] as int,
      name: map['name'] as String? ?? '',
      meaning: map['meaning'] as String? ?? '',
      imagePath: map['image_path'] as String? ?? '',
    );
  }
}

extension TarotCardMeaningExtension on TarotCardModel {
  Map<String, dynamic>? get _decodedMeaning {
    try {
      final decoded = jsonDecode(meaning);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  bool get isDetailed => _decodedMeaning != null;

  String get keywordsUp {
    final decoded = _decodedMeaning;
    if (decoded != null) {
      final kw = decoded['keywords_up'];
      if (kw is List) return kw.join(', ');
      return kw?.toString() ?? '';
    }
    return '';
  }

  String get keywordsRev {
    final decoded = _decodedMeaning;
    if (decoded != null) {
      final kw = decoded['keywords_rev'];
      if (kw is List) return kw.join(', ');
      return kw?.toString() ?? '';
    }
    return '';
  }

  String get uprightGeneral => _decodedMeaning?['upright_general'] as String? ?? meaning;
  String get uprightLove => _decodedMeaning?['upright_love'] as String? ?? '';
  String get uprightCareer => _decodedMeaning?['upright_career'] as String? ?? '';

  String get reversedGeneral => _decodedMeaning?['reversed_general'] as String? ?? meaning;
  String get reversedLove => _decodedMeaning?['reversed_love'] as String? ?? '';
  String get reversedCareer => _decodedMeaning?['reversed_career'] as String? ?? '';
}

