import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:localgems_proj/screens/login_page.dart';
import 'package:localgems_proj/screens/signup_page.dart';
import 'firebase_options.dart';
import 'screens/customer_home.dart';
import 'screens/seller_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LocalGems',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color.fromARGB(255, 179, 162, 218), 
        fontFamily: 'Poppins',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFB200), // Sunset yellow theme
          brightness: Brightness.light,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 255, 115, 0), // Yellow buttons
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 4,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF640D5F), // Dark violet header
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(
            fontSize: 16,
            fontFamily: 'Poppins',
            color: Colors.black87,
          ),
        ),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const login_page(),
        '/signup': (context) => const signup_page(),
        '/customer_home': (context) => const CustomerHomePage(),
        '/seller_home': (context) => const SellerHomePage(),
      },
    );
  }
}
