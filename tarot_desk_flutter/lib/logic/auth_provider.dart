import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/web_redirect.dart';
import '../data/datasources/tarotdesk_api_service.dart';

/// Login state of the Google session.
enum AuthState {
  /// Restoring a saved session (initial state).
  loading,

  /// No saved / valid session.
  loggedOut,

  /// A session token is saved and the Worker confirmed the user.
  loggedIn,

  /// Using the app offline without a Google account (guest mode).
  ///
  /// A guest keeps full local use (sqflite decks / readings);
  /// cloud sync, shared-deck submit and the admin UI need a login
  /// and fail with a readable error instead of crashing.
  guest,
}

/// Google login state (OAuth Web Application Flow) for TarotDesk.
///
/// Flow: the user taps login, the app redirects the same browser tab
/// to Google's authorize page; Google redirects back to the app with
/// `?code=` + `?state=`, and [restoreSession] exchanges the code for
/// a Worker `session_token` via [TarotdeskApiService]. The Worker —
/// never the app — talks to Google (it holds the OAuth client secret
/// as a Worker secret).
///
/// The app keeps sqflite as its local store; the Worker is a cloud
/// layer on top. This provider only owns the login session: the saved
/// session token and the logged-in user. It never touches local
/// sqflite data.
///
/// Admin rule: the logged-in Google email `orenji11299@gmail.com`
/// is the admin; every other account is a regular user ([isAdmin]).
///
/// No UI strings live here (no `tr()` calls) — screens own their
/// strings. The session token is never logged, displayed, or sent
/// anywhere except the `Authorization` header inside
/// [TarotdeskApiService].
class AuthProvider extends ChangeNotifier {
  AuthProvider({TarotdeskApiService? api})
      : api = api ?? TarotdeskApiService();

  final TarotdeskApiService api;

  static const String _sessionTokenKey = 'tarotdesk_google_session_token';
  static const String _oauthStateKey = 'tarotdesk_oauth_state';

  /// Google email of the admin / server owner.
  static const String adminEmail = 'orenji11299@gmail.com';

  /// Client ID of the Google OAuth client "TarotDesk Web".
  /// This is a public identifier, not a secret. There is NO client
  /// secret in the app — the Worker holds it as a Worker secret and
  /// performs the code exchange server-side.
  static const String clientId =
      '123408820943-7jqa6sqoncp591485d2uo9euumvnlpii.apps.googleusercontent.com';

  /// OAuth scopes requested by the Web Application Flow.
  static const String oauthScope = 'openid email profile';

  /// Redirect URI registered on the Google OAuth client. It must
  /// match exactly — the authorize URL and the code exchange both
  /// use this value.
  static const String redirectUri = 'https://neito112.github.io/TarotDesk/';

  static final Random _secureRandom = Random.secure();

  AuthState _state = AuthState.loading;
  TarotdeskUser? _user;
  String? _sessionToken;
  bool _isCompletingOAuthCallback = false;
  String? _lastAuthErrorCode;
  String? _lastAuthErrorDetail;

  AuthState get state => _state;
  TarotdeskUser? get user => _user;
  bool get isLoggedIn => _state == AuthState.loggedIn;

  /// True while using the app offline without a Google account.
  bool get isGuest => _state == AuthState.guest;

  /// True when the logged-in Google email is the admin account.
  /// Guests are never admins.
  bool get isAdmin => _user?.email == adminEmail;

  /// The saved Worker session token.
  ///
  /// For internal service calls only — NEVER log, display, or send
  /// it anywhere except the `Authorization` header.
  String? get sessionToken => _sessionToken;

  /// Backwards-compatible alias for [sessionToken] (the old provider
  /// exposed the session as `token`).
  String? get token => _sessionToken;

  /// True while the app is exchanging the `?code=` from a Google
  /// redirect back to the app. The app gate shows a "completing
  /// sign-in" message instead of the login screen during this time.
  bool get isCompletingOAuthCallback => _isCompletingOAuthCallback;

  /// Machine-readable code of the last failed login attempt, if any:
  /// `'state_mismatch'`, `'exchange_failed'` or `'network'`. Null
  /// when the last attempt did not fail (or no attempt was made).
  String? get lastAuthErrorCode => _lastAuthErrorCode;

