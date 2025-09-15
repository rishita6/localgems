import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/login_page.dart';
import 'screens/signup_page.dart';
import 'screens/welcom.dart';
// Customer imports
import 'screens/customer_home.dart';
// (later: customer_search.dart, customer_cart.dart, etc.)

// Seller imports
import 'screens/seller_home.dart';
// (later: seller_orders.dart, seller_profile.dart, etc.)

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
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Poppins',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFB200), // Yellow accent
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF640D5F), // Dark violet
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
      ),
      // Always start at login
      initialRoute: '/welcome',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/welcome':
            return MaterialPageRoute(builder: (_) => const WelcomePage());
          // Auth
          case '/login':
            return MaterialPageRoute(builder: (_) => const login_page());
          case '/signup':
            return MaterialPageRoute(builder: (_) => const SignupPage());
         

          // Customer flow
          case '/customer_home':
            return MaterialPageRoute(builder: (_) => const CustomerHomePage());

          // Seller flow
          case '/seller_home':
            return MaterialPageRoute(builder: (_) => const SellerHomePage());

          default:
            return MaterialPageRoute(builder: (_) => const login_page());
        }
      },
    );
  }
}
