// lib/pages/auth_page.dart
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import '../login_info.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SignInScreen(
      showAuthActionSwitch: true,
      breakpoint: 600,
      providers: LoginInfo.authProviders,
      showPasswordVisibilityToggle: true,
    );
  }
}