import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/workout_constants.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import 'providers/big3_competition_providers.dart';

class Big3CompetitionScreen extends ConsumerStatefulWidget {
  const Big3CompetitionScreen({super.key});

  @override
  ConsumerState<Big3CompetitionScreen> createState() =>
      _Big3CompetitionScreenState();
}

class _Big3CompetitionScreenState extends ConsumerState<Big3CompetitionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _aliasController = TextEditingController();
  final _weightControllers = <String, TextEditingController>{
    for (final lift in WorkoutConstants.big3LiftTypes)
      lift: TextEditingController(),
  };
  final _repsControllers = <String, TextEditingController>{
    for (final lift in WorkoutConstants.big3LiftTypes)
      lift: TextEditingController(text: '5'),
  };
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _aliasController.dispose();
    for (final c in _weightControllers.values) {
      c.dispose();
    }
    for (final c in _repsControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _refreshAll() async {
    ref.invalidate(big3CurrentSeasonProvider);
    ref.invalidate(big3MyProfileProvider);
    ref.invalidate(big3MyStatsProvider);
    ref.invalidate(big3LeaderboardProvider);
    ref.invalidate(big3MyRankProvider);
  }

  String _friendlyError(Object error) {
    if (error is ServerException) {
      final message = error.message.toLowerCase();
      if (error.statusCode == 503) {
        return '서버 DB가 설정되지 않았습니다. DATABASE_URL을 확인해 주세요.';
      }
      if (error.statusCode == 401) {
        return '로그인이 필요합니다.';
      }
      if (error.statusCode == 409) {
        return '이미 사용 중인 닉네임이에요.';
      }
      if (error.statusCode == 400 &&
          message.contains('improvement exceeds safe weekly limit')) {
        return '이전 기록 대비 변화가 커서 저장되지 않았어요. 무게와 반복을 다시 확인해 주세요.';
      }
      if (error.statusCode == 400 &&
          message.contains('maximum 3 submissions')) {
        return '오늘은 이 종목 기록을 3회까지 제출할 수 있어요.';
      }
      if (error.statusCode == 400 && message.contains('opt-in required')) {
        return '시즌 참가 후 기록을 제출할 수 있어요.';
      }
      return '서버 오류 (${error.statusCode})';
    }
    if (error is NetworkException) return '네트워크 연결을 확인해 주세요.';
    if (error is ApiTimeoutException) return '요청 시간이 초과되었습니다.';
    return error.toString();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _refreshAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seasonAsync = ref.watch(big3CurrentSeasonProvider);
    final profileAsync = ref.watch(big3MyProfileProvider);
    final rankAsync = ref.watch(big3MyRankProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('시즌 3대 기록'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryBlue,
          tabs: const [
            Tab(text: '내 기록'),
            Tab(text: '리더보드'),
          ],
        ),
      ),
      body: seasonAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(_friendlyError(e))),
        data: (season) {
          if (season == null) {
            return const Center(child: Text('진행 중인 시즌이 없습니다.'));
          }
          return TabBarView(
            controller: _tabController,
            children: [
              _MyRecordsTab(
                seasonName: season.name,
                profileAsync: profileAsync,
                aliasController: _aliasController,
                weightControllers: _weightControllers,
                repsControllers: _repsControllers,
                busy: _busy,
                onOptIn: () => _run(() async {
                  final svc = ref.read(big3CompetitionServiceProvider);
                  await svc.optIn(
                    displayAlias: _aliasController.text.trim().isEmpty
                        ? null
                        : _aliasController.text.trim(),
                  );
                }),
                onOptOut: () => _run(() async {
                  await ref.read(big3CompetitionServiceProvider).optOut();
                }),
                onLeaderboardVisibilityChanged: (visible) => _run(() async {
                  await ref
                      .read(big3CompetitionServiceProvider)
                      .setLeaderboardVisibility(visible: visible);
                }),
                onSubmit: (liftType) => _run(() async {
                  final weight = double.tryParse(
                    _weightControllers[liftType]!.text.trim(),
                  );
                  final reps = int.tryParse(
                    _repsControllers[liftType]!.text.trim(),
                  );
                  if (weight == null || reps == null) {
                    throw ArgumentError('무게와 반복 수를 올바르게 입력해 주세요.');
                  }
                  await ref.read(big3CompetitionServiceProvider).submitLift(
                        liftType: liftType,
                        weightKg: weight,
                        reps: reps,
                      );
                  _weightControllers[liftType]!.clear();
                }),
                statsAsync: ref.watch(big3MyStatsProvider),
                rankAsync: rankAsync,
              ),
              _LeaderboardTab(
                entriesAsync: ref.watch(big3LeaderboardProvider),
                friendlyError: _friendlyError,
                rankAsync: rankAsync,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MyRecordsTab extends StatelessWidget {
  const _MyRecordsTab({
    required this.seasonName,
    required this.profileAsync,
    required this.aliasController,
    required this.weightControllers,
    required this.repsControllers,
    required this.busy,
    required this.onOptIn,
    required this.onOptOut,
    required this.onLeaderboardVisibilityChanged,
    required this.onSubmit,
    required this.statsAsync,
    required this.rankAsync,
  });

  final String seasonName;
  final AsyncValue<dynamic> profileAsync;
  final TextEditingController aliasController;
  final Map<String, TextEditingController> weightControllers;
  final Map<String, TextEditingController> repsControllers;
  final bool busy;
  final VoidCallback onOptIn;
  final VoidCallback onOptOut;
  final void Function(bool visible) onLeaderboardVisibilityChanged;
  final void Function(String liftType) onSubmit;
  final AsyncValue<dynamic> statsAsync;
  final AsyncValue<dynamic> rankAsync;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(seasonName, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          '리더보드에는 선택한 별칭만 표시됩니다. 이메일·내부 ID는 노출되지 않습니다.',
          style: TextStyle(color: Colors.black54, fontSize: 13),
        ),
        const SizedBox(height: 16),
        _OptInCard(
          profileAsync: profileAsync,
          aliasController: aliasController,
          busy: busy,
          onOptIn: onOptIn,
          onOptOut: onOptOut,
          onLeaderboardVisibilityChanged: onLeaderboardVisibilityChanged,
        ),
        const SizedBox(height: 16),
        _StatsCard(statsAsync: statsAsync),
        const SizedBox(height: 16),
        _RankSummaryCard(rankAsync: rankAsync),
        const SizedBox(height: 16),
        ...WorkoutConstants.big3LiftTypes.map(
          (lift) => _SubmitCard(
            liftType: lift,
            label: WorkoutConstants.big3LiftKoLabels[lift] ?? lift,
            weightController: weightControllers[lift]!,
            repsController: repsControllers[lift]!,
            busy: busy,
            enabled: profileAsync.asData?.value?.canSubmit == true,
            onSubmit: () => onSubmit(lift),
          ),
        ),
      ],
    );
  }
}

class _OptInCard extends StatelessWidget {
  const _OptInCard({
    required this.profileAsync,
    required this.aliasController,
    required this.busy,
    required this.onOptIn,
    required this.onOptOut,
    required this.onLeaderboardVisibilityChanged,
  });

  final AsyncValue<dynamic> profileAsync;
  final TextEditingController aliasController;
  final bool busy;
  final VoidCallback onOptIn;
  final VoidCallback onOptOut;
  final void Function(bool visible) onLeaderboardVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
          data: (profile) {
            final optedIn = profile?.competitionOptedIn == true;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  optedIn ? '시즌 참가 중' : '이번 시즌 기록을 남기려면 참가가 필요해요',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (optedIn && profile != null) ...[
                  const SizedBox(height: 8),
                  Text('공개 별칭: ${profile.displayAlias}'),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('리더보드에 표시'),
                    subtitle: const Text('끄면 기록은 유지되고 순위만 숨깁니다'),
                    value: profile.leaderboardOptIn,
                    onChanged: busy
                        ? null
                        : (v) => onLeaderboardVisibilityChanged(v),
                  ),
                ],
                if (!optedIn) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: aliasController,
                    decoration: const InputDecoration(
                      labelText: '공개 별칭 (선택, 2~24자)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '비우면 자동 별칭이 부여됩니다.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
                const SizedBox(height: 12),
                if (optedIn)
                  OutlinedButton(
                    onPressed: busy ? null : onOptOut,
                    child: const Text('참가 취소'),
                  )
                else
                  FilledButton(
                    onPressed: busy ? null : onOptIn,
                    child: const Text('시즌 참가하기'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.statsAsync});

  final AsyncValue<dynamic> statsAsync;

  String _fmt(double? v) => v == null ? '-' : '${v.toStringAsFixed(1)} kg';

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: statsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
          data: (stats) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('시즌 최고 기록 (Epley 1RM)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('스쿼트: ${_fmt(stats.squat1rmKg)}'),
              Text('벤치: ${_fmt(stats.bench1rmKg)}'),
              Text('데드: ${_fmt(stats.deadlift1rmKg)}'),
              const Divider(),
              Text(
                '시즌 합산: ${_fmt(stats.total1rmKg)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankSummaryCard extends StatelessWidget {
  const _RankSummaryCard({required this.rankAsync});

  final AsyncValue<dynamic> rankAsync;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: rankAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => const Text('순위를 불러오지 못했습니다.'),
          data: (rank) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '내 시즌 순위',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                rank.statusMessage,
                style: TextStyle(
                  color: rank.ranked ? AppTheme.primaryBlue : Colors.black54,
                  fontWeight: rank.ranked ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmitCard extends StatelessWidget {
  const _SubmitCard({
    required this.liftType,
    required this.label,
    required this.weightController,
    required this.repsController,
    required this.busy,
    required this.enabled,
    required this.onSubmit,
  });

  final String liftType;
  final String label;
  final TextEditingController weightController;
  final TextEditingController repsController;
  final bool busy;
  final bool enabled;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: weightController,
                    enabled: enabled && !busy,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '무게 (kg)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 88,
                  child: TextField(
                    controller: repsController,
                    enabled: enabled && !busy,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '반복',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: enabled && !busy ? onSubmit : null,
              child: const Text('기록 제출'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardTab extends StatelessWidget {
  const _LeaderboardTab({
    required this.entriesAsync,
    required this.friendlyError,
    required this.rankAsync,
  });

  final AsyncValue<dynamic> entriesAsync;
  final String Function(Object) friendlyError;
  final AsyncValue<dynamic> rankAsync;

  @override
  Widget build(BuildContext context) {
    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(friendlyError(e))),
      data: (entries) {
        if (entries.isEmpty) {
          return const Center(
            child: Text('아직 완전한 3대 기록을 가진 참가자가 없습니다.'),
          );
        }
        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final e = entries[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        child: Text('${e.rank}'),
                      ),
                      title: Text(e.displayAlias),
                      subtitle: Text(
                        'S ${e.squat1rmKg.toStringAsFixed(1)} · '
                        'B ${e.bench1rmKg.toStringAsFixed(1)} · '
                        'D ${e.deadlift1rmKg.toStringAsFixed(1)}',
                      ),
                      trailing: Text(
                        '${e.total1rmKg.toStringAsFixed(1)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            _RankBottomBar(rankAsync: rankAsync),
          ],
        );
      },
    );
  }
}

class _RankBottomBar extends StatelessWidget {
  const _RankBottomBar({required this.rankAsync});

  final AsyncValue<dynamic> rankAsync;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: const Border(top: BorderSide(color: Color(0xFFE0E0E0))),
        ),
        child: rankAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => const Text('내 순위를 불러오지 못했습니다.'),
          data: (rank) => Text(
            rank.statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: rank.ranked ? AppTheme.primaryBlue : Colors.black54,
              fontWeight: rank.ranked ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
