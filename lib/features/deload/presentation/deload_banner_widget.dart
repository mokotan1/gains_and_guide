import 'package:flutter/material.dart';
import '../../../core/domain/models/deload_recommendation.dart';
import '../../../core/domain/models/fatigue_signal.dart';

/// 디로드가 자동 적용되었을 때 홈 화면 상단에 표시하는 배너
class DeloadBannerWidget extends StatelessWidget {
  final DeloadRecommendation recommendation;

  const DeloadBannerWidget({super.key, required this.recommendation});

  @override
  Widget build(BuildContext context) {
    if (!recommendation.shouldDeload) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.self_improvement, color: Colors.orange.shade700, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '디로드 주간이 적용되었습니다',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '무게가 ${((1 - recommendation.reductionRatio) * 100).toStringAsFixed(0)}% 감량되어 로드됩니다. '
            '충분한 회복 후 다시 증량을 시작합니다.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.orange.shade800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _buildSignalSummary(context),
          const SizedBox(height: 8),
          _buildScoreBar(context),
        ],
      ),
    );
  }

  Widget _buildSignalSummary(BuildContext context) {
    final sorted = List<FatigueSignal>.from(recommendation.signals)
      ..sort((a, b) => b.weightedScore.compareTo(a.weightedScore));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '판단 근거',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.orange.shade900,
          ),
        ),
        const SizedBox(height: 4),
        ...sorted.where((s) => s.score > 0).take(3).map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Icon(_iconForType(s.type),
                        size: 14, color: Colors.orange.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        s.reason,
                        style: TextStyle(
                            fontSize: 12, color: Colors.orange.shade800),
                      ),
                    ),
                    Text(
                      '${s.weightedScore.toStringAsFixed(0)}점',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildScoreBar(BuildContext context) {
    final pct = (recommendation.totalScore / 100).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '종합 피로도',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900),
            ),
            Text(
              '${recommendation.totalScore.toStringAsFixed(0)} / 100',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.orange.shade100,
            color: Colors.orange.shade600,
            minHeight: 6,
          ),
        ),
      ],
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
}
