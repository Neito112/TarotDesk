/// Utility định nghĩa biểu tượng và tên các chất bài Tarot (bằng Tiếng Việt)
class TarotSymbols {
  static const String wands = '♣';
  static const String cups = '♥';
  static const String swords = '⚄';
  static const String pentacles = '🔮';

  static const String wandsNameVi = 'Gậy (Wands)';
  static const String cupsNameVi = 'Cốc (Cups)';
  static const String swordsNameVi = 'Kiếm (Swords)';
  static const String pentaclesNameVi = 'Xu (Pentacles)';

  /// Lấy biểu tượng tương ứng với tên chất bài (Tiếng Việt hoặc Tiếng Anh)
  static String getSymbol(String suit) {
    switch (suit.toLowerCase()) {
      case 'wands':
      case 'gậy':
        return wands;
      case 'cups':
      case 'cốc':
        return cups;
      case 'swords':
      case 'kiếm':
        return swords;
      case 'pentacles':
      case 'xu':
        return pentacles;
      default:
        return '🔮';
    }
  }

  /// Lấy tên Tiếng Việt chuẩn của bộ chất bài
  static String getVietnameseName(String suit) {
    switch (suit.toLowerCase()) {
      case 'wands':
      case 'gậy':
        return wandsNameVi;
      case 'cups':
      case 'cốc':
        return cupsNameVi;
      case 'swords':
      case 'kiếm':
        return swordsNameVi;
      case 'pentacles':
      case 'xu':
        return pentaclesNameVi;
      default:
        return suit;
    }
  }
}
