import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/notifications/notification_preferences_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

const _rows = [
  (
    key: NotificationPreferenceKey.newMatchingEvents,
    title: 'Neue passende Veranstaltungen',
    subtitle: 'Basierend auf deinen Interessen (Genres, Komponisten, Venues)',
  ),
  (
    key: NotificationPreferenceKey.priceChanges,
    title: 'Preisänderungen',
    subtitle: 'Bei Veranstaltungen, die du favorisiert hast',
  ),
  (
    key: NotificationPreferenceKey.almostSoldOut,
    title: 'Fast ausverkauft',
    subtitle: 'Letzte Tickets für favorisierte Veranstaltungen',
  ),
  (
    key: NotificationPreferenceKey.reminderDayBefore,
    title: 'Erinnerung am Vortag',
    subtitle: 'Für favorisierte Veranstaltungen, die morgen stattfinden',
  ),
  (
    key: NotificationPreferenceKey.followedEnsembleNewEvent,
    title: 'Neue Termine gefolgter Ensembles',
    subtitle:
        'Wenn ein Ensemble oder eine Person, die dich interessiert, eine neue Veranstaltung ankündigt',
  ),
];

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Benachrichtigungen')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              'Bitte im Profil-Tab anmelden, um Benachrichtigungen einzustellen.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
        ),
      );
    }

    final prefsAsync = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Benachrichtigungen')),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Fehler beim Laden: $e',
            style: TextStyle(color: colors.error),
          ),
        ),
        data: (prefs) => ListView(
          children: [
            for (final row in _rows)
              SwitchListTile(
                title: Text(
                  row.title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  row.subtitle,
                  style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
                ),
                value: prefs[row.key],
                activeThumbColor: colors.accentPrimary,
                onChanged: (value) =>
                    NotificationPreferencesService.setPreference(
                      ref,
                      key: row.key,
                      value: value,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
