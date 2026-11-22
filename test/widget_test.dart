import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_pos/main.dart';

void main() {
  testWidgets('POS app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const PosRetailProApp());
  });
}
