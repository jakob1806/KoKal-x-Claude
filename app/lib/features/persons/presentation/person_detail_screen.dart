import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/genre_artwork.dart';

final _personProvider = FutureProvider.family<Map<String, dynamic>?, String>((
  ref,
  slug,
) async {
  final client = Supabase.instance.client;
  final person = await client
      .from('persons')
      .select()
      .eq('slug', slug)
      .maybeSingle();
  if (person == null) return null;

  final events = await client
      .from('event_participants')
      .select('role, events(id, slug, title, start_datetime, venues(name))')
      .eq('person_id', person['id'])
      .order('events(start_datetime)');

  return {'person': person, 'events': events};
});

class PersonDetailScreen extends ConsumerWidget {
  const PersonDetailScreen({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_personProvider(slug));
    final colors = context.appColors;

    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler beim Laden: $e')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Person nicht gefunden'));
          }
          final person = data['person'] as Map<String, dynamic>;
          final events = data['events'] as List;
          final roles = (person['roles'] as List?)?.cast<String>() ?? [];
          final now = DateTime.now();
          final upcoming = events.where((row) {
            final start = DateTime.tryParse(
              row['events']?['start_datetime'] ?? '',
            );
            return start != null && start.isAfter(now);
          }).toList();
          final past = events.length - upcoming.length;

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
                      const GenreArtwork(genre: EventGenre.kammermusik),
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
                      person['full_name'] ?? '',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    if (roles.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: roles
                            .map(
                              (r) => Chip(
                                label: Text(
                                  r,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (person['nationality'] != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        [
                          person['nationality'],
                          if (person['birth_date'] != null)
                            '* ${(person['birth_date'] as String).substring(0, 4)}'
                                '${person['death_date'] != null ? ' † ${(person['death_date'] as String).substring(0, 4)}' : ''}',
                        ].join(' · '),
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (person['biography_de'] != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        person['biography_de'],
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          height: 1.5,
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
                      for (final row in upcoming)
                        _EventRow(row: row, colors: colors),
                    if (past > 0) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        '$past vergangene Veranstaltung${past == 1 ? '' : 'en'}',
                        style: TextStyle(
                          color: colors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
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

class _EventRow extends StatelessWidget {
  const _EventRow({required this.row, required this.colors});
  final dynamic row;
  final AppColorsExtension colors;

  @override
  Widget build(BuildContext context) {
    final event = row['events'] as Map<String, dynamic>?;
    if (event == null) return const SizedBox.shrink();
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
      subtitle: Text(
        [
          if (event['venues']?['name'] != null) event['venues']['name'],
          if (start != null) '${start.day}.${start.month}.${start.year}',
        ].join(' · '),
        style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
      ),
      onTap: () => context.push('/event/${event['slug']}'),
    );
  }
}
