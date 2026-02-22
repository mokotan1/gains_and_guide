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

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Gains & Guide', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 0,
      ),
      body: exercises.isEmpty 
        ? _buildEmptyState()
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildTimerCard(),
                const SizedBox(height: 16),
                _buildProgressCard(completedSets, totalSets, percent),
                const SizedBox(height: 16),
                _buildExerciseList(exercises),
              ],
            ),
          ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.fitness_center, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('오늘 진행할 프로그램이 없습니다.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('프로그램 탭에서 루틴을 선택해 보세요!', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => DefaultTabController.of(context).animateTo(1), 
            child: const Text('프로그램 보러 가기'),
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
          Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('운동 목록', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), IconButton(onPressed: _showAddExerciseDialog, icon: const Icon(Icons.add_circle, color: Color(0xFF2563EB), size: 30))])),
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            itemCount: exercises.length,
            itemBuilder: (context, exIndex) {
              final ex = exercises[exIndex];
              return ExpansionTile(
                initiallyExpanded: true,
                title: Text(ex.name, style: TextStyle(fontWeight: FontWeight.bold, decoration: ex.isAllCompleted ? TextDecoration.lineThrough : null)),
                subtitle: Text('${ex.sets}세트 | ${ex.reps}회 | ${ex.weight}kg'),
                children: [
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Wrap(spacing: 10, runSpacing: 10, children: List.generate(ex.sets, (sIdx) {
                    bool isDone = ex.setStatus[sIdx];
                    return InkWell(onTap: () => _toggleSetStatus(exIndex, sIdx, exercises), child: Container(width: 50, height: 50, decoration: BoxDecoration(color: isDone ? const Color(0xFF22C55E) : Colors.white, border: Border.all(color: isDone ? const Color(0xFF22C55E) : Colors.grey[300]!), shape: BoxShape.circle), child: Center(child: Text('${sIdx + 1}', style: TextStyle(color: isDone ? Colors.white : Colors.black54, fontWeight: FontWeight.bold)))));
                  }))),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
