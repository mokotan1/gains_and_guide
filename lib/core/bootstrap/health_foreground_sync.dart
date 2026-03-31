import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/repository_providers.dart';

/// 앱이 포그라운드로 돌아올 때 웨어러블 유산소를 자동 동기화한다 (디바운스).
class HealthForegroundSync extends ConsumerStatefulWidget {
  const HealthForegroundSync({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<HealthForegroundSync> createState() =>
      _HealthForegroundSyncState();
}

class _HealthForegroundSyncState extends ConsumerState<HealthForegroundSync>
    with WidgetsBindingObserver {
  static const Duration _debounce = Duration(seconds: 90);
  DateTime? _lastSyncAttempt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_maybeSync());
    }
  }

  Future<void> _maybeSync() async {
    final now = DateTime.now();
    if (_lastSyncAttempt != null &&
        now.difference(_lastSyncAttempt!) < _debounce) {
      return;
    }
    _lastSyncAttempt = now;

    final uid = ref.read(userIdentityProvider).userId;
    final sync = ref.read(healthCardioSyncRepositoryProvider);
    await sync.syncCardioFromHealth(userId: uid);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
