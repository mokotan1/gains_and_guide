import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:path_provider/path_provider.dart';
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

  @override
  void dispose() {
    _cardioTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  bool _checkIsCardio(String name) =>
      name.contains('런닝머신') || name.contains('사이클') || name.contains('유산소');

  bool _checkIsBodyweight(String name) {
    const keywords = ['풀업', '턱걸이', '푸쉬업', '팔굽혀펴기', '딥스', '맨몸', '플랭크'];
    return keywords.any((k) => name.contains(k));
  }

  // --- CSV 데이터 생성 로직 ---
  Future<String> _generateWorkoutCsv(List<Exercise> currentExercises) async {
    String csv = "date,name,weight,sets,reps,rpe_list\n";
    final history = await DatabaseHelper.instance.getAllHistory();

    Map<String, Map<String, List<Map<String, dynamic>>>> grouped = {};
    for (var row in history) {
      String date = row['date'].toString().substring(0, 10);
      String name = row['name'];
      grouped.putIfAbsent(date, () => {});
      grouped[date]!.putIfAbsent(name, () => []);
      grouped[date]![name]!.add(row);
    }

    grouped.forEach((date, exercises) {
      exercises.forEach((name, sets) {
        double weight = sets.first['weight'];
        int reps = sets.first['reps'];
        String rpes = sets.map((s) => s['rpe'] ?? 8).join('|');
        csv += "$date,$name,$weight,${sets.length},$reps,$rpes\n";
      });
    });

    String today = DateTime.now().toString().split(' ')[0];
    if (!grouped.containsKey(today)) {
      for (var ex in currentExercises) {
        String rpes = ex.setRpe.asMap().entries
            .where((entry) => ex.setStatus[entry.key])
            .map((entry) => entry.value ?? 8)
            .join('|');
        if (rpes.isNotEmpty) {
          csv += "$today,${ex.name},${ex.weight},${ex.sets},${ex.reps},$rpes\n";
        }
      }
    }
    return csv;
  }

  // --- UI 알림 및 다이얼로그 메서드 ---
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('데이터를 분석 중입니다...', style: TextStyle(fontWeight: FontWeight.bold))
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAiResultDialog(String response) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🤖 AI 코치 분석 결과'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(response),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
      ),
    );
  }

  // --- 핵심 정산 및 분석 로직 ---
  void _processAiRecommendation(List<Exercise> currentExercises) async {
    _showLoadingDialog();
    try {
      // 1. 오늘의 기록 저장
      await ref.read(workoutProvider.notifier).saveCurrentWorkoutToHistory();
      await _exportHistoryToCsv();

      // 2. 프로필 및 데이터 준비
      final profile = await DatabaseHelper.instance.getProfile();
      String pInfo = profile != null ? "사용자 체중: ${profile['weight']}kg. " : "";
      String fullCsv = await _generateWorkoutCsv(currentExercises);

      // 3. AI 서버 요청
      final response = await http.post(
        Uri.parse('https://gains-and-guide-1.onrender.com/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': 'master_user',
          'message': '$pInfo 오늘 운동 기록을 분석하고 증량 가이드 데이터를 포함해서 줘.',
          'context': fullCsv,
        }),
      ).timeout(const Duration(seconds: 60));

      if (!mounted) return;
      Navigator.pop(context); // 로딩창 닫기

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        // AI가 제안한 증량 데이터를 실제 주간 루틴에 자동 반영
        if (data['progression'] != null) {
          await ref.read(workoutProvider.notifier).applyProgression(data['progression']);
        }

        ref.read(workoutProvider.notifier).finishWorkout();
        _showAiResultDialog(data['response']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('서버 오류: ${response.statusCode}'))
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('정산 중 오류가 발생했습니다. 다시 시도해 주세요.'), backgroundColor: Colors.red),
      );
    }
  }

  // --- 운동 추가 및 제어 로직 ---
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

  void _showAddExerciseDialog() async {
    // 1. DB에서 운동 카탈로그 데이터 비동기 조회
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> catalog = await db.query('exercise_catalog');

    // 2. 부위별 데이터 파싱 및 분류 (기본 운동 포함하여 누락 방지)
    final Map<String, Set<String>> rawExerciseData = {
      '가슴': {'플랫 벤치 프레스', '인클라인 벤치 프레스', '덤벨 프레스', '펙 덱 플라이', '푸쉬업', '케이블 크로스오버'},
      '등': {'컨벤셔널 데드리프트', '루마니안 데드리프트', '펜들레이 로우', '바벨 로우', '랫 풀다운', '풀업', '시티드 로우'},
      '하체': {'백 스쿼트', '프론트 스쿼트', '레그 프레스', '레그 익스텐션', '레그 컬', '런지', '카프 레이즈'},
      '어깨': {'오버헤드 프레스 (OHP)', '덤벨 숄더 프레스', '사이드 레터럴 레이즈', '프론트 레이즈', '페이스 풀'},
      '팔': {'바벨 컬', '덤벨 컬', '해머 컬', '트라이셉스 푸쉬다운', '오버헤드 트라이셉스 익스텐션'},
      '복근': {'크런치', '레그 레이즈', '플랭크', '케이블 크런치'},
      '기타': {},
      '유산소': {'런닝머신', '실내 사이클', '스텝밀(천국의 계단)'},
    };

    // 카탈로그 데이터를 분석하여 해당 부위에 추가
    for (var row in catalog) {
      final name = row['name']?.toString() ?? 'Unknown';
      final muscles = (row['primary_muscles']?.toString() ?? '').toLowerCase();
      final category = (row['category']?.toString() ?? '').toLowerCase();

      if (category.contains('cardio')) {
        rawExerciseData['유산소']!.add(name);
        continue;
      }

      bool matched = false;
      if (muscles.contains('chest')) { rawExerciseData['가슴']!.add(name); matched = true; }
      if (muscles.contains('lats') || muscles.contains('middle back') || muscles.contains('lower back') || muscles.contains('back')) { rawExerciseData['등']!.add(name); matched = true; }
      if (muscles.contains('quadriceps') || muscles.contains('hamstrings') || muscles.contains('glutes') || muscles.contains('calves') || muscles.contains('legs')) { rawExerciseData['하체']!.add(name); matched = true; }
      if (muscles.contains('shoulders') || muscles.contains('delts')) { rawExerciseData['어깨']!.add(name); matched = true; }
      if (muscles.contains('biceps') || muscles.contains('triceps') || muscles.contains('forearms') || muscles.contains('arms')) { rawExerciseData['팔']!.add(name); matched = true; }
      if (muscles.contains('abs') || muscles.contains('core')) { rawExerciseData['복근']!.add(name); matched = true; }

      // 해당하는 부위가 없으면 '기타' 카테고리로 분류
      if (!matched) {
        rawExerciseData['기타']!.add(name);
      }
    }

    // 3. 비어있는 카테고리 제거 및 리스트 변환 후 가나다/알파벳순 정렬
    final Map<String, List<String>> exerciseData = {};
    rawExerciseData.forEach((key, value) {
      if (value.isNotEmpty) {
        final list = value.toList()..sort();
        exerciseData[key] = list;
      }
    });

    if (!mounted) return;

    String? selectedCategory;
    String? selectedExercise;
    double weight = 0.0;
    int sets = 3;
    int reps = 10;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // 숫자 조절용 커스텀 위젯 (+ / - 버튼)
          Widget buildCounter(String label, String valueStr, VoidCallback onDec, VoidCallback onInc) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    IconButton(
                      onPressed: onDec,
                      icon: const Icon(Icons.remove_circle_outline, color: AppTheme.primaryBlue),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 12),
                    Text(valueStr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: onInc,
                      icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryBlue),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            );
          }

          return AlertDialog(
            title: const Text('새 운동 추가'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 부위 선택 드롭다운
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: '운동 부위',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    value: selectedCategory,
                    items: exerciseData.keys.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setDialogState(() {
                        selectedCategory = newValue;
                        selectedExercise = null; // 부위 변경 시 운동명 초기화
                        if (newValue == '유산소') {
                          sets = 1;
                          reps = 30; // 30분 기본값
                          weight = 0.0;
                        } else {
                          sets = 3;
                          reps = 10;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // 2. 운동명 선택 드롭다운
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: '운동명',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    value: selectedExercise,
                    isExpanded: true,
                    items: selectedCategory == null
                        ? []
                        : exerciseData[selectedCategory]!.map((String exercise) {
                      return DropdownMenuItem<String>(
                        value: exercise,
                        child: Text(exercise, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (String? newValue) async {
                      selectedExercise = newValue;
                      // 맨몸 운동일 경우 사용자의 몸무게를 자동으로 가져옴
                      if (newValue != null && _checkIsBodyweight(newValue)) {
                        final profile = await DatabaseHelper.instance.getProfile();
                        if (profile != null) {
                          weight = (profile['weight'] as num).toDouble();
                        }
                      } else if (selectedCategory == '유산소') {
                        weight = 0.0;
                      }
                      setDialogState(() {});
                    },
                    hint: const Text('부위를 먼저 선택하세요'),
                  ),
                  const SizedBox(height: 24),

                  // 3. 조절 패널 (운동이 선택되었을 때만 표시)
                  if (selectedExercise != null) ...[
                    // 무게 조절
                    if (selectedCategory != '유산소' && !_checkIsBodyweight(selectedExercise!)) ...[
                      buildCounter(
                          '무게 (kg)',
                          weight.toStringAsFixed(1),
                              () => setDialogState(() => weight = (weight - 2.5).clamp(0.0, 500.0)),
                              () => setDialogState(() => weight += 2.5)
                      ),
                      const SizedBox(height: 16),
                    ],
                    // 세트 및 횟수 조절
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (selectedCategory != '유산소')
                          buildCounter(
                              '세트',
                              '$sets',
                                  () => setDialogState(() => sets = (sets - 1).clamp(1, 20)),
                                  () => setDialogState(() => sets += 1)
                          ),
                        buildCounter(
                            selectedCategory == '유산소' ? '목표 시간 (분)' : '횟수',
                            '$reps',
                                () => setDialogState(() => reps = (reps - 1).clamp(1, 100)),
                                () => setDialogState(() => reps += 1)
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
              ElevatedButton(
                onPressed: selectedExercise == null ? null : () {
                  _addExercise(
                    name: selectedExercise!,
                    weight: weight,
                    sets: sets,
                    reps: reps,
                    isBodyweight: _checkIsBodyweight(selectedExercise!),
                    isCardio: selectedCategory == '유산소',
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('추가'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _addExercise({
    required String name,
    double weight = 0,
    int sets = 3,
    int reps = 10,
    bool isBodyweight = false,
    bool isCardio = false,
  }) {
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
    if (ref.read(workoutProvider.notifier).isFinished) return;
    final ex = exercises[exIdx];
    if (ex.setStatus[sIdx]) {
      if (ex.isCardio) _cardioTimer?.cancel();
      ref.read(workoutProvider.notifier).toggleSet(exIdx, sIdx, null);
    } else {
      if (ex.isCardio) {
        _showCardioTimerPopup(exIdx, sIdx, ex);
      } else {
        _showRpeAndTimerSequence(exIdx, sIdx, exercises);
      }
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
            if (_remainingSeconds > 0) {
              if (mounted) setDialogState(() => _remainingSeconds--);
            } else {
              timer.cancel();
              _onCardioTimerEnd(exIdx, sIdx);
              Navigator.pop(context);
            }
          });
          return AlertDialog(
            title: Center(child: Text('${ex.name} 중...')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: AppTheme.warningOrange),
                ),
                const SizedBox(height: 10),
                const Text('지방이 타고 있습니다!', style: TextStyle(color: Colors.black54)),
              ],
            ),
            actions: [
              Center(
                child: TextButton(
                  onPressed: () {
                    _cardioTimer?.cancel();
                    ref.read(workoutProvider.notifier).toggleSet(exIdx, sIdx, 5);
                    Navigator.pop(context);
                  },
                  child: const Text('운동 종료', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  void _onCardioTimerEnd(int exIdx, int sIdx) {
    ref.read(workoutProvider.notifier).toggleSet(exIdx, sIdx, 5);
    Vibrate.vibrate();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 목표 유산소 달성!'), backgroundColor: AppTheme.warningOrange),
      );
    }
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
            if (_remainingSeconds > 0) {
              if (mounted) setDialogState(() => _remainingSeconds--);
            } else {
              timer.cancel();
              Navigator.pop(context);
            }
          });
          return AlertDialog(
            title: const Center(child: Text('휴식 타이머')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _restOption(setDialogState, '2분', 120),
                    _restOption(setDialogState, '3분', 180),
                    _restOption(setDialogState, '5분', 300),
                  ],
                ),
              ],
            ),
            actions: [
              Center(
                child: TextButton(
                  onPressed: () {
                    _restTimer?.cancel();
                    Navigator.pop(context);
                  },
                  child: const Text('건너뛰기', style: TextStyle(color: Colors.red)),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _restOption(StateSetter setDialogState, String label, int seconds) {
    bool isSel = _selectedRestTime == seconds;
    return InkWell(
      onTap: () => setDialogState(() {
        _selectedRestTime = seconds;
        _remainingSeconds = seconds;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? AppTheme.primaryBlue : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: isSel ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _exportHistoryToCsv() async {
    try {
      final history = await DatabaseHelper.instance.getAllHistory();
      if (history.isEmpty) return;
      String csvData = 'Date,Exercise,Set,Reps,Weight,RPE\n';
      for (var row in history) {
        csvData += '${row['date']},${row['name']},${row['sets']},${row['reps']},${row['weight']},${row['rpe']}\n';
      }
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/workout_history.csv');
      await file.writeAsString(csvData);
    } catch (e) {
      print('CSV 내보내기 에러: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(workoutProvider);
    final isFinished = ref.watch(workoutProvider.notifier).isFinished;

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
          if (!isFinished) ...[
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
            _buildExerciseList(exercises, isFinished),
            const SizedBox(height: 24),
            if (isFinished) _buildFinishedBanner()
            else if (isAllSetsDone) _buildFinishButton(exercises)
            else if (exercises.isNotEmpty) _buildIncompleteMessage(completedSets, totalSets)
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(int comp, int tot) {
    double per = tot == 0 ? 0 : comp / tot;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('오늘의 운동 달성도', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('$comp / $tot 세트', style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold))
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: per,
              backgroundColor: Colors.grey[200],
              color: AppTheme.successGreen,
              minHeight: 8,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseList(List<Exercise> exercises, bool isFinished) {
    return Opacity(
      opacity: isFinished ? 0.6 : 1.0,
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
                  Expanded(child: Text(ex.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18))),
                  if (!isFinished)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => ref.read(workoutProvider.notifier).removeExercise(ex.id),
                    ),
                ],
              ),
              subtitle: Text(
                ex.isCardio ? '${ex.reps}분 수행' : '${ex.sets}세트 | ${ex.reps}회 | ${ex.weight}kg',
                style: const TextStyle(color: Colors.black54),
              ),
              children: List.generate(ex.sets, (sIdx) => ListTile(
                title: Text(
                  ex.isCardio ? '목표 시간: ${ex.reps}분' : '${ex.weight}kg / ${ex.reps}회',
                  style: const TextStyle(color: Colors.black87),
                ),
                trailing: Checkbox(
                  value: ex.setStatus[sIdx],
                  onChanged: isFinished ? null : (v) => _toggleSetStatus(idx, sIdx, exercises),
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
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.successGreen,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('오늘의 훈련 종료 및 정산', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildIncompleteMessage(int comp, int tot) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
      child: Text(
        '남은 세트를 모두 완료하면 정산 버튼이 나타납니다. ($comp/$tot)',
        style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildFinishedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(16)),
      child: const Column(
        children: [
          Icon(Icons.check_circle, color: AppTheme.successGreen, size: 48),
          SizedBox(height: 8),
          Text('오운완! 오늘 운동 끝', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.successGreen)),
        ],
      ),
    );
  }
}