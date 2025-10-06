import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../auth/login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Widget _buildUserAvatar(User? user) {
    if (user == null) {
      return const CircleAvatar(
        radius: 40,
        backgroundColor: Colors.grey,
        child: Icon(Icons.person, color: Colors.white, size: 40),
      );
    }

    final photoUrl = user.photoURL;
    final displayName = user.displayName?.trim();
    final email = user.email?.trim();

    // ✅ Safely choose a single initial
    final initials = (displayName != null && displayName.isNotEmpty)
        ? displayName[0].toUpperCase()
        : (email != null && email.isNotEmpty ? email[0].toUpperCase() : "U");

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 40,
        backgroundColor: Colors.grey.shade300,
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (_, __) {
          debugPrint("⚠️ Failed to load profile photo, showing initials.");
        },
      );
    } else {
      return CircleAvatar(
        radius: 40,
        backgroundColor: Colors.grey.shade300,
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("SleepWell"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildUserAvatar(user),
            const SizedBox(height: 16),
            Text(
              "Welcome, ${user?.displayName ?? user?.email ?? "User"} 👋",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (user?.email != null) ...[
              const SizedBox(height: 8),
              Text(
                user!.email!,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
