import 'package:flutter_test/flutter_test.dart';
import 'package:tsw6_pure_ebula/main.dart';

void main() {
  testWidgets('Pure EBuLa splash starts', (tester) async {
    await tester.pumpWidget(const PureEBuLaApp());
    expect(find.text('EBuLa'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
