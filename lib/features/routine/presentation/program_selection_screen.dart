import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/workout_provider.dart';
import '../domain/exercise.dart';

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
        title: 'Stronglifts 5x5 (Master Custom)',
        level: '초중급 스트렝스',
        description: '주인님의 현재 중량(스쿼트 100kg+, 데드리프트 145kg+)에 맞춘 커스텀 5x5 루틴입니다.',
        weeklyExercises: {
          1: [ // 월 (Workout A)
            Exercise.initial(id: 's1_a', name: '백 스쿼트', sets: 5, reps: 5, weight: 100),
            Exercise.initial(id: 's2_a', name: '플랫 벤치 프레스', sets: 5, reps: 5, weight: 80),
            Exercise.initial(id: 's3_a', name: '펜들레이 로우', sets: 5, reps: 5, weight: 80),
          ],
          3: [ // 수 (Workout B)
            Exercise.initial(id: 's1_b', name: '백 스쿼트', sets: 5, reps: 5, weight: 100),
            Exercise.initial(id: 's4_b', name: '오버헤드 프레스 (OHP)', sets: 5, reps: 5, weight: 55),
            Exercise.initial(id: 's5_b', name: '컨벤셔널 데드리프트', sets: 1, reps: 5, weight: 145),
          ],
          5: [ // 금 (Workout A 다시)
            Exercise.initial(id: 's1_c', name: '백 스쿼트', sets: 5, reps: 5, weight: 102.5),
            Exercise.initial(id: 's2_c', name: '플랫 벤치 프레스', sets: 5, reps: 5, weight: 82.5),
            Exercise.initial(id: 's3_c', name: '펜들레이 로우', sets: 5, reps: 5, weight: 82.5),
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
          1: [Exercise.initial(id: 'p1', name: '벤치프레스', sets: 4, reps: 10, weight: 60), Exercise.initial(id: 'p2', name: '숄더프레스', sets: 3, reps: 10, weight: 30)], // 월 (Push)
          4: [Exercise.initial(id: 'p1', name: '벤치프레스', sets: 4, reps: 10, weight: 60), Exercise.initial(id: 'p2', name: '숄더프레스', sets: 3, reps: 10, weight: 30)], // 목 (Push)
          2: [Exercise.initial(id: 'l1', name: '데드리프트', sets: 3, reps: 8, weight: 100), Exercise.initial(id: 'l2', name: '풀업', sets: 3, reps: 10, weight: 0)], // 화 (Pull)
          5: [Exercise.initial(id: 'l1', name: '데드리프트', sets: 3, reps: 8, weight: 100), Exercise.initial(id: 'l2', name: '풀업', sets: 3, reps: 10, weight: 0)], // 금 (Pull)
          3: [Exercise.initial(id: 'h1', name: '스쿼트', sets: 4, reps: 8, weight: 80), Exercise.initial(id: 'h2', name: '레그프레스', sets: 3, reps: 12, weight: 120)], // 수 (Legs)
          6: [Exercise.initial(id: 'h1', name: '스쿼트', sets: 4, reps: 8, weight: 80), Exercise.initial(id: 'h2', name: '레그프레스', sets: 3, reps: 12, weight: 120)], // 토 (Legs)
        },
        icon: Icons.repeat,
        color: Colors.purple,
      ),
      WeeklyProgram(
        title: '다이어트 유산소 루틴 (매일)',
        level: '체지방 연소',
        description: '매일 실내 사이클과 런닝머신을 병행하여 체지방을 효과적으로 태웁니다.',
        weeklyExercises: {
          1: [Exercise.initial(id: 'c1', name: '실내 사이클', sets: 1, reps: 30, weight: 0), Exercise.initial(id: 't1', name: '런닝머신', sets: 1, reps: 20, weight: 0)],
          2: [Exercise.initial(id: 'c1', name: '실내 사이클', sets: 1, reps: 30, weight: 0), Exercise.initial(id: 't1', name: '런닝머신', sets: 1, reps: 20, weight: 0)],
          3: [Exercise.initial(id: 'c1', name: '실내 사이클', sets: 1, reps: 30, weight: 0), Exercise.initial(id: 't1', name: '런닝머신', sets: 1, reps: 20, weight: 0)],
          4: [Exercise.initial(id: 'c1', name: '실내 사이클', sets: 1, reps: 30, weight: 0), Exercise.initial(id: 't1', name: '런닝머신', sets: 1, reps: 20, weight: 0)],
          5: [Exercise.initial(id: 'c1', name: '실내 사이클', sets: 1, reps: 30, weight: 0), Exercise.initial(id: 't1', name: '런닝머신', sets: 1, reps: 20, weight: 0)],
          6: [Exercise.initial(id: 'c1', name: '실내 사이클', sets: 1, reps: 30, weight: 0), Exercise.initial(id: 't1', name: '런닝머신', sets: 1, reps: 20, weight: 0)],
          7: [Exercise.initial(id: 'c1', name: '실내 사이클', sets: 1, reps: 30, weight: 0), Exercise.initial(id: 't1', name: '런닝머신', sets: 1, reps: 20, weight: 0)],
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
