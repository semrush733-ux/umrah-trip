import 'package:flutter/material.dart';

import '../core/strings.dart';
import 'package:provider/provider.dart';

import '../services/social_service.dart';
import 'explore_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calls_screen.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'trip_screen.dart';

/// Six-tab shell: Home · Chats · Explore · Map · My Trip · Profile.
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  /// Lets any screen switch tabs (e.g. Home's "plan your next Ziyarat" CTA).
  static final ValueNotifier<int> tabIndex = ValueNotifier<int>(0);

  /// "Chats & calls only": hides the Umrah guide tabs.
  static final ValueNotifier<bool> simpleMode = ValueNotifier<bool>(false);

  static Future<void> setSimpleMode(bool v) async {
    simpleMode.value = v;
    tabIndex.value = 0;
    final p = await SharedPreferences.getInstance();
    await p.setBool('simple_mode', v);
  }

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    RootScreen.tabIndex.addListener(_onTab);
    RootScreen.simpleMode.addListener(_onMode);
    SharedPreferences.getInstance().then((p) {
      final v = p.getBool('simple_mode') ?? false;
      if (v != RootScreen.simpleMode.value) RootScreen.simpleMode.value = v;
    });
  }

  void _onMode() {
    if (mounted) setState(() => _index = 0);
  }

  void _onTab() {
    if (mounted && RootScreen.tabIndex.value != _index) {
      setState(() => _index = RootScreen.tabIndex.value);
    }
  }

  @override
  void dispose() {
    RootScreen.tabIndex.removeListener(_onTab);
    RootScreen.simpleMode.removeListener(_onMode);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final social = context.watch<SocialService>();
    final badge = social.totalUnread + social.pendingRequests + social.missedCallsUnseen;
    final simple = RootScreen.simpleMode.value;
    final chatsDest = NavigationDestination(
        icon: Badge(
            isLabelVisible: badge > 0, label: Text('$badge'), child: const Icon(Icons.forum_outlined)),
        selectedIcon: Badge(
            isLabelVisible: badge > 0, label: Text('$badge'), child: const Icon(Icons.forum_rounded)),
        label: 'Chats');
    if (simple) {
      final i = _index.clamp(0, 1);
      return Scaffold(
        body: IndexedStack(index: i, children: const [ChatsHub(), ProfileScreen()]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: i,
          onDestinationSelected: (v) => setState(() => _index = v),
          destinations: [
            chatsDest,
            NavigationDestination(
                icon: const Icon(Icons.person_outline_rounded),
                selectedIcon: const Icon(Icons.person_rounded),
                label: s.profile),
          ],
        ),
      );
    }
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          ChatsHub(),
          ExploreScreen(),
          MapScreen(),
          TripScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: _index,
        onDestinationSelected: (i) {
          RootScreen.tabIndex.value = i;
          setState(() => _index = i);
        },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: s.home),
          chatsDest,
          NavigationDestination(icon: const Icon(Icons.explore_outlined), selectedIcon: const Icon(Icons.explore_rounded), label: s.explore),
          NavigationDestination(icon: const Icon(Icons.map_outlined), selectedIcon: const Icon(Icons.map_rounded), label: s.map),
          NavigationDestination(icon: const Icon(Icons.event_note_outlined), selectedIcon: const Icon(Icons.event_note_rounded), label: s.myTrip),
          NavigationDestination(icon: const Icon(Icons.person_outline_rounded), selectedIcon: const Icon(Icons.person_rounded), label: s.profile),
        ],
      ),
    );
  }
}
