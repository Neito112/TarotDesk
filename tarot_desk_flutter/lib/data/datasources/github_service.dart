import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Exception thrown by [GithubService] for every failure mode.
///
/// [code] is a short machine-readable code:
/// * `'network'` — no connectivity / socket error / timeout.
/// * `'expired_token'` — the device-flow code expired (or polling ran
///   past [DeviceCodeResponse.expiresIn]).
/// * `'access_denied'` — the user denied the device-flow authorisation.
/// * `'api'` — any other GitHub API error (the human-readable GitHub
///   `message` is in [message], the HTTP status in [statusCode]).
///
/// [toString] returns only [message], so the exception is safe to show
/// in UI. It never contains a token.
class GithubException implements Exception {
  const GithubException(
    this.message, {
    this.statusCode,
    this.code,
  });

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

/// The authenticated GitHub user (`GET /user`).
class GithubUser {
  const GithubUser({
    required this.login,
    this.name,
    this.avatarUrl,
  });

  factory GithubUser.fromMap(Map<String, dynamic> map) {
    return GithubUser(
      login: map['login'] as String,
      name: map['name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
    );
  }

  final String login;
  final String? name;
  final String? avatarUrl;
}

/// Response of `POST https://github.com/login/device/code`.
class DeviceCodeResponse {
  const DeviceCodeResponse({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.expiresIn,
    required this.interval,
  });

  factory DeviceCodeResponse.fromMap(Map<String, dynamic> map) {
    return DeviceCodeResponse(
      deviceCode: map['device_code'] as String,
      userCode: map['user_code'] as String,
      verificationUri: map['verification_uri'] as String,
      expiresIn: (map['expires_in'] as num).toInt(),
      interval: (map['interval'] as num?)?.toInt() ?? 5,
    );
  }

  /// Code the app sends to the token endpoint while polling.
  final String deviceCode;

  /// Short code the user types at [verificationUri].
  final String userCode;

  /// URL the user opens in a browser (e.g. https://github.com/login/device).
  final String verificationUri;

  /// Seconds until [deviceCode] expires.
  final int expiresIn;

  /// Seconds to wait between poll attempts.
  final int interval;
}

/// Thin GitHub API client (package:http only).
///
/// The service stores NO token: every authenticated method takes the
/// token as a parameter, and the token is never logged or printed.
/// All api.github.com calls send `Authorization: Bearer <token>`,
/// `Accept: application/vnd.github+json` and
/// `X-GitHub-Api-Version: 2022-11-28`.
///
/// Every method either returns a result or throws [GithubException]
/// with a readable message — the app must never crash on a
/// network/API failure.
class GithubService {
  GithubService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _apiHost = 'api.github.com';
  static const String _owner = 'Neito112';
  static const String _repo = 'TarotDesk';

  /// Base URL of the TarotDesk OAuth proxy (Cloudflare Worker).
  ///
  /// GitHub's OAuth endpoints (login/device/code and
  /// login/oauth/access_token) return NO CORS headers, so a browser
  /// app cannot call them directly — the browser blocks the response
  /// and the app reports a "network" error. The Worker relays those
  /// two calls server-to-server and answers with CORS headers for
  /// neito112.github.io. All api.github.com calls stay direct (that
  /// host DOES support CORS). Worker: tarotdesk-oauth, deployed
  /// 2026-11-21, version b5ab38fd.
  static const String _oauthProxyBaseUrl =
      'https://tarotdesk-oauth.thewolverineking.workers.dev';

  /// Device Flow: ask GitHub for a user code (via the OAuth proxy).
  static const String _deviceCodeUrl = '$_oauthProxyBaseUrl/device-code';

  /// Device Flow: exchange a device code for a token (via the proxy).
  static const String _accessTokenUrl = '$_oauthProxyBaseUrl/access-token';
  static const Duration _requestTimeout = Duration(seconds: 30);

  /// Release the underlying HTTP client. Only call this when the
  /// service owns the client (i.e. no client was injected).
  void close() => _client.close();

  Map<String, String> _authHeaders(String token) {
    return <String, String>{
      'Authorization': 'Bearer $token',
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    };
  }

  /// Decode a GitHub file `content` field (base64 with newlines)
  /// to UTF-8 text. Whitespace/newlines are stripped first.
  static String decodeBase64Content(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'\s'), '');
    return utf8.decode(base64.decode(cleaned));
  }

  // ------------------------------------------------------------------
  // Low-level helpers
  // ------------------------------------------------------------------

