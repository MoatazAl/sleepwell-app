import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // Email login
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await UserPrefs.saveUserInfo(cred.user!);
      _goHome();
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "Login failed");
    } finally {
      setState(() => _loading = false);
    }
  }

  // Google login
  Future<void> _loginWithGoogle() async {
    try {
      final googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      final cred = await FirebaseAuth.instance.signInWithPopup(googleProvider);

      // Save user
      await UserPrefs.saveUserInfo(cred.user!);

      debugPrint("✅ Google user: ${cred.user?.email}");

      _goHome();
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

                  // Cached user
                  if (_lastUser != null) ...[
                    ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (_lastUser!["photo"] != null &&
                                _lastUser!["photo"]!.isNotEmpty)
                            ? NetworkImage(_lastUser!["photo"]!)
                            : null,
                        backgroundColor: Colors.grey.shade300,
                        child: (_lastUser!["photo"] == null ||
                                _lastUser!["photo"]!.isEmpty)
                            ? Text(
                                (_lastUser!["name"] ?? "U")
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              )
                            : null,
                        onBackgroundImageError: (_, __) {
                          debugPrint("⚠️ Failed to load photo, showing initials.");
                        },
                      ),
                      title: Text("Continue as ${_lastUser!["name"]}"),
                      subtitle: Text(_lastUser!["email"] ?? ""),
                      onTap: _loginWithGoogle,
                    ),
                    const Divider(),
                    const Text("Or use another account"),
                  ],

                  // Email login
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildTextField(_emailController, "Email"),
                        const SizedBox(height: 16),
                        _buildTextField(_passwordController, "Password",
                            obscureText: true),
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

                  // Google login
                  ElevatedButton.icon(
                    icon: const Icon(Icons.g_mobiledata, size: 28),
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
