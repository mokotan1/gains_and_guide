import 'dart:convert';

enum TrainingGoal {
  strength,
  hypertrophy,
  fatLoss,
  generalFitness;

  String get label => switch (this) {
        strength => '스트렝스 향상',
        hypertrophy => '근육량 증가',
        fatLoss => '체지방 감소',
        generalFitness => '체력 증진',
      };

  String get emoji => switch (this) {
        strength => '\u{1F4AA}',
        hypertrophy => '\u{1F98D}',
        fatLoss => '\u{1F525}',
        generalFitness => '\u{1F3C3}',
      };

  String get description => switch (this) {
        strength => '더 무거운 무게(1RM)를 드는 것이 목표입니다.',
        hypertrophy => '근육의 크기를 키우고 체형을 바꾸는 것이 목표입니다.',
        fatLoss => '체중을 감량하고 탄탄한 몸을 만드는 것이 목표입니다.',
        generalFitness => '일상생활의 활력을 얻고 부상을 방지하는 것이 목표입니다.',
      };

  String get aiHint => switch (this) {
        strength => 'AI는 RPE와 중량 증가 폭에 칭찬을 집중합니다.',
        hypertrophy => 'AI는 주간 부위별 타겟 세트 수(10~20세트) 달성 여부를 집중 평가합니다.',
        fatLoss => 'AI는 총 소모 칼로리와 유산소 볼륨 달성 여부를 집중 평가합니다.',
        generalFitness => 'AI는 꾸준한 운동 빈도와 부상 방지 지표를 집중 평가합니다.',
      };
}

enum TrainingLevel {
  beginner,
  intermediate,
  advanced;

  String get label => switch (this) {
        beginner => '초보자 (1년 미만)',
        intermediate => '중급자 (1~3년)',
        advanced => '고급자 (3년 이상)',
      };

  String get emoji => switch (this) {
        beginner => '\u{1F331}',
        intermediate => '\u{1F33F}',
        advanced => '\u{1F333}',
      };

  String get description => switch (this) {
        beginner => '기구 사용법을 익히고 기본기를 다지는 단계입니다.',
        intermediate => '3대 운동 자세가 안정적이고, 점진적 과부하를 적용 중입니다.',
        advanced => '정체기를 겪어봤으며, 주기화(Periodization) 훈련이 필요합니다.',
      };

  String get aiHint => switch (this) {
        beginner => '주 단위 무게 증가를 기대하며, 자세 교정에 집중합니다.',
        intermediate => '격주~월 단위 성장을 기대하며, 볼륨 관리에 집중합니다.',
        advanced => '월 단위 미세 성장을 기대하며, 주기화를 적극 활용합니다.',
      };
}

enum WeeklyFrequency {
  low,
  moderate,
  high;

  String get label => switch (this) {
        low => '주 1~2일',
        moderate => '주 3~4일',
        high => '주 5일 이상',
      };

  String get emoji => switch (this) {
        low => '\u{1F50B}',
        moderate => '\u{26A1}',
        high => '\u{1F680}',
      };

  String get description => switch (this) {
        low => '바쁜 일상 속에서 최소한의 근력을 유지하고 싶어요.',
        moderate => '회복과 성장의 밸런스를 맞추며 꾸준히 하고 싶어요.',
        high => '한계를 부수고 극강의 성장을 이끌어내고 싶어요.',
      };

  String get splitRecommendation => switch (this) {
        low => '전신 무분할 추천',
        moderate => '상하체 2분할 추천',
        high => '3분할 이상 추천',
      };
}

enum EquipmentType {
  freeWeight,
  machine,
  bodyweight;

  String get label => switch (this) {
        freeWeight => '프리웨이트 (바벨/덤벨)',
        machine => '머신 위주',
        bodyweight => '맨몸/홈트레이닝',
      };

  String get emoji => switch (this) {
        freeWeight => '\u{1F3CB}',
        machine => '\u{1F916}',
        bodyweight => '\u{1F3E0}',
      };

  String get description => switch (this) {
        freeWeight => '랙과 플랫폼이 갖춰진 헬스장을 이용해요.',
        machine => '궤적이 고정된 안전한 헬스장 기구를 선호해요.',
        bodyweight => '철봉이나 밴드, 덤벨 정도만 있는 환경이에요.',
      };
}

class UserProfile {
  final int id;
  final TrainingGoal goal;
  final TrainingLevel level;
  final WeeklyFrequency frequency;
  final Set<EquipmentType> equipment;
  final DateTime createdAt;

  const UserProfile({
    this.id = 1,
    required this.goal,
    required this.level,
    required this.frequency,
    required this.equipment,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goal': goal.name,
      'level': level.name,
      'frequency': frequency.name,
      'equipment': json.encode(equipment.map((e) => e.name).toList()),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final equipmentJson = json.decode(map['equipment'] as String) as List;
    return UserProfile(
      id: map['id'] as int,
      goal: TrainingGoal.values.byName(map['goal'] as String),
      level: TrainingLevel.values.byName(map['level'] as String),
      frequency: WeeklyFrequency.values.byName(map['frequency'] as String),
      equipment: equipmentJson
          .map((e) => EquipmentType.values.byName(e as String))
          .toSet(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  UserProfile copyWith({
    TrainingGoal? goal,
    TrainingLevel? level,
    WeeklyFrequency? frequency,
    Set<EquipmentType>? equipment,
  }) {
    return UserProfile(
      id: id,
      goal: goal ?? this.goal,
      level: level ?? this.level,
      frequency: frequency ?? this.frequency,
      equipment: equipment ?? this.equipment,
      createdAt: createdAt,
    );
  }
}
