import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_desk_flutter/main.dart';

void main() {
  testWidgets('Kiểm thử render TarotDeskApp thành công', (WidgetTester tester) async {
    await tester.pumpWidget(const TarotDeskApp());
    expect(find.text('TarotDesk'), findsWidgets);
  });
}
