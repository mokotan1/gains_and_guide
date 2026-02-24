import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  ChatNotifier() : super([
    {
      'role': 'assistant',
      'content': '반갑습니다, 주인님! 오늘 운동은 어떠셨나요? 궁금한 점이나 분석이 필요하시면 말씀해 주세요.',
      'routine': null
    }
  ]);

  void addMessage(Map<String, dynamic> message) {
    state = [...state, message];
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, List<Map<String, dynamic>>>((ref) => ChatNotifier());