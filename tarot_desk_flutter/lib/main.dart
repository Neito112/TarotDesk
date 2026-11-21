import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'logic/auth_provider.dart';
import 'logic/deck_provider.dart';
import 'logic/reading_provider.dart';
import 'logic/settings_provider.dart';
import 'core/translation_service.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'data/datasources/cloud_sync_service.dart';
import 'data/datasources/database_helper.dart';
import 'data/datasources/tarotdesk_api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Khởi tạo DB (bao gồm cả web init bên trong DatabaseHelper)
  await DatabaseHelper.instance.database;
  runApp(const TarotDeskApp());
}

class TarotDeskApp extends StatelessWidget {
  const TarotDeskApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Settings first: AuthProvider's create reads it (via the
        // create context) to wire the automatic login/reload sync
        // with the active language for the sync's translation
        // warm-up.
        ChangeNotifierProvider(create: (_) => SettingsProvider()..initSettings()),
        ChangeNotifierProvider(create: (context) {
          final settings = context.read<SettingsProvider>();
          final auth = AuthProvider();
          // AUTOMATIC SYNC (no manual button): after a successful
          // Google login AND after a saved session is validated on
          // app start (page reload), sync the cloud data in the
          // background via the two-way login policy
          // (CloudSyncService.syncAfterLogin — download when the
          // cloud has data this device lacks, upload when this
          // device has user data the cloud lacks, never overwrite
          // when both sides have data). Best-effort: a failure
          // never breaks the login or the Home screen; the next
          // login / reload retries. Guests never trigger it
          // (AuthProvider only fires the hook on loggedIn).
          auth.onLoggedIn = () async {
            try {
              await CloudSyncService(
                auth,
                targetLanguageCode: () => settings.language.code,
              ).syncAfterLogin();
            } catch (_) {
              // Best-effort: a failed auto-sync never breaks login.
            }
          };
          unawaited(auth.restoreSession());
          return auth;
        }),
        ChangeNotifierProvider(create: (_) => DeckProvider()),
        ChangeNotifierProvider(create: (_) => ReadingProvider()),
        ProxyProvider2<AuthProvider, SettingsProvider, TranslationService>(
          update: (_, auth, settings, previous) => previous ?? TranslationService(
            TarotdeskApiService(),
            sessionToken: () => auth.sessionToken,
            targetLanguageCode: () => settings.language.code,
            // WIRING (V2 display path): the signed-in user's Google
            // `sub`, or null for guests. The service needs it to
            // derive a personal deck_key for preloading a deck's
            // stored translations ([preloadLocalDeck]). It is a
            // closure, so it tracks logins/logouts live.
            userSub: () => auth.user?.sub,
          ),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          final themeData = settings.currentThemeData;

          return MaterialApp(
            title: 'TarotDesk - Không Gian Giải Nghĩa Bài Tarot',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: themeData.backgroundColor,
              primaryColor: themeData.primaryColor,
              colorScheme: ColorScheme.dark(
                primary: themeData.primaryColor,
                secondary: themeData.accentColor,
                surface: themeData.cardBackgroundColor,
              ),
              fontFamily: 'Roboto',
            ),
            home: const _AuthGate(),
          );
        },
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    switch (auth.state) {
      case AuthState.loading:
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                // While the app exchanges the ?code= after redirecting
                // back from Google, say so under the spinner.
                if (auth.isCompletingOAuthCallback) ...[
                  const SizedBox(height: 16),
                  Text(
                    context.read<SettingsProvider>().tr('auth.completingLogin'),
                  ),
                ],
              ],
            ),
          ),
        );
      case AuthState.loggedOut:
        return const LoginScreen();
      case AuthState.loggedIn:
      case AuthState.guest:
        return const HomeScreen();
    }
  }
}
