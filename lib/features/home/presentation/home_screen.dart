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
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _cardioTimer;
  Timer? _restTimer;
  int _remainingSeconds = 0;
  int _selectedRestTime = 180;
  bool _isWorkoutFinished = false;

  @override
  void dispose() {
    _cardioTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  // --- 유틸리티 및 체크 로직 ---
  bool _checkIsCardio(String name) =>
      name.contains('런닝머신') || name.contains('사이클') || name.contains('유산소');

  bool _checkIsBodyweight(String name) {
    const keywords = ['풀업', '턱걸이', '푸쉬업', '팔굽혀펴기', '딥스', '맨몸', '플랭크'];
    return keywords.any((k) => name.contains(k));
  }

  // --- CSV 데이터 생성 로직 (보정 데이터 포함) ---
  Future<String> _generateWorkoutCsv(List<Exercise> currentExercises) async {
    // 1. 헤더 설정
    String csv = "date,name,weight,sets,reps,rpe_list\n";

    // 2. 요청하신 2025년 2월 23일 보정 데이터 강제 포함
    csv += "2025-02-23,스쿼트,100,5,5,8|8|8|9|9\n";
    csv += "2025-02-23,벤치프레스,80,5,5,7|8|8|8|8\n";
    csv += "2025-02-23,바벨로우,80,5,5,8|8|8|8|9\n";

    // 3. 오늘의 실시간 기록 추가
    String today = DateTime.now().toString().split(' ')[0];
    for (var ex in currentExercises) {
      // 완료된 세트의 RPE만 추출
      String rpes = ex.setRpe.asMap().entries
          .where((entry) => ex.setStatus[entry.key])
          .map((entry) => entry.value ?? 8)
          .join('|');

      csv += "$today,${ex.name},${ex.weight},${ex.sets},${ex.reps},$rpes\n";
    }
    return csv;
  }

  // --- 다이얼로그 및 팝업 로직 ---
  void _showCardioSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('유산소 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.directions_bike, color: AppTheme.warningOrange),
              title: const Text('실내 사이클'),
              onTap: () { _addExercise(name: '실내 사이클', isCardio: true); Navigator.pop(context); },
            ),
            ListTile(
              leading: const Icon(Icons.directions_run, color: AppTheme.warningOrange),
              title: const Text('런닝머신'),
              onTap: () { _addExercise(name: '런닝머신', isCardio: true); Navigator.pop(context); },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExerciseDialog() {
    final nameCont = TextEditingController();
    final weightCont = TextEditingController(text: '0.0');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('새 운동 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCont,
                decoration: const InputDecoration(labelText: '운동 이름'),
                onChanged: (val) async {
                  if (_checkIsBodyweight(val)) {
                    final profile = await DatabaseHelper.instance.getProfile();
                    if (profile != null) {
                      setDialogState(() => weightCont.text = profile['weight'].toString());
                    }
                  }
                },
              ),
              TextField(
                controller: weightCont,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '무게 (kg)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                if (nameCont.text.isNotEmpty) {
                  _addExercise(
                    name: nameCont.text,
                    weight: double.tryParse(weightCont.text) ?? 0,
                    isBodyweight: _checkIsBodyweight(nameCont.text),
                    isCardio: _checkIsCardio(nameCont.text),
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  void _addExercise({required String name, double weight = 0, int sets = 3, int reps = 10, bool isBodyweight = false, bool isCardio = false}) {
    ref.read(workoutProvider.notifier).addExercise(Exercise.initial(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      sets: isCardio ? 1 : sets,
      reps: isCardio ? 30 : reps,
      weight: weight,
      isBodyweight: isBodyweight,
      isCardio: isCardio,
    ));
  }

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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          _cardioTimer?.cancel();
          _cardioTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (_remainingSeconds > 0) { if (mounted) setDialogState(() => _remainingSeconds--); }
            else { timer.cancel(); _onCardioTimerEnd(exIdx, sIdx); Navigator.pop(context); }
          });
          return AlertDialog(
            title: Center(child: Text('${ex.name} 중...')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: AppTheme.warningOrange)),
                const SizedBox(height: 10),
                const Text('지방이 타고 있습니다!', style: TextStyle(color: Colors.black54)),
              ],
            ),
            actions: [Center(child: TextButton(onPressed: () { _cardioTimer?.cancel(); ref.read(workoutProvider.notifier).toggleSet(exIdx, sIdx, 5); Navigator.pop(context); }, child: const Text('운동 종료', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))))],
          );
        },
      ),
    );
  }

  void _onCardioTimerEnd(int exIdx, int sIdx) {
    ref.read(workoutProvider.notifier).toggleSet(exIdx, sIdx, 5);
    Vibrate.vibrate();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 목표 유산소 달성!'), backgroundColor: AppTheme.warningOrange));
  }

  void _showRpeAndTimerSequence(int exIdx, int sIdx, List<Exercise> exercises) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('${exercises[exIdx].name} 완료!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('체감 강도(RPE)를 선택하세요.'),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
              children: List.generate(10, (index) {
                int rpe = index + 1;
                return InkWell(
                  onTap: () {
                    ref.read(workoutProvider.notifier).toggleSet(exIdx, sIdx, rpe);
                    Navigator.pop(context);
                    if (sIdx < exercises[exIdx].sets - 1) _showRestTimerPopup();
                  },
                  child: Container(
                    width: 40, height: 40,
                    decoration: const BoxDecoration(color: AppTheme.primaryBlue, shape: BoxShape.circle),
                    child: Center(child: Text('$rpe', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _showRestTimerPopup() {
    _remainingSeconds = _selectedRestTime;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          _restTimer?.cancel();
          _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (_remainingSeconds > 0) { if (mounted) setDialogState(() => _remainingSeconds--); }
            else { timer.cancel(); Navigator.pop(context); }
          });
          return AlertDialog(
            title: const Center(child: Text('휴식 타이머')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _restOption(setDialogState, '2분', 120),
                  _restOption(setDialogState, '3분', 180),
                  _restOption(setDialogState, '5분', 300),
                ]),
              ],
            ),
            actions: [Center(child: TextButton(onPressed: () { _restTimer?.cancel(); Navigator.pop(context); }, child: const Text('건너뛰기', style: TextStyle(color: Colors.red))))],
          );
        },
      ),
    );
  }

  Widget _restOption(StateSetter setDialogState, String label, int seconds) {
    bool isSel = _selectedRestTime == seconds;
    return InkWell(
      onTap: () => setDialogState(() { _selectedRestTime = seconds; _remainingSeconds = seconds; }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: isSel ? AppTheme.primaryBlue : Colors.grey[200], borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: isSel ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- CSV 기반 AI 정산 ---
  void _processAiRecommendation(List<Exercise> currentExercises) async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: Card(child: Padding(padding: EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('CSV 데이터를 분석 중입니다...')])))));

    final profile = await DatabaseHelper.instance.getProfile();
    String pInfo = profile != null ? "사용자 체중: ${profile['weight']}kg. " : "";

    // CSV 생성 (2/23 기록 포함)
    String fullCsv = await _generateWorkoutCsv(currentExercises);

    try {
      final response = await http.post(
        Uri.parse('https://gains-and-guide-1.onrender.com/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': 'master_user',
          'message': '$pInfo 첨부된 CSV 데이터(과거 및 오늘 기록)를 분석해서 가이드를 줘.',
          'context': fullCsv,
        }),
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() => _isWorkoutFinished = true);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('🤖 AI 코치 분석 결과'),
            content: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('📍 전송된 CSV 로그', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                Container(padding: const EdgeInsets.all(8), color: Colors.grey[100], child: Text(fullCsv, style: const TextStyle(fontSize: 10))),
                const Divider(height: 30),
                Text(data['response']),
              ]),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
          ),
        );
      }
    } catch (e) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('서버 연결 실패'))); }
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(workoutProvider);
    int totalSets = 0, completedSets = 0;
    for (var ex in exercises) {
      totalSets += ex.sets;
      completedSets += ex.setStatus.where((s) => s).length;
    }
    final bool isAllSetsDone = totalSets > 0 && completedSets == totalSets;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gains & Guide'),
        actions: [
          if (!_isWorkoutFinished) ...[
            IconButton(onPressed: _showCardioSelectionDialog, icon: const Icon(Icons.directions_run, color: AppTheme.warningOrange)),
            IconButton(onPressed: _showAddExerciseDialog, icon: const Icon(Icons.add_circle, color: AppTheme.primaryBlue)),
          ]
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildProgressCard(completedSets, totalSets),
            const SizedBox(height: 16),
            _buildExerciseList(exercises),
            const SizedBox(height: 24),
            if (_isWorkoutFinished) _buildFinishedBanner()
            else if (isAllSetsDone) _buildFinishButton(exercises)
            else if (exercises.isNotEmpty) _buildIncompleteMessage(completedSets, totalSets)
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(int comp, int tot) {
    double per = tot == 0 ? 0 : comp / tot;
    return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('오늘의 운동 달성도', style: TextStyle(fontWeight: FontWeight.bold)),
        Text('$comp / $tot 세트', style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold))
      ]),
      const SizedBox(height: 12),
      LinearProgressIndicator(value: per, backgroundColor: Colors.grey[200], color: AppTheme.successGreen, minHeight: 8),
    ])));
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
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              initiallyExpanded: true,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(ex.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  if (!_isWorkoutFinished)
                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => ref.read(workoutProvider.notifier).removeExercise(ex.id)),
                ],
              ),
              subtitle: Text(ex.isCardio ? '${ex.reps}분 수행' : '${ex.sets}세트 | ${ex.reps}회 | ${ex.weight}kg'),
              children: List.generate(ex.sets, (sIdx) => ListTile(
                title: Text(ex.isCardio ? '목표 시간: ${ex.reps}분' : '${ex.weight}kg / ${ex.reps}회'),
                trailing: Checkbox(
                  value: ex.setStatus[sIdx],
                  onChanged: _isWorkoutFinished ? null : (v) => _toggleSetStatus(idx, sIdx, exercises),
                ),
              )),
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
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('오늘의 훈련 종료 및 정산', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildIncompleteMessage(int comp, int tot) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
      child: Text('남은 세트를 모두 완료하면 정산 버튼이 나타납니다. ($comp/$tot)', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildFinishedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(16)),
      child: const Column(children: [
        Icon(Icons.check_circle, color: AppTheme.successGreen, size: 48),
        SizedBox(height: 8),
        Text('오운완! 오늘 운동 끝', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.successGreen)),
      ]),
    );
  }
}