import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:gains_and_guide/core/auth/auth_session.dart';
import 'package:gains_and_guide/core/bootstrap/database_bootstrap.dart';
import 'package:gains_and_guide/core/config/app_config.dart';
import 'package:gains_and_guide/core/database/database_helper.dart';
import 'package:gains_and_guide/core/theme/app_theme.dart';
import 'package:gains_and_guide/features/home/presentation/body_profile_screen.dart';
import 'package:gains_and_guide/features/home/presentation/home_screen.dart';
import 'package:gains_and_guide/features/onboarding/presentation/onboarding_screen.dart';
import 'package:gains_and_guide/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:gains_and_guide/features/routine/presentation/program_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DatabaseBootstrap.run(DatabaseHelper.instance);

  final appConfig = AppConfig.fromEnvironment();
  await AuthSession.instance.initialize(appConfig);

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gains & Guide',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: AppTheme.lightTheme,
      home: const AppEntryPoint(),
    );
  }
}

class AppEntryPoint extends ConsumerStatefulWidget {
  const AppEntryPoint({super.key});

  @override
  ConsumerState<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends ConsumerState<AppEntryPoint> {
  bool _onboardingJustCompleted = false;

  void _handleOnboardingComplete() {
    setState(() => _onboardingJustCompleted = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingJustCompleted) {
      return const MainScreen();
    }

    final asyncCompleted = ref.watch(onboardingCompletedProvider);

    return asyncCompleted.when(
      data: (completed) => completed
          ? const MainScreen()
          : OnboardingScreen(onComplete: _handleOnboardingComplete),
      loading: () => const _SplashScreen(),
      error: (_, __) => const MainScreen(),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.fitness_center,
              size: 64,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            Text(
              'Gains & Guide',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
              ),
            ),
          ],
        ),
      ),
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
        selectedItemColor: AppTheme.primaryBlue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: '루틴'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '프로필'),
        ],
      ),
    );
  }
}
