// lib/main.dart (updated without chat route, using login for auth)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/chat_repository.dart';
import 'firebase_options.dart';
import 'login_info.dart';
import 'pages/auth_page.dart';
import 'pages/home_page.dart';

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
      // Загрузка globals при смене пользователя или перезапуске (если залогинен)
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
  Widget build(BuildContext context) => MaterialApp.router(
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      );
}