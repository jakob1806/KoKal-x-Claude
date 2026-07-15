import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Push-Grundintegration (FCM). Bewusst schlank gehalten für den ersten
/// Wurf: Berechtigung anfragen, Token in `push_tokens` speichern,
/// eingehende Nachrichten im Vordergrund loggen. Das serverseitige
/// Auslösen (neue Events, Preisänderungen, Erinnerungen) folgt als
/// eigener Ausbauschritt über eine Edge Function, siehe
/// docs/03-api-concept.md, `/functions/v1/notify/*`.
///
/// iOS-Zustellung erfordert zusätzlich einen APNs-Auth-Key im Firebase-
/// Projekt (braucht ein Apple-Developer-Programm-Konto) — ohne das bleibt
/// die iOS-Registrierung wirkungslos, Android funktioniert unabhängig davon.
class PushService {
  const PushService._();

  static final _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(token);
    }
    _messaging.onTokenRefresh.listen(_saveToken);

    FirebaseMessaging.onMessage.listen((message) {
      debugPrint(
        'Push (Vordergrund): ${message.notification?.title} — ${message.notification?.body}',
      );
    });
  }

  static Future<void> _saveToken(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final platform = Platform.isIOS ? 'ios' : 'android';
    await Supabase.instance.client.from('push_tokens').upsert({
      'user_id': user.id,
      'token': token,
      'platform': platform,
    }, onConflict: 'token');
  }
}
