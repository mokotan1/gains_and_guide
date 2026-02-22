import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/workout_provider.dart';

// 운동 모델 공유
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
  // 타이머 관련
  int _selectedRestTime = 120;
  int _currentTimerSeconds = 120;
  bool _isResting = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _setRestTime(int seconds) {
    setState(() {
      _selectedRestTime = seconds;
      if (!_isResting) _currentTimerSeconds = seconds;
    });
  }

  void _toggleTimer() {
    if (_isResting) {
      _timer?.cancel();
      setState(() {
        _isResting = false;
        _currentTimerSeconds = _selectedRestTime;
      });
    } else {
      _startTimerDirectly();
    }
  }

  void _startTimerDirectly() {
    _timer?.cancel();
    setState(() {
      _isResting = true;
      _currentTimerSeconds = _selectedRestTime;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentTimerSeconds <= 0) {
        timer.cancel();
        setState(() {
          _isResting = false;
          _currentTimerSeconds = _selectedRestTime;
        });
      } else {
        setState(() => _currentTimerSeconds--);
      }
    });
  }

  void _toggleSetStatus(int exerciseIndex, int setIndex, List<Exercise> exercises) {
    if (exercises[exerciseIndex].setStatus[setIndex]) {
      ref.read(workoutProvider.notifier).toggleSet(exerciseIndex, setIndex, null);
    } else {
      _showRpeDialog(exerciseIndex, setIndex, exercises);
    }
  }

  void _showRpeDialog(int exerciseIndex, int setIndex, List<Exercise> exercises) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${exercises[exerciseIndex].name} ${setIndex + 1}세트 강도'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('이 세트의 난이도는 어땠나요?\n(1: 매우 쉬움 ~ 10: 실패 지점)', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
              children: List.generate(10, (index) {
                int rpe = index + 1;
                return InkWell(
                  onTap: () {
                    ref.read(workoutProvider.notifier).toggleSet(exerciseIndex, setIndex, rpe);
                    _startTimerDirectly();
                    Navigator.pop(context);
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

  void _showCardioSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('유산소 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.directions_bike, color: Colors.orange),
              title: const Text('실내 사이클'),
              onTap: () {
                _addCardio('실내 사이클');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions_run, color: Colors.orange),
              title: const Text('런닝머신'),
              onTap: () {
                _addCardio('런닝머신');
                Navigator.pop(context);
              },
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
      sets: 1,
      reps: 30, // 기본 30분
      weight: 0,
    ));
  }

  void _showAddExerciseDialog() {
    final nameController = TextEditingController();
    final setsController = TextEditingController(text: '3');
    final repsController = TextEditingController(text: '10');
    final weightController = TextEditingController(text: '60');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 운동 추가'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: '운동 이름')),
              TextField(controller: setsController, decoration: const InputDecoration(labelText: '세트 수'), keyboardType: TextInputType.number),
              TextField(controller: repsController, decoration: const InputDecoration(labelText: '회수'), keyboardType: TextInputType.number),
              TextField(controller: weightController, decoration: const InputDecoration(labelText: '무게 (kg)'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                ref.read(workoutProvider.notifier).addExercise(Exercise(
                  id: DateTime.now().toString(),
                  name: nameController.text,
                  sets: int.tryParse(setsController.text) ?? 3,
                  reps: int.tryParse(repsController.text) ?? 10,
                  weight: double.tryParse(weightController.text) ?? 60.0,
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

  String _formatTime(int seconds) {
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
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
    final bool isAllFinished = percent >= 1.0 && exercises.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Gains & Guide', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (exercises.isEmpty) _buildEmptyStateAdvice(),
            _buildTimerCard(),
            const SizedBox(height: 16),
            _buildProgressCard(completedSets, totalSets, percent),
            if (isAllFinished) ...[
              const SizedBox(height: 16),
              _buildFinishButton(exercises),
            ],
            const SizedBox(height: 16),
            _buildExerciseList(exercises),
          ],
        ),
      ),
    );
  }

  Widget _buildFinishButton(List<Exercise> exercises) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showSummaryDialog(exercises),
        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
        label: const Text('오늘의 훈련 종료 및 정산', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF22C55E),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _showSummaryDialog(List<Exercise> exercises) {
    double totalVolume = 0;
    int totalCals = 0;
    
    for (var ex in exercises) {
      // 볼륨: 무게 * 횟수 * 완료된 세트 수
      int completedSetsCount = ex.setStatus.where((s) => s).length;
      totalVolume += ex.weight * ex.reps * completedSetsCount;
      
      // 칼로리 간이 계산 (근력: 세트당 5-10kcal, 유산소: 분당 7-10kcal)
      if (ex.name.contains('사이클') || ex.name.contains('런닝머신')) {
        totalCals += (ex.reps * 8).toInt(); // reps를 분 단위로 활용
      } else {
        totalCals += (completedSetsCount * 7);
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🏋️ 오늘의 훈련 리포트', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _summaryItem('총 훈련 볼륨', '${totalVolume.toStringAsFixed(0)} kg', Colors.blue),
            _summaryItem('예상 소모 칼로리', '$totalCals kcal', Colors.orange),
            const Divider(height: 30),
            const Text('AI 코치가 내일의 보조 운동을\n분석하여 루틴에 추가합니다...', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _processAiRecommendation(exercises);
              Navigator.pop(context);
            },
            child: const Text('확인 및 AI 분석 요청'),
          ),
        ],
      ),
    );
  }

  void _processAiRecommendation(List<Exercise> currentExercises) async {
    // 1. 오늘의 데이터를 텍스트로 정리
    String workoutSummary = currentExercises.map((e) => 
      "${e.name}: ${e.weight}kg x ${e.sets}세트 (강도RPE: ${e.setRpe.where((r) => r != null).join(',')})"
    ).join('\n');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('AI 코치가 오늘의 데이터를 분석하여 내일의 보조 운동을 설계 중입니다...'),
        backgroundColor: Colors.blue,
      )
    );

    // 2. 서버 연동 및 자동 추가 로직 (시뮬레이션)
    // 실제 운영 시에는 http.post를 통해 backend_ai와 통신하여 JSON을 받아옵니다.
    Future.delayed(const Duration(seconds: 2), () {
      final aiRecommendation = Exercise(
        id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
        name: '[AI 추천] 사이드 레터럴 레이즈', 
        sets: 3,
        reps: 15,
        weight: 5,
      );

      // 내일 루틴에 자동으로 꽂아넣는 로직을 호출할 수 있습니다.
      // 여기서는 현재 상태에 바로 추가하여 시각적으로 보여줍니다.
      ref.read(workoutProvider.notifier).addExercise(aiRecommendation);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('내일의 보조 운동으로 "${aiRecommendation.name}"이 배정되었습니다!'),
          backgroundColor: Colors.green,
        )
      );
    });
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildEmptyStateAdvice() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '오늘은 지정된 루틴이 없는 휴식일입니다. 가벼운 운동을 추가해 보시겠어요?',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('휴식 타이머', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('세트 간 권장 휴식', style: TextStyle(fontSize: 14, color: Colors.grey)),
              ]),
              Text(_formatTime(_currentTimerSeconds), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
            ],
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_restTimeButton('2분', 120), _restTimeButton('3분', 180), _restTimeButton('5분', 300)]),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _toggleTimer,
            style: ElevatedButton.styleFrom(backgroundColor: _isResting ? Colors.red[400] : const Color(0xFF2563EB), padding: const EdgeInsets.symmetric(vertical: 12)),
            child: Text(_isResting ? '타이머 중지' : '타이머 시작', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          )),
        ],
      ),
    );
  }

  Widget _restTimeButton(String label, int seconds) {
    bool isSel = _selectedRestTime == seconds;
    return InkWell(onTap: () => _setRestTime(seconds), child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), decoration: BoxDecoration(color: isSel ? const Color(0xFF2563EB) : Colors.grey[200], borderRadius: BorderRadius.circular(20)), child: Text(label, style: TextStyle(color: isSel ? Colors.white : Colors.black87, fontWeight: FontWeight.bold))));
  }

  Widget _buildProgressCard(int comp, int tot, double per) {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('오늘의 세트 달성도', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), Text('$comp / $tot 세트', style: const TextStyle(fontSize: 14, color: Colors.blue))]), const SizedBox(height: 12), LinearProgressIndicator(value: per, backgroundColor: Colors.grey[200], valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)), minHeight: 10)]));
  }

  Widget _buildExerciseList(List<Exercise> exercises) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('운동 목록', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    IconButton(
                      onPressed: _showCardioSelectionDialog,
                      icon: const Icon(Icons.directions_run, color: Color(0xFFF59E0B), size: 30),
                    ),
                    IconButton(
                      onPressed: _showAddExerciseDialog,
                      icon: const Icon(Icons.add_circle, color: Color(0xFF2563EB), size: 30),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            itemCount: exercises.length,
            itemBuilder: (context, exIndex) {
              final ex = exercises[exIndex];
              final isCardio = ex.name.contains('런닝머신') || ex.name.contains('사이클');

              return ExpansionTile(
                initiallyExpanded: true,
                title: Text(ex.name, style: TextStyle(fontWeight: FontWeight.bold, decoration: ex.isAllCompleted ? TextDecoration.lineThrough : null)),
                subtitle: Text(isCardio ? '${ex.reps}분 수행' : '${ex.sets}세트 | ${ex.reps}회 | ${ex.weight}kg'),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: isCardio 
                      ? _buildCardioCheck(exIndex, ex)
                      : _buildWeightTrainingCheck(exIndex, ex, exercises),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCardioCheck(int exIndex, Exercise ex) {
    bool isDone = ex.setStatus[0];
    return InkWell(
      onTap: () {
        ref.read(workoutProvider.notifier).toggleSet(exIndex, 0, isDone ? null : 5); // 유산소는 기본 RPE 5 할당
        if (!isDone) _startTimerDirectly();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDone ? const Color(0xFF22C55E) : Colors.white,
          border: Border.all(color: isDone ? const Color(0xFF22C55E) : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            isDone ? '유산소 완료! 🎉' : '${ex.reps}분 운동 시작하기',
            style: TextStyle(color: isDone ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildWeightTrainingCheck(int exIndex, Exercise ex, List<Exercise> exercises) {
    return Wrap(
      spacing: 10, runSpacing: 10,
      children: List.generate(ex.sets, (sIdx) {
        bool isDone = ex.setStatus[sIdx];
        return InkWell(
          onTap: () => _toggleSetStatus(exIndex, sIdx, exercises),
          child: Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: isDone ? const Color(0xFF22C55E) : Colors.white,
              border: Border.all(color: isDone ? const Color(0xFF22C55E) : Colors.grey[300]!),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text('${sIdx + 1}', style: TextStyle(color: isDone ? Colors.white : Colors.black54, fontWeight: FontWeight.bold))),
          ),
        );
      }),
    );
  }
}
