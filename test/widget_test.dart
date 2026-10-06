import 'package:flutter_test/flutter_test.dart';

import 'package:cmmr/main.dart';

void main() {
  testWidgets('shows the video cutter entry state', (tester) async {
    await tester.pumpWidget(const CmmrApp());

    expect(find.text('CMMR Cut'), findsOneWidget);
    expect(find.text('İki türlü kırp.'), findsOneWidget);
    expect(find.text('Video seç'), findsOneWidget);
  });
}
