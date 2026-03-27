import '../../../core/domain/models/user_profile.dart';

class OnboardingState {
  static const int totalPages = 4;

  final int currentPage;
  final TrainingGoal? goal;
  final TrainingLevel? level;
  final WeeklyFrequency? frequency;
  final Set<EquipmentType> equipment;

  const OnboardingState({
    this.currentPage = 0,
    this.goal,
    this.level,
    this.frequency,
    this.equipment = const {},
  });

  bool get isComplete =>
      goal != null &&
      level != null &&
      frequency != null &&
      equipment.isNotEmpty;

  bool get canProceed => switch (currentPage) {
        0 => goal != null,
        1 => level != null,
        2 => frequency != null,
        3 => equipment.isNotEmpty,
        _ => false,
      };

  double get progress => (currentPage + 1) / totalPages;

  OnboardingState copyWith({
    int? currentPage,
    TrainingGoal? goal,
    TrainingLevel? level,
    WeeklyFrequency? frequency,
    Set<EquipmentType>? equipment,
  }) {
    return OnboardingState(
      currentPage: currentPage ?? this.currentPage,
      goal: goal ?? this.goal,
      level: level ?? this.level,
      frequency: frequency ?? this.frequency,
      equipment: equipment ?? this.equipment,
    );
  }
}
