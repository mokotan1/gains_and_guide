import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gains_and_guide/core/bootstrap/app_initializer.dart';
import 'package:gains_and_guide/core/bootstrap/startup_screen.dart';
import 'package:gains_and_guide/core/theme/app_theme.dart';
import 'package:gains_and_guide/features/home/presentation/body_profile_screen.dart';
import 'package:gains_and_guide/features/home/presentation/home_screen.dart';
import 'package:gains_and_guide/features/onboarding/presentation/onboarding_screen.dart';
import 'package:gains_and_guide/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:gains_and_guide/features/routine/presentation/program_selection_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const AppInitializer(app: AppEntryPoint()),
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
      loading: () => const AppLoadingSplash(),
      error: (_, __) => const MainScreen(),
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
      bottomNavigationBar: SafeArea(
        top: false,
        left: false,
        right: false,
        child: BottomNavigationBar(
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
      ),
    );
  }
}
