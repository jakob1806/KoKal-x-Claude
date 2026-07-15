import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Liest Umgebungsvariablen aus `.env` (lokal, nicht eingecheckt — siehe
/// `.env.example`). In CI/Store-Builds werden dieselben Keys stattdessen via
/// `--dart-define-from-file` gesetzt; `Env.load()` fällt in dem Fall auf
/// `dotenv.env` mit leeren Defaults zurück, ohne zu crashen.
class Env {
  const Env._();

  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // .env fehlt (z. B. im Release-Build) — Werte kommen dann aus --dart-define.
    }
  }

  static String get supabaseUrl => _read('SUPABASE_URL');
  static String get supabaseAnonKey => _read('SUPABASE_ANON_KEY');
  static String get googleMapsApiKey => _read('GOOGLE_MAPS_API_KEY');

  static String _read(String key) {
    final fromDefine = String.fromEnvironment(key);
    final value = dotenv.env[key] ?? (fromDefine.isNotEmpty ? fromDefine : '');
    if (value.isEmpty) {
      // ignore: avoid_print
      print('[Env] Warnung: $key ist nicht gesetzt. Siehe .env.example.');
    }
    return value;
  }
}
