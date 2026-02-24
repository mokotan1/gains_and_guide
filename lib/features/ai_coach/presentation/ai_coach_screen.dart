import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/workout_provider.dart';
import '../../routine/domain/exercise.dart';
import '../../../core/database/database_helper.dart';

class AICoachScreen extends ConsumerStatefulWidget {
  const AICoachScreen({super.key});

  @override
  ConsumerState<AICoachScreen> createState() => _AICoachScreenState();
}

class _AICoachScreenState extends ConsumerState<AICoachScreen> {
  final TextEditingController _messageController = TextEditingController();

  final List<Map<String, dynamic>> _messages = [
    {
      'role': 'assistant',
      'content': '반갑습니다, 주인님! 오늘 운동은 어떠셨나요? 궁금한 점이나 분석이 필요하시면 말씀해 주세요.',
      'routine': null
    }
  ];
  bool _isLoading = false;

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    final userMsg = _messageController.text;
    setState(() {
      _messages.add({'role': 'user', 'content': userMsg, 'routine': null});
      _isLoading = true;
      _messageController.clear();
    });

    // 💡 [핵심 수정] 빈 현재 상태가 아니라, DB에서 진짜 '과거 운동 기록'을 가져옵니다.
    final history = await DatabaseHelper.instance.getAllHistory();
    String contextData = "과거 운동 기록:\n";

    if (history.isEmpty) {
      contextData = "아직 저장된 과거 운동 기록이 없습니다. 오늘이 첫 운동입니다.";
    } else {
      // 너무 많은 데이터 전송을 막기 위해 최근 20개 세트 기록만 전달
      for (var h in history.take(20)) {
        String date = h['date'].toString().split(' ')[0]; // 날짜 부분만 추출
        contextData += "$date - ${h['name']}: ${h['weight']}kg x ${h['reps']}회 (${h['sets']}세트) RPE:${h['rpe']}\n";
      }
    }

    try {
      final response = await http.post(
        Uri.parse('https://gains-and-guide-1.onrender.com/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': 'master_user',
          'message': userMsg,
          'context': contextData, // 👈 실제 DB 기록이 AI에게 전달됨
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': data['response'] ?? '답변을 불러올 수 없습니다.',
            'routine': data['routine'],
          });
        });
      } else {
        setState(() {
          _messages.add({'role': 'assistant', 'content': '서버 응답 에러 (코드: ${response.statusCode})', 'routine': null});
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'content': '서버에 연결할 수 없습니다.', 'routine': null});
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 💡 루틴 내의 모든 운동을 홈 화면에 추가
  void _applyRoutine(Map<String, dynamic> routine) {
    final exercisesList = routine['exercises'] as List<dynamic>? ?? [];

    if (exercisesList.isEmpty) return;

    for (int i = 0; i < exercisesList.length; i++) {
      final ex = exercisesList[i];
      final newExercise = Exercise.initial(
        id: '${DateTime.now().millisecondsSinceEpoch}_$i',
        name: ex['name'] ?? '추천 운동',
        sets: ex['sets'] ?? 3,
        reps: ex['reps'] ?? 10,
        weight: (ex['weight'] ?? 0).toDouble(),
      );
      ref.read(workoutProvider.notifier).addExercise(newExercise);
    }

    final title = routine['title'] ?? '추천 루틴';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🔥 [$title]이(가) 홈 화면에 추가되었습니다!'),
        backgroundColor: Colors.blueAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('AI 전문 코치', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildChatBubble(_messages[index]);
              },
            ),
          ),
          if (_isLoading) const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> msg) {
    final isUser = msg['role'] == 'user';
    final routine = msg['routine'] as Map<String, dynamic>?;

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
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 0),
                bottomRight: Radius.circular(isUser ? 0 : 16),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
            ),
            child: Text(
              msg['content']?.toString() ?? '',
              style: TextStyle(color: isUser ? Colors.white : Colors.black87),
            ),
          ),
          // 루틴 데이터가 존재하면 '통합 루틴 카드' 띄우기
          if (!isUser && routine != null)
            _buildRoutineCard(routine),
        ],
      ),
    );
  }

  // 통합 루틴 카드 위젯
  Widget _buildRoutineCard(Map<String, dynamic> routine) {
    final title = routine['title'] ?? '맞춤형 추천 루틴';
    final exercises = routine['exercises'] as List<dynamic>? ?? [];

    // 최대 3개의 운동만 미리보기 텍스트로 보여줍니다.
    String exercisesPreview = '';
    for (int i = 0; i < exercises.length; i++) {
      if (i < 3) {
        exercisesPreview += '• ${exercises[i]['name']} (${exercises[i]['sets']}세트)\n';
      } else if (i == 3) {
        exercisesPreview += '외 ${exercises.length - 3}개 운동...';
        break;
      }
    }

    return GestureDetector(
      onTap: () => _applyRoutine(routine),
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade200, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF2563EB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                    exercisesPreview.trim(),
                    style: TextStyle(color: Colors.grey.shade800, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        '눌러서 전체 루틴 적용하기',
                        style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: '코치에게 질문하기...',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(30))),
                contentPadding: EdgeInsets.symmetric(horizontal: 20),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sendMessage,
            icon: const Icon(Icons.send, color: Color(0xFF2563EB)),
          ),
        ],
      ),
    );
  }
}