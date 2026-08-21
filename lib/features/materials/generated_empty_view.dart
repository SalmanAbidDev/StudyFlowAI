// lib/features/materials/generated_empty_view.dart
//
// What Flashcards and Quiz show when there is nothing to show: the honest
// version, naming the document you picked and saying why it is empty.
//
// The copy has been wrong twice. "Upload a document and Flow will build a deck
// from it" was wrong once a document *had* been picked — you had uploaded one.
// Its replacement said Flow's AI "isn't connected yet", which stopped being
// true the day it was (§5.5.2). What is under this view is a button that
// generates, so the text points at it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/widgets.dart';
import 'materials_view_model.dart';

class GeneratedEmptyView extends ConsumerWidget {
  const GeneratedEmptyView({
    super.key,
    required this.icon,
    required this.noun,
  });

  final IconData icon;

  /// "cards" or "questions" — what has not been generated.
  final String noun;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final material = ref.watch(currentMaterialProvider).value;

    return SfEmptyView(
      icon: icon,
      title: 'No $noun yet',
      body: material == null
          ? 'Pick a document first — $noun are built from what you upload.'
          // Was "…once its AI is connected, which it isn't yet". It is
          // connected (§5.5.2), and the button below this says so.
          : '“${material.title}” has no $noun yet. Flow can write them from '
              'the document.',
    );
  }
}
