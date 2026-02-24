import 'package:flutter/material.dart';

const _burntOrange = Color(0xFFCC5500);
const _burntOrangeDark = Color(0xFFA84300);

final appTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: Colors.white,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _burntOrange,
    primary: _burntOrange,
    secondary: _burntOrangeDark,
    surface: Colors.white,
    onSurface: Color(0xFF1A1A1A),
    outline: Color(0xFFE0E0E0),
  ),
  appBarTheme: const AppBarTheme(
    centerTitle: true,
    elevation: 0,
    backgroundColor: Colors.white,
    foregroundColor: Color(0xFF1A1A1A),
    titleTextStyle: TextStyle(
      color: Color(0xFF1A1A1A),
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 1,
    shadowColor: Colors.black12,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    color: Colors.white,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _burntOrange,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    filled: true,
    fillColor: const Color(0xFFF5F5F5),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    selectedItemColor: _burntOrange,
    unselectedItemColor: Color(0xFF9E9E9E),
    type: BottomNavigationBarType.fixed,
  ),
);