  /// Run an HTTP call, mapping connectivity failures to a
  /// `code: 'network'` [GithubException].
  ///
  /// NOTE: no `dart:io` import here — this app builds for Flutter web,
  /// where `dart:io` does not exist. Transport failures arrive as
  /// [http.ClientException] on every platform (package:http wraps the
  /// underlying socket errors), so that is what we catch.
  Future<http.Response> _send(
    Future<http.Response> Function() call,
  ) async {
    try {
      return await call().timeout(_requestTimeout);
    } on TimeoutException {
      throw const GithubException(
        'Timed out waiting for GitHub. Please try again.',
        code: 'network',
      );
    } on http.ClientException {
      throw const GithubException(
        'Could not reach GitHub. Please check your connection and try again.',
        code: 'network',
      );
    }
  }

  /// Decode a successful api.github.com response body as JSON.
  /// A non-JSON body (e.g. an HTML error page) yields an empty map
  /// instead of throwing, so callers always see [GithubException].
  dynamic _decodeSuccess(http.Response response) {
    if (response.body.isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// Throw a [GithubException] for a non-2xx api.github.com response,
  /// using GitHub's JSON `message` field when present.
  Never _throwApiError(http.Response response) {
    String message = 'GitHub API error (${response.statusCode}).';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final githubMessage = decoded['message'];
        if (githubMessage is String && githubMessage.isNotEmpty) {
          message = githubMessage;
        }
      }
    } catch (_) {
      // Keep the fallback message.
    }
    throw GithubException(
      message,
      statusCode: response.statusCode,
      code: 'api',
    );
  }

