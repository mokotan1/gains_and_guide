import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_vibrate/flutter_vibrate.dart';
import '../../../core/workout_provider.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../routine/domain/exercise.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _cardioTimer; Timer? _restTimer;
  int _remainingSeconds = 0; int _selectedRestTime = 180;
  bool _isWorkoutFinished = false;

  @override void dispose() { _cardioTimer?.cancel(); _restTimer?.cancel(); super.dispose(); }

  // --- CSV 데이터 생성 로직 ---
  Future<String> _generateWorkoutCsv(List<Exercise> currentExercises) async {
    // 1. 헤더 설정
    String csv = "date,name,weight,sets,reps,rpe_list\n";

    // 2. 2월 23일 보정 데이터 (수동 삽입)
    csv += "2025-02-23,스쿼트,100,5,5,8|8|8|9|9\n";
    csv += "2025-02-23,벤치프레스,80,5,5,7|8|8|8|8\n";
    csv += "2025-02-23,바벨로우,80,5,5,8|8|8|8|9\n";

    // 3. DB에 저장된 과거 모든 기록 추가
    final history = await DatabaseHelper.instance.getAllHistory();
    for (var row in history) {
      csv += "${row['date']},${row['name']},${row['weight']},${row['sets']},${row['reps']},${row['setRpe']}\n";
    }

    // 4. 오늘의 실시간 기록 추가
    String today = DateTime.now().toString().split(' ')[0];
    for (var ex in currentExercises) {
      csv += "$today,${ex.name},${ex.weight},${ex.sets},${ex.reps},${ex.setRpe.join('|')}\n";
    }

    return csv;
  }

  // --- CSV 전송 및 정산 ---
  void _processAiRecommendation(List<Exercise> currentExercises) async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));

    final profile = await DatabaseHelper.instance.getProfile();
    String pStr = profile != null ? "체중:${profile['weight']}kg " : "";

    // CSV 생성
    String fullCsv = await _generateWorkoutCsv(currentExercises);

    try {
      final response = await http.post(
        Uri.parse('https://gains-and-guide-1.onrender.com/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': 'master_user',
          'message': '$pStr 첨부한 CSV 운동 기록 전체를 파싱해서 내 성장도를 분석하고 가이드를 줘.',
          'context': fullCsv, // CSV를 컨텍스트로 전송
        }),
      );

      Navigator.pop(context); // 로딩 닫기

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() => _isWorkoutFinished = true);

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('🤖 CSV 기반 AI 정산 완료'),
            content: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('📍 전송된 CSV 데이터 요약', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                const Text('2/23 보정치 및 과거 기록 포함됨', style: TextStyle(fontSize: 11)),
                const Divider(),
                Text(data['response']),
              ]),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
          ),
        );
      }
    } catch (e) { Navigator.pop(context); }
  }

  // --- UI 컴포넌트들 (유산소 타이머, 체크박스 등) ---
  void _toggleSetStatus(int exIdx, int sIdx, List<Exercise> exercises) {
    if (_isWorkoutFinished) return;
    final ex = exercises[exIdx];
    if (ex.setStatus[sIdx]) {
      if (ex.isCardio) _cardioTimer?.cancel();
      ref.read(workoutProvider.notifier).toggleSet(exIdx, sIdx, null);
    } else {
      if (ex.isCardio) { _showCardioTimerPopup(exIdx, sIdx, ex); }
      else { _showRpeAndTimerSequence(exIdx, sIdx, exercises); }
    }
  }

  void _showCardioTimerPopup(int exIdx, int sIdx, Exercise ex) {
    _remainingSeconds = ex.reps * 60;
    showDialog(context: context, barrierDismissible: false, builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
      _cardioTimer?.cancel();
      _cardioTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds > 0) { if (mounted) setDialogState(() => _remainingSeconds--); }
        else { timer.cancel(); Vibrate.vibrate(); Navigator.pop(context); }
      });
      return AlertDialog(title: Center(child: Text('${ex.name} 중...')), content: Text('${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.orange), textAlign: TextAlign.center));
    }));
  }

  void _showRpeAndTimerSequence(int exIdx, int sIdx, List<Exercise> exercises) {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('RPE 선택'), content: Wrap(spacing: 10, children: List.generate(10, (i) => InkWell(onTap: () {
      ref.read(workoutProvider.notifier).toggleSet(exIdx, sIdx, i+1);
      Navigator.pop(context);
      if (sIdx < exercises[exIdx].sets - 1) _showRestTimerPopup();
    }, child: CircleAvatar(child: Text('${i+1}')))))));
  }

  void _showRestTimerPopup() {
    _remainingSeconds = _selectedRestTime;
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
      _restTimer?.cancel();
      _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds > 0) { if (mounted) setDialogState(() => _remainingSeconds--); }
        else { timer.cancel(); Navigator.pop(context); }
      });
      return AlertDialog(title: const Center(child: Text('휴식 타이머')), content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.blue)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          ElevatedButton(onPressed: () => setDialogState(() => _remainingSeconds = 120), child: const Text('2분')),
          ElevatedButton(onPressed: () => setDialogState(() => _remainingSeconds = 180), child: const Text('3분')),
          ElevatedButton(onPressed: () => setDialogState(() => _remainingSeconds = 300), child: const Text('5분')),
        ])
      ]));
    }));
  }

  @override Widget build(BuildContext context) {
    final exercises = ref.watch(workoutProvider);
    int tot = 0, comp = 0;
    for (var ex in exercises) { tot += ex.sets; comp += ex.setStatus.where((s) => s).length; }

    return Scaffold(
      appBar: AppBar(title: const Text('Gains & Guide'), actions: [
        if (!_isWorkoutFinished) IconButton(icon: const Icon(Icons.add_circle), onPressed: () {})
      ]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        LinearProgressIndicator(value: tot == 0 ? 0 : comp / tot),
        const SizedBox(height: 16),
        ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: exercises.length, itemBuilder: (context, idx) {
          final ex = exercises[idx];
          return Card(child: ExpansionTile(initiallyExpanded: true, title: Text(ex.name), children: List.generate(ex.sets, (sIdx) => ListTile(
            title: Text('${ex.weight}kg x ${ex.reps}회'),
            trailing: Checkbox(value: ex.setStatus[sIdx], onChanged: _isWorkoutFinished ? null : (v) => _toggleSetStatus(idx, sIdx, exercises)),
          ))));
        }),
        const SizedBox(height: 20),
        if (tot > 0 && comp == tot && !_isWorkoutFinished)
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => _processAiRecommendation(exercises), child: const Text('오늘의 운동 정산하기')))
        else if (_isWorkoutFinished) const Text('오운완! 🎉', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green))
      ])),
    );
  }
}