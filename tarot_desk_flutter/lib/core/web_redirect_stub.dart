// Stub for non-web platforms (desktop/mobile).
//
// Redirecting the current tab to an OAuth authorize page only makes
// sense on web, where the app runs in a browser tab. On any other
// platform these helpers throw [UnsupportedError].

/// Throws [UnsupportedError]: tab redirects are web-only.
void redirectTo(String url) {
  throw UnsupportedError(
    'OAuth redirect is only supported on web (redirectTo).',
  );
}

/// Throws [UnsupportedError]: tab redirects are web-only.
void cleanOAuthCallbackUrl() {
  throw UnsupportedError(
    'OAuth redirect is only supported on web (cleanOAuthCallbackUrl).',
  );
}
