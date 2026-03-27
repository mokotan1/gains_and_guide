import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/chat_provider.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/workout_provider.dart';
import '../../routine/domain/exercise.dart';

class AICoachScreen extends ConsumerStatefulWidget {
  const AICoachScreen({super.key});
  @override
  ConsumerState<AICoachScreen> createState() => _AICoachScreenState();
}

class _AICoachScreenState extends ConsumerState<AICoachScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;
    final userMsg = _messageController.text;

    ref
        .read(chatProvider.notifier)
        .addMessage({'role': 'user', 'content': userMsg, 'routine': null});
    setState(() => _isLoading = true);
    _messageController.clear();

    final aiCoachService = ref.read(aiCoachServiceProvider);
    final String personalizedContext = await _buildPersonalizedContext(userMsg);
    final String contextData = await aiCoachService.buildEnrichedContext(
      userMessage: userMsg,
      personalizedContext: personalizedContext,
    );

    try {
      final response = await http.post(
        Uri.parse('https://gains-and-guide-1.onrender.com/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': 'master',
          'message': userMsg,
          'context': contextData,
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        ref.read(chatProvider.notifier).addMessage({
          'role': 'assistant',
          'content': data['response'],
          'routine': data['routine'],
        });
      }
    } catch (e) {
      ref.read(chatProvider.notifier).addMessage({
        'role': 'assistant',
        'content': '연결 실패. 서버를 확인해 주세요.',
        'routine': null,
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// AI가 더 개인화된 루틴을 제안할 수 있도록,
  /// 프로필 + 최근 운동 히스토리 + 현재 루틴 요약을 하나의 컨텍스트 문자열로 구성한다.
  Future<String> _buildPersonalizedContext(String userMsg) async {
    final historyRepo = ref.read(workoutHistoryRepositoryProvider);
    final profileRepo = ref.read(bodyProfileRepositoryProvider);
    final exercises = ref.read(workoutProvider);

    final history = await historyRepo.getAllHistory();
    final profile = await profileRepo.getProfile();

    final buffer = StringBuffer();

    buffer.writeln('USER_PROFILE:');
    if (profile == null) {
      buffer.writeln('- profile_available: false');
    } else {
      buffer.writeln('- profile_available: true');
      buffer.writeln('- weight_kg: ${profile['weight']}');
      buffer.writeln('- muscle_mass_kg: ${profile['muscle_mass']}');
    }
    buffer.writeln();

    buffer.writeln('CURRENT_GOAL_AND_CONTEXT:');
    buffer.writeln(
        '- default_goal: strength_and_hypertrophy (근비대 + 중량 향상)');
    buffer.writeln('- weekly_target_sessions: 3');
    buffer.writeln('- user_message: "$userMsg"');
    buffer.writeln();

    buffer.writeln('RECENT_WORKOUT_HISTORY (최근 최대 20세트):');
    if (history.isEmpty) {
      buffer.writeln('- no_history: true');
    } else {
      for (final h in history.take(20)) {
        final date = h['date'].toString().split(' ').first;
        buffer.writeln(
            '- $date | ${h['name']} | set ${h['sets']} | ${h['reps']} reps @ ${h['weight']}kg | RPE: ${h['rpe']}');
      }
    }
    buffer.writeln();

    buffer.writeln('PER_EXERCISE_SUMMARY (최근 기록 기준):');
    if (history.isNotEmpty) {
      final Map<String, Map<String, dynamic>> summary = {};
      for (final h in history) {
        final name = (h['name'] ?? '').toString();
        if (name.isEmpty) continue;
        final key = name;
        summary.putIfAbsent(key, () {
          return {
            'last_date': h['date'].toString().split(' ').first,
            'last_weight': (h['weight'] as num?)?.toDouble() ?? 0.0,
            'last_rpe': (h['rpe'] as num?)?.toDouble() ?? 0.0,
            'total_sets': 0,
          };
        });
        summary[key]!['total_sets'] =
            (summary[key]!['total_sets'] as int) + 1;
      }

      summary.forEach((name, s) {
        buffer.writeln(
            '- $name | last_date: ${s['last_date']} | last_weight_kg: ${s['last_weight']} | last_rpe: ${s['last_rpe']} | total_sets: ${s['total_sets']}');
      });
    } else {
      buffer.writeln('- no_exercise_summary: true');
    }
    buffer.writeln();

    buffer.writeln('TODAY_PLAN (현재 앱에 세팅된 루틴):');
    if (exercises.isEmpty) {
      buffer.writeln('- no_plan: true');
    } else {
      for (final ex in exercises) {
        buffer.writeln(
            '- ${ex.name} | sets: ${ex.sets} | reps: ${ex.reps} | weight_kg: ${ex.weight} | is_cardio: ${ex.isCardio} | is_bodyweight: ${ex.isBodyweight}');
      }
    }

    return buffer.toString();
  }

  Future<void> _applyRoutine(Map<String, dynamic> routine) async {
    final list = routine['exercises'] as List<dynamic>? ?? [];
    List<Exercise> newExs = [];

    for (var i = 0; i < list.length; i++) {
      final entry = list[i];
      final String name = entry['name'];
      
      final catalogRepo = ref.read(exerciseCatalogRepositoryProvider);
      final results = await catalogRepo.search(name);
      
      if (results.isNotEmpty) {
        // 정확히 일치하는 이름을 찾거나, 첫 번째 결과 사용
        final catalog = results.firstWhere(
          (e) => e.name.toLowerCase() == name.toLowerCase(),
          orElse: () => results.first,
        );
        
        newExs.add(Exercise.initial(
          id: '${DateTime.now().millisecondsSinceEpoch}_$i',
          name: catalog.name, // DB의 정확한 이름 사용
          sets: entry['sets'],
          reps: entry['reps'],
          weight: (entry['weight'] ?? 0).toDouble(),
        ));
      } else {
        // DB에 없으면 AI가 준 이름 그대로 생성
        newExs.add(Exercise.initial(
          id: '${DateTime.now().millisecondsSinceEpoch}_$i',
          name: name,
          sets: entry['sets'],
          reps: entry['reps'],
          weight: (entry['weight'] ?? 0).toDouble(),
        ));
      }
    }

    if (newExs.isNotEmpty) {
      ref.read(workoutProvider.notifier).replaceRecommendedExercises(newExs);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🔥 루틴이 교체되었습니다!'), backgroundColor: Colors.blueAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(title: const Text('AI 전문 코치', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0),
      body: Column(
        children: [
          Expanded(child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: messages.length, itemBuilder: (context, i) => _buildChatBubble(messages[i]))),
          if (_isLoading) const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> msg) {
    final isUser = msg['role'] == 'user';
    final routine = msg['routine'];
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isUser ? const Color(0xFF2563EB) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(msg['content'] ?? '', style: TextStyle(color: isUser ? Colors.white : Colors.black87)),
          ),
          if (!isUser && routine != null) GestureDetector(onTap: () => _applyRoutine(routine), child: _buildRoutineCard(routine)),
        ],
      ),
    );
  }

  Widget _buildRoutineCard(Map<String, dynamic> r) {
    return Container(
      width: 260, margin: const EdgeInsets.symmetric(vertical: 8), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blue.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r['title'] ?? '추천 루틴', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          const Divider(),
          Text((r['exercises'] as List).map((e) => "• ${e['name']}").join('\n')),
          const SizedBox(height: 8),
          const Center(child: Text('클릭하여 루틴 적용', style: TextStyle(fontSize: 12, color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16), color: Colors.white,
      child: Row(children: [
        Expanded(child: TextField(controller: _messageController, decoration: const InputDecoration(hintText: '질문하기...', border: InputBorder.none))),
        IconButton(icon: const Icon(Icons.send, color: Color(0xFF2563EB)), onPressed: _sendMessage),
      ]),
    );
  }
}