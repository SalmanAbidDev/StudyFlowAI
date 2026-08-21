// lib/features/materials/generate_button.dart
//
// The full-width "Generate…" button under the empty flashcards and quiz
// screens, and the state that goes with it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import 'generate_view_model.dart';
import 'materials_view_model.dart';

class GenerateBar extends ConsumerWidget {
  const GenerateBar({super.key, required this.target});

  final GenerateTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sf = context.sf;
    final state = ref.watch(generateProvider);
    final material = ref.watch(currentMaterialProvider).value;
    final label = switch (target) {
      GenerateTarget.flashcards => ('Generate flashcards', 'Writing cards…'),
      GenerateTarget.quiz => ('Generate quiz', 'Writing questions…'),
      GenerateTarget.summary => ('Summarize this', 'Reading it…'),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // What went wrong, in the words the service used. A model that can
          // find only two ideas in a two-line note is an ordinary outcome, and
          // saying so beats a spinner that stops.
          if (state.error != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded, size: 14, color: sf.coralInk),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.error!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: sf.coralInk,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          SfButton(
            state.busy ? label.$2 : label.$1,
            icon: Icons.auto_awesome_rounded,
            size: SfButtonSize.lg,
            expand: true,
            busy: state.busy,
            // Nothing to generate *from* without a document.
            onPressed: material == null || state.busy
                ? null
                : () => ref.read(generateProvider.notifier).run(target),
          ),
        ],
      ),
    );
  }
}
