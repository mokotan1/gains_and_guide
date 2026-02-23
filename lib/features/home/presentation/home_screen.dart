import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_vibrate/flutter_vibrate.dart'; // vibration 대신 flutter_vibrate 권장
import '../../../core/workout_provider.dart';
import '../../../core/database/database_helper.dart';

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
  int _remainingSeconds = 0;
  bool _isWorkoutFinished = false;

  @override
  void dispose() {
    _cardioTimer?.cancel();
    super.dispose();
  }

  // --- 정산 및 AI 요청 (신체 프로필 반영) ---
  void _processAiRecommendation(List<Exercise> currentExercises) async {
    if (_isWorkoutFinished) return;

    // 로딩 팝업
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
          child: Card(child: Padding(padding: EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('AI 코치가 신체 정보를 바탕으로 분석 중...', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
          ])))
      ),
    );

    // DB에서 신체 프로필 가져오기
    final profile = await DatabaseHelper.instance.getProfile();
    String profilePrompt = profile != null
        ? "사용자 스펙: 체중 ${profile['weight']}kg, 골격근량 ${profile['muscle_mass']}kg. "
        : "";

    String summary = currentExercises.map((e) => "${e.name}: ${e.weight}kg x ${e.sets}세트 (RPE: ${e.setRpe.join(',')})").join('\n');

    try {
      final response = await http.post(
        Uri.parse('https://gains-and-guide-1.onrender.com/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': 'master_user',
          'message': '$profilePrompt 위 신체 정보를 고려해서 오늘 운동 강도가 적절했는지 분석하고 다음 무게를 추천해줘.',
          'context': summary,
        }),
      );

      Navigator.pop(context); // 로딩 팝업 닫기

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() => _isWorkoutFinished = true);
        _showResultDialog(data['response']);
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('서버 연결 실패')));
    }
  }

  void _showResultDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🤖 AI 코치 분석 결과', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: Text(message, style: const TextStyle(color: Colors.black))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(workoutProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Gains & Guide', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        actions: [
          if (!_isWorkoutFinished)
            IconButton(onPressed: () {}, icon: const Icon(Icons.add_circle, color: Colors.blue)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildExerciseList(exercises),
            const SizedBox(height: 24),
            _isWorkoutFinished
                ? _buildFinishedBanner()
                : (exercises.isNotEmpty ? _buildFinishButton(exercises) : const SizedBox.shrink()),
          ],
        ),
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
        itemBuilder: (context, idx) {
          final ex = exercises[idx];
          return Card(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              initiallyExpanded: true,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(ex.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                  if (!_isWorkoutFinished) // 삭제 기능 추가
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () => ref.read(workoutProvider.notifier).removeExercise(ex.id),
                    ),
                ],
              ),
              children: [
                Column(
                  children: List.generate(ex.sets, (sIdx) => ListTile(
                    title: Text('${ex.weight}kg / ${ex.reps}회', style: const TextStyle(color: Colors.black)),
                    trailing: Checkbox(
                      value: ex.setStatus[sIdx],
                      onChanged: _isWorkoutFinished ? null : (v) => ref.read(workoutProvider.notifier).toggleSet(idx, sIdx, 8),
                    ),
                  )),
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
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.all(16)),
        child: const Text('오늘의 훈련 종료 및 정산', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFinishedBanner() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(16)),
      child: const Column(children: [
        Icon(Icons.check_circle, color: Colors.green, size: 48),
        Text('오운완! 오늘 운동 끝', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
      ]),
    );
  }
}