import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_background/flutter_background.dart';
import 'package:gains_and_guide/core/auth/auth_session.dart';
import 'package:gains_and_guide/core/bootstrap/database_bootstrap.dart';
import 'package:gains_and_guide/core/config/app_config.dart';
import 'package:gains_and_guide/core/database/database_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 앱 부팅 단계별 진행 상태.
class StartupProgress {
  const StartupProgress({
    required this.message,
    required this.progress,
  });

  final String message;

  /// 0.0 ~ 1.0 선형 progress bar 값.
  final double progress;
}

/// `runApp` 이전에 실행되던 초기화를 앱 내부에서 순차 수행한다.
class AppStartup {
  AppStartup._();

  static Future<void> run({
    required void Function(StartupProgress progress) onProgress,
  }) async {
    onProgress(
      const StartupProgress(message: '운동 데이터 준비 중...', progress: 0.15),
    );
    try {
      await DatabaseBootstrap.run(DatabaseHelper.instance);
    } on Object catch (e, st) {
      debugPrint('AppStartup: DatabaseBootstrap failed ($e)\n$st');
    }

    onProgress(
      const StartupProgress(message: '앱 설정 확인 중...', progress: 0.35),
    );
    final appConfig = AppConfig.fromEnvironment();

    if (appConfig.supabaseConfigured) {
      try {
        await Supabase.initialize(
          url: appConfig.supabaseUrl,
          anonKey: appConfig.supabaseAnonKey,
        );
      } on Object catch (e, st) {
        debugPrint('AppStartup: Supabase.initialize failed ($e)\n$st');
      }
    }

    onProgress(
      const StartupProgress(message: '로그인 세션 준비 중...', progress: 0.55),
    );
    try {
      await AuthSession.instance.initialize(appConfig);
    } on Object catch (e, st) {
      debugPrint('AppStartup: AuthSession.initialize failed ($e)\n$st');
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      onProgress(
        const StartupProgress(message: '백그라운드 타이머 준비 중...', progress: 0.75),
      );
      try {
        final androidConfig = const FlutterBackgroundAndroidConfig(
          notificationTitle: 'Gains & Guide',
          notificationText: '운동 타이머가 백그라운드에서 실행 중입니다.',
          notificationImportance: AndroidNotificationImportance.normal,
          notificationIcon:
              AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
        );

        final ok =
            await FlutterBackground.initialize(androidConfig: androidConfig);
        if (ok) {
          await FlutterBackground.enableBackgroundExecution();
        }
      } on Object catch (e, st) {
        debugPrint('AppStartup: FlutterBackground setup failed ($e)\n$st');
      }
    }

    onProgress(
      const StartupProgress(message: '거의 다 됐어요...', progress: 0.95),
    );
  }
}
