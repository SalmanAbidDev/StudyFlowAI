// lib/features/materials/pick_material_screen.dart
//
// "Which document?" — the step Flashcards and Quiz need when they are opened
// from Home, where nothing has been chosen yet.
//
// Opened from a document instead, both screens skip this entirely: the answer
// is already known, and asking again would be asking a question the app can
// see the answer to.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../flashcards/flashcards_screen.dart';
import '../quiz/quiz_screen.dart';
import 'material_browser.dart';
import 'materials_view_model.dart';

/// Which practice surface the picker is feeding.
enum StudyTool {
  flashcards(
    title: 'Flashcards',
    prompt: 'Pick a document to make cards from.',
  ),
  quiz(
    title: 'Quiz',
    prompt: 'Pick a document to be quizzed on.',
  );

  const StudyTool({required this.title, required this.prompt});

  final String title;
  final String prompt;
}

class PickMaterialScreen extends ConsumerWidget {
  const PickMaterialScreen({super.key, required this.tool});

  final StudyTool tool;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sf = context.sf;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SfModalHeader(title: tool.title),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
              child: Row(
                children: [
                  const FlowOrb(size: 18, animate: false),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tool.prompt,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: sf.ink2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: MaterialBrowser(
                emptyTitle: 'Nothing to study yet',
                emptyBody: 'Upload a document first — '
                    '${tool.title.toLowerCase()} are built from what you add.',
                onPick: (material) {
                  // The two screens read the selection rather than taking an
                  // argument, because they are also opened straight from a
                  // document, where the same selection is already set.
                  ref
                      .read(selectedMaterialProvider.notifier)
                      .update(material.id);
                  Navigator.of(context).push(
                    sfModalRoute(
                      builder: (_) => switch (tool) {
                        StudyTool.flashcards => const FlashcardsScreen(),
                        StudyTool.quiz => const QuizScreen(),
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
