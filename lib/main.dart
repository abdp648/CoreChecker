import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'Screens/Info.dart';

void main() {
  runApp(const DeviceMonitorApp());
}

class DeviceMonitorApp extends StatelessWidget {
  const DeviceMonitorApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Device Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.purple,
        primaryColor: const Color(0xFF6C5CE7),
        scaffoldBackgroundColor: const Color(0xFF0A0E27),
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C5CE7),
          secondary: Color(0xFF74B9FF),
          surface: Color(0xFF1A1F3A),
          background: Color(0xFF0A0E27),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0E27),
          foregroundColor: Colors.white,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1A1F3A),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C5CE7),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF6C5CE7),
          foregroundColor: Colors.white,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFF6C5CE7),
        ),
      ),
      home: const DeviceInfoHomeScreen(),
    );
  }
}
