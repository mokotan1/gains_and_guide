import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/workout_provider.dart';
import '../../routine/domain/exercise.dart';
import '../application/weekly_report_service.dart';
import '../domain/models/weekly_report.dart';
import 'widgets/action_items_card.dart';
import 'widgets/headline_card.dart';
import 'widgets/performance_card.dart';
import 'widgets/routine_recommendation_card.dart';
import 'widgets/warning_card.dart';

class WeeklyReportScreen extends ConsumerStatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  ConsumerState<WeeklyReportScreen> createState() =>
      _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends ConsumerState<WeeklyReportScreen> {
  WeeklyReport? _report;
  bool _loading = true;
  String? _error;
  bool _aiLoading = false;
  bool _routineLoading = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = ref.read(weeklyReportServiceProvider);
      final report = await service.getOrGenerateReport();
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '레포트 생성 중 오류가 발생했습니다.';
        _loading = false;
      });
    }
  }

  Future<void> _regenerate() async {
    setState(() => _loading = true);
    try {
      final service = ref.read(weeklyReportServiceProvider);
      final report = await service.regenerateReport();
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '재생성 중 오류가 발생했습니다.';
        _loading = false;
      });
    }
  }

  Future<void> _enrichWithAi() async {
    if (_report == null || _aiLoading) return;
    setState(() => _aiLoading = true);
    try {
      final service = ref.read(weeklyReportServiceProvider);
      final enriched = await service.enrichWithAi(_report!);
      if (!mounted) return;
      setState(() {
        _report = enriched;
        _aiLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _aiLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 분석에 실패했습니다.')),
      );
    }
  }

  Future<void> _getRoutineRecommendation() async {
    if (_report == null || _routineLoading) return;
    setState(() => _routineLoading = true);
    try {
      final service = ref.read(weeklyReportServiceProvider);
      final enriched =
          await service.enrichWithRoutineRecommendation(_report!);
      if (!mounted) return;
      setState(() {
        _report = enriched;
        _routineLoading = false;
      });
      if (enriched.recommendedRoutine == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('루틴 추천에 실패했습니다. 다시 시도해 주세요.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _routineLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('루틴 추천에 실패했습니다.')),
      );
    }
  }

  void _applyRecommendedRoutine() {
    final routine = _report?.recommendedRoutine;
    if (routine == null || routine.exercises.isEmpty) return;

    final newExercises = routine.exercises.asMap().entries.map((entry) {
      final i = entry.key;
      final ex = entry.value;
      return Exercise.initial(
        id: '${DateTime.now().millisecondsSinceEpoch}_$i',
        name: ex.name,
        sets: ex.sets,
        reps: ex.reps,
        weight: ex.weight,
      );
    }).toList();

    ref.read(workoutProvider.notifier).replaceRecommendedExercises(newExercises);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('추천 루틴이 적용되었습니다!'),
        backgroundColor: Color(0xFF2563EB),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('주간 레포트'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '레포트 재생성',
            onPressed: _loading ? null : _regenerate,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('레포트를 생성하고 있습니다...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReport,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    final report = _report!;
    final dateFormat = DateFormat('M월 d일');
    final periodText =
        '${dateFormat.format(report.weekStart)} ~ ${dateFormat.format(report.weekEnd)}';

    return RefreshIndicator(
      onRefresh: _regenerate,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // 기간 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              periodText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withValues(alpha: 0.5),
                  ),
            ),
          ),

          // 메트릭스 요약 배지
          _MetricsSummaryRow(report: report),

          const SizedBox(height: 4),

          // 4 섹션
          HeadlineCard(headline: report.headline),
          PerformanceCard(insights: report.performances),
          WarningCard(warnings: report.warnings),
          ActionItemsCard(items: report.actionItems),

          // 추천 루틴 카드
          if (report.recommendedRoutine != null &&
              report.recommendedRoutine!.exercises.isNotEmpty)
            RoutineRecommendationCard(
              routine: report.recommendedRoutine!,
              onApply: _applyRecommendedRoutine,
            ),

          // 루틴 추천 버튼
          if (report.recommendedRoutine == null &&
              report.metrics.totalSessions > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: OutlinedButton.icon(
                onPressed: _routineLoading ? null : _getRoutineRecommendation,
                icon: _routineLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fitness_center_rounded),
                label: Text(
                    _routineLoading ? '루틴 생성 중...' : '다음 주 루틴 추천 받기'),
              ),
            ),

          // AI 코멘트
          if (report.aiComment != null && report.aiComment!.isNotEmpty)
            _AiCommentCard(comment: report.aiComment!),

          // AI 보강 버튼
          if (report.aiComment == null || report.aiComment!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: OutlinedButton.icon(
                onPressed: _aiLoading ? null : _enrichWithAi,
                icon: _aiLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(_aiLoading ? 'AI 분석 중...' : 'AI 코치 분석 받기'),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricsSummaryRow extends StatelessWidget {
  final WeeklyReport report;

  const _MetricsSummaryRow({required this.report});

  @override
  Widget build(BuildContext context) {
    final m = report.metrics;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _Badge(label: '훈련', value: '${m.totalSessions}회'),
          _Badge(
            label: '볼륨',
            value: '${(m.totalVolume / 1000).toStringAsFixed(1)}t',
          ),
          _Badge(
            label: 'RPE',
            value: m.avgRpe.toStringAsFixed(1),
          ),
          if (m.acwr > 0)
            _Badge(
              label: 'ACWR',
              value: m.acwr.toStringAsFixed(2),
              highlight: m.acwr > 1.3,
            ),
          if (m.volumeChangePercent != null)
            _Badge(
              label: '볼륨 변화',
              value: '${m.volumeChangePercent! >= 0 ? '+' : ''}'
                  '${m.volumeChangePercent!.toStringAsFixed(1)}%',
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _Badge({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlight
            ? Colors.orange.withValues(alpha: 0.12)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: highlight ? Colors.orange : null,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withValues(alpha: 0.6),
                ),
          ),
        ],
      ),
    );
  }
}

class _AiCommentCard extends StatelessWidget {
  final String comment;

  const _AiCommentCard({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    color: Colors.deepPurple, size: 22),
                const SizedBox(width: 8),
                Text(
                  'AI 코치 코멘트',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const Divider(height: 20),
            Text(comment, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
