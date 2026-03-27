import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/models/user_profile.dart';
import '../providers/onboarding_providers.dart';
import 'ai_hint_banner.dart';
import 'onboarding_page_layout.dart';
import 'selection_card.dart';

class ExperienceSelectionPage extends ConsumerWidget {
  const ExperienceSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(
      onboardingStateProvider.select((s) => s.level),
    );
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingPageLayout(
      title: '웨이트 트레이닝\n경력이 어떻게 되시나요?',
      subtitle: '초기 볼륨 기준치와 디로딩 주기를 설정하기 위한 질문입니다.',
      bottomHint: selected != null
          ? AiHintBanner(text: selected.aiHint)
          : null,
      children: [
        for (final level in TrainingLevel.values) ...[
          SelectionCard(
            emoji: level.emoji,
            title: level.label,
            subtitle: level.description,
            isSelected: selected == level,
            onTap: () => notifier.setLevel(level),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
