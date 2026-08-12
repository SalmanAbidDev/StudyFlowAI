// lib/features/shell/shell_view_model.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The four tab destinations. Nothing else belongs here — Exams and Insights
/// were briefly members and had to be removed: a page inside the shell's
/// IndexedStack gets no route, so it has no transition, keeps the tab bar over
/// it, and leaves the system back button with nothing to pop.
enum ShellPage { home, materials, planner, profile }

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
