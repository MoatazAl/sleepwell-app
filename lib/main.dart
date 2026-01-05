import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'screens/insights/insights_screen.dart';

// Firebase options
import 'firebase_options.dart';

// Theme
import 'theme.dart';

// Screens
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/tracker/sleep_tracker_screen.dart';
import 'screens/summary/sleep_summary_screen.dart';
import 'screens/settings/settings_screen.dart';

// Controllers
import 'services/tracking/tracking_controller.dart';

// Auto sleep tracking (OUR NEW PART)
import 'services/sleep_detection/auto_sleep_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 👉 Initialize auto sleep detection before running the app
  AutoSleepController().init();

  runApp(const SleepWellApp());
}

class SleepWellApp extends StatelessWidget {
  const SleepWellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => TrackingController(),
        ),
      ],
      child: MaterialApp(
        title: 'SleepWell',
        debugShowCheckedModeBanner: false,
        theme: appTheme,

        initialRoute: '/',
        routes: {
          '/': (context) => const AuthGate(),
          '/home': (context) => const HomeScreen(),
          '/tracker': (context) => const SleepTrackerScreen(),
          '/summary': (context) => const SleepSummaryScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/insights': (_) => const InsightsScreen(),

        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Firebase loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Logged in
        if (snapshot.hasData) {
          return const HomeScreen();
        }

        // Not logged in
        return const LoginScreen();
      },
    );
  }
}
