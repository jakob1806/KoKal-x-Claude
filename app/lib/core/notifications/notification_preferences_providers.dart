import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';

enum NotificationPreferenceKey {
  newMatchingEvents('notify_new_matching_events'),
  priceChanges('notify_price_changes'),
  almostSoldOut('notify_almost_sold_out'),
  reminderDayBefore('notify_reminder_day_before');

  const NotificationPreferenceKey(this.column);

  final String column;
}

class NotificationPreferences {
  const NotificationPreferences({
    required this.newMatchingEvents,
    required this.priceChanges,
    required this.almostSoldOut,
    required this.reminderDayBefore,
  });

  final bool newMatchingEvents;
  final bool priceChanges;
  final bool almostSoldOut;
  final bool reminderDayBefore;

  static const defaults = NotificationPreferences(
    newMatchingEvents: true,
    priceChanges: true,
    almostSoldOut: true,
    reminderDayBefore: true,
  );

  bool operator [](NotificationPreferenceKey key) => switch (key) {
    NotificationPreferenceKey.newMatchingEvents => newMatchingEvents,
    NotificationPreferenceKey.priceChanges => priceChanges,
    NotificationPreferenceKey.almostSoldOut => almostSoldOut,
    NotificationPreferenceKey.reminderDayBefore => reminderDayBefore,
  };

  factory NotificationPreferences.fromRow(Map<String, dynamic> row) {
    return NotificationPreferences(
      newMatchingEvents: row['notify_new_matching_events'] as bool? ?? true,
      priceChanges: row['notify_price_changes'] as bool? ?? true,
      almostSoldOut: row['notify_almost_sold_out'] as bool? ?? true,
      reminderDayBefore: row['notify_reminder_day_before'] as bool? ?? true,
    );
  }
}

final notificationPreferencesProvider =
    FutureProvider.autoDispose<NotificationPreferences>((ref) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) return NotificationPreferences.defaults;

      final row = await Supabase.instance.client
          .from('profiles')
          .select(
            'notify_new_matching_events, notify_price_changes, '
            'notify_almost_sold_out, notify_reminder_day_before',
          )
          .eq('id', user.id)
          .single();
      return NotificationPreferences.fromRow(row);
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

    await Supabase.instance.client
        .from('profiles')
        .update({key.column: value})
        .eq('id', user.id);
    ref.invalidate(notificationPreferencesProvider);
  }
}
