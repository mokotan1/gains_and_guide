import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/routine/presentation/program_selection_screen.dart';
import 'features/ai_coach/presentation/ai_coach_screen.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gains & Guide',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black),
          bodyMedium: TextStyle(color: Colors.black),
          titleLarge: TextStyle(color: Colors.black),
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 2.0,
          surfaceTintColor: Colors.white,
        ),
      ),
      // HomeScreen 대신 하단 탭이 포함된 MainScreen을 호출합니다.
      home: const MainScreen(),
    );
  }
}

// 하단 탭 네비게이션을 관리하는 새로운 위젯
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // 전환할 화면 목록
  final List<Widget> _screens = [
    const HomeScreen(),
    const ProgramSelectionScreen(),
    const AICoachScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF2563EB),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: '루틴'),
          BottomNavigationBarItem(icon: Icon(Icons.psychology), label: 'AI 코치'),
        ],
      ),
    );
  }
}