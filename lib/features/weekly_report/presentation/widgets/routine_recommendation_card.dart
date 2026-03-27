import 'package:flutter/material.dart';

import '../../../../core/data/exercise_name_ko.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/recommended_routine.dart';

/// 주간 리포트 내에서 AI 추천 루틴을 표시하고 적용할 수 있는 카드 위젯.
class RoutineRecommendationCard extends StatelessWidget {
  final RecommendedRoutine routine;
  final VoidCallback onApply;

  const RoutineRecommendationCard({
    super.key,
    required this.routine,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const Divider(height: 20),
            _buildRationale(context),
            const SizedBox(height: 12),
            _buildExerciseList(context),
            const SizedBox(height: 16),
            _buildApplyButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.fitness_center_rounded,
          color: AppTheme.primaryBlue,
          size: 24,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            routine.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildRationale(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        routine.rationale,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.black87,
              height: 1.5,
            ),
      ),
    );
  }

  Widget _buildExerciseList(BuildContext context) {
    return Column(
      children: routine.exercises.asMap().entries.map((entry) {
        final idx = entry.key;
        final ex = entry.value;
        return _ExerciseTile(index: idx + 1, exercise: ex);
      }).toList(),
    );
  }

  Widget _buildApplyButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onApply,
        icon: const Icon(Icons.check_circle_outline_rounded),
        label: const Text(
          '이 루틴으로 교체',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final int index;
  final RoutineExercise exercise;

  const _ExerciseTile({required this.index, required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ExerciseNameKo.get(ExerciseNameKo.reverse(exercise.name)),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Text(
            '${exercise.sets}x${exercise.reps}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryBlue,
                ),
          ),
          const SizedBox(width: 8),
          Text(
            '${exercise.weight.toStringAsFixed(1)}kg',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                ),
          ),
        ],
      ),
    );
  }
}
