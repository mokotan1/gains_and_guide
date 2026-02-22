import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/workout_provider.dart';
import '../../home/presentation/home_screen.dart';

class WeeklyProgram {
  final String title;
  final String level;
  final String description;
  final Map<int, List<Exercise>> weeklyExercises; // 요일별 운동 (1:월 ~ 7:일)
  final IconData icon;
  final Color color;

  WeeklyProgram({
    required this.title,
    required this.level,
    required this.description,
    required this.weeklyExercises,
    required this.icon,
    required this.color,
  });
}

class ProgramSelectionScreen extends ConsumerWidget {
  const ProgramSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<WeeklyProgram> programs = [
      WeeklyProgram(
        title: 'Stronglifts 5x5 (월수금)',
        level: '초중급 스트렝스',
        description: '월, 수, 금 주 3회 훈련합니다. 나머지 요일은 자동으로 휴식일로 지정됩니다.',
        weeklyExercises: {
          1: [ // 월
            Exercise(id: 's1', name: '스쿼트', sets: 5, reps: 5, weight: 60),
            Exercise(id: 's2', name: '벤치프레스', sets: 5, reps: 5, weight: 40),
            Exercise(id: 's3', name: '바벨로우', sets: 5, reps: 5, weight: 40),
          ],
          3: [ // 수
            Exercise(id: 's1', name: '스쿼트', sets: 5, reps: 5, weight: 60),
            Exercise(id: 's4', name: '오버헤드 프레스', sets: 5, reps: 5, weight: 30),
            Exercise(id: 's5', name: '데드리프트', sets: 1, reps: 5, weight: 80),
            Exercise(id: 's6', name: '실내 사이클', sets: 1, reps: 20, weight: 0), // 유산소 추가
          ],
          5: [ // 금
            Exercise(id: 's1', name: '스쿼트', sets: 5, reps: 5, weight: 62.5),
            Exercise(id: 's2', name: '벤치프레스', sets: 5, reps: 5, weight: 42.5),
            Exercise(id: 's3', name: '바벨로우', sets: 5, reps: 5, weight: 42.5),
            Exercise(id: 's7', name: '런닝머신', sets: 1, reps: 15, weight: 0), // 유산소 추가
          ],
        },
        icon: Icons.fitness_center,
        color: Colors.red,
      ),
      WeeklyProgram(
        title: 'PPL 3분할 (월~토)',
        level: '고급자',
        description: '월/목(Push), 화/금(Pull), 수/토(Legs) 순서로 자동으로 루틴이 바뀝니다.',
        weeklyExercises: {
          1: [Exercise(id: 'p1', name: '벤치프레스', sets: 4, reps: 10, weight: 60), Exercise(id: 'p2', name: '숄더프레스', sets: 3, reps: 10, weight: 30)], // 월 (Push)
          4: [Exercise(id: 'p1', name: '벤치프레스', sets: 4, reps: 10, weight: 60), Exercise(id: 'p2', name: '숄더프레스', sets: 3, reps: 10, weight: 30)], // 목 (Push)
          2: [Exercise(id: 'l1', name: '데드리프트', sets: 3, reps: 8, weight: 100), Exercise(id: 'l2', name: '풀업', sets: 3, reps: 10, weight: 0)], // 화 (Pull)
          5: [Exercise(id: 'l1', name: '데드리프트', sets: 3, reps: 8, weight: 100), Exercise(id: 'l2', name: '풀업', sets: 3, reps: 10, weight: 0)], // 금 (Pull)
          3: [Exercise(id: 'h1', name: '스쿼트', sets: 4, reps: 8, weight: 80), Exercise(id: 'h2', name: '레그프레스', sets: 3, reps: 12, weight: 120)], // 수 (Legs)
          6: [Exercise(id: 'h1', name: '스쿼트', sets: 4, reps: 8, weight: 80), Exercise(id: 'h2', name: '레그프레스', sets: 3, reps: 12, weight: 120)], // 토 (Legs)
        },
        icon: Icons.repeat,
        color: Colors.purple,
      ),
      WeeklyProgram(
        title: '다이어트 유산소 루틴 (매일)',
        level: '체지방 연소',
        description: '매일 실내 사이클과 런닝머신을 병행하여 체지방을 효과적으로 태웁니다.',
        weeklyExercises: {
          1: [Exercise(id: 'c1', name: '실내 사이클', sets: 1, reps: 30, weight: 0), Exercise(id: 't1', name: '런닝머신', sets: 1, reps: 20, weight: 0)],
          2: [Exercise(id: 'c1', name: '실내 사이클', sets: 1, reps: 30, weight: 0), Exercise(id: 't1', name: '런닝머신', sets: 1, reps: 20, weight: 0)],
          3: [Exercise(id: 'c1', name: '실내 사이클', sets: 1, reps: 30, weight: 0), Exercise(id: 't1', name: '런닝머신', sets: 1, reps: 20, weight: 0)],
          4: [Exercise(id: 'c1', name: '실내 사이클', sets: 1, reps: 30, weight: 0), Exercise(id: 't1', name: '런닝머신', sets: 1, reps: 20, weight: 0)],
          5: [Exercise(id: 'c1', name: '실내 사이클', sets: 1, reps: 30, weight: 0), Exercise(id: 't1', name: '런닝머신', sets: 1, reps: 20, weight: 0)],
          6: [Exercise(id: 'c1', name: '실내 사이클', sets: 1, reps: 30, weight: 0), Exercise(id: 't1', name: '런닝머신', sets: 1, reps: 20, weight: 0)],
          7: [Exercise(id: 'c1', name: '실내 사이클', sets: 1, reps: 30, weight: 0), Exercise(id: 't1', name: '런닝머신', sets: 1, reps: 20, weight: 0)],
        },
        icon: Icons.directions_run,
        color: Colors.orange,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('요일별 프로그램', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: programs.length,
        itemBuilder: (context, index) {
          final program = programs[index];
          return _buildProgramCard(context, ref, program);
        },
      ),
    );
  }

  Widget _buildProgramCard(BuildContext context, WidgetRef ref, WeeklyProgram program) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: program.color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(program.icon, color: program.color, size: 30),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(program.level, style: TextStyle(color: program.color, fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(program.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(program.description, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(workoutProvider.notifier).applyWeeklyProgram(program.weeklyExercises);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${program.title} 요일별 자동 루틴이 설정되었습니다!'), backgroundColor: program.color),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: program.color,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('요일별 자동 모드 시작', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
