import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:gains_and_guide/features/home/presentation/home_screen.dart';
import 'package:gains_and_guide/features/routine/presentation/program_selection_screen.dart';
import 'package:gains_and_guide/features/ai_coach/presentation/ai_coach_screen.dart';
import 'package:gains_and_guide/features/home/presentation/body_profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const androidConfig = FlutterBackgroundAndroidConfig(
    notificationTitle: "Gains & Guide",
    notificationText: "운동 타이머가 백그라운드에서 실행 중입니다.",
    notificationImportance: AndroidNotificationImportance.Default,
    notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
  );

  await FlutterBackground.initialize(androidConfig: androidConfig);
  await FlutterBackground.enableBackgroundExecution();

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
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ProgramSelectionScreen(),
    const AICoachScreen(),
    const BodyProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 💡 [핵심 수정] 기존의 body: _screens[_selectedIndex] 를 아래처럼 IndexedStack으로 감싸줍니다.
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF2563EB),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: '루틴'),
          BottomNavigationBarItem(icon: Icon(Icons.psychology), label: 'AI 코치'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '프로필'),
        ],
      ),
    );
  }
}
