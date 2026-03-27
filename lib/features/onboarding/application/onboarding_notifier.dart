import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/models/user_profile.dart';
import '../domain/onboarding_state.dart';

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(const OnboardingState());

  void setGoal(TrainingGoal goal) {
    state = state.copyWith(goal: goal);
  }

  void setLevel(TrainingLevel level) {
    state = state.copyWith(level: level);
  }

  void setFrequency(WeeklyFrequency frequency) {
    state = state.copyWith(frequency: frequency);
  }

  void toggleEquipment(EquipmentType type) {
    final updated = Set<EquipmentType>.from(state.equipment);
    if (updated.contains(type)) {
      updated.remove(type);
    } else {
      updated.add(type);
    }
    state = state.copyWith(equipment: updated);
  }

  void nextPage() {
    if (state.currentPage < OnboardingState.totalPages - 1) {
      state = state.copyWith(currentPage: state.currentPage + 1);
    }
  }

  void previousPage() {
    if (state.currentPage > 0) {
      state = state.copyWith(currentPage: state.currentPage - 1);
    }
  }

  void goToPage(int page) {
    if (page >= 0 && page < OnboardingState.totalPages) {
      state = state.copyWith(currentPage: page);
    }
  }

  UserProfile buildProfile() {
    if (!state.isComplete) {
      throw StateError('온보딩이 완료되지 않았습니다. 모든 항목을 선택해주세요.');
    }
    return UserProfile(
      goal: state.goal!,
      level: state.level!,
      frequency: state.frequency!,
      equipment: state.equipment,
      createdAt: DateTime.now(),
    );
  }
}
