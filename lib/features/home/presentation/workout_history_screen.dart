import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';

/// 날짜별로 저장된 운동 기록을 조회한다.
class WorkoutHistoryListScreen extends ConsumerStatefulWidget {
  const WorkoutHistoryListScreen({super.key});

  @override
  ConsumerState<WorkoutHistoryListScreen> createState() =>
      _WorkoutHistoryListScreenState();
}

class _WorkoutHistoryListScreenState
    extends ConsumerState<WorkoutHistoryListScreen> {
  late Future<List<String>> _datesFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repo = ref.read(workoutHistoryRepositoryProvider);
    _datesFuture = repo.getDistinctWorkoutSessionDates();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '운동 기록',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FutureBuilder<List<String>>(
        future: _datesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('불러오기 실패: ${snapshot.error}'));
          }
          final dates = snapshot.data ?? [];
          if (dates.isEmpty) {
            return const Center(child: Text('저장된 운동 기록이 없습니다.'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _reload());
              await _datesFuture;
            },
            child: ListView.separated(
              itemCount: dates.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final d = dates[i];
                return ListTile(
                  title: Text(d),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => WorkoutHistoryDetailScreen(sessionDate: d),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class WorkoutHistoryDetailScreen extends ConsumerStatefulWidget {
  const WorkoutHistoryDetailScreen({super.key, required this.sessionDate});

  final String sessionDate;

  @override
  ConsumerState<WorkoutHistoryDetailScreen> createState() =>
      _WorkoutHistoryDetailScreenState();
}

class _WorkoutHistoryDetailScreenState
    extends ConsumerState<WorkoutHistoryDetailScreen> {
  late final Future<List<Map<String, dynamic>>> _rowsFuture;

  @override
  void initState() {
    super.initState();
    _rowsFuture = ref
        .read(workoutHistoryRepositoryProvider)
        .getHistoryForDateRange(widget.sessionDate, widget.sessionDate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.sessionDate,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _rowsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('불러오기 실패: ${snapshot.error}'));
          }
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return const Center(child: Text('이 날짜에 기록이 없습니다.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final r = rows[i];
              final name = r['name']?.toString() ?? '';
              final weight = r['weight'];
              final reps = r['reps'];
              final sets = r['sets'];
              final rpe = r['rpe'];
              final isDeload = (r['is_deload'] as int? ?? 0) == 1;
              return ListTile(
                title: Text(name),
                subtitle: Text(
                  '${weight}kg × $reps회 · 세트 $sets · RPE $rpe'
                  '${isDeload ? ' · 디로드' : ''}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
