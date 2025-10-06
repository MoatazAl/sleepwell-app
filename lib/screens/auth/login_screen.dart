import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../home/home_screen.dart';
import 'signup_screen.dart';
import '../../utils/user_prefs.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  Map<String, String?>? _lastUser;

  @override
  void initState() {
    super.initState();
    _loadLastUser();
  }

  Future<void> _loadLastUser() async {
    final userInfo = await UserPrefs.getLastUserInfo();
    if (userInfo["email"] != null && userInfo["email"]!.isNotEmpty) {
      setState(() => _lastUser = userInfo);
    }
  }

  // 🔹 Email login
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await UserPrefs.saveUserInfo(cred.user!);
      await UserPrefs.setProvider("email");

      _goHome();
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "Login failed");
    } finally {
      setState(() => _loading = false);
    }
  }

  // 🔹 Google login
  Future<void> _loginWithGoogle() async {
    try {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');

        final cred =
            await FirebaseAuth.instance.signInWithPopup(googleProvider);

        await UserPrefs.saveUserInfo(cred.user!);
        await UserPrefs.setProvider("google");

        _goHome();
      } else {
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return; // User canceled

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCred =
            await FirebaseAuth.instance.signInWithCredential(credential);

        await UserPrefs.saveUserInfo(userCred.user!);
        await UserPrefs.setProvider("google");

        _goHome();
      }
    } catch (e, st) {
      debugPrint("❌ Google login failed: $e\n$st");
      _showError("Google login failed: $e");
    }
  }

  void _goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

Widget _buildCachedUserAvatar(Map<String, String?> user) {
  final photo = user["photo"];
  final name = user["name"];
  final hasPhoto = photo != null && photo.isNotEmpty;

  if (hasPhoto) {
    return CircleAvatar(
      backgroundImage: NetworkImage(photo),
      backgroundColor: Colors.grey.shade300,
      onBackgroundImageError: (_, __) {
        debugPrint("⚠️ Cached photo failed to load, showing initials.");
      },
    );
  } else {
    final initials = (name?.isNotEmpty == true ? name![0] : "U").toUpperCase();
    return CircleAvatar(
      backgroundColor: Colors.grey.shade300,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Welcome Back 👋",
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),

                  // 🔹 Show cached user only if last login was Google
                  if (_lastUser != null &&
                      _lastUser!["provider"] == "google") ...[
                    ListTile(
                      leading: _buildCachedUserAvatar(_lastUser!),
                      title: Text("Continue as ${_lastUser!["name"]}"),
                      subtitle: Text(_lastUser!["email"] ?? ""),
                      onTap: _loginWithGoogle,
                    ),
                    const Divider(),
                    const Text("Or use another account"),
                  ],

                  // 🔹 Email login
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildTextField(_emailController, "Email"),
                        const SizedBox(height: 16),

                        // Password with show/hide + enter key login
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _login(),
                          decoration: InputDecoration(
                            labelText: "Password",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? "Please enter Password"
                              : null,
                        ),
                        const SizedBox(height: 20),

                        _loading
                            ? const CircularProgressIndicator()
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 48),
                                ),
                                onPressed: _login,
                                child: const Text("Login"),
                              ),

                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SignupScreen(),
                            ),
                          ),
                          child: const Text("Don’t have an account? Sign up"),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),

                  // 🔹 Google login button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.account_circle, size: 28),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    onPressed: _loginWithGoogle,
                    label: const Text("Continue with Google"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🔹 Avatar helper for cached users
  Widget _buildUserAvatar(User? user) {
  final photoUrl = user?.photoURL;
  final displayName = user?.displayName?.trim();
  final email = user?.email?.trim();

  // Safely get first initial — fallback to first letter of email or "U"
  final initials = (displayName?.isNotEmpty == true
          ? displayName![0]
          : (email?.isNotEmpty == true ? email![0] : "U"))
      .toUpperCase();

  return CircleAvatar(
    radius: 40,
    backgroundColor: Colors.grey.shade300,
    child: photoUrl != null && photoUrl.isNotEmpty
        ? ClipOval(
            child: Image.network(
              photoUrl,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                debugPrint("⚠️ Failed to load photo, showing initials.");
                return Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                );
              },
            ),
          )
        : Text(
            initials,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
  );
}



  // 🔹 Simple text field builder
  Widget _buildTextField(TextEditingController c, String label,
      {bool obscureText = false}) {
    return TextFormField(
      controller: c,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (v) =>
          v == null || v.isEmpty ? "Please enter $label" : null,
    );
  }
}
