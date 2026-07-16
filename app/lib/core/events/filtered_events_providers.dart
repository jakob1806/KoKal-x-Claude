import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/home/application/home_providers.dart';
import 'event_filters.dart';

final eventFiltersProvider = StateProvider<EventFilters>(
  (ref) => EventFilters.empty,
);

/// Ruft filter_events() statt search_all() oder eines client-seitigen
/// Query-Builders auf — Entfernung braucht profiles.home_location +
/// ST_DWithin gegen venues.location serverseitig, das lässt sich über
/// PostgREST-Filter-Syntax auf einer eingebetteten Ressource nicht robust
/// ausdrücken. Eine RPC für alle sechs Dimensionen ist außerdem weniger
/// fragil als sechs unabhängige Query-Builder-Bedingungen im Client.
final filteredEventsProvider = FutureProvider.autoDispose<List<HomeEventItem>>((
  ref,
) async {
  final filters = ref.watch(eventFiltersProvider);
  if (!filters.isActive) return [];

  final range = filters.dateRange;
  final dateTo = range == null
      ? null
      : DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
        ).add(const Duration(days: 1));

  final rows = await Supabase.instance.client.rpc(
    'filter_events',
    params: {
      'p_genre_ids': filters.genreIds.isEmpty
          ? null
          : filters.genreIds.toList(),
      'p_date_from': range?.start.toIso8601String(),
      'p_date_to': dateTo?.toIso8601String(),
      'p_max_price': filters.maxPrice,
      'p_accessible_only': filters.accessibleOnly,
      'p_open_air_only': filters.openAirOnly,
      'p_max_distance_km': filters.maxDistanceKm,
    },
  );

  return (rows as List)
      .map((r) => HomeEventItem.fromRow(r as Map<String, dynamic>))
      .toList();
});
