import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'genre_artwork.dart';

/// Karten-Widget für Event-Listen (Home-Sektionen, Suchergebnisse, Favoriten).
/// Bild trägt die Emotion, Metadaten bleiben knapp — siehe
/// docs/04-design-system.md, §4 „EventCard".
class EventCard extends StatelessWidget {
  const EventCard({
    required this.title,
    required this.venueAndTime,
    required this.genre,
    this.badgeLabel,
    this.onTap,
    this.width = 150,
    super.key,
  });

  final String title;
  final String venueAndTime;
  final EventGenre genre;
  final String? badgeLabel;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 3 / 2,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GenreArtwork(
                    genre: genre,
                    borderRadius: BorderRadius.circular(AppRadius.cardImage),
                  ),
                  if (badgeLabel != null)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accentSecondary.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badgeLabel!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: colors.backgroundPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              venueAndTime,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
