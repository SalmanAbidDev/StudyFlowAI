// lib/screens/app_shell.dart
//
// Hosts the four tab destinations plus the two peer screens (Exams,
// Insights) that the design draws with the tab bar still visible. Anything
// with a back or close affordance is pushed as a route instead.

import 'package:flutter/material.dart';

import '../widgets/widgets.dart';
import 'analytics_screen.dart';
import 'chat_screen.dart';
import 'exams_screen.dart';
import 'home_screen.dart';
import 'materials_screen.dart';
import 'planner_screen.dart';
import 'profile_screen.dart';

enum ShellPage { home, materials, planner, profile, exams, analytics }

/// Lets any descendant switch the shell's visible page — used by Planner to
/// open Exams and by Profile to open Insights.
class AppShellScope extends InheritedWidget {
  const AppShellScope({
    super.key,
    required this.go,
    required this.current,
    required super.child,
  });

  final void Function(ShellPage) go;
  final ShellPage current;

  static AppShellScope of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppShellScope>();
    assert(scope != null, 'AppShellScope was not found in the widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppShellScope old) => old.current != current;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialPage = ShellPage.home});

  final ShellPage initialPage;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late ShellPage _page = widget.initialPage;

  static const _order = ShellPage.values;

  SfNavTab get _activeTab => switch (_page) {
        ShellPage.home => SfNavTab.home,
        ShellPage.materials => SfNavTab.materials,
        ShellPage.planner || ShellPage.exams => SfNavTab.planner,
        ShellPage.profile || ShellPage.analytics => SfNavTab.profile,
      };

  void _go(ShellPage page) => setState(() => _page = page);

  void _selectTab(SfNavTab tab) {
    _go(switch (tab) {
      SfNavTab.home => ShellPage.home,
      SfNavTab.materials => ShellPage.materials,
      SfNavTab.planner => ShellPage.planner,
      SfNavTab.profile => ShellPage.profile,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppShellScope(
      go: _go,
      current: _page,
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: IndexedStack(
                index: _order.indexOf(_page),
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
                  active: _activeTab,
                  onSelect: _selectTab,
                  onFlow: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChatScreen()),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
