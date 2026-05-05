import 'package:flutter/material.dart';
import '../theme.dart';

enum NavSection {
  home,
  tracker,
  summary,
  history,
  insights,
  aiCoach,
  sounds,
  settings,
}

const _navItems = [
  _NavItem(
    section: NavSection.home,
    label: 'Home',
    icon: Icons.home_rounded,
    route: '/home',
  ),
  _NavItem(
    section: NavSection.tracker,
    label: 'Tracker',
    icon: Icons.bedtime_rounded,
    route: '/tracker',
  ),
  _NavItem(
    section: NavSection.summary,
    label: 'Summary',
    icon: Icons.insert_chart_rounded,
    route: '/summary',
  ),
  _NavItem(
    section: NavSection.history,
    label: 'History',
    icon: Icons.history_rounded,
    route: '/history',
  ),
  _NavItem(
    section: NavSection.insights,
    label: 'Insights',
    icon: Icons.auto_awesome_rounded,
    route: '/insights',
  ),
  _NavItem(
    section: NavSection.aiCoach,
    label: 'AI Coach',
    icon: Icons.psychology_alt_rounded,
    route: '/ai-coach',
  ),
  _NavItem(
    section: NavSection.sounds,
    label: 'Sounds',
    icon: Icons.surround_sound_rounded,
    route: '/sounds',
  ),
  _NavItem(
    section: NavSection.settings,
    label: 'Settings',
    icon: Icons.settings_rounded,
    route: '/settings',
  ),
];

class AppNavBar extends StatelessWidget implements PreferredSizeWidget {
  const AppNavBar({super.key, required this.current});

  final NavSection current;

  @override
  Size get preferredSize => const Size.fromHeight(76);

  bool _smallWidth(BuildContext context) =>
      MediaQuery.of(context).size.width < 1060;

  @override
  Widget build(BuildContext context) {
    final isSmall = _smallWidth(context);

    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 76,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1420),
              child: Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: kSurface.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const _BrandBlock(),
                    const Spacer(),
                    if (isSmall) _MobileMenu(current: current),
                    if (!isSmall) _DesktopNav(current: current),
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
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [kBrand, kBrandDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: kBrand.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.nightlight_round,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'SleepWell',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: 0,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _navItems
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _NavChip(item: item, current: current),
            ),
          )
          .toList(),
    );
  }
}

class _MobileMenu extends StatelessWidget {
  const _MobileMenu({required this.current});

  final NavSection current;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showNavSheet(context, current),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        ),
        child: const Icon(Icons.menu_rounded, color: kTextSecondary, size: 22),
      ),
    );
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({required this.item, required this.current});

  final _NavItem item;
  final NavSection current;

  @override
  Widget build(BuildContext context) {
    final selected = item.section == current;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: selected ? null : () => _go(context, item.section),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? kBrand.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.025),
          border: Border.all(
            color: selected
                ? kBrand.withValues(alpha: 0.34)
                : Colors.white.withValues(alpha: 0.045),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: 16,
              color: selected
                  ? Colors.white
                  : kTextSecondary.withValues(alpha: 0.86),
            ),
            const SizedBox(width: 6),
            Text(
              item.label,
              style: TextStyle(
                color: selected ? Colors.white : kTextSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showNavSheet(BuildContext context, NavSection current) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              color: kSurface.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.32),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                for (final item in _navItems)
                  _NavSheetItem(
                    item: item,
                    selected: item.section == current,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      if (item.section != current) {
                        _go(context, item.section);
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _NavSheetItem extends StatelessWidget {
  const _NavSheetItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? kBrand.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.025),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? kBrand.withValues(alpha: 0.30)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              color: selected ? Colors.white : kTextSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  color: selected ? Colors.white : kTextSecondary,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: 0,
                ),
              ),
            ),
            if (selected)
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: kAccentBlue,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void _go(BuildContext context, NavSection section) {
  final route = _navItems.firstWhere((item) => item.section == section).route;
  Navigator.pushReplacementNamed(context, route);
}

class _NavItem {
  final NavSection section;
  final String label;
  final IconData icon;
  final String route;

  const _NavItem({
    required this.section,
    required this.label,
    required this.icon,
    required this.route,
  });
}
