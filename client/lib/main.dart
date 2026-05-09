import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const ShijieTVApp());
}

class ShijieTVApp extends StatelessWidget {
  const ShijieTVApp({super.key});

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF5F5F5),
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: const Color(0xFFE50914),
        onPrimary: Colors.white,
        secondary: const Color(0xFFFF6B6B),
        onSecondary: Colors.white,
        surface: isDark ? const Color(0xFF16161E) : Colors.white,
        onSurface: isDark ? const Color(0xFFE0E0E8) : const Color(0xFF1A1A2E),
        error: const Color(0xFFE50914),
        onError: Colors.white,
      ),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : const Color(0xFF1A1A2E)),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF0A0A0F) : Colors.white,
        selectedItemColor: const Color(0xFFE50914),
        unselectedItemColor: isDark ? const Color(0xFF5A5A6E) : const Color(0xFF9E9E9E),
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: '视界MAX',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: mode,
          home: const HomeScreen(),
        );
      },
    );
  }
}
