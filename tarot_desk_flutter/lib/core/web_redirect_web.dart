// Web implementation of the redirect helpers (dart:html).
import 'dart:html' as html;

/// Navigate the current tab to [url] (same-tab redirect, e.g. to the
/// Google authorize page).
void redirectTo(String url) {
  html.window.location.assign(url);
}

/// Remove the OAuth `?code=` / `?state=` query parameters from the
/// address bar, leaving the plain app URL — so a reload does not
/// replay the callback. Uses `replaceState`, so no new history entry
/// is created and the page is not reloaded.
void cleanOAuthCallbackUrl() {
  final uri = Uri.parse(html.window.location.href);
  final clean = uri.removeFragment().replace(queryParameters: <String, String>{});
  html.window.history.replaceState(null, '', clean.toString());
}
