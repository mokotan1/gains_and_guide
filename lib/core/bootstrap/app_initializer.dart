import 'package:flutter/material.dart';
import 'package:gains_and_guide/core/bootstrap/app_startup.dart';
import 'package:gains_and_guide/core/bootstrap/health_foreground_sync.dart';
import 'package:gains_and_guide/core/bootstrap/startup_screen.dart';

/// 부팅 초기화를 수행한 뒤 본 앱 위젯 트리로 전환한다.
class AppInitializer extends StatefulWidget {
  const AppInitializer({
    super.key,
    required this.app,
  });

  /// 초기화 완료 후 표시할 루트 위젯 (예: [AppEntryPoint]).
  final Widget app;

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _initialized = false;
  String _message = '운동 데이터 준비 중...';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _runStartup();
  }

  Future<void> _runStartup() async {
    await AppStartup.run(
      onProgress: (progress) {
        if (!mounted) return;
        setState(() {
          _message = progress.message;
          _progress = progress.progress;
        });
      },
    );

    if (!mounted) return;
    setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return StartupScreen(message: _message, progress: _progress);
    }

    return HealthForegroundSync(child: widget.app);
  }
}
