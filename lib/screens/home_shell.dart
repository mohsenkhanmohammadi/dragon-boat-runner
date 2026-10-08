import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/backend.dart';
import 'calendar_screen.dart';
import 'home_screen.dart';
import 'leaderboard_screen.dart';
import 'more_screen.dart';
import 'team_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          CalendarScreen(),
          LeaderboardScreen(timingMode: true),
          TeamScreen(),
          MoreScreen(),
        ],
      ),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        if (Backend.demo)
          Container(
            width: double.infinity,
            color: const Color(0xFFF2B33D),
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
            child: Text(s.t('demoBanner'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: s.t('navHome')),
          NavigationDestination(
              icon: const Icon(Icons.calendar_month_outlined),
              selectedIcon: const Icon(Icons.calendar_month),
              label: s.t('navCalendar')),
          NavigationDestination(
              icon: const Icon(Icons.timer_outlined),
              selectedIcon: const Icon(Icons.timer),
              label: s.t('timing')),
          NavigationDestination(
              icon: const Icon(Icons.groups_outlined),
              selectedIcon: const Icon(Icons.groups),
              label: s.t('navTeam')),
          NavigationDestination(
              icon: const Icon(Icons.more_horiz),
              label: s.t('navMore')),
        ],
      ),
      ]),
    );
  }
}
