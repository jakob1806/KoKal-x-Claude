import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_mode_provider.dart';
import 'widgets/auth_section.dart';
import 'widgets/theme_mode_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final user = ref.watch(currentUserProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPaddingMobile,
          vertical: AppSpacing.xl,
        ),
        children: [
          if (user == null)
            const AuthSection()
          else
            _SignedInHeader(email: user.email ?? 'Angemeldet', colors: colors),
          const SizedBox(height: AppSpacing.xxl),
          _ProfileRow(
            label: 'Meine Favoriten',
            colors: colors,
            onTap: () => context.push('/favorites'),
          ),
          _ProfileRow(
            label: 'Interessen',
            colors: colors,
            onTap: () => context.push('/interests'),
          ),
          for (final row in const ['Meine Listen', 'Benachrichtigungen'])
            _ProfileRow(
              label: row,
              colors: colors,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('„$row" folgt in einer der nächsten Phasen.'),
                ),
              ),
            ),
          _ProfileRow(
            label: 'Darstellung',
            colors: colors,
            onTap: () => showModalBottomSheet(
              context: context,
              builder: (_) =>
                  ThemeModeSheet(current: ref.read(themeModeProvider)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignedInHeader extends StatelessWidget {
  const _SignedInHeader({required this.email, required this.colors});
  final String email;
  final AppColorsExtension colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: colors.accentPrimary,
          child: const Icon(
            Icons.person_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          email,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: AuthService.signOut,
          child: Text('Abmelden', style: TextStyle(color: colors.error)),
        ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.colors, this.onTap});
  final String label;
  final AppColorsExtension colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
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
      ),
    );
  }
}
