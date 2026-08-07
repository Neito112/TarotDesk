import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_desk_flutter/core/constants/tarot_symbols.dart';
import 'package:tarot_desk_flutter/data/models/tarot_card.dart';
import 'package:tarot_desk_flutter/data/models/tarot_deck.dart';

void main() {
  group('Kiểm thử TarotSymbols', () {
    test('Lấy đúng biểu tượng Tarot chuẩn cho các chất bài', () {
      expect(TarotSymbols.getSymbol('gậy'), TarotSymbols.wands);
      expect(TarotSymbols.getSymbol('wands'), TarotSymbols.wands);
      expect(TarotSymbols.getSymbol('cốc'), TarotSymbols.cups);
      expect(TarotSymbols.getSymbol('cups'), TarotSymbols.cups);
      expect(TarotSymbols.getSymbol('kiếm'), TarotSymbols.swords);
      expect(TarotSymbols.getSymbol('xu'), TarotSymbols.pentacles);
    });

    test('Lấy đúng tên Tiếng Việt chuẩn', () {
      expect(TarotSymbols.getVietnameseName('wands'), TarotSymbols.wandsNameVi);
      expect(TarotSymbols.getVietnameseName('cups'), TarotSymbols.cupsNameVi);
    });
  });

  group('Kiểm thử TarotCardModel & TarotDeckModel', () {
    test('Chuyển đổi toMap và fromMap khớp dữ liệu lá bài', () {
      final card = TarotCardModel(
        id: 1,
        deckId: 10,
        name: 'The Fool (Chàng Khờ)',
        meaning: 'Khởi đầu mới và tự do',
        imagePath: 'assets/images/fool.png',
      );

      final map = card.toMap();
      final restored = TarotCardModel.fromMap(map);

      expect(restored.id, 1);
      expect(restored.deckId, 10);
      expect(restored.name, 'The Fool (Chàng Khờ)');
      expect(restored.meaning, 'Khởi đầu mới và tự do');
    });

    test('Chuyển đổi toMap và fromMap khớp dữ liệu bộ bài', () {
      final deck = TarotDeckModel(
        id: 5,
        name: 'Bộ Bài Tarot Mặt Trời',
        createdDate: DateTime(2026, 8, 3),
      );

      final map = deck.toMap();
      final restored = TarotDeckModel.fromMap(map);

      expect(restored.id, 5);
      expect(restored.name, 'Bộ Bài Tarot Mặt Trời');
    });
  });
}
