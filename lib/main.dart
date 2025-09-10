// lib/main.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dynamic_color/dynamic_color.dart'; // 1. Импортируем пакет

import 'data/chat_repository.dart';
import 'firebase_options.dart';
import 'login_info.dart';
import 'pages/auth_page.dart';
import 'pages/home_page.dart';
import 'theme.dart'; // Импортируем наш обновлённый theme.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  runApp(App());
}

class App extends StatefulWidget {
  App({super.key}) {
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      LoginInfo.instance.user = user;
      ChatRepository.user = user;
      if (user != null) {
        await ChatRepository.getGlobalSettings();
      }
    });
  }

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _router = GoRouter(
    routes: [
      GoRoute(
        name: 'home',
        path: '/',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        name: 'login',
        path: '/login',
        builder: (context, state) => const AuthPage(),
      ),
    ],
    redirect: (context, state) {
      final loginLocation = state.namedLocation('login');
      final homeLocation = state.namedLocation('home');
      final loggedIn = FirebaseAuth.instance.currentUser != null;
      final loggingIn = state.matchedLocation == loginLocation;

      if (!loggedIn && !loggingIn) return loginLocation;
      if (loggedIn && loggingIn) return homeLocation;
      return null;
    },
    refreshListenable: LoginInfo.instance,
  );

  @override
  Widget build(BuildContext context) {
    // 2. Оборачиваем MaterialApp в DynamicColorBuilder
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;

        // Если система предоставила динамические цвета (Android 12+) - используем их
        if (lightDynamic != null && darkDynamic != null) {
          lightColorScheme = lightDynamic.harmonized();
          darkColorScheme = darkDynamic.harmonized();
        } else {
          // Иначе - используем наш запасной оранжевый цвет
          lightColorScheme = ColorScheme.fromSeed(seedColor: brandOrange);
          darkColorScheme = ColorScheme.fromSeed(
            seedColor: brandOrange,
            brightness: Brightness.dark,
          );
        }

        // 3. Создаём темы на лету с помощью нашей функции
        final lightTheme = buildTheme(lightColorScheme);
        final darkTheme = buildTheme(darkColorScheme);

        return MaterialApp.router(
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: ThemeMode.system, // Flutter сам выберет тему
        );
      },
    );
  }
}