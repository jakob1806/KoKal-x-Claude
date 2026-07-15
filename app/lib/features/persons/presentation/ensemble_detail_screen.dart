import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/genre_artwork.dart';

final _ensembleProvider = FutureProvider.family<Map<String, dynamic>?, String>((
  ref,
  slug,
) async {
  final client = Supabase.instance.client;
  final ensemble = await client
      .from('ensembles')
      .select('*, home_venue:venues(name)')
      .eq('slug', slug)
      .maybeSingle();
  if (ensemble == null) return null;

  final events = await client
      .from('event_participants')
      .select('events(id, slug, title, start_datetime, venues(name))')
      .eq('ensemble_id', ensemble['id'])
      .order('events(start_datetime)');

  return {'ensemble': ensemble, 'events': events};
});

const _typeLabel = {
  'chor': 'Chor',
  'orchester': 'Orchester',
  'kammerensemble': 'Kammerensemble',
  'big_band': 'Big Band',
  'sonstiges': 'Ensemble',
};

class EnsembleDetailScreen extends ConsumerWidget {
  const EnsembleDetailScreen({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_ensembleProvider(slug));
    final colors = context.appColors;

    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler beim Laden: $e')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Ensemble nicht gefunden'));
          }
          final ensemble = data['ensemble'] as Map<String, dynamic>;
          final events = data['events'] as List;
          final now = DateTime.now();
          final upcoming = events.where((row) {
            final start = DateTime.tryParse(
              row['events']?['start_datetime'] ?? '',
            );
            return start != null && start.isAfter(now);
          }).toList();

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
                      const GenreArtwork(genre: EventGenre.orchester),
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
                      ensemble['name'] ?? '',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        _typeLabel[ensemble['type']] ?? ensemble['type'],
                        if (ensemble['founded_year'] != null)
                          'seit ${ensemble['founded_year']}',
                        if (ensemble['home_venue']?['name'] != null)
                          ensemble['home_venue']['name'],
                      ].join(' · '),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    if (ensemble['description_de'] != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        ensemble['description_de'],
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
                        _EnsembleEventRow(row: row, colors: colors),
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

class _EnsembleEventRow extends StatelessWidget {
  const _EnsembleEventRow({required this.row, required this.colors});
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
