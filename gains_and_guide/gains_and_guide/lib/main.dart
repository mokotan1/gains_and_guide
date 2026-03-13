import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:gains_and_guide/features/home/presentation/home_screen.dart';
import 'package:gains_and_guide/features/routine/presentation/program_selection_screen.dart';
import 'package:gains_and_guide/features/ai_coach/presentation/ai_coach_screen.dart';
import 'package:gains_and_guide/features/home/presentation/body_profile_screen.dart';
import 'package:gains_and_guide/core/database/database_helper.dart';
import 'package:gains_and_guide/features/exercise_catalog/infrastructure/exercise_catalog_repository_impl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initializeDatabase();

  // 💡 [핵심 수정] Default -> normal 로 변경하면 에러가 사라집니다.
  final androidConfig = FlutterBackgroundAndroidConfig(
    notificationTitle: "Gains & Guide",
    notificationText: "운동 타이머가 백그라운드에서 실행 중입니다.",
    notificationImportance: AndroidNotificationImportance.normal,
    notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
  );

  await FlutterBackground.initialize(androidConfig: androidConfig);
  await FlutterBackground.enableBackgroundExecution();

  runApp(const ProviderScope(child: MyApp()));
}

Future<void> _initializeDatabase() async {
  final catalogRepo = ExerciseCatalogRepositoryImpl(DatabaseHelper.instance);
  if (await catalogRepo.isEmpty()) {
    try {
      final String response = await rootBundle.loadString('assets/data/exercises.json');
      final data = await json.decode(response) as Map<String, dynamic>;
      final List<dynamic> exercisesJson = data['exercises'] as List<dynamic>;

      final List<Map<String, dynamic>> exercisesToSeed = exercisesJson.map((e) {
        final map = e as Map<String, dynamic>;
        return {
          'name': map['name'],
          'category': map['category'],
          'equipment': (map['equipment'] is List)
              ? (map['equipment'] as List).join(', ')
              : map['equipment'].toString(),
          'primary_muscles': (map['primary_muscles'] is List)
              ? (map['primary_muscles'] as List).join(', ')
              : map['primary_muscles'].toString(),
          'instructions': (map['instructions'] is List)
              ? (map['instructions'] as List).join('\n')
              : map['instructions'].toString(),
        };
      }).toList();

      await catalogRepo.seed(exercisesToSeed);
      debugPrint('운동 카탈로그 시딩 완료: ${exercisesToSeed.length}개 운동');
    } catch (e) {
      debugPrint('운동 카탈로그 시딩 실패: $e');
    }
  }
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
        // 💡 [확인] 이곳도 CardThemeData로 되어 있는지 확인하세요.
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
