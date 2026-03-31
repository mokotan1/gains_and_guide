import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import 'workout_history_screen.dart';

class BodyProfileScreen extends ConsumerStatefulWidget {
  const BodyProfileScreen({super.key});

  @override
  ConsumerState<BodyProfileScreen> createState() => _BodyProfileScreenState();
}

class _BodyProfileScreenState extends ConsumerState<BodyProfileScreen> {
  final _wController = TextEditingController();
  final _mController = TextEditingController();
  final _birthYearController = TextEditingController();
  bool _syncingHealth = false;

  @override
  void dispose() {
    _wController.dispose();
    _mController.dispose();
    _birthYearController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final repo = ref.read(bodyProfileRepositoryProvider);
    final p = await repo.getProfile();
    if (p != null) {
      setState(() {
        _wController.text = p['weight'].toString();
        _mController.text = p['muscle_mass'].toString();
      });
    }
    final up = await ref.read(userProfileRepositoryProvider).getProfile();
    if (up?.birthYear != null && mounted) {
      setState(() {
        _birthYearController.text = up!.birthYear!.toString();
      });
    }
  }

  Future<void> _syncHealthCardio() async {
    if (_syncingHealth) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _syncingHealth = true);
    try {
      final svc = ref.read(healthCardioSyncRepositoryProvider);
      final uid = ref.read(userIdentityProvider).userId;
      final result = await svc.syncCardioFromHealth(userId: uid);
      if (!mounted) return;
      final msg = result.success
          ? '유산소 ${result.sessionsImported}건을 가져왔습니다.'
          : (result.message ?? '동기화할 수 없습니다.');
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _syncingHealth = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('신체 프로필',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history, color: Colors.black54),
            title: const Text('날짜별 운동 기록'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WorkoutHistoryListScreen(),
                ),
              );
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.favorite, color: Colors.black54),
            title: const Text('건강 앱에서 유산소 동기화'),
            subtitle: const Text('최근 7일 러닝·사이클 등과 심박수 (Apple 건강 / Health Connect)'),
            trailing: const Icon(Icons.sync),
            onTap: _syncHealthCardio,
          ),
          const Divider(),
          const SizedBox(height: 8),
          TextField(
              controller: _wController,
              decoration: const InputDecoration(labelText: '몸무게 (kg)'),
              keyboardType: TextInputType.number),
          const SizedBox(height: 15),
          TextField(
              controller: _mController,
              decoration: const InputDecoration(labelText: '골격근량 (kg)'),
              keyboardType: TextInputType.number),
          const SizedBox(height: 15),
          TextField(
            controller: _birthYearController,
            decoration: const InputDecoration(
              labelText: '출생연도 (선택, 심박 존 참고용)',
              hintText: '예: 1990',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final repo = ref.read(bodyProfileRepositoryProvider);
                await repo.saveProfile({
                  'id': 1,
                  'weight': double.tryParse(_wController.text) ?? 0,
                  'muscle_mass': double.tryParse(_mController.text) ?? 0
                });
                final upRepo = ref.read(userProfileRepositoryProvider);
                final existing = await upRepo.getProfile();
                if (existing != null) {
                  final raw = _birthYearController.text.trim();
                  final y = int.tryParse(raw);
                  if (raw.isEmpty) {
                    await upRepo.saveProfile(existing.copyWith(clearBirthYear: true));
                  } else if (y != null) {
                    await upRepo.saveProfile(existing.copyWith(birthYear: y));
                  }
                }
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('정보가 저장되었습니다.')));
                }
              },
              child: const Text('저장하기'),
            ),
          )
        ]),
      ),
    );
  }
}
