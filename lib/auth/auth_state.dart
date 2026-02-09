import 'package:flutter/foundation.dart';

import '../services/auth/auth_service.dart';
import '../services/auth/backend_api_service.dart';

enum AuthStatus {
  initializing,
  unauthenticated,
  authenticated,
  guest,
}

class AuthState extends ChangeNotifier {
  AuthState({required AuthService authService}) : _authService = authService;

  final AuthService _authService;

  AuthStatus _status = AuthStatus.initializing;
  bool _isBusy = false;
  String? _errorMessage;
  AuthSession? _session;
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _quota;

  static const int guestTokensLimit = 2000;

  AuthStatus get status => _status;
  bool get isBusy => _isBusy;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isGuest => _status == AuthStatus.guest;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get user => _user;
  Map<String, dynamic>? get profile => _profile;
  Map<String, dynamic>? get quota => _quota;

  Future<void> bootstrap() async {
    _status = AuthStatus.initializing;
    _errorMessage = null;
    notifyListeners();

    try {
      final guestMode = await _authService.isGuestMode();
      if (guestMode) {
        _status = AuthStatus.guest;
        _quota = {
          'plan': 'guest',
          'tokensRemaining': guestTokensLimit,
          'periodType': 'session',
          'resetAt': null,
        };
        notifyListeners();
        return;
      }

      final restored = await _authService.restoreSession();
      if (restored == null) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      _session = restored;
      await _loadMeWithRefresh();
      _status = AuthStatus.authenticated;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Session restore failed. Please sign in again.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _runBusy(() async {
      final payload =
          await _authService.login(email: email, password: password);
      _session = payload.session;
      await _loadMeWithRefresh();
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      await _authService.persistSession(payload.session);
      await _authService.setGuestMode(false);
    });
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    await _runBusy(() async {
      final payload = await _authService.register(
        name: name,
        email: email,
        password: password,
      );
      _session = payload.session;
      await _loadMeWithRefresh();
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      await _authService.persistSession(payload.session);
      await _authService.setGuestMode(false);
    });
  }

  Future<void> continueAsGuest() async {
    _status = AuthStatus.guest;
    _user = {
      'id': 'guest',
      'email': null,
    };
    _profile = {
      'name': 'Guest',
    };
    _quota = {
      'plan': 'guest',
      'tokensRemaining': guestTokensLimit,
      'periodType': 'session',
      'resetAt': null,
    };
    _errorMessage = null;
    await _authService.setGuestMode(true);
    notifyListeners();
  }

  Future<void> signOut() async {
    await _authService.logout(_session);
    _session = null;
    _user = null;
    _profile = null;
    _quota = null;
    _errorMessage = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> refreshMe() async {
    if (_session == null) return;
    await _runBusy(_loadMeWithRefresh);
  }

  Future<void> syncProfile({
    required String name,
    required int age,
    required String gender,
  }) async {
    if (_session == null || !isAuthenticated) return;
    await _runBusy(() async {
      final data = await _authService.updateProfile(
        _session!.accessToken,
        name: name,
        age: age,
        gender: gender,
      );
      _profile = (data['profile'] as Map?)?.cast<String, dynamic>();
    });
  }

  Future<void> _loadMeWithRefresh() async {
    if (_session == null) {
      throw StateError('No active session');
    }

    try {
      final data = await _authService.me(_session!.accessToken);
      _user = (data['user'] as Map?)?.cast<String, dynamic>();
      _profile = (data['profile'] as Map?)?.cast<String, dynamic>();
      _quota = (data['quota'] as Map?)?.cast<String, dynamic>();
    } on BackendApiException catch (e) {
      if (e.statusCode != 401) rethrow;
      _session = await _authService.refresh(_session!);
      final retryData = await _authService.me(_session!.accessToken);
      _user = (retryData['user'] as Map?)?.cast<String, dynamic>();
      _profile = (retryData['profile'] as Map?)?.cast<String, dynamic>();
      _quota = (retryData['quota'] as Map?)?.cast<String, dynamic>();
    }
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
    } on BackendApiException catch (e) {
      _errorMessage = e.message;
      rethrow;
    } catch (e) {
      _errorMessage = 'Unexpected error. Please try again.';
      rethrow;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
