import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/push/push_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Env.load();
  await initializeDateFormatting('de_DE', null);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (Env.supabaseUrl.isNotEmpty && Env.supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );

    // Jede Session braucht einen profiles-Datensatz — Favoriten, Interessen
    // und Benachrichtigungseinstellungen hängen alle an user_id, was ohne
    // irgendeine Session (auch ohne echten Login) nie der Fall wäre. Scheitert
    // das offline beim allerersten Start, bleibt die App nutzbar, nur ohne
    // Personalisierung bis zum nächsten Start mit Netz.
    if (Supabase.instance.client.auth.currentUser == null) {
      try {
        await Supabase.instance.client.auth.signInAnonymously();
      } catch (_) {}
    }
  }

  // Wiederkehrende, bereits *echt* eingeloggte Nutzer bekommen Push direkt
  // beim Start registriert. Erstanmeldung stößt das stattdessen über den
  // Auth-State-Listener in KlassikMuenchenApp an, sobald der Login
  // tatsächlich abgeschlossen ist (relevant v.a. für OAuth, das über einen
  // externen Browser läuft und nicht synchron zurückkehrt); die anonyme
  // Bootstrap-Session oben triggert das bewusst nicht — Berechtigung wird
  // erst im Onboarding-Flow bzw. beim ersten echten Login abgefragt.
  final startupUser = Supabase.instance.client.auth.currentUser;
  if (startupUser != null && !startupUser.isAnonymous) {
    unawaited(PushService.initialize());
  }

  runApp(const ProviderScope(child: KlassikMuenchenApp()));
}

class KlassikMuenchenApp extends ConsumerStatefulWidget {
  const KlassikMuenchenApp({super.key});

  @override
  ConsumerState<KlassikMuenchenApp> createState() => _KlassikMuenchenAppState();
}

class _KlassikMuenchenAppState extends ConsumerState<KlassikMuenchenApp> {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    try {
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((data) {
            if (data.event == AuthChangeEvent.signedIn) {
              PushService.initialize();
            }
          });
    } catch (_) {
      // Supabase wurde nicht initialisiert (z. B. in Widget-Tests ohne main()) — kein Push-Setup nötig.
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Klassik München',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: appRouter,
      locale: const Locale('de', 'DE'),
      supportedLocales: const [Locale('de', 'DE'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
