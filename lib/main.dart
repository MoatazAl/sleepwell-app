import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'theme.dart';

// Screens
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/tracker/sleep_tracker_screen.dart';
import 'screens/summary/sleep_summary_screen.dart';
import 'screens/settings/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const SleepWellApp());
}

class SleepWellApp extends StatelessWidget {
  const SleepWellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SleepWell',
      debugShowCheckedModeBanner: false,
      theme: appTheme,

      // ✅ Routing configuration
      routes: {
        '/': (context) => const AuthGate(), // auto-detect login state
        '/home': (context) => const HomeScreen(),
        '/tracker': (context) => const SleepTrackerScreen(),
        '/summary': (context) => const SleepSummaryScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

/// Detects whether the user is logged in and directs them accordingly
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const HomeScreen(); // ✅ user is logged in
        } else {
          return const LoginScreen(); // ✅ go to login page
        }
      },
    );
  }
}
