import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/workout_provider.dart';
import '../../../core/chat_provider.dart';
import '../../routine/domain/exercise.dart';
import '../../../core/database/database_helper.dart';

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

    ref.read(chatProvider.notifier).addMessage({'role': 'user', 'content': userMsg, 'routine': null});
    setState(() => _isLoading = true);
    _messageController.clear();

    final history = await DatabaseHelper.instance.getAllHistory();
    String contextData = history.isEmpty ? "기록 없음" : history.take(15).map((h) =>
    "${h['date'].toString().split(' ')[0]} - ${h['name']}: ${h['weight']}kg RPE:${h['rpe']}"
    ).join('\n');

    try {
      final response = await http.post(
        Uri.parse('https://gains-and-guide-1.onrender.com/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': 'master', 'message': userMsg, 'context': contextData}),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        ref.read(chatProvider.notifier).addMessage({'role': 'assistant', 'content': data['response'], 'routine': data['routine']});
      }
    } catch (e) {
      ref.read(chatProvider.notifier).addMessage({'role': 'assistant', 'content': '연결 실패. 서버를 확인해 주세요.', 'routine': null});
    } finally { if (mounted) setState(() => _isLoading = false); }
  }

  void _applyRoutine(Map<String, dynamic> routine) {
    final list = routine['exercises'] as List<dynamic>? ?? [];
    final newExs = list.asMap().entries.map((entry) => Exercise.initial(
      id: '${DateTime.now().millisecondsSinceEpoch}_${entry.key}',
      name: entry.value['name'], sets: entry.value['sets'], reps: entry.value['reps'], weight: (entry.value['weight']).toDouble(),
    )).toList();

    ref.read(workoutProvider.notifier).replaceRecommendedExercises(newExs);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🔥 루틴이 교체되었습니다!'), backgroundColor: Colors.blueAccent));
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