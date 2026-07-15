import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/genre_artwork.dart';

final _venueProvider = FutureProvider.family<Map<String, dynamic>?, String>((
  ref,
  slug,
) async {
  final client = Supabase.instance.client;
  final venue = await client
      .from('venues')
      .select()
      .eq('slug', slug)
      .maybeSingle();
  if (venue == null) return null;

  final events = await client
      .from('events')
      .select('id, slug, title, start_datetime')
      .eq('venue_id', venue['id'])
      .neq('status', 'draft')
      .order('start_datetime');

  return {'venue': venue, 'events': events};
});

class VenueDetailScreen extends ConsumerWidget {
  const VenueDetailScreen({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_venueProvider(slug));
    final colors = context.appColors;

    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler beim Laden: $e')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Venue nicht gefunden'));
          }
          final venue = data['venue'] as Map<String, dynamic>;
          final events = data['events'] as List;
          final now = DateTime.now();
          final upcoming = events.where((e) {
            final start = DateTime.tryParse(e['start_datetime'] ?? '');
            return start != null && start.isAfter(now);
          }).toList();

          final address =
              '${venue['address_street']}, ${venue['address_zip']} ${venue['address_city']}';

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
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
                            colors: [Colors.transparent, Color(0xBF000000)],
                            stops: [0.5, 1.0],
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
                      venue['name'] ?? '',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            address,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => launchUrl(
                            Uri.parse(
                              'https://www.openstreetmap.org/search?query=${Uri.encodeComponent(address)}',
                            ),
                            mode: LaunchMode.externalApplication,
                          ),
                          child: const Text('Route'),
                        ),
                      ],
                    ),
                    if (venue['capacity'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${venue['capacity']} Plätze',
                        style: TextStyle(
                          color: colors.textTertiary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                    if (venue['description_de'] != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        venue['description_de'],
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                    if (venue['parking_info_de'] != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Parken',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        venue['parking_info_de'],
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      'Kommende Veranstaltungen',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (upcoming.isEmpty)
                      Text(
                        'Aktuell nichts geplant.',
                        style: TextStyle(
                          color: colors.textTertiary,
                          fontSize: 13,
                        ),
                      )
                    else
                      for (final event in upcoming)
                        _VenueEventRow(event: event, colors: colors),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VenueEventRow extends StatelessWidget {
  const _VenueEventRow({required this.event, required this.colors});
  final dynamic event;
  final AppColorsExtension colors;

  @override
  Widget build(BuildContext context) {
    final start = DateTime.tryParse(event['start_datetime'] ?? '');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        event['title'] ?? '',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
      ),
      subtitle: start != null
          ? Text(
              '${start.day}.${start.month}.${start.year}',
              style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
            )
          : null,
      onTap: () => context.push('/event/${event['slug']}'),
    );
  }
}
