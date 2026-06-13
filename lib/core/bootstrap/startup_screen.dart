import 'package:flutter/material.dart';
import 'package:gains_and_guide/core/theme/app_theme.dart';

/// 앱 부팅 중 진행 상태를 표시하는 시작 화면.
class StartupScreen extends StatelessWidget {
  const StartupScreen({
    super.key,
    required this.message,
    required this.progress,
  });

  final String message;

  /// 0.0 ~ 1.0
  final double progress;

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppTheme.primaryBlue,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.fitness_center,
                  size: 64,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Gains & Guide',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    value: clampedProgress > 0 ? clampedProgress : null,
                    minHeight: 4,
                    backgroundColor: Colors.white24,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 온보딩 완료 여부 확인 등 짧은 로딩 구간용 간단 스플래시.
class AppLoadingSplash extends StatelessWidget {
  const AppLoadingSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.primaryBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fitness_center,
              size: 64,
              color: Colors.white,
            ),
            SizedBox(height: 16),
            Text(
              'Gains & Guide',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
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
