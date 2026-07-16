import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/genre_artwork.dart';

const _homeEventColumns =
    'id, slug, title, subtitle, is_free, remaining_tickets_status, start_datetime, venues(name), event_genres(genres(slug))';

String _formatDateTime(DateTime d) {
  final time =
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  final now = DateTime.now();
  final isToday =
      d.year == now.year && d.month == now.month && d.day == now.day;
  if (isToday) return 'Heute · $time';
  return '${d.day}.${d.month}. · $time';
}

class HomeEventItem {
  const HomeEventItem({
    required this.id,
    required this.slug,
    required this.title,
    required this.venueAndTime,
    required this.genre,
    required this.startDateTime,
    this.venueId,
    this.badge,
  });

  final String id;
  final String slug;
  final String title;
  final String venueAndTime;
  final EventGenre genre;
  final DateTime? startDateTime;
  final String? venueId;
  final String? badge;

  factory HomeEventItem.fromRow(Map<String, dynamic> row) {
    final start = DateTime.tryParse(row['start_datetime'] as String? ?? '');
    final venueName = row['venues']?['name'] as String?;
    final genreSlugs = (row['event_genres'] as List? ?? [])
        .map((g) => g['genres']?['slug'] as String?)
        .whereType<String>();

    String? badge;
    if (row['is_free'] == true) {
      badge = 'Kostenlos';
    } else if (row['remaining_tickets_status'] == 'few_left') {
      badge = 'Fast ausverkauft';
    }

    return HomeEventItem(
      id: row['id'] as String,
      slug: row['slug'] as String,
      title: row['title'] as String? ?? '',
      venueAndTime: [
        venueName,
        start != null ? _formatDateTime(start) : null,
      ].whereType<String>().join(' · '),
      genre: EventGenre.fromSlug(genreSlugs.isEmpty ? null : genreSlugs.first),
      startDateTime: start,
      venueId: row['venue_id'] as String?,
      badge: badge,
    );
  }
}

class HomeData {
  const HomeData({
    required this.hero,
    required this.heute,
    required this.empfehlungen,
    required this.beliebt,
    required this.neu,
    required this.kostenlos,
    required this.ausverkauft,
  });

  final Map<String, dynamic>? hero;
  final List<HomeEventItem> heute;
  final List<HomeEventItem> empfehlungen;
  final List<HomeEventItem> beliebt;
  final List<HomeEventItem> neu;
  final List<HomeEventItem> kostenlos;
  final List<HomeEventItem> ausverkauft;
}

final homeDataProvider = FutureProvider.autoDispose<HomeData>((ref) async {
  final client = Supabase.instance.client;
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = todayStart.add(const Duration(days: 1));
  final nowIso = now.toIso8601String();

  final results = await Future.wait<dynamic>([
    client
        .from('events')
        .select(_homeEventColumns)
        .eq('status', 'scheduled')
        .gte('start_datetime', nowIso)
        .order('start_datetime')
        .limit(1),
    client
        .from('events')
        .select(_homeEventColumns)
        .eq('status', 'scheduled')
        .gte('start_datetime', todayStart.toIso8601String())
        .lt('start_datetime', todayEnd.toIso8601String())
        .order('start_datetime'),
    // Regelbasierte Empfehlungen (docs/06-mvp-plan.md,
    // "MVP-Empfehlungslogik") — degradiert für anonyme/interesselose
    // Nutzer serverseitig automatisch zu Popularität + zeitlicher Nähe,
    // kein Sonderfall hier im Client nötig.
    client.rpc('recommended_events', params: {'p_result_limit': 10}),
    client.rpc('popular_events', params: {'p_result_limit': 10}),
    client
        .from('events')
        .select(_homeEventColumns)
        .eq('status', 'scheduled')
        .order('created_at', ascending: false)
        .limit(10),
    client
        .from('events')
        .select(_homeEventColumns)
        .eq('status', 'scheduled')
        .eq('is_free', true)
        .gte('start_datetime', nowIso)
        .order('start_datetime')
        .limit(10),
    client
        .from('events')
        .select(_homeEventColumns)
        .eq('status', 'scheduled')
        .eq('remaining_tickets_status', 'few_left')
        .gte('start_datetime', nowIso)
        .order('start_datetime')
        .limit(10),
  ]);

  final heroRows = results[0] as List;

  return HomeData(
    hero: heroRows.isEmpty ? null : heroRows.first as Map<String, dynamic>,
    heute: (results[1] as List)
        .map((r) => HomeEventItem.fromRow(r as Map<String, dynamic>))
        .toList(),
    empfehlungen: (results[2] as List)
        .map((r) => HomeEventItem.fromRow(r as Map<String, dynamic>))
        .toList(),
    beliebt: (results[3] as List)
        .map((r) => HomeEventItem.fromRow(r as Map<String, dynamic>))
        .toList(),
    neu: (results[4] as List)
        .map((r) => HomeEventItem.fromRow(r as Map<String, dynamic>))
        .toList(),
    kostenlos: (results[5] as List)
        .map((r) => HomeEventItem.fromRow(r as Map<String, dynamic>))
        .toList(),
    ausverkauft: (results[6] as List)
        .map((r) => HomeEventItem.fromRow(r as Map<String, dynamic>))
        .toList(),
  );
});
