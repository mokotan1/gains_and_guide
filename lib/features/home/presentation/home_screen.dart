import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:vibration/vibration.dart'; // pubspec.yaml에 vibration: ^1.8.4 필요
import '../../../core/workout_provider.dart';

// 1. 운동 모델 정의
class Exercise {
  final String id;
  final String name;
  final int sets;
  final int reps;
  final double weight;
  final List<bool> setStatus;
  final List<int?> setRpe;

  Exercise({
    required this.id,
    required this.name,
    required this.sets,
    required this.reps,
    required this.weight,
    List<bool>? setStatus,
    List<int?>? setRpe,
  }) : setStatus = setStatus ?? List.filled(sets, false),
        setRpe = setRpe ?? List.filled(sets, null);

  Exercise copyWith({
    String? id,
    String? name,
    int? sets,
    int? reps,
    double? weight,
    List<bool>? setStatus,
    List<int?>? setRpe,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      setStatus: setStatus ?? List.from(this.setStatus),
      setRpe: setRpe ?? List.from(this.setRpe),
    );
  }

  bool get isAllCompleted => setStatus.every((status) => status);
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedRestTime = 180; // 기본 3분
  Timer? _restTimer;
  Timer? _cardioTimer;
  int _remainingSeconds = 0;
  bool _isWorkoutFinished = false; // 정산 상태

  @override
  void dispose() {
    _restTimer?.cancel();
    _cardioTimer?.cancel();
    super.dispose();
  }

