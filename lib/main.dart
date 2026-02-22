import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gains_and_guide/core/theme/app_theme.dart';
import 'package:gains_and_guide/features/home/presentation/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    // ProviderScope로 전체 앱 감싸기 (Riverpod 상태 관리)
    const ProviderScope(
      child: GainsGuideApp(),
    ),
  );
}

class GainsGuideApp extends StatelessWidget {
  const GainsGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gains & Guide',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const HomeScreen(), // 초기 화면: 홈 화면 (디자인 적용)
    );
  }
}
