import 'package:flutter/material.dart';

class AppTheme {
  // 앱 전체에서 사용할 공통 색상 상수
  static const primaryBlue = Color(0xFF2563EB);
  static const backgroundGray = Color(0xFFF3F4F6);
  static const successGreen = Colors.green;
  static const warningOrange = Colors.orange;

  // --- Light Theme (밝은 테마) ---
  static final lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: backgroundGray,
    primaryColor: primaryBlue,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBlue,
      primary: primaryBlue,
      surface: Colors.white,
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: Colors.black),
      bodyMedium: TextStyle(color: Colors.black87),
    ),
    // [수정된 부분] CardTheme -> CardThemeData
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      surfaceTintColor: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: Colors.black),
    ),
  );

  // --- Dark Theme (어두운 테마) ---
  static final darkTheme = ThemeData.dark().copyWith(
    useMaterial3: true,
    primaryColor: primaryBlue,
    scaffoldBackgroundColor: const Color(0xFF121212),
    colorScheme: const ColorScheme.dark(
      primary: primaryBlue,
      secondary: Color(0xFF03DAC6),
      surface: Color(0xFF1E1E1E),
    ),
    // 다크 모드에서도 카드 스타일을 맞추고 싶다면 아래를 추가하세요
    cardTheme: CardThemeData(
      color: const Color(0xFF1E1E1E),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      surfaceTintColor: Colors.transparent,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1F1F1F),
      elevation: 0,
    ),
  );
}