import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
