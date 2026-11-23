import 'package:flutter/material.dart';

/// Interface cho Router của TarotDesk — để các màn hình điều hướng
/// qua Router mà không cần import file delegate (tránh import vòng
/// với tarot_router.dart, vì delegate import các màn hình).
///
/// (Bản §19 — MaterialApp.router đầy đủ: Router quản lý stack
/// trang theo URL nên nút Forward của trình duyệt / chuột gaming
/// mới chạy được. Mọi màn hình đều đi qua tarotPush thay cho
/// Navigator.pushNamed.)
abstract class TarotRouter {
  /// Đẩy một trang mới (theo URL) lên stack. Trả về Future hoàn
  /// thành với kết quả khi trang được pop.
  Future<T?> push<T>(String path);

  /// Pop trang hiện tại. Kết quả được trả về cho Future của push().
  void pop<T>([T? result]);
}

/// Đẩy một trang mới (theo URL) lên stack của Router. Trả về kết
/// quả khi trang được pop (như Navigator.pushNamed<T>).
Future<T?> tarotPush<T>(BuildContext context, String path) {
  final delegate = Router.of(context).routerDelegate;
  return (delegate as TarotRouter).push<T>(path);
}

/// Pop trang hiện tại (như Navigator.pop).
void tarotPop<T>(BuildContext context, [T? result]) {
  final delegate = Router.of(context).routerDelegate;
  (delegate as TarotRouter).pop<T>(result);
}
