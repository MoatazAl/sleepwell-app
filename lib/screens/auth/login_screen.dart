import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final _passwordFocus = FocusNode();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    _emailController.text = prefs.getString('email') ?? '';
    _passwordController.text = prefs.getString('password') ?? '';
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('email', _emailController.text.trim());
      await prefs.setString('password', _passwordController.text.trim());
    } else {
      await prefs.remove('email');
      await prefs.remove('password');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.setPersistence(
        _rememberMe ? Persistence.LOCAL : Persistence.SESSION,
      );

      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await _saveCredentials();
      await UserPrefs.saveUserInfo(cred.user!);
      await UserPrefs.setProvider("email");

      if (!mounted) return;
      _goHome();
    } on FirebaseAuthException catch (e) {
      _showError(_mapError(e.code));
    } catch (e) {
      _showError("Unexpected error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found for this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email format.';
      default:
        return 'Login failed. Please check your details.';
    }
  }

  Future<void> _loginWithGoogle() async {
    try {
      await FirebaseAuth.instance.setPersistence(
        _rememberMe ? Persistence.LOCAL : Persistence.SESSION,
      );

      if (kIsWeb) {
        // ✅ Web login
        final googleProvider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');

        final cred = await FirebaseAuth.instance.signInWithPopup(googleProvider);
        await UserPrefs.saveUserInfo(cred.user!);
        await UserPrefs.setProvider("google");
        if (!mounted) return;
        _goHome();
      } else {
        // ✅ Mobile login - FIXED: Use the correct constructor
        final googleSignIn = GoogleSignIn(
          scopes: ['email', 'profile'],
        );

        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) return; // user canceled

        final googleAuth = await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCred =
            await FirebaseAuth.instance.signInWithCredential(credential);

        await UserPrefs.saveUserInfo(userCred.user!);
        await UserPrefs.setProvider("google");
        if (!mounted) return;
        _goHome();
      }
    } catch (e) {
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
        child: Card(
          elevation: 8,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Welcome to SleepWell",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(_passwordFocus),
                    decoration: InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? "Enter your email" : null,
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? "Enter your password" : null,
                  ),

                  CheckboxListTile(
                    value: _rememberMe,
                    onChanged: (v) => setState(() => _rememberMe = v!),
                    title: const Text("Remember me"),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),

                  const SizedBox(height: 10),
                  _loading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            backgroundColor: const Color(0xff7C4DFF),
                          ),
                          onPressed: _login,
                          child: const Text("Login"),
                        ),

                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                    ),
                    child: const Text("Don't have an account? Sign up"),
                  ),
                  const Divider(height: 30),
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
}