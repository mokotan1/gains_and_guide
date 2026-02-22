import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/workout_provider.dart';
import '../../home/presentation/home_screen.dart';

class Program {
  final String title;
  final String level;
  final String description;
  final List<Exercise> exercises;
  final IconData icon;
  final Color color;

  Program({
    required this.title,
    required this.level,
    required this.description,
    required this.exercises,
    required this.icon,
    required this.color,
  });
}

class ProgramSelectionScreen extends ConsumerWidget {
  const ProgramSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Program> programs = [
      Program(
        title: 'Stronglifts 5x5',
        level: '초중급 스트렝스',
        description: '가장 검증된 스트렝스 프로그램. 주 3회 전신 복합 다관절 운동으로 힘을 기릅니다.',
        exercises: [
          Exercise(id: 's1', name: '스쿼트', sets: 5, reps: 5, weight: 60),
          Exercise(id: 's2', name: '벤치프레스', sets: 5, reps: 5, weight: 40),
          Exercise(id: 's3', name: '바벨로우', sets: 5, reps: 5, weight: 40),
        ],
        icon: Icons.fitness_center,
        color: Colors.red,
      ),
      Program(
        title: '전신 무분할 기초',
        level: '초급자',
        description: '운동을 처음 시작하시나요? 기초 체력과 자세를 잡기에 가장 좋은 프로그램입니다.',
        exercises: [
          Exercise(id: 'b1', name: '스쿼트', sets: 3, reps: 10, weight: 40),
          Exercise(id: 'b2', name: '벤치프레스', sets: 3, reps: 10, weight: 30),
          Exercise(id: 'b3', name: '렛풀다운', sets: 3, reps: 12, weight: 25),
        ],
        icon: Icons.accessibility_new,
        color: Colors.green,
      ),
      Program(
        title: '상하체 2분할',
        level: '중급자',
        description: '부위별 집중도를 높이고 싶은 분들을 위한 효율적인 분할 루틴입니다.',
        exercises: [
          Exercise(id: 'm1', name: '벤치프레스', sets: 4, reps: 8, weight: 60),
          Exercise(id: 'm2', name: '바벨로우', sets: 4, reps: 8, weight: 50),
          Exercise(id: 'm3', name: '숄더프레스', sets: 3, reps: 10, weight: 30),
          Exercise(id: 'm4', name: '스쿼트', sets: 4, reps: 8, weight: 80),
        ],
        icon: Icons.flash_on,
        color: Colors.blue,
      ),
      Program(
        title: '전문 4분할',
        level: '고급자/보디빌딩',
        description: '가슴, 등, 어깨, 하체를 하루에 한 부위씩 완전히 고립 타격합니다.',
        exercises: [
          Exercise(id: 'a1', name: '가슴: 인클라인 벤치', sets: 4, reps: 10, weight: 70),
          Exercise(id: 'a2', name: '가슴: 덤벨 플라이', sets: 3, reps: 12, weight: 15),
          Exercise(id: 'a3', name: '가슴: 딥스', sets: 3, reps: 15, weight: 0),
        ],
        icon: Icons.workspace_premium,
        color: Colors.purple,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('추천 프로그램', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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

  Widget _buildProgramCard(BuildContext context, WidgetRef ref, Program program) {
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
                    Text(
                      program.level,
                      style: TextStyle(color: program.color, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Text(
                      program.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
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
                Text(
                  program.description,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // 1. 프로그램 적용 (상태 업데이트)
                      ref.read(workoutProvider.notifier).applyProgram(program.exercises);
                      
                      // 2. 피드백 및 이동
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${program.title} 루틴이 홈 화면에 적용되었습니다!'),
                          backgroundColor: program.color,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: program.color,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('이 프로그램으로 훈련 시작', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
