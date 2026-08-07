// Stub cho nền tảng non-web (desktop/mobile)
// File này được dùng khi KHÔNG chạy trên web
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Khởi tạo database factory cho nền tảng non-web
void initializeDatabaseFactory() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}
