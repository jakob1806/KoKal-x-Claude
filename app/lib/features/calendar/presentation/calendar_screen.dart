import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/favorite_button.dart';
import '../../../core/widgets/genre_artwork.dart';
import '../../home/application/home_providers.dart';
import '../application/calendar_providers.dart';
import 'widgets/calendar_sync_sheet.dart';

DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

enum _CalendarViewMode { month, week, agenda }

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  _CalendarViewMode _mode = _CalendarViewMode.month;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final monthKey = MonthKey(_focusedDay.year, _focusedDay.month);
    final monthAsync = ref.watch(monthEventsProvider(monthKey));
    final eventsByDay = <DateTime, List<HomeEventItem>>{
      ...monthAsync.valueOrNull ?? const {},
    };
    // Woche-Format zeigt table_calendar zufolge die Mon-So-Woche um
    // _focusedDay — die kann in den vorigen/nächsten Monat hineinragen,
    // dessen Events monthEventsProvider (nur _focusedDay's Monat) nicht
    // enthält. Fehlender Monat wird bei Bedarf zusätzlich geladen.
    if (_mode == _CalendarViewMode.week) {
      final weekStart = _focusedDay.subtract(
        Duration(days: _focusedDay.weekday - 1),
      );
      final weekEnd = weekStart.add(const Duration(days: 6));
      for (final edge in [weekStart, weekEnd]) {
        if (edge.month != _focusedDay.month || edge.year != _focusedDay.year) {
          final edgeAsync = ref.watch(
            monthEventsProvider(MonthKey(edge.year, edge.month)),
          );
          eventsByDay.addAll(edgeAsync.valueOrNull ?? const {});
        }
      }
    }
    final dayAgenda = eventsByDay[_dayKey(_selectedDay)] ?? const [];

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingMobile,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Kalender',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.sync_rounded, color: colors.textSecondary),
                  tooltip: 'Kalender synchronisieren',
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    builder: (_) => const CalendarSyncSheet(),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingMobile,
            ),
            child: SegmentedButton<_CalendarViewMode>(
              segments: const [
                ButtonSegment(
                  value: _CalendarViewMode.month,
                  label: Text('Monat'),
                ),
                ButtonSegment(
                  value: _CalendarViewMode.week,
                  label: Text('Woche'),
                ),
                ButtonSegment(
                  value: _CalendarViewMode.agenda,
                  label: Text('Agenda'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) =>
                  setState(() => _mode = selection.first),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_mode != _CalendarViewMode.agenda) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPaddingMobile,
              ),
              child: TableCalendar(
                locale: 'de_DE',
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                calendarFormat: _mode == _CalendarViewMode.week
                    ? CalendarFormat.week
                    : CalendarFormat.month,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: (day) => eventsByDay[_dayKey(day)] ?? const [],
                onDaySelected: (selected, focused) => setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                }),
                onPageChanged: (focused) =>
                    setState(() => _focusedDay = focused),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: colors.accentPrimary,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: colors.accentSecondary,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: colors.accentPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Divider(color: colors.separator, height: 1),
          ],
          Expanded(
            child: _mode == _CalendarViewMode.agenda
                ? const _FullAgendaList()
                : _DayAgendaList(
                    day: _selectedDay,
                    events: dayAgenda,
                    isLoading: monthAsync.isLoading && !monthAsync.hasValue,
                    error: monthAsync.hasError ? monthAsync.error : null,
                  ),
          ),
        ],
      ),
    );
  }
}

class _DayAgendaList extends StatelessWidget {
  const _DayAgendaList({
    required this.day,
    required this.events,
    required this.isLoading,
    required this.error,
  });

  final DateTime day;
  final List<HomeEventItem> events;
  final bool isLoading;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dayLabel = DateFormat('EEEE, d. MMMM', 'de_DE').format(day);

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Text(
          'Fehler beim Laden: $error',
          style: TextStyle(color: colors.error),
        ),
      );
    }
    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'Keine Veranstaltungen am $dayLabel.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingMobile,
        vertical: AppSpacing.md,
      ),
      itemCount: events.length,
      separatorBuilder: (_, __) => Divider(color: colors.separator, height: 1),
      itemBuilder: (context, i) => _EventTile(event: events[i], colors: colors),
    );
  }
}

/// Agenda-Modus: chronologische Liste ab heute mit Tages-Überschriften statt
/// der Tagesauswahl in Monat/Woche — siehe [agendaEventsProvider].
class _FullAgendaList extends ConsumerWidget {
  const _FullAgendaList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final async = ref.watch(agendaEventsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Fehler beim Laden: $e',
          style: TextStyle(color: colors.error),
        ),
      ),
      data: (eventsByDay) {
        if (eventsByDay.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                'Keine anstehenden Veranstaltungen.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
          );
        }

        final days = eventsByDay.keys.toList()..sort();
        return ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPaddingMobile,
            vertical: AppSpacing.md,
          ),
          itemCount: days.length,
          itemBuilder: (context, i) {
            final day = days[i];
            final events = eventsByDay[day]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (i > 0) const SizedBox(height: AppSpacing.lg),
                Text(
                  DateFormat('EEEE, d. MMMM', 'de_DE').format(day),
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final event in events)
                  _EventTile(event: event, colors: colors),
              ],
            );
          },
        );
      },
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.colors});

  final HomeEventItem event;
  final AppColorsExtension colors;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: SizedBox(
        width: 48,
        height: 48,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: GenreArtwork(genre: event.genre),
        ),
      ),
      title: Text(
        event.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
      ),
      subtitle: Text(
        event.venueAndTime,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
      ),
      trailing: FavoriteButton(eventId: event.id, size: 20),
      onTap: () => context.push('/event/${event.slug}'),
    );
  }
}
