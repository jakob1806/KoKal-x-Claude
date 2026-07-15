import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPaddingMobile,
          vertical: AppSpacing.xl,
        ),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(radius: 32, backgroundColor: colors.accentPrimary),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Anmelden',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  'Für Favoriten, Benachrichtigungen & Empfehlungen',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          for (final row in const [
            'Meine Favoriten',
            'Meine Listen',
            'Interessen',
            'Benachrichtigungen',
            'Darstellung',
          ])
            _ProfileRow(label: row, colors: colors),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.colors});
  final String label;
  final AppColorsExtension colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.separator)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: colors.textTertiary,
            size: 20,
          ),
        ],
      ),
    );
  }
}
