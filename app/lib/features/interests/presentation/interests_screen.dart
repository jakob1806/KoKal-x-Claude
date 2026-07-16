import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/interests/interests_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class InterestsScreen extends ConsumerWidget {
  const InterestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Interessen')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              'Bitte im Profil-Tab anmelden, um Interessen auszuwählen.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
        ),
      );
    }

    final genres = ref.watch(genreOptionsProvider).valueOrNull ?? const [];
    final composers =
        ref.watch(composerOptionsProvider).valueOrNull ?? const [];
    final venues = ref.watch(venueOptionsProvider).valueOrNull ?? const [];
    final selected =
        ref.watch(userInterestsProvider).valueOrNull ?? UserInterests.empty;

    return Scaffold(
      appBar: AppBar(title: const Text('Interessen')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
        children: [
          Text(
            'Wähle aus, was dich interessiert — das hilft uns, dir passende Veranstaltungen zu zeigen.',
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.lg),
          _InterestSection(
            title: 'Genres',
            options: genres,
            selectedIds: selected.genreIds,
            category: InterestCategory.genre,
          ),
          const SizedBox(height: AppSpacing.lg),
          _InterestSection(
            title: 'Komponisten',
            options: composers,
            selectedIds: selected.personIds,
            category: InterestCategory.person,
          ),
          const SizedBox(height: AppSpacing.lg),
          _InterestSection(
            title: 'Venues',
            options: venues,
            selectedIds: selected.venueIds,
            category: InterestCategory.venue,
          ),
        ],
      ),
    );
  }
}

class _InterestSection extends ConsumerWidget {
  const _InterestSection({
    required this.title,
    required this.options,
    required this.selectedIds,
    required this.category,
  });

  final String title;
  final List<InterestOption> options;
  final Set<String> selectedIds;
  final InterestCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    if (options.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              FilterChip(
                label: Text(option.label),
                selected: selectedIds.contains(option.id),
                onSelected: (_) => InterestsService.toggle(
                  ref,
                  category: category,
                  id: option.id,
                  isSelected: selectedIds.contains(option.id),
                ),
                showCheckmark: false,
                selectedColor: colors.accentPrimary.withValues(alpha: 0.16),
                backgroundColor: colors.backgroundSecondary,
                side: BorderSide(
                  color: selectedIds.contains(option.id)
                      ? colors.accentPrimary
                      : colors.separator,
                ),
                labelStyle: TextStyle(
                  color: selectedIds.contains(option.id)
                      ? colors.accentPrimary
                      : colors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
