import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/workout_provider.dart';

class AICoachScreen extends ConsumerStatefulWidget {
  const AICoachScreen({super.key});

  @override
  ConsumerState<AICoachScreen> createState() => _AICoachScreenState();
}

class _AICoachScreenState extends ConsumerState<AICoachScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, String>> _messages = [
    {'role': 'assistant', 'content': '반갑습니다, 주인님! 오늘 운동은 어떠셨나요? 궁금한 점이나 분석이 필요하시면 말씀해 주세요.'}
  ];
  bool _isLoading = false;

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    final userMsg = _messageController.text;
    setState(() {
      _messages.add({'role': 'user', 'content': userMsg});
      _isLoading = true;
      _messageController.clear();
    });

    // 오늘의 운동 데이터(Context) 수집
    final exercises = ref.read(workoutProvider);
    String contextData = exercises.map((e) => 
      "${e.name}: ${e.weight}kg x ${e.sets}세트 (RPE: ${e.setRpe.join(',')})"
    ).join('\n');

    try {
      // ⚠️ 클라우드 서버 주소 반영
      // 실제 배포된 클라우드 주소로 변경
      final response = await http.post(
        Uri.parse('https://gains-and-guide-1.onrender.com/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': 'master_user',
          'message': userMsg,
          'context': contextData, // 이 데이터가 핵심입니다!
        }),
      ).timeout(const Duration(seconds: 60)); // 넉넉하게 60초 설정

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _messages.add({'role': 'assistant', 'content': data['response']});
        });
      } else {
        setState(() {
          _messages.add({'role': 'assistant', 'content': '죄송합니다, 주인님. 서버 응답에 문제가 있습니다. (에러 코드: ${response.statusCode})'});
        });
      }
    } catch (e) {
      // 👇 이 줄을 추가해서 안드로이드 스튜디오 하단 Run(또는 Debug) 콘솔창에 진짜 에러를 출력합니다!
      print('🚨🚨🚨 진짜 에러 원인: $e');
      setState(() {
        _messages.add({'role': 'assistant', 'content': '서버에 연결할 수 없습니다. Python 서버(main.py)가 켜져 있는지 확인해 주세요.'});
      });
    } finally {
      setState(() => _isLoading = false);
    }
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
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return _buildChatBubble(msg['content']!, isUser);
              },
            ),
          ),
          if (_isLoading) const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String content, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
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
          content,
          style: TextStyle(color: isUser ? Colors.white : Colors.black87),
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
