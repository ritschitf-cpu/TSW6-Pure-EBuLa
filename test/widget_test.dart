import 'package:flutter_test/flutter_test.dart';
import 'package:tsw6_pure_ebula/main.dart';

void main() {
  testWidgets('Pure EBuLa main display starts', (tester) async {
    await tester.pumpWidget(const PureEBuLaApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('ICE 15'), findsOneWidget);
    expect(find.text('Zug'), findsOneWidget);
    expect(find.text('FSD'), findsOneWidget);
  });
}
