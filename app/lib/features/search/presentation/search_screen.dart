import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPaddingMobile,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: colors.backgroundSecondary,
                borderRadius: BorderRadius.circular(AppRadius.button),
                border: Border.all(color: colors.separator),
              ),
              child: TextField(
                decoration: InputDecoration(
                  border: InputBorder.none,
                  icon: Icon(
                    Icons.search_rounded,
                    color: colors.textTertiary,
                    size: 20,
                  ),
                  hintText: 'Werk, Komponist, Ensemble, Ort …',
                  hintStyle: TextStyle(
                    color: colors.textTertiary,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Trending',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(letterSpacing: 1),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                'Bach',
                'Kirchenmusik',
                'Herkulessaal',
                'Kostenlos',
              ].map((c) => Chip(label: Text(c))).toList(),
            ),
            const Spacer(),
            Center(
              child: Text(
                'Meilisearch-Anbindung folgt in Phase 1\n(siehe docs/03-api-concept.md, §3)',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textTertiary, fontSize: 12),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
