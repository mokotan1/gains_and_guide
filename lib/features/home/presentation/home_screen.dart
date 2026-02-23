import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_vibrate/flutter_vibrate.dart'; // Vibration 대신 Vibrate 사용
import '../../../core/workout_provider.dart';
import '../../../core/database/database_helper.dart';

// [Exercise 모델 정의]
class Exercise {
  final String id;
  final String name;
  final int sets;
  final int reps;
  final double weight;
  final List<bool> setStatus;
  final List<int?> setRpe;

  Exercise({
    required this.id, required this.name, required this.sets, required this.reps, required this.weight,
    List<bool>? setStatus, List<int?>? setRpe,
  }) : setStatus = setStatus ?? List.filled(sets, false),
        setRpe = setRpe ?? List.filled(sets, null);

  Exercise copyWith({String? id, String? name, int? sets, int? reps, double? weight, List<bool>? setStatus, List<int?>? setRpe}) {
    return Exercise(
      id: id ?? this.id, name: name ?? this.name, sets: sets ?? this.sets, reps: reps ?? this.reps, weight: weight ?? this.weight,
      setStatus: setStatus ?? List.from(this.setStatus), setRpe: setRpe ?? List.from(this.setRpe),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _cardioTimer;
  Timer? _restTimer;
  int _remainingSeconds = 0;
  int _selectedRestTime = 180; // 기본 휴식 시간 3분
  bool _isWorkoutFinished = false;

  @override
  void dispose() {
    _cardioTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  // --- 판별 로직 ---
  bool _isCardio(String name) => name.contains('런닝머신') || name.contains('사이클') || name.contains('유산소');
  bool _isBodyweight(String name) {
    const keywords = ['풀업', '턱걸이', '푸쉬업', '팔굽혀펴기', '딥스', '맨몸', '플랭크'];
    return keywords.any((k) => name.contains(k));
  }

  // --- 유산소 및 운동 추가 다이얼로그 ---
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
    final weightCont = TextEditingController(text: '0.0');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('새 운동 추가', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCont,
                style: const TextStyle(color: Colors.black),
                decoration: const InputDecoration(labelText: '운동 이름'),
                onChanged: (val) async {
                  if (_isBodyweight(val)) {
                    final profile = await DatabaseHelper.instance.getProfile();
                    if (profile != null) {
                      setDialogState(() => weightCont.text = profile['weight'].toString());
                    }
                  }
                },
              ),
              TextField(
                controller: weightCont,
                style: const TextStyle(color: Colors.black),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '무게 (kg)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                if (nameCont.text.isNotEmpty) {
                  ref.read(workoutProvider.notifier).addExercise(Exercise(
                    id: DateTime.now().toString(),
                    name: nameCont.text,
                    sets: 3, reps: 10,
                    weight: double.tryParse(weightCont.text) ?? 0,
                  ));
                  Navigator.pop(context);
                }
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  // --- 체크박스 및 타이머 처리 ---
  void _toggleSetStatus(int exIdx, int sIdx, List<Exercise> exercises) {
    if (_isWorkoutFinished) return;
    final ex = exercises[exIdx];

    if (ex.setStatus[sIdx]) {
      if (_isCardio(ex.name)) _cardioTimer?.cancel();
      ref.read(workoutProvider.notifier).toggleSet(exIdx, sIdx, null);
    } else {
      if (_isCardio(ex.name)) {
        _showCardioTimerPopup(exIdx, sIdx, ex);
      } else {
        _showRpeAndTimerSequence(exIdx, sIdx, exercises);
      }
    }
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Center(child: Text('${ex.name} 중...', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.orange)),
                const SizedBox(height: 10),
                const Text('지방이 타고 있습니다!', style: TextStyle(color: Colors.black54)),
              ],
            ),
            actions: [
              Center(child: TextButton(onPressed: () {
                _cardioTimer?.cancel();
                ref.read(workoutProvider.notifier).toggleSet(exIdx, sIdx, 5);
                Navigator.pop(context);
              }, child: const Text('운동 종료', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))))
            ],
          );
        },
      ),
    );
  }

  void _onCardioTimerEnd(int exIdx, int sIdx) {
    ref.read(workoutProvider.notifier).toggleSet(exIdx, sIdx, 5);
    Vibrate.vibrate(); // Vibrate 사용
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 목표 유산소 달성!'), backgroundColor: Colors.orange));
    }
  }

  void _showRpeAndTimerSequence(int exIdx, int sIdx, List<Exercise> exercises) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('${exercises[exIdx].name} 완료!', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
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

  // --- 휴식 타이머 팝업 (2, 3, 5분 선택 복구) ---
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
            actions: [
              Center(child: TextButton(onPressed: () {
                _restTimer?.cancel();
                Navigator.pop(context);
              }, child: const Text('건너뛰기', style: TextStyle(color: Colors.red))))
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
          color: isSel ? const Color(0xFF2563EB) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: isSel ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- 정산 및 AI 분석 ---
  void _processAiRecommendation(List<Exercise> currentExercises) async {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (context) => const Center(child: Card(child: Padding(padding: EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('AI 코치가 분석 중입니다...', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
      ])))),
    );

    final profile = await DatabaseHelper.instance.getProfile();
    String pInfo = profile != null ? "사용자: 체중 ${profile['weight']}kg, 골격근 ${profile['muscle_mass']}kg. " : "";
    String summary = currentExercises.map((e) => "${e.name}: ${e.weight}kg x ${e.sets}세트").join('\n');

    try {
      final response = await http.post(
        Uri.parse('https://gains-and-guide-1.onrender.com/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': 'master_user', 'message': '$pInfo 오늘 운동 기록을 바탕으로 다음 가이드를 줘.', 'context': summary}),
      );
      Navigator.pop(context);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() => _isWorkoutFinished = true);
        showDialog(context: context, builder: (context) => AlertDialog(title: const Text('🤖 분석 결과'), content: SingleChildScrollView(child: Text(data['response'])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))]));
      }
    } catch (e) {
      Navigator.pop(context);
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
    final bool isAllSetsDone = totalSets > 0 && completedSets == totalSets;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Gains & Guide', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
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
            _buildProgressCard(completedSets, totalSets),
            const SizedBox(height: 16),
            _buildExerciseList(exercises),
            const SizedBox(height: 24),
            if (_isWorkoutFinished) _buildFinishedBanner()
            else if (isAllSetsDone) _buildFinishButton(exercises)
            else if (exercises.isNotEmpty) _buildIncompleteMessage(completedSets, totalSets)
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(int comp, int tot) {
    double per = tot == 0 ? 0 : comp / tot;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('오늘의 운동 달성도', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
          Text('$comp / $tot 세트', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))
        ]),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: per, backgroundColor: Colors.grey[200], color: Colors.green, minHeight: 8),
      ]),
    );
  }

  Widget _buildExerciseList(List<Exercise> exercises) {
    return Opacity(
      opacity: _isWorkoutFinished ? 0.6 : 1.0,
      child: ListView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        itemCount: exercises.length,
        itemBuilder: (context, idx) {
          final ex = exercises[idx];
          final bool isCardio = _isCardio(ex.name);

          return Card(
            color: Colors.white, margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              initiallyExpanded: true,
              title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(ex.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 18)),
                if (!_isWorkoutFinished) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => ref.read(workoutProvider.notifier).removeExercise(ex.id)),
              ]),
              subtitle: Text(isCardio ? '${ex.reps}분 수행' : '${ex.sets}세트 | ${ex.reps}회 | ${ex.weight}kg', style: const TextStyle(color: Colors.black54)),
              children: List.generate(ex.sets, (sIdx) => ListTile(
                title: Text(isCardio ? '목표 시간: ${ex.reps}분' : '${ex.weight}kg / ${ex.reps}회', style: const TextStyle(color: Colors.black87)),
                trailing: Checkbox(value: ex.setStatus[sIdx], onChanged: _isWorkoutFinished ? null : (v) => _toggleSetStatus(idx, sIdx, exercises)),
              )),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFinishButton(List<Exercise> exercises) {
    return SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => _processAiRecommendation(exercises), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('오늘의 훈련 종료 및 정산', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))));
  }

  Widget _buildIncompleteMessage(int comp, int tot) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)), child: Text('남은 세트를 모두 완료하면 정산 버튼이 나타납니다. ($comp/$tot)', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)));
  }

  Widget _buildFinishedBanner() {
    return Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(16)), child: const Column(children: [Icon(Icons.check_circle, color: Colors.green, size: 48), Text('오운완! 오늘 운동 끝', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green))]));
  }
}