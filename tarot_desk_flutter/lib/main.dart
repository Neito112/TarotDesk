import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'logic/auth_provider.dart';
import 'logic/deck_provider.dart';
import 'logic/reading_provider.dart';
import 'logic/settings_provider.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'data/datasources/database_helper.dart';

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
        ChangeNotifierProvider(create: (_) => AuthProvider()..restoreSession()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..initSettings()),
        ChangeNotifierProvider(create: (_) => DeckProvider()),
        ChangeNotifierProvider(create: (_) => ReadingProvider()),
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
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthState.loggedOut:
        return const LoginScreen();
      case AuthState.loggedIn:
      case AuthState.guest:
        return const HomeScreen();
    }
  }
}
