import 'dart:async';
import 'package:flutter/material.dart';

// 운동 모델
class Exercise {
  final String id;
  final String name;
  final int sets;
  final int reps;
  final double weight;
  final List<bool> setStatus; 
  final List<int?> setRpe; // 각 세트별 RPE (1~10) 추가

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 샘플 데이터
  List<Exercise> exercises = [
    Exercise(id: '1', name: '벤치프레스', sets: 3, reps: 10, weight: 60),
    Exercise(id: '2', name: '스쿼트', sets: 4, reps: 8, weight: 80),
    Exercise(id: '3', name: '데드리프트', sets: 3, reps: 6, weight: 100),
  ];

  // 타이머 관련
  int _selectedRestTime = 120; // 기본 2분 (120초)
  int _currentTimerSeconds = 120;
  bool _isResting = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // 휴식 시간 설정
  void _setRestTime(int seconds) {
    setState(() {
      _selectedRestTime = seconds;
      if (!_isResting) {
        _currentTimerSeconds = seconds;
      }
    });
  }

  // 타이머 시작/종료
  void _toggleTimer() {
    if (_isResting) {
      _timer?.cancel();
      setState(() {
        _isResting = false;
        _currentTimerSeconds = _selectedRestTime;
      });
    } else {
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
          // 휴식 종료 알림 등을 여기에 추가할 수 있습니다.
        } else {
          setState(() {
            _currentTimerSeconds--;
          });
        }
      });
    }
  }

  // 세트 체크/해제 및 RPE 입력
  void _toggleSetStatus(int exerciseIndex, int setIndex) {
    if (exercises[exerciseIndex].setStatus[setIndex]) {
      // 이미 완료된 경우 취소만 함
      setState(() {
        exercises[exerciseIndex].setStatus[setIndex] = false;
        exercises[exerciseIndex].setRpe[setIndex] = null;
      });
    } else {
      // 완료 처리 시 RPE 입력 다이얼로그 표시
      _showRpeDialog(exerciseIndex, setIndex);
    }
  }

  void _showRpeDialog(int exerciseIndex, int setIndex) {
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
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: List.generate(10, (index) {
                int rpe = index + 1;
                return InkWell(
                  onTap: () {
                    setState(() {
                      exercises[exerciseIndex].setStatus[setIndex] = true;
                      exercises[exerciseIndex].setRpe[setIndex] = rpe;
                      _startTimerDirectly();
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue[50 * rpe] ?? Colors.blue[900],
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('$rpe', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // 타이머를 즉시 시작하는 내부 메서드
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
        setState(() {
          _currentTimerSeconds--;
        });
      }
    });
  }

  // 운동 추가 다이얼로그
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
              TextField(controller: nameController, decoration: const InputDecoration(labelText: '운동 이름 (예: 스쿼트)')),
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
                setState(() {
                  exercises.add(Exercise(
                    id: DateTime.now().toString(),
                    name: nameController.text,
                    sets: int.tryParse(setsController.text) ?? 3,
                    reps: int.tryParse(repsController.text) ?? 10,
                    weight: double.tryParse(weightController.text) ?? 60.0,
                  ));
                });
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
    final int min = seconds ~/ 60;
    final int sec = seconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    int totalSets = 0;
    int completedSets = 0;
    for (var ex in exercises) {
      totalSets += ex.sets;
      completedSets += ex.setStatus.where((s) => s).length;
    }
    final double progressPercent = totalSets == 0 ? 0 : completedSets / totalSets;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Gains & Guide', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildTimerCard(),
            const SizedBox(height: 16),
            _buildProgressCard(completedSets, totalSets, progressPercent),
            const SizedBox(height: 16),
            _buildExerciseList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('휴식 타이머', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('세트 간 권장 휴식', style: TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
              Text(
                _formatTime(_currentTimerSeconds),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _restTimeButton('2분', 120),
              _restTimeButton('3분', 180),
              _restTimeButton('5분', 300),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _toggleTimer,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isResting ? Colors.red[400] : const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(_isResting ? '타이머 중지' : '타이머 시작', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _restTimeButton(String label, int seconds) {
    bool isSelected = _selectedRestTime == seconds;
    return InkWell(
      onTap: () => _setRestTime(seconds),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildProgressCard(int completed, int total, double percent) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('오늘의 세트 달성도', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('$completed / $total 세트', style: const TextStyle(fontSize: 14, color: Colors.blue)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: percent,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
            minHeight: 10,
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('운동 목록', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: _showAddExerciseDialog,
                  icon: const Icon(Icons.add_circle, color: Color(0xFF2563EB), size: 30),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: exercises.length,
            itemBuilder: (context, exIndex) {
              final ex = exercises[exIndex];
              return ExpansionTile(
                initiallyExpanded: true,
                title: Text(ex.name, style: TextStyle(fontWeight: FontWeight.bold, decoration: ex.isAllCompleted ? TextDecoration.lineThrough : null)),
                subtitle: Text('${ex.sets}세트 | ${ex.reps}회 | ${ex.weight}kg'),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: List.generate(ex.sets, (setIndex) {
                        bool isDone = ex.setStatus[setIndex];
                        return InkWell(
                          onTap: () => _toggleSetStatus(exIndex, setIndex),
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isDone ? const Color(0xFF22C55E) : Colors.white,
                              border: Border.all(color: isDone ? const Color(0xFF22C55E) : Colors.grey[300]!),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${setIndex + 1}',
                                style: TextStyle(color: isDone ? Colors.white : Colors.black54, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
