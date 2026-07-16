import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/home/application/home_providers.dart';
import 'event_filters.dart';

final eventFiltersProvider = StateProvider<EventFilters>(
  (ref) => EventFilters.empty,
);

/// Direkte events-Query statt search_all() — die Filter (Datum, Preis,
/// Barrierefrei, Open Air) gelten nur für Events, während search_all über
/// vier verschiedene Entitätstypen sucht. Genre steckt in der
/// event_genres-Junction-Tabelle, daher !inner + Filter auf die eingebettete
/// Spalte nur, wenn tatsächlich Genres ausgewählt sind — sonst würde jedes
/// Event ohne Genre-Zuordnung aus den Ergebnissen fallen.
final filteredEventsProvider = FutureProvider.autoDispose<List<HomeEventItem>>((
  ref,
) async {
  final filters = ref.watch(eventFiltersProvider);
  if (!filters.isActive) return [];

  final hasGenreFilter = filters.genreIds.isNotEmpty;
  final selectCols = hasGenreFilter
      ? 'id, slug, title, subtitle, is_free, remaining_tickets_status, start_datetime, venues(name), event_genres!inner(genre_id, genres(slug))'
      : 'id, slug, title, subtitle, is_free, remaining_tickets_status, start_datetime, venues(name), event_genres(genres(slug))';

  var query = Supabase.instance.client
      .from('events')
      .select(selectCols)
      .eq('status', 'scheduled');

  if (hasGenreFilter) {
    query = query.inFilter('event_genres.genre_id', filters.genreIds.toList());
  }
  final range = filters.dateRange;
  if (range != null) {
    final endExclusive = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
    ).add(const Duration(days: 1));
    query = query
        .gte('start_datetime', range.start.toIso8601String())
        .lt('start_datetime', endExclusive.toIso8601String());
  }
  if (filters.maxPrice != null) {
    query = query.or('price_min.lte.${filters.maxPrice},is_free.eq.true');
  }
  if (filters.accessibleOnly) {
    query = query.eq('accessibility->>wheelchair', true);
  }
  if (filters.openAirOnly) {
    query = query.eq('is_open_air', true);
  }

  final rows = await query.order('start_datetime').limit(50);
  return (rows as List)
      .map((r) => HomeEventItem.fromRow(r as Map<String, dynamic>))
      .toList();
});
