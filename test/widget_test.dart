import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 전체 [MyApp] 은 온보딩·DB·백그라운드 초기화에 의존하므로 위젯 스모크는 최소 셸만 검증한다.
void main() {
  testWidgets('ProviderScope + MaterialApp 셸', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Text('smoke'),
          ),
        ),
      ),
    );
    expect(find.text('smoke'), findsOneWidget);
  });
}
