import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../wardrobe/wardrobe_screen.dart';
import '../outfits/outfit_history_screen.dart';
import '../calendar/calendar_screen.dart';
import '../profile/profile_screen.dart';

final homeTabProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(homeTabProvider);

    // Each tab screen has its own Scaffold, so we just switch between them
    // and add the nav bar via a wrapper
    return Material(
      child: Column(
        children: [
          Expanded(child: _buildCurrentTab(currentTab)),
          _BottomNav(currentTab: currentTab),
        ],
      ),
    );
  }

  Widget _buildCurrentTab(int index) {
    return switch (index) {
      0 => const WardrobeScreen(),
      1 => const OutfitHistoryScreen(),
      2 => const CalendarScreen(),
      3 => const ProfileScreen(),
      _ => const WardrobeScreen(),
    };
  }
}

class _BottomNav extends ConsumerWidget {
  final int currentTab;

  const _BottomNav({required this.currentTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.checkroom,
                label: 'Wardrobe',
                isSelected: currentTab == 0,
                onTap: () => ref.read(homeTabProvider.notifier).state = 0,
              ),
              _NavItem(
                icon: Icons.auto_awesome,
                label: 'Outfits',
                isSelected: currentTab == 1,
                onTap: () => ref.read(homeTabProvider.notifier).state = 1,
              ),
              _NavItem(
                icon: Icons.calendar_month,
                label: 'Calendar',
                isSelected: currentTab == 2,
                onTap: () => ref.read(homeTabProvider.notifier).state = 2,
              ),
              _NavItem(
                icon: Icons.person,
                label: 'Profile',
                isSelected: currentTab == 3,
                onTap: () => ref.read(homeTabProvider.notifier).state = 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
