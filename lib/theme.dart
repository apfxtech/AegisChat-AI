// lib/theme.dart
import 'package:flutter/material.dart';

// Определяем наш "фирменный" оранжевый цвет как ЗАПАСНОЙ
const Color brandOrange = Colors.orange;

// Создаём единую функцию для построения темы
ThemeData buildTheme(ColorScheme colorScheme) {
  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,

    bottomAppBarTheme: BottomAppBarThemeData( // <-- Это правильный, существующий класс
      color: colorScheme.surfaceContainer,
      elevation: 2.0, // Вы можете добавить и другие свойства
    ),

    // --- СТИЛЬ ДЛЯ ПОЛЕЙ ВВОДА ---
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30.0),
        borderSide: BorderSide(color: colorScheme.outline, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30.0),
        borderSide: BorderSide(color: colorScheme.outline, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30.0),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
    ),

    // --- СТИЛЬ ДЛЯ КНОПОК ---
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
  );
}