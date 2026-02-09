import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_api_service.dart';
import 'session_storage_service.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final int accessTokenExpiresAt;

  factory AuthSession.fromSupabase(Session session) {
    return AuthSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken ?? '',
      accessTokenExpiresAt: session.expiresAt ?? 0,
    );
  }
}

class AuthPayload {
  const AuthPayload({
    required this.session,
    required this.user,
    this.profile,
    this.quota,
  });

  final AuthSession session;
  final Map<String, dynamic> user;
  final Map<String, dynamic>? profile;
  final Map<String, dynamic>? quota;
}

class AuthService {
  AuthService({
    required BackendApiService api,
    required SessionStorageService sessionStore,
  })  : _api = api,
        _sessionStore = sessionStore;

  final BackendApiService _api;
  final SessionStorageService _sessionStore;

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<AuthPayload> register({
    required String email,
    required String password,
    required String name,
  }) async {
    late AuthResponse response;
    try {
      response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
        },
      );
    } on AuthException catch (e) {
      throw BackendApiException(400, e.message);
    } catch (e) {
      throw BackendApiException(500, 'Sign-up failed: $e');
    }

    final session = response.session;
    final user = response.user;
    if (session == null || user == null) {
      throw BackendApiException(
        400,
        'Sign-up created. Verify email first, then sign in.',
      );
    }

    return AuthPayload(
      session: AuthSession.fromSupabase(session),
      user: {
        'id': user.id,
        'email': user.email,
      },
    );
  }

  Future<AuthPayload> login({
    required String email,
    required String password,
  }) async {
    late AuthResponse response;
    try {
      response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      throw BackendApiException(401, e.message);
    } catch (e) {
      throw BackendApiException(500, 'Sign-in failed: $e');
    }

    final session = response.session;
    final user = response.user;
    if (session == null || user == null) {
      throw BackendApiException(401, 'Invalid email or password');
    }

    return AuthPayload(
      session: AuthSession.fromSupabase(session),
      user: {
        'id': user.id,
        'email': user.email,
      },
    );
  }

  Future<Map<String, dynamic>> me(String accessToken) {
    return _api.getJson('/me', bearerToken: accessToken);
  }

  Future<Map<String, dynamic>> updateProfile(
    String accessToken, {
    String? name,
    int? age,
    String? gender,
  }) {
    return _api.patchJson(
      '/me/profile',
      bearerToken: accessToken,
      body: {
        if (name != null) 'name': name,
        if (age != null) 'age': age,
        if (gender != null) 'gender': gender,
      },
    );
  }

  Future<AuthSession?> restoreSession() async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      return null;
    }
    return AuthSession.fromSupabase(session);
  }

  Future<AuthSession> refresh(AuthSession current) async {
    late AuthResponse response;
    try {
      response = await _supabase.auth.refreshSession();
    } on AuthException catch (e) {
      throw BackendApiException(401, e.message);
    } catch (e) {
      throw BackendApiException(500, 'Session refresh failed: $e');
    }
    final session = response.session;
    if (session == null) {
      throw BackendApiException(401, 'Session expired. Please sign in.');
    }
    return AuthSession.fromSupabase(session);
  }

  Future<void> logout(AuthSession? current) async {
    await _supabase.auth.signOut();
    await _sessionStore.clearSession();
    await _sessionStore.setGuestMode(false);
  }

  Future<bool> isGuestMode() => _sessionStore.isGuestMode();

  Future<void> setGuestMode(bool enabled) =>
      _sessionStore.setGuestMode(enabled);

  Future<void> persistSession(AuthSession session) async {
    // Supabase persists/refreshes sessions internally.
  }
}
