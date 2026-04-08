import 'dart:ui';

import 'package:flutter/material.dart';
import '../../services/auth/auth_service.dart';
import '../home/home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;

  String? _routineType = 'Student';
  String? _sleepGoal = 'Sleep more consistently';
  String? _stressLevel = 'Moderate';
  String? _screenUse = 'Often';
  String? _caffeineAfter6 = 'Sometimes';

  static const Color _bgTop = Color(0xFF0B1020);
  static const Color _bgBottom = Color(0xFF1A2140);
  static const Color _cardColor = Color(0xCC1A2238);
  static const Color _fieldColor = Color(0xFF222C47);
  static const Color _primary = Color(0xFF7B6DFF);
  static const Color _primary2 = Color(0xFF9B8CFF);
  static const Color _textPrimary = Color(0xFFF7F8FC);
  static const Color _textSecondary = Color(0xFFB7BED3);
  static const Color _borderColor = Color(0xFF36415F);

  final List<String> _routineOptions = const [
    'Student',
    'Office worker',
    'Shift worker',
    'Freelancer',
    'Other',
  ];

  final List<String> _goalOptions = const [
    'Sleep more consistently',
    'Fall asleep faster',
    'Wake up feeling better',
    'Reduce sleep interruptions',
    'Improve overall sleep quality',
  ];

  final List<String> _stressOptions = const [
    'Low',
    'Moderate',
    'High',
  ];

  final List<String> _screenUseOptions = const [
    'Rarely',
    'Sometimes',
    'Often',
    'Very often',
  ];

  final List<String> _caffeineOptions = const [
    'Never',
    'Rarely',
    'Sometimes',
    'Often',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      await AuthService.signup(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;

      // Later, store these in Firestore / user profile model:
      // age: int.parse(_ageController.text.trim())
      // routineType: _routineType
      // sleepGoal: _sleepGoal
      // stressLevel: _stressLevel
      // eveningScreenUse: _screenUse
      // caffeineAfter6: _caffeineAfter6

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Signup failed: $e"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2B3350),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _textSecondary),
      prefixIcon: Icon(icon, color: _textSecondary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _fieldColor,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
      ),
    );
  }

  DropdownButtonFormField<String> _buildDropdown({
  required String label,
  required IconData icon,
  required String? value,
  required List<String> items,
  required ValueChanged<String?> onChanged,
}) {
  return DropdownButtonFormField<String>(
    value: value,
    dropdownColor: _fieldColor,
    style: const TextStyle(color: _textPrimary),
    iconEnabledColor: _textSecondary,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _textSecondary),
      prefixIcon: Icon(icon, color: _textSecondary),
      filled: true,
      fillColor: _fieldColor,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
      ),
      floatingLabelBehavior: FloatingLabelBehavior.always,
    ),
    hint: Text(
      'Select $label',
      style: const TextStyle(color: _textSecondary),
    ),
    items: items
        .map(
          (item) => DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              style: const TextStyle(color: _textPrimary),
            ),
          ),
        )
        .toList(),
    onChanged: onChanged,
    validator: (v) => v == null || v.isEmpty ? 'Please select $label' : null,
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -80,
              child: _GlowCircle(
                size: 260,
                color: const Color(0xFF8B80FF).withValues(alpha: 0.18),
              ),
            ),
            Positioned(
              bottom: -140,
              right: -80,
              child: _GlowCircle(
                size: 300,
                color: const Color(0xFF6EDCFF).withValues(alpha: 0.10),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [_primary2, _primary],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _primary.withValues(alpha: 0.35),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.nightlight_round,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'SleepWell',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Create your sleep profile',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _textPrimary,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tell us a little about your routine so SleepWell can personalize your experience.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _textSecondary,
                                  fontSize: 15,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 28),

                              const _SectionTitle('Account'),
                              const SizedBox(height: 12),

                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(color: _textPrimary),
                                decoration: _inputDecoration(
                                  hint: 'Email address',
                                  icon: Icons.mail_outline_rounded,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _signup(),
                                style: const TextStyle(color: _textPrimary),
                                decoration: _inputDecoration(
                                  hint: 'Password',
                                  icon: Icons.lock_outline_rounded,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      color: _textSecondary,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 24),
                              const _SectionTitle('Personalization'),
                              const SizedBox(height: 12),

                              TextFormField(
                                controller: _ageController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: _textPrimary),
                                decoration: _inputDecoration(
                                  hint: 'Age',
                                  icon: Icons.cake_outlined,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your age';
                                  }
                                  final age = int.tryParse(value.trim());
                                  if (age == null) return 'Age must be a number';
                                  if (age < 10 || age > 100) {
                                    return 'Enter a realistic age';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              _buildDropdown(
                                label: 'Routine type',
                                icon: Icons.work_outline_rounded,
                                value: _routineType,
                                items: _routineOptions,
                                onChanged: (v) => setState(() => _routineType = v),
                              ),
                              const SizedBox(height: 16),

                              _buildDropdown(
                                label: 'Sleep goal',
                                icon: Icons.flag_outlined,
                                value: _sleepGoal,
                                items: _goalOptions,
                                onChanged: (v) => setState(() => _sleepGoal = v),
                              ),
                              const SizedBox(height: 16),

                              _buildDropdown(
                                label: 'Stress level',
                                icon: Icons.psychology_alt_outlined,
                                value: _stressLevel,
                                items: _stressOptions,
                                onChanged: (v) => setState(() => _stressLevel = v),
                              ),
                              const SizedBox(height: 16),

                              _buildDropdown(
                                label: 'Evening screen use',
                                icon: Icons.phone_android_rounded,
                                value: _screenUse,
                                items: _screenUseOptions,
                                onChanged: (v) => setState(() => _screenUse = v),
                              ),
                              const SizedBox(height: 16),

                              _buildDropdown(
                                label: 'Caffeine after 6 PM',
                                icon: Icons.local_cafe_outlined,
                                value: _caffeineAfter6,
                                items: _caffeineOptions,
                                onChanged: (v) =>
                                    setState(() => _caffeineAfter6 = v),
                              ),

                              const SizedBox(height: 28),

                              SizedBox(
                                height: 54,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    gradient: const LinearGradient(
                                      colors: [_primary, _primary2],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _primary.withValues(alpha: 0.35),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _signup,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    child: _loading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Create account',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  foregroundColor: _primary2,
                                ),
                                child: const Text('Back to login'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFF7F8FC),
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}