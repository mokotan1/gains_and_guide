import 'package:flutter/material.dart';
import '../../../core/constants/deload_constants.dart';
import '../../../core/domain/models/deload_recommendation.dart';
import '../../../core/domain/models/fatigue_signal.dart';

/// 홈 화면에 항상 표시되는 피로도 게이지 + 다음 주 디로드 예측 카드
class DeloadPredictionCard extends StatelessWidget {
  final DeloadRecommendation recommendation;

  const DeloadPredictionCard({super.key, required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final status = _FatigueStatus.from(recommendation.totalScore);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(status),
            const SizedBox(height: 12),
            _buildGaugeBar(status),
            const SizedBox(height: 12),
            _buildPredictionText(status),
            if (recommendation.signals.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildSignalBreakdown(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(_FatigueStatus status) {
    return Row(
      children: [
        Icon(status.icon, color: status.color, size: 22),
        const SizedBox(width: 8),
        const Text(
          '피로도 모니터',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: status.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: status.color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGaugeBar(_FatigueStatus status) {
    final pct = (recommendation.totalScore / 100).clamp(0.0, 1.0);
    final threshold = DeloadConstants.fatigueScoreThreshold / 100;

    return Column(
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: Colors.grey.shade200,
                color: status.color,
                minHeight: 10,
              ),
            ),
            Positioned(
              left: threshold * (MediaQueryData.fromView(
                      WidgetsBinding.instance.platformDispatcher.views.first)
                  .size
                  .width - 64) // 대략적인 게이지 너비
                  .clamp(0, 400),
              top: 0,
              bottom: 0,
              child: Container(
                width: 2,
                color: Colors.red.shade400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${recommendation.totalScore.toStringAsFixed(0)}점',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: status.color,
              ),
            ),
            Text(
              '디로드 기준: ${DeloadConstants.fatigueScoreThreshold.toStringAsFixed(0)}점',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPredictionText(_FatigueStatus status) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.next_week, size: 18, color: status.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status.prediction,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalBreakdown() {
    final sorted = List<FatigueSignal>.from(recommendation.signals)
      ..sort((a, b) => b.weightedScore.compareTo(a.weightedScore));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '세부 지표',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        ...sorted.map((s) => _buildSignalRow(s)),
      ],
    );
  }

  Widget _buildSignalRow(FatigueSignal signal) {
    final barPct = (signal.score / 100).clamp(0.0, 1.0);
    final color = signal.score >= 60
        ? Colors.red.shade400
        : signal.score >= 30
            ? Colors.orange.shade400
            : Colors.green.shade400;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(_iconForType(signal.type), size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          SizedBox(
            width: 60,
            child: Text(
              _labelForType(signal.type),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: barPct,
                backgroundColor: Colors.grey.shade200,
                color: color,
                minHeight: 5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              '${signal.score.toStringAsFixed(0)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(FatigueSignalType type) {
    switch (type) {
      case FatigueSignalType.rpeFatigue:
        return Icons.whatshot;
      case FatigueSignalType.plateau:
        return Icons.trending_flat;
      case FatigueSignalType.timeBased:
        return Icons.calendar_today;
      case FatigueSignalType.failureRate:
        return Icons.warning_amber;
    }
  }

  String _labelForType(FatigueSignalType type) {
    switch (type) {
      case FatigueSignalType.rpeFatigue:
        return 'RPE 피로';
      case FatigueSignalType.plateau:
        return '정체/퇴보';
      case FatigueSignalType.timeBased:
        return '주기';
      case FatigueSignalType.failureRate:
        return '실패율';
    }
  }
}

/// 피로도 점수 구간별 상태 정의
class _FatigueStatus {
  final String label;
  final String prediction;
  final Color color;
  final IconData icon;

  const _FatigueStatus({
    required this.label,
    required this.prediction,
    required this.color,
    required this.icon,
  });

  factory _FatigueStatus.from(double score) {
    if (score >= DeloadConstants.fatigueScoreThreshold) {
      return _FatigueStatus(
        label: '디로드 필요',
        prediction: '피로가 누적되어 디로드가 자동 적용되었습니다. '
            '이번 주는 가벼운 무게로 회복에 집중하세요.',
        color: Colors.red.shade600,
        icon: Icons.warning_rounded,
      );
    } else if (score >= 55) {
      return _FatigueStatus(
        label: '주의',
        prediction: '다음 주에 디로드에 들어갈 가능성이 높습니다. '
            '수면과 영양에 신경 쓰고, 무리하지 마세요.',
        color: Colors.orange.shade700,
        icon: Icons.trending_up,
      );
    } else if (score >= 40) {
      return _FatigueStatus(
        label: '피로 누적 중',
        prediction: '피로가 쌓이고 있지만 아직 디로드는 불필요합니다. '
            '현재 루틴을 유지하되, 컨디션 변화를 주시하세요.',
        color: Colors.amber.shade700,
        icon: Icons.remove_circle_outline,
      );
    } else {
      return _FatigueStatus(
        label: '양호',
        prediction: '회복 상태가 좋습니다. 다음 주도 정상 진행하세요. '
            '꾸준한 점진적 증량이 가능합니다.',
        color: Colors.green.shade600,
        icon: Icons.check_circle_outline,
      );
    }
  }
}
