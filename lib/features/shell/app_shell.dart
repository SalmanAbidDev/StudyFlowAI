// lib/features/shell/app_shell.dart
//
// Hosts the four tab destinations. Everything else — including Exams and
// Insights, which used to live here as extra IndexedStack children — is pushed
// as a route.
//
// That distinction matters more than it looks. A screen inside the stack has no
// route of its own, so it gets no page transition, keeps the tab bar on top of
// it, and gives the system back button nothing to pop: Android would close the
// app instead of going back.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../core/widgets/widgets.dart';
import '../chat/chat_screen.dart';
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
        ShellPage.planner => SfNavTab.planner,
        ShellPage.profile => SfNavTab.profile,
      };

  static ShellPage _pageFor(SfNavTab tab) => switch (tab) {
        SfNavTab.home => ShellPage.home,
        SfNavTab.materials => ShellPage.materials,
        SfNavTab.planner => ShellPage.planner,
        SfNavTab.profile => ShellPage.profile,
      };

  /// System back at the root of the app.
  ///
  /// Off Home, back returns to Home — the tab bar is lateral navigation, so
  /// "back" should unwind it before it unwinds the app. On Home there is
  /// nowhere left to go, so ask before leaving rather than dropping the user
  /// out on a stray tap.
  Future<void> _handleBack(BuildContext context, WidgetRef ref) async {
    if (ref.read(shellPageProvider) != ShellPage.home) {
      ref.read(shellPageProvider.notifier).go(ShellPage.home);
      return;
    }

    final leave = await showSfSheet<bool>(
      context,
      (_) => const SfConfirmSheet(
        icon: Icons.exit_to_app_rounded,
        title: 'Close StudyFlow?',
        body: 'Your progress is saved. You can pick up where you left off next '
            'time.',
        confirmLabel: 'Close app',
      ),
    );

    // Null when dismissed by scrim or swipe — treat as "stay".
    if (leave == true) await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(shellPageProvider);

    // canPop: false because the shell is the root route — letting the pop
    // through would close the app. `_handleBack` decides what back means.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack(context, ref);
      },
      child: Scaffold(
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
      ),
    );
  }
}
