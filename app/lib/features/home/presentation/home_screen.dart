import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/event_card.dart';
import '../../../core/widgets/genre_artwork.dart';

/// Placeholder-Datenmodell, bis der Supabase-Client (Phase 1) angebunden ist.
class _EventStub {
  const _EventStub(this.title, this.venueAndTime, this.genre, [this.badge]);
  final String title;
  final String venueAndTime;
  final EventGenre genre;
  final String? badge;
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _heute = [
    _EventStub(
      'Brahms — 4. Sinfonie',
      'Isarphilharmonie · 20:00',
      EventGenre.orchester,
    ),
    _EventStub(
      'Chornacht St. Michael',
      'St. Michael · 20:30',
      EventGenre.chormusik,
    ),
    _EventStub(
      'Orgelkonzert',
      'Allerheiligen-Hofkirche · 19:30',
      EventGenre.kirchenmusik,
    ),
  ];

  static const _ausverkauft = [
    _EventStub(
      'Schubertiade',
      'Herkulessaal · Fr, 19:30',
      EventGenre.kammermusik,
      'Fast ausverkauft',
    ),
  ];

  static const _kostenlos = [
    _EventStub(
      'Mittagsmusik im Dom',
      'Frauenkirche · 12:15',
      EventGenre.kirchenmusik,
      'Kostenlos',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPaddingMobile,
              AppSpacing.md,
              AppSpacing.screenPaddingMobile,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'München',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: colors.accentPrimary,
                    child: const Icon(
                      Icons.person_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPaddingMobile,
              AppSpacing.md,
              AppSpacing.screenPaddingMobile,
              0,
            ),
            sliver: SliverToBoxAdapter(child: _Hero(colors: colors)),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            sliver: SliverList.list(
              children: [
                _Section(title: 'Heute in München', events: _heute),
                const SizedBox(height: AppSpacing.sectionGap),
                _Section(title: 'Demnächst ausverkauft', events: _ausverkauft),
                const SizedBox(height: AppSpacing.sectionGap),
                _Section(title: 'Kostenlose Konzerte', events: _kostenlos),
                const SizedBox(height: AppSpacing.xxxl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.colors});
  final AppColorsExtension colors;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GenreArtwork(
            genre: EventGenre.kirchenmusik,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xC7000000)],
                stops: [0.4, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EMPFEHLUNG DES TAGES',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Matthäus-Passion',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Bachchor München · Herkulessaal · 19:30',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.events});
  final String title;
  final List<_EventStub> events;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPaddingMobile,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              Text(
                'Alle',
                style: TextStyle(
                  color: context.appColors.accentPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingMobile,
            ),
            itemCount: events.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppSpacing.cardGap),
            itemBuilder: (context, i) {
              final e = events[i];
              return EventCard(
                title: e.title,
                venueAndTime: e.venueAndTime,
                genre: e.genre,
                badgeLabel: e.badge,
              );
            },
          ),
        ),
      ],
    );
  }
}