  // --- 유산소 및 추가 운동 다이얼로그 ---
  void _showCardioSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('유산소 추가', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.directions_bike, color: Colors.orange),
              title: const Text('실내 사이클', style: TextStyle(color: Colors.black)),
              onTap: () { _addCardio('실내 사이클'); Navigator.pop(context); },
            ),
            ListTile(
              leading: const Icon(Icons.directions_run, color: Colors.orange),
              title: const Text('런닝머신', style: TextStyle(color: Colors.black)),
              onTap: () { _addCardio('런닝머신'); Navigator.pop(context); },
            ),
          ],
        ),
      ),
    );
  }

  void _addCardio(String name) {
    ref.read(workoutProvider.notifier).addExercise(Exercise(
      id: DateTime.now().toString(),
      name: name,
      sets: 1, reps: 30, weight: 0,
    ));
  }

  void _showAddExerciseDialog() {
    final nameCont = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 운동 추가', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameCont,
          style: const TextStyle(color: Colors.black),
          decoration: const InputDecoration(labelText: '운동 이름', labelStyle: TextStyle(color: Colors.black54)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              if (nameCont.text.isNotEmpty) {
                ref.read(workoutProvider.notifier).addExercise(Exercise(
                  id: DateTime.now().toString(),
                  name: nameCont.text,
                  sets: 3, reps: 10, weight: 60.0,
                ));
                Navigator.pop(context);
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  // --- 체크박스 제어 ---
  void _toggleSetStatus(int exIdx, int sIdx, List<Exercise> exercises) {
    if (_isWorkoutFinished) return; // 정산 완료 시 터치 방지

    final ex = exercises[exIdx];
    final bool isCardio = ex.name.contains('런닝머신') || ex.name.contains('사이클');

    if (ex.setStatus[sIdx]) {
      if (isCardio) _cardioTimer?.cancel();
      ref.read(workoutProvider.notifier).toggleSet(exIdx, sIdx, null);
    } else {
      if (isCardio) {
        _showCardioTimerPopup(exIdx, sIdx, ex);
      } else {
        _showRpeAndTimerSequence(exIdx, sIdx, exercises);
      }
    }
  }

  // --- 유산소 전용 팝업 및 진동 ---
  void _showCardioTimerPopup(int exIdx, int sIdx, Exercise ex) {
    _remainingSeconds = ex.reps * 60;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            _cardioTimer?.cancel();
            _cardioTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
              if (_remainingSeconds > 0) {
                if (mounted) setDialogState(() => _remainingSeconds--);
              } else {
                timer.cancel();
                _triggerVibrationAndFinish(exIdx, sIdx);
                Navigator.pop(context);
              }
            });
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Center(child: Text('${ex.name} 중...', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.orange),
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
        );
      },
    );
  }

  void _triggerVibrationAndFinish(int exIdx, int sIdx) {
    ref.read(workoutProvider.notifier).toggleSet(exIdx, sIdx, 5);
    Vibration.vibrate(duration: 1500); // 1.5초 진동
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 목표 유산소 달성! 수고하셨습니다.'), backgroundColor: Colors.orange),
      );
    }
  }

  // --- 웨이트 휴식 타이머 및 RPE ---
  void _showRpeAndTimerSequence(int exIdx, int sIdx, List<Exercise> exercises) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('${exercises[exIdx].name} 완료!', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('체감 강도(RPE)를 선택하세요.', style: TextStyle(color: Colors.black54)),
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
                    decoration: BoxDecoration(color: Colors.blue[50 * rpe] ?? Colors.blue[900], shape: BoxShape.circle),
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
      builder: (context) {
        return StatefulBuilder(
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Center(child: Text('휴식 타이머', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
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
              actions: [Center(child: TextButton(onPressed: () { _restTimer?.cancel(); Navigator.pop(context); }, child: const Text('건너뛰기', style: TextStyle(color: Colors.red))))],
            );
          },
        );
      },
    );
  }

  Widget _restOption(StateSetter setDialogState, String label, int seconds) {
    bool isSel = _selectedRestTime == seconds;
    return InkWell(
      onTap: () => setDialogState(() { _selectedRestTime = seconds; _remainingSeconds = seconds; }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: isSel ? const Color(0xFF2563EB) : Colors.grey[200], borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: isSel ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- 정산 및 AI 루틴 요청 ---
  void _processAiRecommendation(List<Exercise> currentExercises) async {
    String summary = currentExercises.map((e) {
      String rpes = e.setRpe.where((r) => r != null).join(', ');
      return "${e.name}: ${e.weight}kg x ${e.sets}세트 (RPE: $rpes)";
    }).join('\n');

    try {
      final response = await http.post(
        Uri.parse('https://gains-and-guide-1.onrender.com/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': 'master_user',
          'message': '오늘 기록 기반으로 점진적 과부하 가이드를 제공하고 다음 운동 무게를 추천해줘.',
          'context': summary,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() => _isWorkoutFinished = true);
        showDialog(
            context: context,
            builder: (context) => AlertDialog(
                title: const Text('🤖 AI 코치 분석 결과', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                content: SingleChildScrollView(child: Text(data['response'], style: const TextStyle(color: Colors.black))),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))]
            )
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('서버 연결 실패')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(workoutProvider);
    int totalSets = 0, completedSets = 0;
    for (var ex in exercises) {
      totalSets += ex.sets;
      completedSets += ex.setStatus.where((s) => s).length;
    }
    final double percent = totalSets == 0 ? 0 : completedSets / totalSets;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Gains & Guide', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 0,
        actions: [
          if (!_isWorkoutFinished) ...[
            IconButton(onPressed: _showCardioSelectionDialog, icon: const Icon(Icons.directions_run, color: Colors.orange)),
            IconButton(onPressed: _showAddExerciseDialog, icon: const Icon(Icons.add_circle, color: Colors.blue)),
          ]
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildProgressCard(completedSets, totalSets, percent),
            const SizedBox(height: 16),
            _buildExerciseList(exercises),
            const SizedBox(height: 24),
            _isWorkoutFinished
                ? _buildFinishedBanner()
                : (percent >= 1.0 && exercises.isNotEmpty ? _buildFinishButton(exercises) : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(int comp, int tot, double per) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('오늘의 세트 달성도', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              Text(_isWorkoutFinished ? '정산 완료' : '$comp / $tot 세트', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: per, backgroundColor: Colors.grey[200], color: _isWorkoutFinished ? Colors.blue : Colors.green, minHeight: 8),
        ],
      ),
    );
  }

  Widget _buildExerciseList(List<Exercise> exercises) {
    return Opacity(
      opacity: _isWorkoutFinished ? 0.6 : 1.0,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: exercises.length,
        itemBuilder: (context, exIndex) {
          final ex = exercises[exIndex];
          final bool isCardio = ex.name.contains('런닝머신') || ex.name.contains('사이클');
          return Card(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: ExpansionTile(
              initiallyExpanded: true,
              textColor: Colors.black, collapsedTextColor: Colors.black,
              title: Text(ex.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
              subtitle: Text(isCardio ? '${ex.reps}분 수행' : '${ex.sets}세트 | ${ex.reps}회 | ${ex.weight}kg', style: const TextStyle(color: Colors.black54)),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: List.generate(ex.sets, (sIdx) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(isCardio ? '목표 시간' : '${sIdx + 1}세트', style: const TextStyle(color: Colors.black87, fontSize: 16)),
                          Text(isCardio ? '${ex.reps}분' : '${ex.reps}회 / ${ex.weight}kg', style: const TextStyle(color: Colors.black, fontSize: 16)),
                          Checkbox(
                            value: ex.setStatus[sIdx],
                            activeColor: Colors.green,
                            onChanged: _isWorkoutFinished ? null : (_) => _toggleSetStatus(exIndex, sIdx, exercises),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFinishButton(List<Exercise> exercises) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _processAiRecommendation(exercises),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('오늘의 훈련 종료 및 정산', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFinishedBanner() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green.shade200)),
      child: Column(
        children: const [
          Icon(Icons.check_circle, color: Colors.green, size: 48),
          SizedBox(height: 12),
          Text('오운완! 오늘 운동 끝', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
          Text('데이터가 저장되었습니다. 내일 만나요!', style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}