import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../../core/constants/tarot_card_meanings.dart';
import '../models/tarot_card.dart';
import '../models/tarot_deck.dart';
import '../models/tarot_reading.dart';
import 'db_init_stub.dart' if (dart.library.html) 'db_init_web.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tarot_desk.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      // Web: dùng sqflite_common_ffi_web (khởi tạo qua conditional import)
      initializeDatabaseFactory();
      return await openDatabase(
        filePath,
        version: 5,
        onCreate: _createDB,
        onUpgrade: (db, oldVersion, newVersion) async {
          await db.execute('DROP TABLE IF EXISTS TarotReadings');
          await db.execute('DROP TABLE IF EXISTS TarotCards');
          await db.execute('DROP TABLE IF EXISTS TarotDecks');
          await _createDB(db, newVersion);
        },
      );
    }

    // Desktop/Mobile: dùng sqflite_common_ffi
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path;
    try {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, filePath);
    } catch (_) {
      path = inMemoryDatabasePath;
    }

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        // Xóa toàn bộ DB cũ và tạo lại với bộ bài 78 lá đầy đủ
        await db.execute('DROP TABLE IF EXISTS TarotReadings');
        await db.execute('DROP TABLE IF EXISTS TarotCards');
        await db.execute('DROP TABLE IF EXISTS TarotDecks');
        await _createDB(db, newVersion);
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Tạo bảng TarotDecks (Lưu trữ các Bộ bài)
    await db.execute('''
      CREATE TABLE TarotDecks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_date TEXT NOT NULL
      )
    ''');

    // 2. Tạo bảng TarotCards (Lưu trữ các Lá bài đi kèm nội dung giải nghĩa gộp)
    await db.execute('''
      CREATE TABLE TarotCards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        deck_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        meaning TEXT NOT NULL,
        image_path TEXT NOT NULL
      )
    ''');

    // 3. Tạo bảng TarotReadings (Lưu trữ lịch sử các Lượt trải bài)
    await db.execute('''
      CREATE TABLE TarotReadings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        deck_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        date TEXT NOT NULL,
        card_ids TEXT NOT NULL,
        is_reversed_list TEXT
      )
    ''');

    // Nạp sẵn Bộ bài Mặc định Tarot ĐẦY ĐỦ 78 LÁ Rider-Waite Chuẩn (Tiếng Việt)
    final defaultDeckId = await db.insert('TarotDecks', {
      'name': 'Bộ bài cơ bản',
      'created_date': DateTime.now().toIso8601String(),
    });

    await _seedDefaultCards(db, defaultDeckId);
  }

  /// Nạp danh sách 78 lá mặc định dưới dạng văn bản gộp cho một Deck
  Future<void> _seedDefaultCards(Database db, int deckId) async {
    final default78Cards = defaultTarotMeanings.entries.map((entry) {
      final key = entry.key;
      final data = entry.value;
      
      final meaningText = StringBuffer();
      final kwUpStr = data['keywords_up'] ?? '';
      final kwRevStr = data['keywords_rev'] ?? '';
      
      meaningText.writeln('TỪ KHÓA XUÔI: $kwUpStr');
      meaningText.writeln('TỪ KHÓA NGƯỢC: $kwRevStr');
      meaningText.writeln('\n=== Ý NGHĨA CHIỀU XUÔI ===');
      meaningText.writeln('TỔNG QUAN:\n${data['upright_general'] ?? ''}');
      if (data['upright_love'] != null && data['upright_love'].toString().isNotEmpty) {
        meaningText.writeln('\nTÌNH CẢM:\n${data['upright_love']}');
      }
      if (data['upright_career'] != null && data['upright_career'].toString().isNotEmpty) {
        meaningText.writeln('\nCÔNG VIỆC:\n${data['upright_career']}');
      }
      meaningText.writeln('\n=== Ý NGHĨA CHIỀU NGƯỢC ===');
      meaningText.writeln('TỔNG QUAN:\n${data['reversed_general'] ?? ''}');
      if (data['reversed_love'] != null && data['reversed_love'].toString().isNotEmpty) {
        meaningText.writeln('\nTÌNH CẢM:\n${data['reversed_love']}');
      }
      if (data['reversed_career'] != null && data['reversed_career'].toString().isNotEmpty) {
        meaningText.writeln('\nCÔNG VIỆC:\n${data['reversed_career']}');
      }

      return {
        'deck_id': deckId,
        'name': data['name'] ?? '',
        'meaning': meaningText.toString().trim(),
        'image_path': 'assets/images/$key.jpg',
      };
    }).toList();

    for (var card in default78Cards) {
      await db.insert('TarotCards', card);
    }
  }

  // ================= TarotDeck Operations =================
  Future<List<TarotDeckModel>> getDecks() async {
    final db = await instance.database;
    final result = await db.query('TarotDecks', orderBy: 'id DESC');
    return result.map((json) => TarotDeckModel.fromMap(json)).toList();
  }

  /// Lưu một Bộ bài mới cùng toàn bộ danh sách Lá bài đi kèm (Transaction)
  Future<int> insertFullDeckWithCards(TarotDeckModel deck, List<TarotCardModel> cards) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final deckId = await txn.insert('TarotDecks', deck.toMap());
      for (var card in cards) {
        final cardMap = card.toMap();
        cardMap['deck_id'] = deckId;
        await txn.insert('TarotCards', cardMap);
      }
      return deckId;
    });
  }

  Future<int> updateDeck(TarotDeckModel deck) async {
    final db = await instance.database;
    return await db.update(
      'TarotDecks',
      deck.toMap(),
      where: 'id = ?',
      whereArgs: [deck.id],
    );
  }

  Future<int> deleteDeck(int id) async {
    final db = await instance.database;
    await db.delete('TarotCards', where: 'deck_id = ?', whereArgs: [id]);
    return await db.delete('TarotDecks', where: 'id = ?', whereArgs: [id]);
  }

  // ================= TarotCard Operations =================
  Future<List<TarotCardModel>> getCardsByDeckId(int deckId) async {
    final db = await instance.database;
    var result = await db.query('TarotCards', where: 'deck_id = ?', whereArgs: [deckId]);
    
    // Fail-safe auto-seed: nếu vì lý do nào đó bộ bài cơ bản (ID=1) bị trống lá bài, tự động nạp lại
    if (result.isEmpty && deckId == 1) {
      await _seedDefaultCards(db, 1);
      result = await db.query('TarotCards', where: 'deck_id = ?', whereArgs: [deckId]);
    }
    
    return result.map((json) => TarotCardModel.fromMap(json)).toList();
  }

  Future<List<TarotCardModel>> getCardsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final db = await instance.database;
    final idString = ids.join(',');
    final result = await db.query(
      'TarotCards',
      where: 'id IN ($idString)',
    );
    return result.map((json) => TarotCardModel.fromMap(json)).toList();
  }

  Future<int> updateCard(TarotCardModel card) async {
    final db = await instance.database;
    return await db.update(
      'TarotCards',
      card.toMap(),
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  // ================= TarotReading Operations =================
  Future<int> insertReading(TarotReadingModel reading) async {
    final db = await instance.database;
    return await db.insert('TarotReadings', reading.toMap());
  }

  Future<List<TarotReadingModel>> getReadings() async {
    final db = await instance.database;
    final result = await db.query('TarotReadings', orderBy: 'id DESC');
    return result.map((json) => TarotReadingModel.fromMap(json)).toList();
  }

  Future<int> deleteReading(int id) async {
    final db = await instance.database;
    return await db.delete('TarotReadings', where: 'id = ?', whereArgs: [id]);
  }
}
