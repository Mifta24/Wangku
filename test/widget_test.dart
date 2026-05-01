import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Wangku smoke test renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Wangku')),
        ),
      ),
    );

    expect(find.text('Wangku'), findsOneWidget);
  });
}