  /// English detail of the last failed login attempt, if the Worker
  /// / API supplied one. Null when there is no detail to show.
  String? get lastAuthErrorDetail => _lastAuthErrorDetail;

  /// Restore a saved session on app start.
  ///
  /// FIRST handles a Google OAuth callback (`?code=` + `?state=` in
  /// the URL): when one is present it is exchanged and this returns
  /// immediately. Otherwise, no saved session token ->
  /// [AuthState.loggedOut]; saved token + `GET /me` succeeds ->
  /// [AuthState.loggedIn]; saved token rejected by the Worker (401)
  /// -> the token is cleared and the state is [AuthState.loggedOut].
  /// Any other failure (e.g. no network) also lands on
  /// [AuthState.loggedOut] — the saved token is kept, so the next
  /// app start retries it. Always notifies listeners and never
  /// throws.
  Future<void> restoreSession() async {
    try {
      if (await handleOAuthCallback()) return;
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_sessionTokenKey);
      if (savedToken == null || savedToken.isEmpty) {
        _sessionToken = null;
        _user = null;
        _state = AuthState.loggedOut;
        return;
      }
      try {
        final fetchedUser = await api.getMe(savedToken);
        _sessionToken = savedToken;
        _user = fetchedUser;
        _state = AuthState.loggedIn;
      } on TarotdeskApiException catch (e) {
        if (e.code == 'unauthorized') {
          // Saved session is invalid / revoked: drop it and log out.
          await prefs.remove(_sessionTokenKey);
        }
        // Any other failure (network, server, ...): log out for now,
        // but keep the saved token unless it was rejected above.
        _sessionToken = null;
        _user = null;
        _state = AuthState.loggedOut;
      }
    } catch (_) {
      // SharedPreferences or anything else failed: fail logged-out,
      // never crash the app start.
      _sessionToken = null;
      _user = null;
      _state = AuthState.loggedOut;
    } finally {
      notifyListeners();
    }
  }

  /// Handle a Google OAuth callback in the current URL, if one is
  /// present.
  ///
  /// No `code` query parameter -> returns `false` (not a callback).
  /// A callback is present -> returns `true` and this method owns
  /// the outcome: it verifies the `state` against the value saved
  /// by [startGoogleLogin], exchanges the code for a Worker session
  /// via [TarotdeskApiService.exchangeGoogleCode], saves the session
  /// token, sets the state to [AuthState.loggedIn] and cleans the
  /// `?code=` / `?state=` parameters out of the address bar.
  ///
  /// On failure the state becomes [AuthState.loggedOut] and the
  /// reason is stored in [lastAuthErrorCode] (+ [lastAuthErrorDetail]
  /// when the server supplied one) for the login screen to show:
  /// `'state_mismatch'` when the returned state does not match the
  /// saved one, `'network'` when the Worker could not be reached,
  /// `'exchange_failed'` for anything else. Never throws.
  Future<bool> handleOAuthCallback() async {
    final params = Uri.base.queryParameters;
    final code = params['code'];
    final returnedState = params['state'];
    if (code == null || code.isEmpty) return false;
    if (returnedState == null || returnedState.isEmpty) return false;
    _isCompletingOAuthCallback = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedState = prefs.getString(_oauthStateKey);
      if (savedState == null || savedState != returnedState) {
        await prefs.remove(_oauthStateKey);
        _lastAuthErrorCode = 'state_mismatch';
        _lastAuthErrorDetail = null;
        _sessionToken = null;
        _user = null;
        _state = AuthState.loggedOut;
        _isCompletingOAuthCallback = false;
        _cleanCallbackUrl();
        notifyListeners();
        return true;
      }
      try {
        final result = await api.exchangeGoogleCode(
          code: code,
          redirectUri: redirectUri,
        );
        final token = result['session_token'];
        final userJson = result['user'];
        if (token is! String ||
            token.isEmpty ||
            userJson is! Map<String, dynamic>) {
          throw const TarotdeskApiException(
            'server',
            'The server returned an incomplete sign-in response.',
          );
        }
        await prefs.setString(_sessionTokenKey, token);
        await prefs.remove(_oauthStateKey);
        _sessionToken = token;
        _user = TarotdeskUser.fromJson(userJson);
        _lastAuthErrorCode = null;
        _lastAuthErrorDetail = null;
        _state = AuthState.loggedIn;
      } on TarotdeskApiException catch (e) {
        await prefs.remove(_oauthStateKey);
        _lastAuthErrorCode = e.code == 'network' ? 'network' : 'exchange_failed';
        _lastAuthErrorDetail = e.message;
        _sessionToken = null;
        _user = null;
        _state = AuthState.loggedOut;
      }
      _isCompletingOAuthCallback = false;
      _cleanCallbackUrl();
      notifyListeners();
      return true;
    } catch (_) {
      // Anything unexpected (e.g. storage failure): fail logged-out
      // with a generic code, never crash and never leave the
      // completing flag stuck on.
      _lastAuthErrorCode = 'exchange_failed';
      _lastAuthErrorDetail = null;
      _sessionToken = null;
      _user = null;
      _state = AuthState.loggedOut;
      _isCompletingOAuthCallback = false;
      _cleanCallbackUrl();
      notifyListeners();
      return true;
    }
  }

  /// Start the Google Web Application Flow: redirect the current tab
  /// to Google's authorize page.
  ///
  /// Generates a fresh random `state` for this attempt, saves it,
  /// then redirects the same tab to
  /// `accounts.google.com/o/oauth2/v2/auth` with this app's client
  /// id, redirect URI and `openid email profile` scope. Google
  /// redirects back to the app, where [restoreSession] /
  /// [handleOAuthCallback] finishes the login.
  ///
  /// Never throws: when the redirect cannot start (e.g. storage
  /// failure on a non-web platform) the error is stored as
  /// [lastAuthErrorCode] (`'network'`) and the method returns — the
  /// login screen then shows the error instead of navigating away.
  Future<void> startGoogleLogin() async {
    try {
      _lastAuthErrorCode = null;
      _lastAuthErrorDetail = null;
      final state = _generateState();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_oauthStateKey, state);
      final authorizeUrl = Uri.https(
        'accounts.google.com',
        '/o/oauth2/v2/auth',
        <String, String>{
          'client_id': clientId,
          'redirect_uri': redirectUri,
          'response_type': 'code',
          'scope': oauthScope,
          'state': state,
          'prompt': 'select_account',
        },
      );
      redirectTo(authorizeUrl.toString());
    } catch (_) {
      _lastAuthErrorCode = 'network';
      _lastAuthErrorDetail = null;
      notifyListeners();
    }
  }

  /// Continue without a Google account (offline guest mode).
  ///
  /// Clears any token/user, sets the state to [AuthState.guest] and
  /// notifies listeners, so the app gate shows HomeScreen. Local
  /// sqflite data is untouched. A guest can log in later from the
  /// login screen (via logout, which returns to loggedOut).
  void continueAsGuest() {
    _sessionToken = null;
    _user = null;
    _lastAuthErrorCode = null;
    _lastAuthErrorDetail = null;
    _state = AuthState.guest;
    notifyListeners();
  }

  /// Log out: clear the saved session token and reset the session.
  ///
  /// The Worker session is abandoned client-side only (there is no
  /// `/logout` endpoint in the API contract); the token is simply
  /// dropped, so it can no longer be used. Does NOT touch local
  /// sqflite data.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionTokenKey);
    await prefs.remove(_oauthStateKey);
    _sessionToken = null;
    _user = null;
    _lastAuthErrorCode = null;
    _lastAuthErrorDetail = null;
    _state = AuthState.loggedOut;
    notifyListeners();
  }

  /// A fresh random OAuth `state` (16 random bytes as 32 hex chars),
  /// generated per login attempt.
  String _generateState() {
    final bytes =
        List<int>.generate(16, (_) => _secureRandom.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Best-effort removal of the OAuth query parameters from the
  /// address bar. Never throws (the stub throws on non-web, and a
  /// failure here must not break the login outcome).
  void _cleanCallbackUrl() {
    try {
      cleanOAuthCallbackUrl();
    } catch (_) {
      // Non-web or unavailable: the ?code= stays in the URL, but the
      // login outcome above is already final.
    }
  }
}
