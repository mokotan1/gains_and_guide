import '../../../core/domain/repositories/cardio_history_repository.dart';
import '../../routine/domain/exercise.dart';

/// 오늘 정산 `/chat` 분할 호출용 상수·문구·유산소 컨텍스트.
///
/// Groq TPM 한도를 피하기 위해 웨이트 분석과 유산소 분석을 나누고,
/// `coach_focus` 로 백엔드에 거대 루틴 가이드 주입 생략을 요청한다.
abstract final class SettlementCoach {
  static const String focusStrongliftsWeights = 'stronglifts_weights';
  static const String focusWeightsMinimal = 'weights_minimal';
  static const String focusCardioOnly = 'cardio_only';

  /// [WorkoutNotifier._isStrongliftsTemplateDay] 와 동일.
  static bool isStrongliftsTemplateDay(List<Exercise> dayRoutine) =>
      dayRoutine.isNotEmpty && dayRoutine.any((e) => e.name == '백 스쿼트');

  static Future<String> buildCardioCoachContext({
    required CardioHistoryRepository cardioRepo,
    required String dateYmd,
  }) async {
    final rows = await cardioRepo.getHistoryForDateRange(dateYmd, dateYmd);
    if (rows.isEmpty) return '';
    final b = StringBuffer()
      ..writeln('[유산소 운동 데이터]')
      ..writeln('대상일: $dateYmd');
    for (final r in rows) {
      final name = r['cardio_name']?.toString() ?? '';
      final min = r['duration_minutes'];
      final rpe = r['rpe'];
      b.writeln('- $name: ${min}분, RPE ${rpe ?? '-'}');
    }
    return b.toString();
  }

  static String weightSettlementMessage({
    required bool isStrongliftsDay,
    required bool hasCardioToday,
    required String profilePrefix,
  }) {
    if (isStrongliftsDay) {
      return '${profilePrefix}스트롱리프트 5x5 오늘 웨이트(웨이트 트레이닝) 세션만 분석하고 증량 가이드(progression)를 JSON으로 포함해 줘. '
          '유산소는 이 요청에서 다루지 마.';
    }
    if (hasCardioToday) {
      return '${profilePrefix}오늘 완료한 웨이트 트레이닝만 분석하고 증량 가이드(progression)를 JSON으로 포함해 줘. '
          '유산소는 바로 이어서 별도로 질문할 예정이니 이번 답변에는 포함하지 마.';
    }
    return '${profilePrefix}오늘 완료한 웨이트 트레이닝 기록만 간결히 분석하고 증량 가이드(progression)를 JSON으로 포함해 줘. '
        '스트롱리프트 전용 프로그램 설계나 유산소 종합 평가는 하지 마.';
  }

  static String cardioOnlyMessage({required String profilePrefix}) =>
      '${profilePrefix}아래 유산소 기록만 분석해 줘. 웨이트 트레이닝·스트롱리프트 루틴 설계는 다루지 마. '
      '심폐·볼륨·회복 관점에서 한국어로 조언하고, progression은 없으면 null 로 줘.';
}
