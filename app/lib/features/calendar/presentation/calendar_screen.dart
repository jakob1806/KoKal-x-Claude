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

DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final monthKey = MonthKey(_focusedDay.year, _focusedDay.month);
    final monthAsync = ref.watch(monthEventsProvider(monthKey));
    final eventsByDay = monthAsync.valueOrNull ?? const {};
    final agenda = eventsByDay[_dayKey(_selectedDay)] ?? const [];

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingMobile,
              vertical: AppSpacing.md,
            ),
            child: Text('Kalender', style: Theme.of(context).textTheme.headlineMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingMobile,
            ),
            child: TableCalendar(
              locale: 'de_DE',
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: (day) => eventsByDay[_dayKey(day)] ?? const [],
              onDaySelected: (selected, focused) => setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              }),
              onPageChanged: (focused) => setState(() => _focusedDay = focused),
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
          Expanded(
            child: _AgendaList(
              day: _selectedDay,
              events: agenda,
              isLoading: monthAsync.isLoading && !monthAsync.hasValue,
              error: monthAsync.hasError ? monthAsync.error : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaList extends StatelessWidget {
  const _AgendaList({
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
        child: Text('Fehler beim Laden: $error', style: TextStyle(color: colors.error)),
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
      itemBuilder: (context, i) {
        final e = events[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: SizedBox(
            width: 48,
            height: 48,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: GenreArtwork(genre: e.genre),
            ),
          ),
          title: Text(
            e.title,
            style: TextStyle(fontWeight: FontWeight.w700, color: colors.textPrimary),
          ),
          subtitle: Text(
            e.venueAndTime,
            style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
          ),
          trailing: FavoriteButton(eventId: e.id, size: 20),
          onTap: () => context.push('/event/${e.slug}'),
        );
      },
    );
  }
}
