// lib/pages/auth_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import '../login_info.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    const double logoRadius = 40.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
      ),
      backgroundColor: Theme.of(context).primaryColor,

      // --- КНОПКА С КАРТИНКОЙ ---
      floatingActionButton: SizedBox(
        width: logoRadius * 2,
        height: logoRadius * 2,
        child: FloatingActionButton(
          onPressed: () {
            print("Image button pressed!");
          },
          backgroundColor: Colors.white,
          shape: const CircleBorder(),
          elevation: 6.0,
          child: ClipOval(
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.cover,
              width: logoRadius * 2,
              height: logoRadius * 2,
            ),
          ),
        ),
      ),

      // --- ПАНЕЛЬ ВНИЗУ С ВЫРЕЗОМ И ФОРМОЙ ВХОДА ---
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        // ИСПРАВЛЕНИЕ: Задаем высоту напрямую для BottomAppBar, а не для его дочернего виджета.
        height: 425.0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: SingleChildScrollView(
            child: LoginView(
              action: AuthAction.signIn,
              providers: LoginInfo.authProviders,
              showPasswordVisibilityToggle: true,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}