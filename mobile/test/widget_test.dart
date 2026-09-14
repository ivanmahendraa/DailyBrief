import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('DailyBrief smoke test renders app title and tagline',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DailyBriefApp());

    expect(find.text('DailyBrief'), findsOneWidget);
    expect(find.text('Temukan Informasi dalam Satu Sentuhan'), findsOneWidget);
  });
}
