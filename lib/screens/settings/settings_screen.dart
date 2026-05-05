import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/app_navbar.dart';
import '../../services/auth/auth_service.dart';
import '../../services/health_connect/health_connect_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _sleepGoalController = TextEditingController();

  String _email = '';
  String _scheduleType = 'regular';
  TimeOfDay? _preferredBedtime;
  TimeOfDay? _preferredWakeTime;

  bool _loading = true;
  bool _saving = false;
  bool _hcAvailable = false;
  bool _hcPermissionGranted = false;

  static const List<_ScheduleOption> _scheduleOptions = [
    _ScheduleOption('regular_daytime', 'Regular daytime schedule'),
    _ScheduleOption('student', 'Student schedule'),
    _ScheduleOption('shift_worker', 'Shift worker'),
    _ScheduleOption('flexible', 'Flexible / variable schedule'),
    _ScheduleOption('night_oriented', 'Night-oriented schedule'),
  ];
  @override
  void initState() {
    super.initState();
    _loadProfile();
    _initHealthConnect();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _sleepGoalController.dispose();
    super.dispose();
  }

  Future<void> _initHealthConnect() async {
    try {
      final availability = await HealthConnectService.getAvailability();
      _hcAvailable = availability.available;

      if (_hcAvailable) {
        _hcPermissionGranted = await HealthConnectService.hasSleepPermission();
      }

      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data() ?? <String, dynamic>{};

      _email = (data['email'] ?? user.email ?? '').toString();
      _nameController.text = (data['name'] ?? '').toString();

      final age = data['age'];
      if (age != null) {
        _ageController.text = age.toString();
      }

      final sleepGoal = data['sleepGoalHours'];
      if (sleepGoal != null) {
        _sleepGoalController.text = sleepGoal.toString();
      }

      _scheduleType = (data['scheduleType'] ?? 'regular').toString();

      _preferredBedtime = _parseStoredTime(data['preferredBedtime']);
      _preferredWakeTime = _parseStoredTime(data['preferredWakeTime']);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  TimeOfDay? _parseStoredTime(dynamic value) {
    if (value == null) return null;

    final raw = value.toString().trim();
    final parts = raw.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Not set';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _pickBedtime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _preferredBedtime ?? const TimeOfDay(hour: 23, minute: 0),
    );
    if (picked != null && mounted) {
      setState(() => _preferredBedtime = picked);
    }
  }

  Future<void> _pickWakeTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _preferredWakeTime ?? const TimeOfDay(hour: 7, minute: 0),
    );
    if (picked != null && mounted) {
      setState(() => _preferredWakeTime = picked);
    }
  }

  Future<void> _saveProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final age = int.tryParse(_ageController.text.trim());
    final sleepGoal = double.tryParse(_sleepGoalController.text.trim());

    if (_ageController.text.trim().isNotEmpty && age == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Age must be a number.')));
      return;
    }

    if (_sleepGoalController.text.trim().isNotEmpty &&
        (sleepGoal == null || sleepGoal <= 0 || sleepGoal > 24)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sleep goal must be a valid number of hours.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'email': _email.isNotEmpty ? _email : (user.email ?? ''),
        'age': age,
        'scheduleType': _scheduleType,
        'sleepGoalHours': sleepGoal,
        'preferredBedtime': _preferredBedtime == null
            ? null
            : _formatTime(_preferredBedtime),
        'preferredWakeTime': _preferredWakeTime == null
            ? null
            : _formatTime(_preferredWakeTime),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _connectHealthData() async {
    try {
      if (!_hcAvailable) {
        await HealthConnectService.openHealthConnectSettings();
        return;
      }

      final granted = await HealthConnectService.requestSleepPermission();
      _hcPermissionGranted = granted;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Health Connect error: $e')));
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await AuthService.logout();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sign out failed: $e')));
      }
    }
  }

  String _scheduleLabel(String value) {
    return _scheduleOptions
        .firstWhere(
          (e) => e.value == value,
          orElse: () => const _ScheduleOption('regular', 'Regular schedule'),
        )
        .label;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppNavBar(current: NavSection.settings),
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: appBackgroundDecoration,
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kBrand))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    _buildHero(),
                    const SizedBox(height: 18),
                    _buildAccountCard(),
                    const SizedBox(height: 14),
                    _buildSleepProfileCard(),
                    const SizedBox(height: 14),
                    _buildDevicesCard(),
                    const SizedBox(height: 14),
                    _buildPrivacyCard(),
                    const SizedBox(height: 14),
                    _buildActionsCard(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: glassCardDecoration,
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [kBrand, kAccentBlue.withValues(alpha: 0.9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: kBrand.withValues(alpha: 0.20),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.settings_rounded, color: Colors.white),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings & Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Personalize SleepWell so your goals, insights, and recommendations match your real routine.',
                  style: TextStyle(
                    color: kTextSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard() {
    return _sectionCard(
      title: 'Account',
      icon: Icons.person_rounded,
      child: Column(
        children: [
          _readOnlyRow('Email', _email.isEmpty ? 'No email found' : _email),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Name'),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepProfileCard() {
    return _sectionCard(
      title: 'Sleep Profile',
      icon: Icons.bedtime_rounded,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Age'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _sleepGoalController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Sleep goal (hours)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _scheduleType,
            dropdownColor: const Color(0xFF1C0A24),
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Schedule type'),
            items: _scheduleOptions
                .map(
                  (e) => DropdownMenuItem<String>(
                    value: e.value,
                    child: Text(e.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _scheduleType = value);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _timeTile(
                  label: 'Preferred bedtime',
                  value: _formatTime(_preferredBedtime),
                  onTap: _pickBedtime,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _timeTile(
                  label: 'Preferred wake time',
                  value: _formatTime(_preferredWakeTime),
                  onTap: _pickWakeTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: kBrand.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBrand.withValues(alpha: 0.20)),
            ),
            padding: const EdgeInsets.all(14),
            child: Text(
              _personalizationSummary(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _saving ? null : _saveProfile,
              child: Text(_saving ? 'Saving...' : 'Save changes'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesCard() {
    final statusText = !_hcAvailable
        ? 'Health Connect not available'
        : (_hcPermissionGranted ? 'Connected' : 'Not connected');

    final statusColor = !_hcAvailable
        ? const Color(0xFFF59E0B)
        : (_hcPermissionGranted ? const Color(0xFF22C55E) : kAccentBlue);

    return _sectionCard(
      title: 'Devices & Data Sources',
      icon: Icons.watch_rounded,
      child: Column(
        children: [
          _rowWithBadge(
            title: 'Health Connect',
            subtitle: 'Import smartwatch-recorded sleep data',
            badgeText: statusText,
            badgeColor: statusColor,
            actionLabel: _hcPermissionGranted ? 'Reconnect' : 'Connect',
            onTap: _connectHealthData,
          ),
          const SizedBox(height: 12),
          _infoBox(
            'SleepWell can use imported watch sleep as an additional data source, while still supporting manual sleep records and personalized analysis.',
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyCard() {
    return _sectionCard(
      title: 'Privacy',
      icon: Icons.lock_rounded,
      child: Column(
        children: [
          _privacyLine(
            'Your sleep profile is used to personalize goals, consistency checks, and recommendations.',
          ),
          const SizedBox(height: 10),
          _privacyLine(
            'Imported watch sleep and manual sleep records stay tied to your account.',
          ),
          const SizedBox(height: 10),
          _privacyLine(
            'You can later add delete/export controls here if you want to strengthen the project presentation.',
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard() {
    return _sectionCard(
      title: 'Actions',
      icon: Icons.tune_rounded,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _signOut,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFF97316).withValues(alpha: 0.20),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.logout_rounded, color: Color(0xFFF97316)),
                  SizedBox(width: 10),
                  Text(
                    'Sign Out',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: kBrand.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: kBrand, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _readOnlyRow(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: kTextMuted, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeTile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: kTextMuted, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowWithBadge({
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: kTextSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: badgeColor.withValues(alpha: 0.22)),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                color: badgeColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(onPressed: onTap, child: Text(actionLabel)),
        ],
      ),
    );
  }

  Widget _infoBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kAccentBlue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAccentBlue.withValues(alpha: 0.16)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
      ),
    );
  }

  Widget _privacyLine(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Icon(Icons.circle, size: 6, color: Colors.white38),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  String _personalizationSummary() {
    final goal = _sleepGoalController.text.trim().isEmpty
        ? 'your sleep goal'
        : '${_sleepGoalController.text.trim()}h';
    final bedtime = _preferredBedtime == null
        ? 'your preferred bedtime'
        : _formatTime(_preferredBedtime);
    final wake = _preferredWakeTime == null
        ? 'your preferred wake time'
        : _formatTime(_preferredWakeTime);

    return 'SleepWell can personalize recommendations using ${_scheduleLabel(_scheduleType).toLowerCase()}, a target of $goal, bedtime $bedtime, and wake time $wake.';
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: kTextMuted),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: kBrand.withValues(alpha: 0.7)),
      ),
    );
  }
}

class _ScheduleOption {
  final String value;
  final String label;

  const _ScheduleOption(this.value, this.label);
}
