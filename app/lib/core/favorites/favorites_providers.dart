import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';

/// IDs der vom aktuellen Nutzer favorisierten Events. Ein einzelner Set-Read
/// statt einer Einzelabfrage pro Karte — wird nach jedem Toggle invalidiert.
final favoriteIdsProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};

  final rows = await Supabase.instance.client
      .from('favorites')
      .select('event_id')
      .eq('user_id', user.id);
  return (rows as List).map((r) => r['event_id'] as String).toSet();
});

class FavoritesService {
  const FavoritesService._();

  static Future<void> toggle(
    WidgetRef ref, {
    required String eventId,
    required bool isFavorited,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    if (isFavorited) {
      await Supabase.instance.client
          .from('favorites')
          .delete()
          .eq('user_id', user.id)
          .eq('event_id', eventId);
    } else {
      await Supabase.instance.client.from('favorites').insert({
        'user_id': user.id,
        'event_id': eventId,
      });
    }
    ref.invalidate(favoriteIdsProvider);
  }
}
