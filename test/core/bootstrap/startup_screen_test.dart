import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/core/bootstrap/startup_screen.dart';

void main() {
  testWidgets('StartupScreen shows app name, icon, progress, and step text',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StartupScreen(
          message: '운동 데이터 준비 중...',
          progress: 0.4,
        ),
      ),
    );

    expect(find.text('Gains & Guide'), findsOneWidget);
    expect(find.text('운동 데이터 준비 중...'), findsOneWidget);
    expect(find.byIcon(Icons.fitness_center), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('AppLoadingSplash shows circular progress', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppLoadingSplash()),
    );

    expect(find.text('Gains & Guide'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
