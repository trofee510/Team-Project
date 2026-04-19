import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../wardrobe/wardrobe_screen.dart';
import '../hub/mode_selection_screen.dart';
import '../feed/stranger_feed_screen.dart';
import '../analytics/style_analytics_screen.dart';
import '../profile/profile_screen.dart';

final homeTabProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _screens = [
    WardrobeScreen(),
    ModeSelectionScreen(),
    StrangerFeedScreen(),
    StyleAnalyticsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(homeTabProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentTab,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.grey.shade300, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: currentTab,
          onTap: (index) => ref.read(homeTabProvider.notifier).state = index,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.checkroom),
              label: 'Wardrobe',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome),
              label: 'Outfits',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.public),
              label: 'Discover',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insights),
              label: 'Analytics',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
