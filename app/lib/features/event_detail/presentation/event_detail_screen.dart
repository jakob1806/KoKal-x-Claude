import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/genre_artwork.dart';

/// Zeigt ein Event anhand seines Slugs. Lädt aktuell nur Platzhalterdaten —
/// echtes Laden via PostgREST (`events?slug=eq.<slug>`) folgt in Phase 1,
/// siehe docs/03-api-concept.md.
class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: colors.backgroundPrimary,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  const GenreArtwork(genre: EventGenre.kirchenmusik),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x59000000),
                          Colors.transparent,
                          Color(0xBF000000),
                        ],
                        stops: [0.0, 0.35, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPaddingMobile,
              AppSpacing.lg,
              AppSpacing.screenPaddingMobile,
              AppSpacing.xxxl,
            ),
            sliver: SliverList.list(
              children: [
                Text(
                  'Slug: $slug',
                  style: TextStyle(color: colors.textTertiary, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  'Details werden geladen …',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Programm, Mitwirkende, Ort und Ticket-CTA erscheinen hier, sobald der '
                  'Supabase-Client angebunden ist (events, event_works, event_participants).',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
