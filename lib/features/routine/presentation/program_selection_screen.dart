import 'package:flutter/material.dart';

class Program {
  final String title;
  final String level;
  final String description;
  final List<String> routines;
  final IconData icon;
  final Color color;

  Program({
    required this.title,
    required this.level,
    required this.description,
    required this.routines,
    required this.icon,
    required this.color,
  });
}

class ProgramSelectionScreen extends StatelessWidget {
  const ProgramSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Program> programs = [
      Program(
        title: '전신 무분할 기초',
        level: '초급자',
        description: '운동을 처음 시작하시나요? 기초 체력과 자세를 잡기에 가장 좋은 프로그램입니다.',
        routines: ['스쿼트', '벤치프레스', '데드리프트', '렛풀다운'],
        icon: Icons.fitness_center,
        color: Colors.green,
      ),
      Program(
        title: '상하체 2분할',
        level: '중급자',
        description: '부위별 집중도를 높이고 싶은 분들을 위한 효율적인 분할 루틴입니다.',
        routines: ['상체: 벤치프레스, 바벨로우, 숄더프레스', '하체: 스쿼트, 레그컬, 런지'],
        icon: Icons.flash_on,
        color: Colors.blue,
      ),
      Program(
        title: '부위별 3분할 (PPL)',
        level: '고급자',
        description: 'Push, Pull, Legs로 나누어 근육의 회복과 성장을 극대화하는 전문가용 루틴입니다.',
        routines: ['Push: 가슴/삼두/어깨', 'Pull: 등/이두', 'Legs: 하체/코어'],
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
          return _buildProgramCard(context, program);
        },
      ),
    );
  }

  Widget _buildProgramCard(BuildContext context, Program program) {
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
                const SizedBox(height: 12),
                const Text('주요 루틴:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: program.routines.map((r) => Chip(
                    label: Text(r, style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.grey[100],
                    side: BorderSide.none,
                  )).toList(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${program.title} 프로그램이 선택되었습니다!')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: program.color,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('프로그램 적용하기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
