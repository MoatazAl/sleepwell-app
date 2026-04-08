import 'package:flutter/material.dart';
import '../theme.dart';

enum NavSection { home, tracker, summary, insights, settings }

class AppNavBar extends StatelessWidget implements PreferredSizeWidget {
  const AppNavBar({super.key, required this.current});

  final NavSection current;

  @override
  Size get preferredSize => const Size.fromHeight(82);

  bool _smallWidth(BuildContext context) =>
      MediaQuery.of(context).size.width < 900;

  @override
  Widget build(BuildContext context) {
    final isSmall = _smallWidth(context);

    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 82,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1420),
              child: Container(
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const _BrandBlock(),
                    const Spacer(),
                    if (isSmall)
                      _MobileMenu(current: current)
                    else
                      _DesktopNav(current: current),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandBlock extends StatelessWidget {
  const _BrandBlock();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [kBrand, kBrandDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: kBrand.withValues(alpha: 0.30),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.nightlight_round,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'SleepWell',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _DesktopNav extends StatelessWidget {
  const _DesktopNav({required this.current});

  final NavSection current;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _NavChip(
          label: 'Home',
          icon: Icons.home_rounded,
          section: NavSection.home,
          current: current,
        ),
        _NavChip(
          label: 'Tracker',
          icon: Icons.bedtime_rounded,
          section: NavSection.tracker,
          current: current,
        ),
        _NavChip(
          label: 'Summary',
          icon: Icons.insert_chart_rounded,
          section: NavSection.summary,
          current: current,
        ),
        _NavChip(
          label: 'Insights',
          icon: Icons.auto_awesome_rounded,
          section: NavSection.insights,
          current: current,
        ),
        _NavChip(
          label: 'Settings',
          icon: Icons.settings_rounded,
          section: NavSection.settings,
          current: current,
        ),
      ],
    );
  }
}

class _MobileMenu extends StatelessWidget {
  const _MobileMenu({required this.current});

  final NavSection current;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<NavSection>(
      color: kSurfaceCard,
      tooltip: 'Open navigation',
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kBorder),
      ),
      onSelected: (s) => _go(context, s),
      itemBuilder: (_) => const [
        PopupMenuItem(value: NavSection.home, child: Text('Home')),
        PopupMenuItem(value: NavSection.tracker, child: Text('Tracker')),
        PopupMenuItem(value: NavSection.summary, child: Text('Summary')),
        PopupMenuItem(value: NavSection.insights, child: Text('Insights')),
        PopupMenuItem(value: NavSection.settings, child: Text('Settings')),
      ],
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: const Icon(Icons.menu_rounded, color: Colors.white),
      ),
    );
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({
    required this.label,
    required this.icon,
    required this.section,
    required this.current,
  });

  final String label;
  final IconData icon;
  final NavSection section;
  final NavSection current;

  @override
  Widget build(BuildContext context) {
    final selected = section == current;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: selected ? null : () => _go(context, section),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? kBrand.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: selected
                ? kBrand.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? Colors.white : Colors.white.withValues(alpha: 0.82),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white.withValues(alpha: 0.82),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _go(BuildContext context, NavSection section) {
  switch (section) {
    case NavSection.home:
      Navigator.pushReplacementNamed(context, '/home');
      break;
    case NavSection.tracker:
      Navigator.pushReplacementNamed(context, '/tracker');
      break;
    case NavSection.summary:
      Navigator.pushReplacementNamed(context, '/summary');
      break;
    case NavSection.insights:
      Navigator.pushReplacementNamed(context, '/insights');
      break;
    case NavSection.settings:
      Navigator.pushReplacementNamed(context, '/settings');
      break;
  }
}