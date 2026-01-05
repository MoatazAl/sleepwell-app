import 'package:flutter/material.dart';
import '../theme.dart';

enum NavSection { home, tracker, summary, insights, settings }

class AppNavBar extends StatelessWidget implements PreferredSizeWidget {
  const AppNavBar({super.key, required this.current});

  final NavSection current;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  bool _smallWidth(BuildContext context) =>
      MediaQuery.of(context).size.width < 720;

  @override
  Widget build(BuildContext context) {
    final isSmall = _smallWidth(context);

    Widget brand = Row(
      children: const [
        Icon(Icons.nightlight_round, color: kBrand, size: 22),
        SizedBox(width: 8),
        Text('SleepWell'),
      ],
    );

    if (isSmall) {
      return AppBar(
        title: brand,
        actions: [
          PopupMenuButton<NavSection>(
            onSelected: (s) => _go(context, s),
            itemBuilder: (_) => const [
              PopupMenuItem(value: NavSection.home, child: Text('Home')),
              PopupMenuItem(value: NavSection.tracker, child: Text('Tracker')),
              PopupMenuItem(value: NavSection.summary, child: Text('Summary')),
              PopupMenuItem(value: NavSection.insights, child: Text('Insights')),
              PopupMenuItem(value: NavSection.settings, child: Text('Settings')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      );
    }

    return AppBar(
      title: brand,
      actions: [
        _NavItem(label: 'Home', section: NavSection.home, current: current),
        _NavItem(label: 'Tracker', section: NavSection.tracker, current: current),
        _NavItem(label: 'Summary', section: NavSection.summary, current: current),
        _NavItem(label: 'Insights', section: NavSection.insights, current: current),
        _NavItem(label: 'Settings', section: NavSection.settings, current: current),
        const SizedBox(width: 8),
      ],
    );
  }

  void _go(BuildContext context, NavSection s) {
    switch (s) {
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
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.section,
    required this.current,
  });

  final String label;
  final NavSection section;
  final NavSection current;

  @override
  Widget build(BuildContext context) {
    final selected = section == current;

    return TextButton(
      onPressed: selected
          ? null
          : () {
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
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? kBrand : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 2,
              width: selected ? 22 : 0,
              color: selected ? kBrand : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}
