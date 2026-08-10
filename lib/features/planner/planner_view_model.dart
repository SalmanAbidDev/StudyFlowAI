// lib/state/planner_state.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/demo_content.dart';
import '../../core/view_models.dart';

/// Index into the week strip, Monday first.
final selectedDayProvider = NotifierProvider<ValueViewModel<int>, int>(
  () => ValueViewModel(1),
);

/// The day's study blocks, in the order the user has dragged them into.
class PlannerBlocks extends Notifier<List<StudyBlock>> {
  @override
  List<StudyBlock> build() => demoStudyBlocks;

  /// `onReorderItem` hands back a [newIndex] that already accounts for the row
  /// being lifted out, so no off-by-one correction is needed here.
  void reorder(int oldIndex, int newIndex) {
    final next = [...state];
    next.insert(newIndex, next.removeAt(oldIndex));
    state = next;
  }
}

final plannerBlocksProvider =
    NotifierProvider<PlannerBlocks, List<StudyBlock>>(PlannerBlocks.new);
