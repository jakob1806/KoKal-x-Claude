import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/application/home_providers.dart';
import '../theme/app_spacing.dart';
import 'event_card.dart';

/// Horizontale Event-Karten-Sektion mit Titel — gemeinsam genutzt von Home
/// (Heute/Neu/Kostenlos/Ausverkauft) und EventDetail ("Ähnliche
/// Veranstaltungen").
class EventSection extends StatelessWidget {
  const EventSection({super.key, required this.title, required this.events});

  final String title;
  final List<HomeEventItem> events;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPaddingMobile,
          ),
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 164,
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
                eventId: e.id,
                title: e.title,
                venueAndTime: e.venueAndTime,
                genre: e.genre,
                imageUrl: e.imageUrl,
                badgeLabel: e.badge,
                onTap: () => context.push('/event/${e.slug}'),
              );
            },
          ),
        ),
      ],
    );
  }
}
