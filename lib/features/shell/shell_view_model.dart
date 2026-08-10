// lib/features/shell/shell_view_model.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The pages the shell can display. Exams and Insights are peers of the four
/// tabs: the design draws the tab bar on them, so they live here rather than
/// being pushed as routes.
enum ShellPage { home, materials, planner, profile, exams, analytics }

/// The page the shell opens on. A separate provider rather than a widget
/// argument so it can be seeded from a `ProviderScope` override — the shell
/// itself has no business mutating navigation state during initState.
final initialShellPageProvider = Provider<ShellPage>((_) => ShellPage.home);

/// Not autoDispose: which page the shell is on has to survive a screen being
/// pushed over the top of it.
class ShellViewModel extends Notifier<ShellPage> {
  @override
  ShellPage build() => ref.watch(initialShellPageProvider);

  void go(ShellPage page) => state = page;
}

final shellPageProvider =
    NotifierProvider<ShellViewModel, ShellPage>(ShellViewModel.new);
