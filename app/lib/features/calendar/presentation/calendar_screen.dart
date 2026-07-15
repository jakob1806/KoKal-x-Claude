import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPaddingMobile,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kalender', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.lg),
            TableCalendar(
              locale: 'de_DE',
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selected, focused) => setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              }),
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
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: Center(
                child: Text(
                  'Agenda-Anbindung an Supabase folgt in Phase 1',
                  style: TextStyle(color: colors.textTertiary, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
