import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/workout_provider.dart';
import '../../exercise_search/presentation/exercise_search_bottom_sheet.dart';
import '../../deload/presentation/deload_banner_widget.dart';
import '../../deload/presentation/deload_prediction_card.dart';
import '../../routine/domain/exercise.dart';
import '../../weekly_report/application/weekly_report_service.dart';
import '../../weekly_report/presentation/weekly_report_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _cardioTimer;
  Timer? _restTimer;
  int _remainingSeconds = 0;
  int _selectedRestTime = 180;
  bool _weeklyReportReady = false;

  @override
  void initState() {
    super.initState();
    _checkWeeklyReport();
  }

  @override
  void dispose() {
    _cardioTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkWeeklyReport() async {
    try {
      final service = ref.read(weeklyReportServiceProvider);
      final now = DateTime.now();
      if (now.weekday >= DateTime.monday) {
        final lastMonday = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1 + 7));
        final hasReport = await service.getOrGenerateReport(weekStart: lastMonday);
        if (!mounted) return;
        if (hasReport.metrics.totalSessions > 0) {
          setState(() => _weeklyReportReady = true);
        }
      }
    } catch (_) {
      // 자동 생성 실패 시 조용히 무시
    }
  }

  bool _checkIsBodyweight(String name) {
    const keywords = ['풀업', '턱걸이', '푸쉬업', '팔굽혀펴기', '딥스', '맨몸', '플랭크'];
    return keywords.any((k) => name.contains(k));
  }

  // --- CSV 데이터 생성 로직 ---
  Future<String> _generateWorkoutCsv(List<Exercise> currentExercises) async {
    String csv = "date,name,weight,sets,reps,rpe_list,total_volume,avg_rpe\n";
    final historyRepo = ref.read(workoutHistoryRepositoryProvider);
    final history = await historyRepo.getAllHistory();

    Map<String, Map<String, List<Map<String, dynamic>>>> grouped = {};
    for (var row in history) {
      String date = row['date'].toString().substring(0, 10);
      String name = row['name'];
      grouped.putIfAbsent(date, () => {});
      grouped[date]!.putIfAbsent(name, () => []);
      grouped[date]![name]!.add(row);
    }

    grouped.forEach((date, exercises) {
      exercises.forEach((name, sets) {
        double weight = sets.first['weight'];
        int reps = sets.first['reps'];
        String rpes = sets.map((s) => s['rpe'] ?? 8).join('|');
        
        // 지표 계산
        double volume = sets.fold(0.0, (prev, s) => prev + (s['weight'] * s['reps']));
        double avgRpe = sets.fold(0.0, (prev, s) => prev + (s['rpe'] ?? 8)) / sets.length;
        
        csv += "$date,$name,$weight,${sets.length},$reps,$rpes,${volume.toStringAsFixed(1)},${avgRpe.toStringAsFixed(1)}\n";
      });
    });

    String today = DateTime.now().toString().split(' ')[0];
    if (!grouped.containsKey(today)) {
      for (var ex in currentExercises) {
        final completedEntries = ex.setRpe.asMap().entries
            .where((entry) => ex.setStatus[entry.key])
            .toList();

        if (completedEntries.isNotEmpty) {
          String rpeStr = completedEntries.map((e) => e.value ?? 8).join('|');
          double volume = completedEntries.fold(0.0,
              (prev, e) => prev + ex.setWeights[e.key] * ex.setReps[e.key]);
          double avgRpe = completedEntries.fold(0.0,
              (prev, e) => prev + (e.value ?? 8)) / completedEntries.length;

          csv += "$today,${ex.name},${ex.weight},${ex.sets},${ex.reps},$rpeStr,${volume.toStringAsFixed(1)},${avgRpe.toStringAsFixed(1)}\n";
        }
      }
    }
    return csv;
  }

  // --- UI 알림 및 다이얼로그 메서드 ---
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('데이터를 분석 중입니다...', style: TextStyle(fontWeight: FontWeight.bold))
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAiResultDialog(String response) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🤖 AI 코치 분석 결과'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(response),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
      ),
    );
  }

  // --- 핵심 정산 및 분석 로직 ---
  void _processAiRecommendation(List<Exercise> currentExercises) async {
    _showLoadingDialog();
    try {
      await ref.read(workoutProvider.notifier).saveCurrentWorkoutToHistory();
      await _exportHistoryToCsv();

      final profileRepo = ref.read(bodyProfileRepositoryProvider);
      final profile = await profileRepo.getProfile();
      String pInfo = profile != null ? "사용자 체중: ${profile['weight']}kg. " : "";
      String fullCsv = await _generateWorkoutCsv(currentExercises);

      final ApiClient apiClient = ref.read(apiClientProvider);
      final identity = ref.read(userIdentityProvider);

      final data = await apiClient.post(
        '/chat',
        {
          'user_id': identity.userId,
          'message': '$pInfo 오늘 운동 기록을 분석하고 증량 가이드 데이터를 포함해서 줘.',
          'context': fullCsv,
        },
        timeout: const Duration(seconds: 60),
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (data['progression'] != null) {
        await ref.read(workoutProvider.notifier).applyProgression(data['progression']);
      }

      ref.read(workoutProvider.notifier).finishWorkout();
      _showAiResultDialog(data['response']);
    } on AppException catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.userMessage), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('정산 중 오류가 발생했습니다. 다시 시도해 주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- 운동 추가 및 제어 로직 ---
  Future<void> _showAddExerciseBottomSheet() async {
    final result = await ExerciseSearchBottomSheet.show(context);
    if (result == null || !mounted) return;

    Exercise toAdd = result;
    if (_checkIsBodyweight(result.name)) {
      final profile = await ref.read(bodyProfileRepositoryProvider).getProfile();
      final w = profile != null ? (profile['weight'] as num).toDouble() : result.weight;
      toAdd = result.copyWith(
        isBodyweight: true,
        weight: w,
        setWeights: List.filled(result.sets, w),
      );
    }
    ref.read(workoutProvider.notifier).addExercise(toAdd);
  }

  void _toggleSetStatus(int exIdx, int sIdx, List<Exercise> exercises) {
    if (ref.read(workoutProvider.notifier).isFinished) return;
    final ex = exercises[exIdx];
    if (ex.setStatus[sIdx]) {
      if (ex.isCardio) _cardioTimer?.cancel();
      ref.read(workoutProvider.notifier).toggleSet(exIdx, sIdx, null);
    } else {
      if (ex.isCardio) {
        _showCardioTimerPopup(exIdx, sIdx, ex);
      } else {
        _showSetResultChoice(exIdx, sIdx, exercises);
      }
    }
  }

  void _showSetResultChoice(int exIdx, int sIdx, List<Exercise> exercises) {
    final ex = exercises[exIdx];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('세트 ${sIdx + 1} 결과'),
        content: Text('${ex.setWeights[sIdx].toStringAsFixed(1)}kg × ${ex.setReps[sIdx]}회를 수행했나요?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showFailedRepsDialog(exIdx, sIdx, exercises);
            },
            child: const Text('실패', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showRpeAndTimerSequence(exIdx, sIdx, exercises);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('성공', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _showFailedRepsDialog(int exIdx, int sIdx, List<Exercise> exercises) {
    final ex = exercises[exIdx];
    int actualReps = (ex.setReps[sIdx] - 1).clamp(0, ex.setReps[sIdx]);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade400),
              const SizedBox(width: 8),
              const Text('실패 기록'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '목표: ${ex.setReps[sIdx]}회',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              const Text('실제 완료 횟수', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => setDialogState(() => actualReps = (actualReps - 1).clamp(0, 100)),
                    icon: const Icon(Icons.remove_circle_outline, color: AppTheme.primaryBlue),
                  ),
                  const SizedBox(width: 16),
                  Text('$actualReps', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () => setDialogState(() => actualReps = (actualReps + 1).clamp(0, 100)),
                    icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryBlue),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                ref.read(workoutProvider.notifier).failSet(exIdx, sIdx, actualReps);
                Navigator.pop(context);
                if (sIdx < ex.sets - 1) _showRestTimerPopup();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
              ),
              child: const Text('실패 기록'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCardioTimerPopup(int exIdx, int sIdx, Exercise ex) {
    _remainingSeconds = ex.reps * 60;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          _cardioTimer?.cancel();
          _cardioTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (_remainingSeconds > 0) {
              if (mounted) setDialogState(() => _remainingSeconds--);
            } else {
              timer.cancel();
              _onCardioTimerEnd(exIdx, sIdx);
              Navigator.pop(context);
            }
          });
          return AlertDialog(
            title: Center(child: Text('${ex.name} 중...')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: AppTheme.warningOrange),
                ),
                const SizedBox(height: 10),
                const Text('지방이 타고 있습니다!', style: TextStyle(color: Colors.black54)),
              ],
            ),
            actions: [
              Center(
                child: TextButton(
                  onPressed: () {
                    _cardioTimer?.cancel();
                    ref.read(workoutProvider.notifier).toggleSet(exIdx, sIdx, 5);
                    Navigator.pop(context);
                  },
                  child: const Text('운동 종료', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  void _onCardioTimerEnd(int exIdx, int sIdx) {
    ref.read(workoutProvider.notifier).toggleSet(exIdx, sIdx, 5);
    Vibrate.vibrate();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 목표 유산소 달성!'), backgroundColor: AppTheme.warningOrange),
      );
    }
  }

  void _showRpeAndTimerSequence(int exIdx, int sIdx, List<Exercise> exercises) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('${exercises[exIdx].name} 완료!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('체감 강도(RPE)를 선택하세요.'),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
              children: List.generate(10, (index) {
                int rpe = index + 1;
                return InkWell(
                  onTap: () {
                    ref.read(workoutProvider.notifier).toggleSet(exIdx, sIdx, rpe);
                    Navigator.pop(context);
                    if (sIdx < exercises[exIdx].sets - 1) _showRestTimerPopup();
                  },
                  child: Container(
                    width: 40, height: 40,
                    decoration: const BoxDecoration(color: AppTheme.primaryBlue, shape: BoxShape.circle),
                    child: Center(child: Text('$rpe', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _showRestTimerPopup() {
    _remainingSeconds = _selectedRestTime;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          _restTimer?.cancel();
          _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (_remainingSeconds > 0) {
              if (mounted) setDialogState(() => _remainingSeconds--);
            } else {
              timer.cancel();
              Navigator.pop(context);
            }
          });
          return AlertDialog(
            title: const Center(child: Text('휴식 타이머')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _restOption(setDialogState, '2분', 120),
                    _restOption(setDialogState, '3분', 180),
                    _restOption(setDialogState, '5분', 300),
                  ],
                ),
              ],
            ),
            actions: [
              Center(
                child: TextButton(
                  onPressed: () {
                    _restTimer?.cancel();
                    Navigator.pop(context);
                  },
                  child: const Text('건너뛰기', style: TextStyle(color: Colors.red)),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _restOption(StateSetter setDialogState, String label, int seconds) {
    bool isSel = _selectedRestTime == seconds;
    return InkWell(
      onTap: () => setDialogState(() {
        _selectedRestTime = seconds;
        _remainingSeconds = seconds;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? AppTheme.primaryBlue : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: isSel ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _exportHistoryToCsv() async {
    try {
      final historyRepo = ref.read(workoutHistoryRepositoryProvider);
      final history = await historyRepo.getAllHistory();
      if (history.isEmpty) return;
      String csvData = 'Date,Exercise,Set,Reps,Weight,RPE\n';
      for (var row in history) {
        csvData += '${row['date']},${row['name']},${row['sets']},${row['reps']},${row['weight']},${row['rpe']}\n';
      }
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/workout_history.csv');
      await file.writeAsString(csvData);
    } catch (e) {
      print('CSV 내보내기 에러: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(workoutProvider);
    final notifier = ref.watch(workoutProvider.notifier);
    final isFinished = notifier.isFinished;
    final deloadRec = notifier.deloadRecommendation;

    int totalSets = 0, completedSets = 0;
    for (var ex in exercises) {
      totalSets += ex.sets;
      completedSets += ex.setStatus.where((s) => s).length;
    }
    final bool isAllSetsDone = totalSets > 0 && completedSets == totalSets;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gains & Guide'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WeeklyReportScreen()),
            ),
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: '주간 레포트',
          ),
          if (!isFinished)
            IconButton(onPressed: _showAddExerciseBottomSheet, icon: const Icon(Icons.add_circle, color: AppTheme.primaryBlue)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_weeklyReportReady) _buildWeeklyReportBanner(),
            if (deloadRec != null && deloadRec.shouldDeload)
              DeloadBannerWidget(recommendation: deloadRec)
            else if (deloadRec != null)
              DeloadPredictionCard(recommendation: deloadRec),
            _buildProgressCard(completedSets, totalSets),
            const SizedBox(height: 16),
            _buildExerciseList(exercises, isFinished),
            const SizedBox(height: 24),
            if (exercises.isEmpty && !isFinished) _buildRestDayBanner()
            else if (isFinished) _buildFinishedBanner()
            else if (isAllSetsDone) _buildFinishButton(exercises)
            else if (exercises.isNotEmpty) _buildIncompleteMessage(completedSets, totalSets)
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(int comp, int tot) {
    double per = tot == 0 ? 0 : comp / tot;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('오늘의 운동 달성도', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('$comp / $tot 세트', style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold))
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: per,
              backgroundColor: Colors.grey[200],
              color: AppTheme.successGreen,
              minHeight: 8,
            ),
          ],
        ),
      ),
    );
  }

  void _showSetEditDialog(int exIdx, int sIdx, Exercise ex) {
    double weight = ex.setWeights[sIdx];
    int reps = ex.setReps[sIdx];
    bool applyToRemaining = sIdx < ex.sets - 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Widget counter(String label, String valueStr, VoidCallback onDec, VoidCallback onInc) {
            return Column(
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: onDec,
                      icon: const Icon(Icons.remove_circle_outline, color: AppTheme.primaryBlue),
                      constraints: const BoxConstraints(), padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 8),
                    Text(valueStr, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: onInc,
                      icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryBlue),
                      constraints: const BoxConstraints(), padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            );
          }

          return AlertDialog(
            title: Text('세트 ${sIdx + 1} 조정'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!ex.isBodyweight && !ex.isCardio)
                  counter(
                    '무게 (kg)',
                    weight.toStringAsFixed(1),
                    () => setDialogState(() => weight = (weight - 2.5).clamp(0.0, 500.0)),
                    () => setDialogState(() => weight += 2.5),
                  ),
                const SizedBox(height: 16),
                counter(
                  ex.isCardio ? '시간 (분)' : '횟수',
                  '$reps',
                  () => setDialogState(() => reps = (reps - 1).clamp(1, 100)),
                  () => setDialogState(() => reps += 1),
                ),
                if (sIdx < ex.sets - 1) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: applyToRemaining,
                        onChanged: (v) => setDialogState(() => applyToRemaining = v ?? false),
                      ),
                      const Expanded(child: Text('이후 세트에도 적용', style: TextStyle(fontSize: 13))),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
              ElevatedButton(
                onPressed: () {
                  final notifier = ref.read(workoutProvider.notifier);
                  if (!ex.isBodyweight && !ex.isCardio) {
                    notifier.updateSetWeight(exIdx, sIdx, weight, applyToRemaining: applyToRemaining);
                  }
                  notifier.updateSetReps(exIdx, sIdx, reps, applyToRemaining: applyToRemaining);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('확인'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSetRow(Exercise ex, int exIdx, int sIdx, bool isFinished) {
    final setWeight = ex.setWeights[sIdx];
    final setRep = ex.setReps[sIdx];
    final isDone = ex.setStatus[sIdx];
    final isFailed = ex.setFailed[sIdx];

    final Color badgeColor;
    if (isFailed) {
      badgeColor = Colors.red.shade400;
    } else if (isDone) {
      badgeColor = AppTheme.successGreen;
    } else {
      badgeColor = Colors.grey[300]!;
    }

    final String label = ex.isCardio
        ? '목표 시간: ${setRep}분'
        : '${setWeight.toStringAsFixed(1)}kg × ${setRep}회';

    final canDelete = !isFinished && ex.sets > 1;

    final tile = ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: badgeColor,
        child: isFailed
            ? const Icon(Icons.close, size: 14, color: Colors.white)
            : Text(
                '${sIdx + 1}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDone ? Colors.white : Colors.black54),
              ),
      ),
      title: GestureDetector(
        onTap: isFinished ? null : () => _showSetEditDialog(exIdx, sIdx, ex),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isFailed ? Colors.red.shade400 : (isDone ? Colors.black38 : Colors.black87),
                decoration: isDone && !isFailed ? TextDecoration.lineThrough : null,
              ),
            ),
            if (isFailed) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('실패', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade400)),
              ),
            ] else if (!isFinished && !isDone) ...[
              const SizedBox(width: 4),
              Icon(Icons.edit, size: 14, color: Colors.grey[400]),
            ],
          ],
        ),
      ),
      trailing: Checkbox(
        value: isDone,
        onChanged: isFinished ? null : (v) => _toggleSetStatus(exIdx, sIdx, ref.read(workoutProvider)),
      ),
    );

    if (!canDelete) return tile;

    return Dismissible(
      key: ValueKey('${ex.id}_set_$sIdx'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade400,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) {
        ref.read(workoutProvider.notifier).removeSetFromExercise(exIdx, sIdx);
      },
      child: tile,
    );
  }

  Widget _buildExerciseList(List<Exercise> exercises, bool isFinished) {
    return Opacity(
      opacity: isFinished ? 0.6 : 1.0,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: exercises.length,
        itemBuilder: (context, idx) {
          final ex = exercises[idx];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              initiallyExpanded: true,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(ex.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18))),
                  if (!isFinished)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => ref.read(workoutProvider.notifier).removeExercise(ex.id),
                    ),
                ],
              ),
              subtitle: Text(
                ex.isCardio
                    ? '${ex.reps}분 수행'
                    : '${ex.sets}세트 | 기본 ${ex.reps}회 | ${ex.weight.toStringAsFixed(1)}kg'
                      '${ex.failedSetCount > 0 ? ' | ${ex.failedSetCount}세트 실패' : ''}',
                style: TextStyle(
                  color: ex.failedSetCount > 0 ? Colors.red.shade400 : Colors.black54,
                ),
              ),
              children: [
                ...List.generate(ex.sets, (sIdx) => _buildSetRow(ex, idx, sIdx, isFinished)),
                if (!isFinished)
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.grey[200],
                      child: Icon(Icons.add, size: 16, color: Colors.grey[500]),
                    ),
                    title: Text('세트 추가', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                    onTap: () => ref.read(workoutProvider.notifier).addSetToExercise(idx),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFinishButton(List<Exercise> exercises) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _processAiRecommendation(exercises),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('오늘의 훈련 종료 및 정산', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () async {
              await ref.read(workoutProvider.notifier).saveCurrentWorkoutToHistory();
              ref.read(workoutProvider.notifier).finishWorkout();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('오늘 운동 기록이 저장되었습니다. 내일 루틴이 A/B에 맞춰 바뀝니다.')),
                );
              }
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('기록만 저장하고 종료 (AI 없이)', style: TextStyle(fontSize: 14)),
          ),
        ),
      ],
    );
  }

  Widget _buildIncompleteMessage(int comp, int tot) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
      child: Text(
        '남은 세트를 모두 완료하면 정산 버튼이 나타납니다. ($comp/$tot)',
        style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildWeeklyReportBanner() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WeeklyReportScreen()),
        );
        setState(() => _weeklyReportReady = false);
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryBlue.withValues(alpha: 0.1),
              AppTheme.primaryBlue.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.bar_chart_rounded, color: AppTheme.primaryBlue, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '지난 주 레포트가 준비되었습니다',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '탭하여 퍼포먼스 리뷰를 확인하세요',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.primaryBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildRestDayBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.self_improvement, color: Colors.blue[300], size: 48),
          const SizedBox(height: 12),
          const Text(
            '오늘은 휴식일입니다',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
          ),
          const SizedBox(height: 8),
          const Text(
            '충분한 휴식도 성장의 일부입니다.\n상단 + 버튼으로 운동을 추가할 수 있습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildFinishedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(16)),
      child: const Column(
        children: [
          Icon(Icons.check_circle, color: AppTheme.successGreen, size: 48),
          SizedBox(height: 8),
          Text('오운완! 오늘 운동 끝', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.successGreen)),
        ],
      ),
    );
  }
}