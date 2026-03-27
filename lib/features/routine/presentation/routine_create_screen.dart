import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/workout_provider.dart';
import '../../exercise_search/presentation/exercise_search_bottom_sheet.dart';
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

  void _addExercise() async {
    final result = await ExerciseSearchBottomSheet.show(context);
    if (result != null && mounted) {
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
                          onPressed: _addExercise,
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
