import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/workout_provider.dart';
import '../data/routine_repository.dart';
import '../domain/exercise.dart';
import '../domain/routine.dart';

class RoutineCreateScreen extends ConsumerStatefulWidget {
  const RoutineCreateScreen({super.key});

  @override
  ConsumerState<RoutineCreateScreen> createState() => _RoutineCreateScreenState();
}

class _RoutineCreateScreenState extends ConsumerState<RoutineCreateScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final Set<int> _selectedWeekdays = {};
  final List<Exercise> _exercises = [];
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _nameController.text.trim().isNotEmpty &&
      _selectedWeekdays.isNotEmpty &&
      _exercises.isNotEmpty;

  Future<void> _saveRoutine() async {
    if (!_isValid || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      final routine = Routine(
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        createdAt: DateTime.now().toString().split(' ')[0],
        exercises: _exercises,
        assignedWeekdays: _selectedWeekdays.toList()..sort(),
      );

      final repo = ref.read(routineRepositoryProvider);
      await repo.createRoutineWithExercises(routine);

      final weeklyProgram = await repo.getWeeklyProgram();
      await ref.read(workoutProvider.notifier).applyWeeklyProgram(weeklyProgram);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('루틴이 저장되었습니다!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addExerciseDialog() async {
    final catalogRepo = ref.read(exerciseCatalogRepositoryProvider);
    final List<Map<String, dynamic>> catalog = await catalogRepo.getAll();

    final Map<String, Set<String>> rawData = {
      '가슴': {'플랫 벤치 프레스', '인클라인 벤치 프레스', '덤벨 프레스', '펙 덱 플라이', '푸쉬업', '케이블 크로스오버'},
      '등': {'컨벤셔널 데드리프트', '루마니안 데드리프트', '펜들레이 로우', '바벨 로우', '랫 풀다운', '풀업', '시티드 로우'},
      '하체': {'백 스쿼트', '프론트 스쿼트', '레그 프레스', '레그 익스텐션', '레그 컬', '런지', '카프 레이즈'},
      '어깨': {'오버헤드 프레스 (OHP)', '덤벨 숄더 프레스', '사이드 레터럴 레이즈', '프론트 레이즈', '페이스 풀'},
      '팔': {'바벨 컬', '덤벨 컬', '해머 컬', '트라이셉스 푸쉬다운', '오버헤드 트라이셉스 익스텐션'},
      '복근': {'크런치', '레그 레이즈', '플랭크', '케이블 크런치'},
      '유산소': {'런닝머신', '실내 사이클', '스텝밀(천국의 계단)'},
      '기타': {},
    };

    for (var row in catalog) {
      final name = row['name']?.toString() ?? 'Unknown';
      final muscles = (row['primary_muscles']?.toString() ?? '').toLowerCase();
      final category = (row['category']?.toString() ?? '').toLowerCase();

      if (category.contains('cardio')) { rawData['유산소']!.add(name); continue; }

      bool matched = false;
      if (muscles.contains('chest')) { rawData['가슴']!.add(name); matched = true; }
      if (muscles.contains('lats') || muscles.contains('back')) { rawData['등']!.add(name); matched = true; }
      if (muscles.contains('quadriceps') || muscles.contains('hamstrings') || muscles.contains('glutes') || muscles.contains('calves')) { rawData['하체']!.add(name); matched = true; }
      if (muscles.contains('shoulders') || muscles.contains('delts')) { rawData['어깨']!.add(name); matched = true; }
      if (muscles.contains('biceps') || muscles.contains('triceps') || muscles.contains('forearms')) { rawData['팔']!.add(name); matched = true; }
      if (muscles.contains('abs') || muscles.contains('core')) { rawData['복근']!.add(name); matched = true; }
      if (!matched) { rawData['기타']!.add(name); }
    }

    final Map<String, List<String>> exerciseData = {};
    rawData.forEach((key, value) {
      if (value.isNotEmpty) exerciseData[key] = value.toList()..sort();
    });

    if (!mounted) return;

    String? selectedCategory;
    String? selectedExercise;
    double weight = 0.0;
    int sets = 3;
    int reps = 10;

    final result = await showDialog<Exercise>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final bool isCardio = selectedCategory == '유산소';

          Widget buildCounter(String label, String valueStr, VoidCallback onDec, VoidCallback onInc) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    IconButton(onPressed: onDec, icon: const Icon(Icons.remove_circle_outline, color: AppTheme.primaryBlue), constraints: const BoxConstraints(), padding: EdgeInsets.zero),
                    const SizedBox(width: 12),
                    Text(valueStr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    IconButton(onPressed: onInc, icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryBlue), constraints: const BoxConstraints(), padding: EdgeInsets.zero),
                  ],
                ),
              ],
            );
          }

          return AlertDialog(
            title: const Text('운동 추가'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: '운동 부위', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                    value: selectedCategory,
                    items: exerciseData.keys.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setDialogState(() {
                      selectedCategory = v;
                      selectedExercise = null;
                      if (v == '유산소') { sets = 1; reps = 30; weight = 0.0; } else { sets = 3; reps = 10; }
                    }),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: '운동명', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                    value: selectedExercise,
                    isExpanded: true,
                    items: selectedCategory == null ? [] : exerciseData[selectedCategory]!.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setDialogState(() => selectedExercise = v),
                    hint: const Text('부위를 먼저 선택하세요'),
                  ),
                  if (selectedExercise != null) ...[
                    const SizedBox(height: 24),
                    if (!isCardio)
                      buildCounter('무게 (kg)', weight.toStringAsFixed(1),
                        () => setDialogState(() => weight = (weight - 2.5).clamp(0.0, 500.0)),
                        () => setDialogState(() => weight += 2.5)),
                    if (!isCardio) const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (!isCardio)
                          buildCounter('세트', '$sets',
                            () => setDialogState(() => sets = (sets - 1).clamp(1, 20)),
                            () => setDialogState(() => sets += 1)),
                        buildCounter(isCardio ? '목표 시간 (분)' : '횟수', '$reps',
                          () => setDialogState(() => reps = (reps - 1).clamp(1, 100)),
                          () => setDialogState(() => reps += 1)),
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
                  Navigator.pop(context, Exercise.initial(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: selectedExercise!,
                    sets: isCardio ? 1 : sets,
                    reps: isCardio ? reps : reps,
                    weight: weight,
                    isCardio: isCardio,
                  ));
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white),
                child: const Text('추가'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      setState(() => _exercises.add(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    const weekdayLabels = {1: '월', 2: '화', 3: '수', 4: '목', 5: '금', 6: '토', 7: '일'};

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('새 루틴 만들기', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('루틴 정보', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: '루틴 이름',
                        hintText: '예: 상체 운동 A',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descController,
                      decoration: InputDecoration(
                        labelText: '설명 (선택)',
                        hintText: '예: 가슴/어깨 위주',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('운동하는 요일', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: weekdayLabels.entries.map((entry) {
                        final selected = _selectedWeekdays.contains(entry.key);
                        return FilterChip(
                          label: Text(entry.value),
                          selected: selected,
                          selectedColor: AppTheme.primaryBlue.withOpacity(0.2),
                          checkmarkColor: AppTheme.primaryBlue,
                          onSelected: (v) => setState(() {
                            v ? _selectedWeekdays.add(entry.key) : _selectedWeekdays.remove(entry.key);
                          }),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('운동 목록', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: _addExerciseDialog,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('추가'),
                        ),
                      ],
                    ),
                    if (_exercises.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('운동을 추가해 주세요', style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    else
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _exercises.length,
                        onReorder: (oldIdx, newIdx) {
                          setState(() {
                            if (newIdx > oldIdx) newIdx--;
                            final item = _exercises.removeAt(oldIdx);
                            _exercises.insert(newIdx, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final ex = _exercises[index];
                          return ListTile(
                            key: ValueKey(ex.id),
                            leading: const Icon(Icons.drag_handle, color: Colors.grey),
                            title: Text(ex.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              ex.isCardio
                                  ? '${ex.reps}분'
                                  : '${ex.sets}세트 x ${ex.reps}회 / ${ex.weight}kg',
                              style: const TextStyle(color: Colors.black54),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => setState(() => _exercises.removeAt(index)),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isValid && !_isSaving ? _saveRoutine : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('루틴 저장', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
