import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../favorites/favorites_providers.dart';
import '../theme/app_colors.dart';

/// Herz-Button zum Favorisieren. Ohne Login zeigt ein Tap nur einen Hinweis —
/// Browsing bleibt account-frei, siehe docs/01-architecture.md §5.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({
    required this.eventId,
    this.size = 22,
    this.activeColor,
    this.inactiveColor,
    super.key,
  });

  final String eventId;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoriteIdsProvider);
    final isFavorited = favorites.valueOrNull?.contains(eventId) ?? false;
    final colors = context.appColors;

    return IconButton(
      icon: Icon(
        isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        size: size,
        color: isFavorited
            ? (activeColor ?? colors.accentPrimary)
            : (inactiveColor ?? colors.textTertiary),
      ),
      onPressed: () async {
        if (ref.read(currentUserProvider) == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Zum Favorisieren bitte im Profil-Tab anmelden.'),
            ),
          );
          return;
        }
        await FavoritesService.toggle(
          ref,
          eventId: eventId,
          isFavorited: isFavorited,
        );
      },
    );
  }
}
