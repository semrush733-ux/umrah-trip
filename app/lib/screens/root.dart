import 'package:flutter/material.dart';

import '../core/strings.dart';
import 'explore_screen.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'trip_screen.dart';

/// Five-tab shell: Home · Explore · Map · My Trip · Profile.
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  /// Lets any screen switch tabs (e.g. Home's "plan your next Ziyarat" CTA).
  static final ValueNotifier<int> tabIndex = ValueNotifier<int>(0);

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    RootScreen.tabIndex.addListener(_onTab);
  }

  void _onTab() {
    if (mounted && RootScreen.tabIndex.value != _index) {
      setState(() => _index = RootScreen.tabIndex.value);
    }
  }

  @override
  void dispose() {
    RootScreen.tabIndex.removeListener(_onTab);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          ExploreScreen(),
          MapScreen(),
          TripScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          RootScreen.tabIndex.value = i;
          setState(() => _index = i);
        },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: s.home),
          NavigationDestination(icon: const Icon(Icons.explore_outlined), selectedIcon: const Icon(Icons.explore_rounded), label: s.explore),
          NavigationDestination(icon: const Icon(Icons.map_outlined), selectedIcon: const Icon(Icons.map_rounded), label: s.map),
          NavigationDestination(icon: const Icon(Icons.event_note_outlined), selectedIcon: const Icon(Icons.event_note_rounded), label: s.myTrip),
          NavigationDestination(icon: const Icon(Icons.person_outline_rounded), selectedIcon: const Icon(Icons.person_rounded), label: s.profile),
        ],
      ),
    );
  }
}
