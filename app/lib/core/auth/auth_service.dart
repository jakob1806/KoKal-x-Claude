import 'package:supabase_flutter/supabase_flutter.dart';

/// Kapselt Supabase-Auth-Aufrufe. E-Mail-Login läuft über einen 6-stelligen
/// Code statt über einen Magic-Link — braucht dadurch keinen registrierten
/// Deep-Link/keine freigegebene Redirect-URL (siehe docs/07-roadmap.md).
/// Sign in with Apple/Google braucht beides und funktioniert erst, sobald
/// die OAuth-Provider im Supabase-Dashboard konfiguriert sind.
class AuthService {
  const AuthService._();

  static const _oauthRedirect = 'de.klassikmuenchen://login-callback';

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<void> sendEmailCode(String email) {
    return _client.auth.signInWithOtp(email: email, shouldCreateUser: true);
  }

  static Future<AuthResponse> verifyEmailCode({
    required String email,
    required String code,
  }) {
    return _client.auth.verifyOTP(
      email: email,
      token: code,
      type: OtpType.email,
    );
  }

  static Future<bool> signInWithApple() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: _oauthRedirect,
    );
  }

  static Future<bool> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _oauthRedirect,
    );
  }

  static Future<void> signOut() => _client.auth.signOut();
}
