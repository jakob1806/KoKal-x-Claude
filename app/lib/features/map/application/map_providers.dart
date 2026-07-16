import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MapVenue {
  const MapVenue({
    required this.id,
    required this.slug,
    required this.name,
    required this.addressCity,
    required this.lat,
    required this.lng,
    required this.upcomingEventCount,
  });

  final String id;
  final String slug;
  final String name;
  final String? addressCity;
  final double lat;
  final double lng;
  final int upcomingEventCount;

  factory MapVenue.fromRow(Map<String, dynamic> row) {
    return MapVenue(
      id: row['id'] as String,
      slug: row['slug'] as String,
      name: row['name'] as String? ?? '',
      addressCity: row['address_city'] as String?,
      lat: (row['lat'] as num).toDouble(),
      lng: (row['lng'] as num).toDouble(),
      upcomingEventCount: (row['upcoming_event_count'] as num?)?.toInt() ?? 0,
    );
  }
}

final mapVenuesProvider = FutureProvider.autoDispose<List<MapVenue>>((
  ref,
) async {
  final rows = await Supabase.instance.client.rpc('venues_with_latlng');
  return (rows as List)
      .map((r) => MapVenue.fromRow(r as Map<String, dynamic>))
      .toList();
});
