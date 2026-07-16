import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../home/application/home_providers.dart';

/// Schlüssel für [monthEventsProvider] — Jahr+Monat statt eines konkreten
/// Tages, damit ein Monatswechsel im Kalender genau eine Query auslöst statt
/// einer pro sichtbarem Tag.
class MonthKey {
  const MonthKey(this.year, this.month);

  final int year;
  final int month;

  @override
  bool operator ==(Object other) =>
      other is MonthKey && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

const _calendarEventColumns =
    'id, slug, title, subtitle, is_free, remaining_tickets_status, start_datetime, venues(name), event_genres(genres(slug))';

DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

/// Events eines Monats, gruppiert nach Kalendertag — Basis sowohl für die
/// Punkt-Marker im Monatsraster als auch für die Agenda-Liste darunter.
final monthEventsProvider = FutureProvider.autoDispose
    .family<Map<DateTime, List<HomeEventItem>>, MonthKey>((ref, key) async {
      final start = DateTime(key.year, key.month, 1);
      final end = DateTime(key.year, key.month + 1, 1);

      final rows = await Supabase.instance.client
          .from('events')
          .select(_calendarEventColumns)
          .eq('status', 'scheduled')
          .gte('start_datetime', start.toIso8601String())
          .lt('start_datetime', end.toIso8601String())
          .order('start_datetime');

      final byDay = <DateTime, List<HomeEventItem>>{};
      for (final row in rows as List) {
        final map = row as Map<String, dynamic>;
        final item = HomeEventItem.fromRow(map);
        if (item.startDateTime == null) continue;
        byDay.putIfAbsent(_dayKey(item.startDateTime!), () => []).add(item);
      }
      return byDay;
    });

/// Event mit den Feldern, die ein Kalender-Eintrag braucht (Dauer, Adresse,
/// Link) statt der schlankeren [HomeEventItem] aus den Listen-Providern.
class SyncableEvent {
  const SyncableEvent({
    required this.id,
    required this.title,
    required this.start,
    this.durationMinutes,
    this.description,
    this.location,
    this.url,
  });

  final String id;
  final String title;
  final DateTime start;
  final int? durationMinutes;
  final String? description;
  final String? location;
  final String? url;

  DateTime get end => start.add(Duration(minutes: durationMinutes ?? 120));
}

/// Für den Kalender-Sync-Sheet (Apple/Google Kalender, ICS-Export): nur
/// anstehende favorisierte Events — vergangene in den Gerätekalender/eine
/// ICS zu schreiben wäre nutzlos.
final upcomingFavoriteEventsProvider =
    FutureProvider.autoDispose<List<SyncableEvent>>((ref) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) return [];

      final rows = await Supabase.instance.client
          .from('favorites')
          .select(
            'events(id, title, description_de, start_datetime, duration_minutes, website_url, ticket_url, venues(name, address_street, address_zip, address_city))',
          )
          .eq('user_id', user.id);

      final now = DateTime.now();
      final events = <SyncableEvent>[];
      for (final row in rows as List) {
        final e = row['events'] as Map<String, dynamic>?;
        if (e == null) continue;
        final start = DateTime.tryParse(e['start_datetime'] as String? ?? '');
        if (start == null || !start.isAfter(now)) continue;

        final venue = e['venues'] as Map<String, dynamic>?;
        events.add(
          SyncableEvent(
            id: e['id'] as String,
            title: e['title'] as String? ?? '',
            start: start,
            durationMinutes: e['duration_minutes'] as int?,
            description: e['description_de'] as String?,
            location: venue == null
                ? null
                : [
                    venue['name'],
                    venue['address_street'],
                    venue['address_zip'],
                    venue['address_city'],
                  ].whereType<String>().join(', '),
            url: e['website_url'] as String? ?? e['ticket_url'] as String?,
          ),
        );
      }
      events.sort((a, b) => a.start.compareTo(b.start));
      return events;
    });

/// Für den Agenda-Modus: chronologische Liste ab heute statt an einen
/// Kalendermonat gebunden, mit Cap statt Datumsgrenze — bei Konzerten kein
/// Bedarf für Pagination, ein Limit reicht als Schutz vor unbegrenztem Fetch.
final agendaEventsProvider =
    FutureProvider.autoDispose<Map<DateTime, List<HomeEventItem>>>((ref) async {
      final now = DateTime.now();
      final rows = await Supabase.instance.client
          .from('events')
          .select(_calendarEventColumns)
          .eq('status', 'scheduled')
          .gte('start_datetime', _dayKey(now).toIso8601String())
          .order('start_datetime')
          .limit(200);

      final byDay = <DateTime, List<HomeEventItem>>{};
      for (final row in rows as List) {
        final map = row as Map<String, dynamic>;
        final item = HomeEventItem.fromRow(map);
        if (item.startDateTime == null) continue;
        byDay.putIfAbsent(_dayKey(item.startDateTime!), () => []).add(item);
      }
      return byDay;
    });
