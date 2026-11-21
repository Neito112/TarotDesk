import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/datasources/github_service.dart';

/// Login state of the GitHub session.
enum AuthState {
  /// Restoring a saved session (initial state).
  loading,

  /// No saved / valid token.
  loggedOut,

  /// A token is saved and the GitHub user was fetched successfully.
  loggedIn,

  /// Using the app offline without a GitHub account (hotfix).
  ///
  /// The GitHub Device Flow cannot run directly from a browser
  /// (github.com/login/* returns no CORS headers), so until the
  /// OAuth proxy is live the app must not hard-require login.
  /// A guest keeps full local use (sqflite decks / readings);
  /// Gist sync, shared-deck submit and the admin UI need a login
  /// and fail with a readable error instead of crashing.
  guest,
}

/// GitHub login state (OAuth Device Flow) for TarotDesk.
///
/// The app keeps sqflite as its local store; GitHub is a cloud layer
/// on top. This provider only owns the login session: the saved
/// token and the logged-in user. It never touches local sqflite data.
///
/// Admin rule: the logged-in GitHub username `Neito112` is the admin;
/// every other account is a regular user ([isAdmin]).
///
/// No UI strings live here (no `tr()` calls) — screens own their
/// strings. The token is never logged, displayed, or sent anywhere
/// except the `Authorization` header inside [GithubService].
class AuthProvider extends ChangeNotifier {
  AuthProvider({GithubService? github})
      : github = github ?? GithubService();

  final GithubService github;

  static const String _tokenKey = 'tarotdesk_github_token';

  /// GitHub username of the admin / server owner.
  static const String adminLogin = 'Neito112';

  /// Client ID of the GitHub OAuth App "TarotDesk".
  /// Device Flow is enabled; there is NO client secret and none is
  /// ever needed or stored.
  static const String clientId = 'Ov23liWavH5gANVQIFcY';

  /// OAuth scopes requested by the Device Flow.
  static const String oauthScope = 'read:user gist public_repo';

  AuthState _state = AuthState.loading;
  GithubUser? _user;
  String? _token;

  AuthState get state => _state;
  GithubUser? get user => _user;
  bool get isLoggedIn => _state == AuthState.loggedIn;

  /// True while using the app offline without a GitHub account.
  bool get isGuest => _state == AuthState.guest;

  /// True when the logged-in GitHub username is the admin account.
  /// Guests are never admins.
  bool get isAdmin => _user?.login == adminLogin;

  /// The saved GitHub access token.
  ///
  /// For internal service calls only — NEVER log, display, or send
  /// it anywhere except the `Authorization` header.
  String? get token => _token;

  /// Restore a saved session on app start.
  ///
  /// No saved token -> [AuthState.loggedOut]. Saved token + user
  /// fetch succeeds -> [AuthState.loggedIn]. Saved token rejected
  /// by GitHub (e.g. 401 / invalid) -> the token is cleared and the
  /// state is [AuthState.loggedOut]. Always notifies listeners and
  /// never throws.
  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_tokenKey);
      if (savedToken == null || savedToken.isEmpty) {
        _token = null;
        _user = null;
        _state = AuthState.loggedOut;
        return;
      }
      try {
        final fetchedUser = await github.getCurrentUser(savedToken);
        _token = savedToken;
        _user = fetchedUser;
        _state = AuthState.loggedIn;
      } on GithubException {
        // Saved token is invalid / revoked: drop it and log out.
        await prefs.remove(_tokenKey);
        _token = null;
        _user = null;
        _state = AuthState.loggedOut;
      }
    } catch (_) {
      // SharedPreferences or anything else failed: fail logged-out,
      // never crash the app start.
      _token = null;
      _user = null;
      _state = AuthState.loggedOut;
    } finally {
      notifyListeners();
    }
  }

  /// Start the Device Flow: ask GitHub for a user code.
  ///
  /// Returns the [DeviceCodeResponse]; the LoginScreen shows its
  /// [DeviceCodeResponse.userCode] and
  /// [DeviceCodeResponse.verificationUri], then calls
  /// [waitForAuthorization]. Throws [GithubException] on failure.
  Future<DeviceCodeResponse> startDeviceFlow() {
    return github.requestDeviceCode(clientId: clientId, scope: oauthScope);
  }

  /// Wait until the user authorises (or denies / the code expires).
  ///
  /// On success the token is saved, the user is fetched, the state
  /// becomes [AuthState.loggedIn], listeners are notified and `true`
  /// is returned. On [GithubException] with code `'expired_token'`
  /// or `'access_denied'` (or any other [GithubException]) the
  /// exception is rethrown so the LoginScreen can show the error and
  /// offer a retry.
  Future<bool> waitForAuthorization(DeviceCodeResponse code) async {
    final accessToken = await github.pollForAccessToken(
      clientId: clientId,
      deviceCode: code.deviceCode,
      interval: Duration(seconds: code.interval),
      expiresAt: DateTime.now().add(Duration(seconds: code.expiresIn)),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, accessToken);
    _token = accessToken;
    // If this fetch fails the exception propagates; the token stays
    // saved so the next app start retries via [restoreSession].
    _user = await github.getCurrentUser(accessToken);
    _state = AuthState.loggedIn;
    notifyListeners();
    return true;
  }

  /// Continue without a GitHub account (offline guest mode).
  ///
  /// Clears any token/user, sets the state to [AuthState.guest] and
  /// notifies listeners, so the app gate shows HomeScreen. Local
  /// sqflite data is untouched. A guest can log in later from the
  /// login screen (via logout, which returns to loggedOut).
  void continueAsGuest() {
    _token = null;
    _user = null;
    _state = AuthState.guest;
    notifyListeners();
  }

  /// Log out: clear the saved token and reset the session.
  ///
  /// Does NOT touch local sqflite data.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    _token = null;
    _user = null;
    _state = AuthState.loggedOut;
    notifyListeners();
  }
}
