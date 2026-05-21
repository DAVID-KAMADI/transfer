import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'package:inter_store/auth/login_page.dart';
import 'package:inter_store/auth/register_page.dart';
import 'package:inter_store/auth/waiting.dart';
import 'package:inter_store/home.dart'; // ✅ make sure this exists
import 'package:inter_store/driver_home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ================================
  // LOAD ENV FILE (EMAIL + PASSWORD)
  // ================================
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print('Warning: Could not load .env file: $e');
    print('The app will continue but email functionality may not work.');
  }

  // ================================
  // INITIALIZE FIREBASE
  // ================================
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Store Transfer',

      // ================================
      // APP THEME
      // ================================
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF063052)),
      ),

      // ================================
      // ROUTES CONFIGURATION
      // ================================
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/waiting': (context) => const WaitingScreen(),
        '/home': (context) => const Home(),
        '/driver': (context) => const DriverHomePage(),
      },

      // ================================
      // ENTRY POINT (AUTH HANDLER)
      // ================================
      home: const AuthWrapper(),
    );
  }
}

// =========================================================
// ✅ AUTH WRAPPER (LOGIN PERSISTENCE)
// =========================================================
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // ⏳ Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ✅ User is logged in
        if (snapshot.hasData) {
          return const Home();
        }

        // ❌ User is not logged in
        return const LoginPage();
      },
    );
  }
}
