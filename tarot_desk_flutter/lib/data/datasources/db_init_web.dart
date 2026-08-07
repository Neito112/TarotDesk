// Implementation cho nền tảng Web
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Khởi tạo database factory cho Web
void initializeDatabaseFactory() {
  databaseFactory = databaseFactoryFfiWeb;
}
