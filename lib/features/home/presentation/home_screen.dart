import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cupertino_icons/cupertino_icons.dart';

// 임시 데이터 모델 (나중에 DB와 연동)
class Exercise {
  final String id;
  final String name;
  final int sets;
  final int reps;
  final double weight;
  bool completed;

  Exercise({
    required this.id,
    required this.name,
    required this.sets,
    required this.reps,
    required this.weight,
    this.completed = false,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 샘플 데이터
  final List<Exercise> exercises = [
    Exercise(id: '1', name: '벤치프레스', sets: 3, reps: 10, weight: 60),
    Exercise(id: '2', name: '스쿼트', sets: 4, reps: 8, weight: 80),
    Exercise(id: '3', name: '데드리프트', sets: 3, reps: 6, weight: 100),
    Exercise(id: '4', name: '숄더프레스', sets: 3, reps: 12, weight: 30, completed: true),
  ];

  // 타이머 상태
  int _restTime = 90; // 90초 (1분 30초)
  bool _isResting = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startRest() {
    setState(() {
      _isResting = true;
      _restTime = 90;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restTime <= 0) {
        timer.cancel();
        setState(() {
          _isResting = false;
          _restTime = 90;
        });
      } else {
        setState(() {
          _restTime--;
        });
      }
    });
  }

  void _toggleExercise(String id) {
    setState(() {
      final exercise = exercises.firstWhere((e) => e.id == id);
      exercise.completed = !exercise.completed;
    });
  }

  String _formatTime(int seconds) {
    final int min = seconds ~/ 60;
    final int sec = seconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final int completedCount = exercises.where((e) => e.completed).length;
    final int totalCount = exercises.length;
    final double progressPercent = totalCount == 0 ? 0 : completedCount / totalCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6), // Tailwind gray-100
      appBar: AppBar(
        title: const Text(
          'Gains & Guide',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. Rest Timer Card
            _buildTimerCard(),
            const SizedBox(height: 16),

            // 2. Progress Card
            _buildProgressCard(completedCount, totalCount, progressPercent),
            const SizedBox(height: 16),

            // 3. Exercise List
            _buildExerciseList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.timer, color: Color(0xFF2563EB), size: 28), // Blue-600
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '휴식 시간',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827), // Gray-900
                        ),
                      ),
                      Text(
                        '세트 간 휴식',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(_restTime),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB), // Blue-600
                    ),
                  ),
                  if (!_isResting)
                    GestureDetector(
                      onTap: _startRest,
                      child: const Padding(
                        padding: EdgeInsets.only(top: 4.0),
                        child: Text(
                          '타이머 시작',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (_isResting) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: _restTime / 90,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                minHeight: 8,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressCard(int completed, int total, double percent) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '오늘의 진행률',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              Text(
                '$completed / $total',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)), // Green-500
              minHeight: 12,
            ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '오늘의 운동',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    // TODO: 운동 추가
                  },
                  icon: const Icon(Icons.add, size: 18, color: Color(0xFF2563EB)),
                  label: const Text(
                    '운동 추가',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)), // Gray-200

          // List Items
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: exercises.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
            itemBuilder: (context, index) {
              final exercise = exercises[index];
              return InkWell(
                onTap: () => _toggleExercise(exercise.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      // Checkbox
                      Icon(
                        exercise.completed ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: exercise.completed ? const Color(0xFF22C55E) : Colors.grey[300],
                        size: 28,
                      ),
                      const SizedBox(width: 16),
                      // Text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exercise.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: exercise.completed ? Colors.grey[400] : const Color(0xFF111827),
                                decoration: exercise.completed ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${exercise.sets} 세트 × ${exercise.reps} 회 • ${exercise.weight.toStringAsFixed(0)}kg',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
