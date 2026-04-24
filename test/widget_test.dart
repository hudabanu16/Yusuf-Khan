import 'package:flutter_test/flutter_test.dart';

import 'package:QUIK/main.dart';

void main() {
  testWidgets('QUiK ERP app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const QuikApp());
    await tester.pump();

    expect(find.text('QUiK ERP'), findsWidgets);
  });
}
