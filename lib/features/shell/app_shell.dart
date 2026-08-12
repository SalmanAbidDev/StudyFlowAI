// lib/features/shell/app_shell.dart
//
// Hosts the four tab destinations plus the two peer screens (Exams,
// Insights) that the design draws with the tab bar still visible. Anything
// with a back or close affordance is pushed as a route instead.
//
// The shell used to publish an AppShellScope InheritedWidget so Planner could
// open Exams and Profile could open Insights. `shellPageProvider` does that
// job now, so any descendant can navigate without the shell handing a callback
// down through the tree.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../core/widgets/widgets.dart';
import '../analytics/analytics_screen.dart';
import '../chat/chat_screen.dart';
import '../exams/exams_screen.dart';
import '../home/home_screen.dart';
import '../materials/materials_screen.dart';
import '../planner/planner_screen.dart';
import '../profile/profile_screen.dart';
import 'shell_view_model.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const _order = ShellPage.values;

  static SfNavTab _tabFor(ShellPage page) => switch (page) {
        ShellPage.home => SfNavTab.home,
        ShellPage.materials => SfNavTab.materials,
        ShellPage.planner || ShellPage.exams => SfNavTab.planner,
        ShellPage.profile || ShellPage.analytics => SfNavTab.profile,
      };

  static ShellPage _pageFor(SfNavTab tab) => switch (tab) {
        SfNavTab.home => ShellPage.home,
        SfNavTab.materials => ShellPage.materials,
        SfNavTab.planner => ShellPage.planner,
        SfNavTab.profile => ShellPage.profile,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(shellPageProvider);

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _order.indexOf(page),
              children: const [
                HomeScreen(),
                MaterialsScreen(),
                PlannerScreen(),
                ProfileScreen(),
                ExamsScreen(),
                AnalyticsScreen(),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: FloatingNavBar(
                active: _tabFor(page),
                onSelect: (tab) =>
                    ref.read(shellPageProvider.notifier).go(_pageFor(tab)),
                onFlow: () => Navigator.of(context).push(
                  sfRoute(builder: (_) => const ChatScreen()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
