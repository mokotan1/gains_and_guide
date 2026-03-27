import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/models/user_profile.dart';
import '../providers/onboarding_providers.dart';
import 'ai_hint_banner.dart';
import 'onboarding_page_layout.dart';
import 'selection_card.dart';

class FrequencySelectionPage extends ConsumerWidget {
  const FrequencySelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(
      onboardingStateProvider.select((s) => s.frequency),
    );
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingPageLayout(
      title: '일주일에 며칠 정도\n훈련할 계획이신가요?',
      subtitle: '주간 레포트의 계획 대비 달성률 계산과 운동 분할 추천에 사용됩니다.',
      bottomHint: selected != null
          ? AiHintBanner(text: '${selected.splitRecommendation}이 가장 효과적입니다.')
          : null,
      children: [
        for (final freq in WeeklyFrequency.values) ...[
          SelectionCard(
            emoji: freq.emoji,
            title: '${freq.label} — ${freq.splitRecommendation}',
            subtitle: freq.description,
            isSelected: selected == freq,
            onTap: () => notifier.setFrequency(freq),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
