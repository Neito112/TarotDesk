import 'dart:math';
import 'package:flutter/material.dart';
import '../data/datasources/database_helper.dart';
import '../data/models/tarot_card.dart';
import '../data/models/tarot_reading.dart';

class ReadingProvider extends ChangeNotifier {
  List<TarotReadingModel> _readingsHistory = [];
  List<TarotCardModel> _drawnCards = [];
  List<bool> _flippedStates = [];
  List<bool> _isReversedStates = []; // Thêm trạng thái xoay ngược của từng lá bài
  String _currentReadingTitle = 'Lượt Trải Bài Mới';
  bool _isLoading = false;

  List<TarotReadingModel> get readingsHistory => _readingsHistory;
  List<TarotCardModel> get drawnCards => _drawnCards;
  List<bool> get flippedStates => _flippedStates;
  List<bool> get isReversedStates => _isReversedStates;
  String get currentReadingTitle => _currentReadingTitle;
  bool get isLoading => _isLoading;

  Future<void> fetchReadingsHistory() async {
    _isLoading = true;
    notifyListeners();
    _readingsHistory = await DatabaseHelper.instance.getReadings();
    _isLoading = false;
    notifyListeners();
  }

  void startNewReading(String title, List<TarotCardModel> deckCards, {int cardCount = 3}) {
    _currentReadingTitle = title.isEmpty ? 'Lượt Trải Bài Mới' : title;
    _drawnCards.clear();
    _flippedStates.clear();
    _isReversedStates.clear();

    if (deckCards.isNotEmpty) {
      final random = Random();
      final tempCards = List<TarotCardModel>.from(deckCards)..shuffle(random);
      final count = tempCards.length < cardCount ? tempCards.length : cardCount;
      _drawnCards = tempCards.sublist(0, count);
      _flippedStates = List.generate(count, (_) => false);
      _isReversedStates = List.generate(count, (_) => false);
    }

    notifyListeners();
  }

  // Khởi tạo lượt trải bài trống để người dùng tự chọn thủ công
  void startManualReading(String title) {
    _currentReadingTitle = title.isEmpty ? 'Lượt Trải Bài Mới' : title;
    _drawnCards.clear();
    _flippedStates.clear();
    _isReversedStates.clear();
    notifyListeners();
  }

  // Thêm lá bài được chọn thủ công vào khay
  void addCardToReading(TarotCardModel card, {bool isReversed = false}) {
    _drawnCards.add(card);
    _flippedStates.add(true); // Mặc định hiển thị luôn
    _isReversedStates.add(isReversed);
    notifyListeners();
  }

  // Xóa lá bài khỏi khay bốc bài
  void removeCardFromReading(int index) {
    if (index >= 0 && index < _drawnCards.length) {
      _drawnCards.removeAt(index);
      _flippedStates.removeAt(index);
      _isReversedStates.removeAt(index);
      notifyListeners();
    }
  }

  // Đảo ngược chiều lá bài (Xuôi <-> Ngược)
  void toggleCardOrientation(int index) {
    if (index >= 0 && index < _isReversedStates.length) {
      _isReversedStates[index] = !_isReversedStates[index];
      notifyListeners();
    }
  }

  void flipCard(int index) {
    if (index >= 0 && index < _flippedStates.length) {
      _flippedStates[index] = !_flippedStates[index];
      notifyListeners();
    }
  }

  void updateTitle(String title) {
    _currentReadingTitle = title.isEmpty ? 'Lượt Trải Bài Mới' : title;
    notifyListeners();
  }

  Future<void> saveCurrentReading(int deckId) async {
    if (_drawnCards.isEmpty) return;

    final cardIds = _drawnCards.map((c) => c.id ?? 0).toList();
    final reading = TarotReadingModel(
      deckId: deckId,
      name: _currentReadingTitle,
      date: DateTime.now(),
      cardIds: cardIds,
      isReversedList: _isReversedStates,
    );

    await DatabaseHelper.instance.insertReading(reading);
    await fetchReadingsHistory();
  }

  Future<void> deleteReading(int readingId) async {
    await DatabaseHelper.instance.deleteReading(readingId);
    await fetchReadingsHistory();
  }
}

