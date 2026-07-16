import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';

enum NotificationPreferenceKey {
  newMatchingEvents('new_matching_events'),
  priceChanges('price_changes'),
  almostSoldOut('almost_sold_out'),
  reminderDayBefore('reminder_day_before'),
  followedEnsembleNewEvent('followed_ensemble_new_event');

  const NotificationPreferenceKey(this.column);

  final String column;
}

class NotificationPreferences {
  const NotificationPreferences({
    required this.newMatchingEvents,
    required this.priceChanges,
    required this.almostSoldOut,
    required this.reminderDayBefore,
    required this.followedEnsembleNewEvent,
  });

  final bool newMatchingEvents;
  final bool priceChanges;
  final bool almostSoldOut;
  final bool reminderDayBefore;
  final bool followedEnsembleNewEvent;

  static const defaults = NotificationPreferences(
    newMatchingEvents: true,
    priceChanges: true,
    almostSoldOut: true,
    reminderDayBefore: true,
    followedEnsembleNewEvent: true,
  );

  bool operator [](NotificationPreferenceKey key) => switch (key) {
    NotificationPreferenceKey.newMatchingEvents => newMatchingEvents,
    NotificationPreferenceKey.priceChanges => priceChanges,
    NotificationPreferenceKey.almostSoldOut => almostSoldOut,
    NotificationPreferenceKey.reminderDayBefore => reminderDayBefore,
    NotificationPreferenceKey.followedEnsembleNewEvent =>
      followedEnsembleNewEvent,
  };

  factory NotificationPreferences.fromRow(Map<String, dynamic> row) {
    return NotificationPreferences(
      newMatchingEvents: row['new_matching_events'] as bool? ?? true,
      priceChanges: row['price_changes'] as bool? ?? true,
      almostSoldOut: row['almost_sold_out'] as bool? ?? true,
      reminderDayBefore: row['reminder_day_before'] as bool? ?? true,
      followedEnsembleNewEvent:
          row['followed_ensemble_new_event'] as bool? ?? true,
    );
  }
}

/// notification_preferences existiert seit Phase 0 als eigene Tabelle,
/// aber ohne Zeile pro Nutzer (kein Auto-Insert-Trigger wie bei profiles) —
/// vor dem ersten Toggle also einfach noch keine Zeile, daher der
/// Default-Fallback statt .single().
final notificationPreferencesProvider =
    FutureProvider.autoDispose<NotificationPreferences>((ref) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) return NotificationPreferences.defaults;

      final row = await Supabase.instance.client
          .from('notification_preferences')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      return row == null
          ? NotificationPreferences.defaults
          : NotificationPreferences.fromRow(row);
    });

class NotificationPreferencesService {
  const NotificationPreferencesService._();

  static Future<void> setPreference(
    WidgetRef ref, {
    required NotificationPreferenceKey key,
    required bool value,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Upsert statt update — vor dem ersten Toggle gibt es noch keine Zeile;
    // die übrigen Spalten fallen dann korrekt auf ihre eigenen DB-Defaults
    // (default true) zurück statt auf null.
    await Supabase.instance.client.from('notification_preferences').upsert({
      'user_id': user.id,
      key.column: value,
    }, onConflict: 'user_id');
    ref.invalidate(notificationPreferencesProvider);
  }
}