  /// Perform an authenticated api.github.com request and return the
  /// decoded JSON body. Throws [GithubException] on any failure.
  Future<dynamic> _api(
    String method,
    Uri uri, {
    required String token,
    Map<String, dynamic>? body,
  }) async {
    final headers = _authHeaders(token);
    late final http.Response response;
    switch (method) {
      case 'GET':
        response = await _send(() => _client.get(uri, headers: headers));
      case 'POST':
        response = await _send(
          () => _client.post(
            uri,
            headers: {...headers, 'Content-Type': 'application/json'},
            body: body == null ? null : jsonEncode(body),
          ),
        );
      case 'PATCH':
        response = await _send(
          () => _client.patch(
            uri,
            headers: {...headers, 'Content-Type': 'application/json'},
            body: body == null ? null : jsonEncode(body),
          ),
        );
      case 'PUT':
        response = await _send(
          () => _client.put(
            uri,
            headers: {...headers, 'Content-Type': 'application/json'},
            body: body == null ? null : jsonEncode(body),
          ),
        );
      case 'DELETE':
        response = await _send(
          () => _client.delete(
            uri,
            headers: {...headers, 'Content-Type': 'application/json'},
            body: body == null ? null : jsonEncode(body),
          ),
        );
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
    return _decodeSuccess(response);
  }

  Uri _apiUri(String path, [Map<String, String>? query]) {
    return Uri.https(_apiHost, path, query);
  }

  Uri _repoUri(String suffix, [Map<String, String>? query]) {
    return _apiUri('/repos/$_owner/$_repo$suffix', query);
  }

  // ------------------------------------------------------------------
  // OAuth Device Flow (no client secret — none exists or is needed)
  // ------------------------------------------------------------------

  /// Step 1 of the Device Flow: request a user code for the user to
  /// enter at [DeviceCodeResponse.verificationUri].
  ///
  /// Uses the passed [clientId] and [scope]; nothing is hardcoded
  /// except the endpoint URL.
  Future<DeviceCodeResponse> requestDeviceCode({
    required String clientId,
    required String scope,
  }) async {
    final response = await _send(
      () => _client.post(
        Uri.parse(_deviceCodeUrl),
        headers: {'Accept': 'application/json'},
        body: <String, String>{'client_id': clientId, 'scope': scope},
      ),
    );
    final decoded = _decodeDeviceFlowBody(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _deviceFlowError(decoded, response.statusCode);
    }
    return DeviceCodeResponse.fromMap(decoded);
  }

  /// Step 2 of the Device Flow: poll until the user authorises (or
  /// denies / the code expires) and return the access token.
  ///
  /// Polls every [interval] (`slow_down` adds 5s); throws
  /// [GithubException] with code `'expired_token'` when [expiresAt]
  /// passes or GitHub reports `expired_token`, and code
  /// `'access_denied'` when the user denies the request.
  Future<String> pollForAccessToken({
    required String clientId,
    required String deviceCode,
    required Duration interval,
    required DateTime expiresAt,
  }) async {
    var delay = interval;
    while (true) {
      if (DateTime.now().isAfter(expiresAt)) {
        throw const GithubException(
          'The sign-in code has expired. Please try again.',
          code: 'expired_token',
        );
      }
      final response = await _send(
        () => _client.post(
          Uri.parse(_accessTokenUrl),
          headers: {'Accept': 'application/json'},
          body: <String, String>{
            'client_id': clientId,
            'device_code': deviceCode,
            'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          },
        ),
      );
      final decoded = _decodeDeviceFlowBody(response);
      final accessToken = decoded['access_token'];
      if (accessToken is String && accessToken.isNotEmpty) {
        return accessToken;
      }
      final error = decoded['error'];
      if (error == 'authorization_pending') {
        await Future<void>.delayed(delay);
        continue;
      }
      if (error == 'slow_down') {
        delay = interval + const Duration(seconds: 5);
        await Future<void>.delayed(delay);
        continue;
      }
      if (error == 'expired_token') {
        throw const GithubException(
          'The sign-in code has expired. Please try again.',
          code: 'expired_token',
        );
      }
      if (error == 'access_denied') {
        throw const GithubException(
          'You declined the GitHub sign-in request.',
          code: 'access_denied',
        );
      }
      if (error is String && error.isNotEmpty) {
        throw GithubException(
          (decoded['error_description'] as String?) ??
              (decoded['error_uri'] as String?) ??
              'GitHub sign-in failed ($error).',
          statusCode: response.statusCode,
          code: 'api',
        );
      }
      throw GithubException(
        'GitHub sign-in failed (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
        code: 'api',
      );
    }
  }

  Map<String, dynamic> _decodeDeviceFlowBody(http.Response response) {
    if (response.body.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Non-JSON body (e.g. an HTML error page): fall through to the
      // empty map so the caller throws a readable GithubException.
    }
    return <String, dynamic>{};
  }

  GithubException _deviceFlowError(
    Map<String, dynamic> decoded,
    int statusCode,
  ) {
    final message = (decoded['error_description'] as String?) ??
        (decoded['error'] as String?) ??
        (decoded['message'] as String?) ??
        'Could not start GitHub sign-in (HTTP $statusCode).';
    return GithubException(message, statusCode: statusCode, code: 'api');
  }

  // ------------------------------------------------------------------
  // Authenticated: user + gists
  // ------------------------------------------------------------------

  /// `GET /user` — the currently authenticated user.
  Future<GithubUser> getCurrentUser(String token) async {
    final decoded = await _api(
      'GET',
      _apiUri('/user'),
      token: token,
    );
    return GithubUser.fromMap(decoded as Map<String, dynamic>);
  }

  /// `GET /gists?per_page=100` — the user's gists, newest first.
  Future<List<Map<String, dynamic>>> listGists(String token) async {
    final decoded = await _api(
      'GET',
      _apiUri('/gists', <String, String>{'per_page': '100'}),
      token: token,
    );
    return _asMapList(decoded);
  }

  /// `POST /gists` — create a gist.
  ///
  /// [files] maps filename -> file content; each file is sent as
  /// `{content: ...}`.
  Future<Map<String, dynamic>> createGist(
    String token, {
    required String description,
    required Map<String, String> files,
    required bool isPublic,
  }) async {
    final decoded = await _api(
      'POST',
      _apiUri('/gists'),
      token: token,
      body: <String, dynamic>{
        'description': description,
        'public': isPublic,
        'files': <String, dynamic>{
          for (final entry in files.entries)
            entry.key: <String, dynamic>{'content': entry.value},
        },
      },
    );
    return decoded as Map<String, dynamic>;
  }

  /// `PATCH /gists/{gistId}` — update files in an existing gist.
  Future<Map<String, dynamic>> patchGist(
    String token,
    String gistId, {
    required Map<String, String> files,
  }) async {
    final decoded = await _api(
      'PATCH',
      _apiUri('/gists/$gistId'),
      token: token,
      body: <String, dynamic>{
        'files': <String, dynamic>{
          for (final entry in files.entries)
            entry.key: <String, dynamic>{'content': entry.value},
        },
      },
    );
    return decoded as Map<String, dynamic>;
  }

  /// `GET /gists/{gistId}` — one gist with its files.
  Future<Map<String, dynamic>> getGist(String token, String gistId) async {
    final decoded = await _api(
      'GET',
      _apiUri('/gists/$gistId'),
      token: token,
    );
    return decoded as Map<String, dynamic>;
  }

  // ------------------------------------------------------------------
  // Authenticated: repo contents (Neito112/TarotDesk)
  // ------------------------------------------------------------------

  /// `GET /repos/Neito112/TarotDesk/contents/<path>` — directory
  /// listing. GitHub returns a single object for a file path, which
  /// is wrapped in a list so the return type is always a list.
  Future<List<Map<String, dynamic>>> listRepoContents(
    String token,
    String path,
  ) async {
    final decoded = await _api(
      'GET',
      _repoUri('/contents/${_trimSlashes(path)}'),
      token: token,
    );
    if (decoded is Map<String, dynamic>) return <Map<String, dynamic>>[decoded];
    return _asMapList(decoded);
  }

  /// `GET /repos/Neito112/TarotDesk/contents/<path>` for a file —
  /// returns the JSON including base64 `content`, `sha` and
  /// `download_url`. Use [decodeBase64Content] on `content`.
  Future<Map<String, dynamic>> getRepoFile(
    String token,
    String path,
  ) async {
    final decoded = await _api(
      'GET',
      _repoUri('/contents/${_trimSlashes(path)}'),
      token: token,
    );
    return decoded as Map<String, dynamic>;
  }

  /// `GET /git/ref/heads/<branch>` — the branch's head commit SHA.
  Future<String> getBranchSha(String token, String branch) async {
    final decoded = await _api(
      'GET',
      _repoUri('/git/ref/heads/$branch'),
      token: token,
    );
    final object = (decoded as Map<String, dynamic>)['object'];
    if (object is Map<String, dynamic> && object['sha'] is String) {
      return object['sha'] as String;
    }
    throw const GithubException(
      'Could not read the branch SHA.',
      code: 'api',
    );
  }

  /// `POST /git/refs` — create branch [branch] at commit [sha].
  Future<Map<String, dynamic>> createBranch(
    String token, {
    required String branch,
    required String sha,
  }) async {
    final decoded = await _api(
      'POST',
      _repoUri('/git/refs'),
      token: token,
      body: <String, dynamic>{
        'ref': 'refs/heads/$branch',
        'sha': sha,
      },
    );
    return decoded as Map<String, dynamic>;
  }

  /// `PUT /contents/<path>` — create a file, or update it when [sha]
  /// (the current blob SHA) is passed. [contentBase64] must be the
  /// base64-encoded file content.
  Future<Map<String, dynamic>> createOrUpdateFile(
    String token, {
    required String path,
    required String contentBase64,
    required String message,
    required String branch,
    String? sha,
  }) async {
    final body = <String, dynamic>{
      'message': message,
      'content': contentBase64,
      'branch': branch,
    };
    if (sha != null) body['sha'] = sha;
    final decoded = await _api(
      'PUT',
      _repoUri('/contents/${_trimSlashes(path)}'),
      token: token,
      body: body,
    );
    return decoded as Map<String, dynamic>;
  }

  /// `DELETE /contents/<path>` — delete a file. [sha] is the current
  /// blob SHA of the file (from [getRepoFile]).
  Future<void> deleteFile(
    String token, {
    required String path,
    required String message,
    required String sha,
    required String branch,
  }) async {
    await _api(
      'DELETE',
      _repoUri('/contents/${_trimSlashes(path)}'),
      token: token,
      body: <String, dynamic>{
        'message': message,
        'sha': sha,
        'branch': branch,
      },
    );
  }

  // ------------------------------------------------------------------
  // Authenticated: pull requests (Neito112/TarotDesk)
  // ------------------------------------------------------------------

  /// `POST /pulls` — open a pull request from [head] into [base].
  Future<Map<String, dynamic>> createPullRequest(
    String token, {
    required String title,
    required String body,
    required String head,
    required String base,
  }) async {
    final decoded = await _api(
      'POST',
      _repoUri('/pulls'),
      token: token,
      body: <String, dynamic>{
        'title': title,
        'body': body,
        'head': head,
        'base': base,
      },
    );
    return decoded as Map<String, dynamic>;
  }

  /// `GET /pulls?state=open&per_page=100` — open pull requests.
  Future<List<Map<String, dynamic>>> listOpenPullRequests(
    String token,
  ) async {
    final decoded = await _api(
      'GET',
      _repoUri('/pulls', <String, String>{
        'state': 'open',
        'per_page': '100',
      }),
      token: token,
    );
    return _asMapList(decoded);
  }

  /// `PUT /pulls/{number}/merge` — merge with the `merge` method.
  Future<Map<String, dynamic>> mergePullRequest(
    String token,
    int number,
  ) async {
    final decoded = await _api(
      'PUT',
      _repoUri('/pulls/$number/merge'),
      token: token,
      body: <String, dynamic>{'merge_method': 'merge'},
    );
    return decoded as Map<String, dynamic>;
  }

  /// `PATCH /pulls/{number}` with `state: 'closed'`.
  Future<Map<String, dynamic>> closePullRequest(
    String token,
    int number,
  ) async {
    final decoded = await _api(
      'PATCH',
      _repoUri('/pulls/$number'),
      token: token,
      body: <String, dynamic>{'state': 'closed'},
    );
    return decoded as Map<String, dynamic>;
  }

  // ------------------------------------------------------------------
  // Small helpers
  // ------------------------------------------------------------------

  List<Map<String, dynamic>> _asMapList(dynamic decoded) {
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  String _trimSlashes(String path) {
    var p = path;
    while (p.startsWith('/')) {
      p = p.substring(1);
    }
    while (p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }
}
