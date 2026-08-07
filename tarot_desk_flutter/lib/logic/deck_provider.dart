import 'package:flutter/material.dart';
import '../data/datasources/database_helper.dart';
import '../data/models/tarot_card.dart';
import '../data/models/tarot_deck.dart';

class DeckProvider extends ChangeNotifier {
  List<TarotDeckModel> _decks = [];
  List<TarotCardModel> _currentDeckCards = [];
  TarotDeckModel? _selectedDeck;
  bool _isLoading = false;

  List<TarotDeckModel> get decks => _decks;
  List<TarotCardModel> get currentDeckCards => _currentDeckCards;
  TarotDeckModel? get selectedDeck => _selectedDeck;
  bool get isLoading => _isLoading;

  Future<void> fetchDecks() async {
    _isLoading = true;
    notifyListeners();

    _decks = await DatabaseHelper.instance.getDecks();
    if (_decks.isNotEmpty && _selectedDeck == null) {
      _selectedDeck = _decks.first;
      await fetchCardsForSelectedDeck();
    }

    _isLoading = false;
    notifyListeners();
  }

  void selectDeck(TarotDeckModel deck) async {
    _selectedDeck = deck;
    notifyListeners();
    await fetchCardsForSelectedDeck();
  }

  Future<void> fetchCardsForSelectedDeck() async {
    if (_selectedDeck == null || _selectedDeck!.id == null) return;
    _currentDeckCards = await DatabaseHelper.instance.getCardsByDeckId(_selectedDeck!.id!);
    notifyListeners();
  }

  /// Tạo trọn bộ bài mới cùng danh sách lá bài đi kèm
  Future<void> createFullDeckWithCards(String deckName, List<TarotCardModel> cards) async {
    _isLoading = true;
    notifyListeners();

    final newDeck = TarotDeckModel(name: deckName, createdDate: DateTime.now());
    final newDeckId = await DatabaseHelper.instance.insertFullDeckWithCards(newDeck, cards);

    await fetchDecks();

    // Chọn ngay bộ bài vừa tạo
    final createdDeck = _decks.firstWhere((d) => d.id == newDeckId, orElse: () => newDeck);
    selectDeck(createdDeck);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteDeck(int id) async {
    await DatabaseHelper.instance.deleteDeck(id);
    if (_selectedDeck?.id == id) {
      _selectedDeck = null;
      _currentDeckCards = [];
    }
    await fetchDecks();
  }

  Future<void> updateDeckName(int deckId, String newName) async {
    final index = _decks.indexWhere((d) => d.id == deckId);
    if (index == -1) return;

    final deck = _decks[index];
    final updatedDeck = TarotDeckModel(
      id: deck.id,
      name: newName,
      createdDate: deck.createdDate,
    );

    await DatabaseHelper.instance.updateDeck(updatedDeck);

    if (_selectedDeck?.id == deckId) {
      _selectedDeck = updatedDeck;
    }

    await fetchDecks();
  }
}
