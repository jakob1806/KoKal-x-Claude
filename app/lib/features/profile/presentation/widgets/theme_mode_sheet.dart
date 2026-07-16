import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/theme_mode_provider.dart';

class ThemeModeSheet extends ConsumerWidget {
  const ThemeModeSheet({super.key, required this.current});

  final ThemeMode current;

  static const _options = [
    (
      mode: ThemeMode.system,
      label: 'System',
      icon: Icons.brightness_auto_rounded,
    ),
    (mode: ThemeMode.light, label: 'Hell', icon: Icons.light_mode_rounded),
    (mode: ThemeMode.dark, label: 'Dunkel', icon: Icons.dark_mode_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPaddingMobile,
              AppSpacing.lg,
              AppSpacing.screenPaddingMobile,
              AppSpacing.sm,
            ),
            child: Text(
              'Darstellung',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final option in _options)
            ListTile(
              leading: Icon(option.icon, color: colors.textSecondary),
              title: Text(
                option.label,
                style: TextStyle(color: colors.textPrimary),
              ),
              trailing: option.mode == current
                  ? Icon(Icons.check_rounded, color: colors.accentPrimary)
                  : null,
              onTap: () {
                ref.read(themeModeProvider.notifier).setThemeMode(option.mode);
                Navigator.of(context).pop();
              },
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
