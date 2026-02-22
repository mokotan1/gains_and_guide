import 'package:flutter/material.dart';

class AppTheme {
  // 다크 모드 (Gains & Guide 메인 테마)
  static final darkTheme = ThemeData.dark().copyWith(
    primaryColor: const Color(0xFF6200EE), // 보라색
    scaffoldBackgroundColor: const Color(0xFF121212), // 찐 검정
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFBB86FC),
      secondary: Color(0xFF03DAC6),
      surface: Color(0xFF1E1E1E),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1F1F1F),
      elevation: 0,
    ),
  );

  // 라이트 모드 (낮 운동용)
  static final lightTheme = ThemeData.light().copyWith(
    primaryColor: const Color(0xFF6200EE),
    scaffoldBackgroundColor: Colors.white,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF6200EE),
      secondary: Color(0xFF018786),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF6200EE),
      elevation: 0,
    ),
  );
}
