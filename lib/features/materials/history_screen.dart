// lib/features/materials/history_screen.dart
//
// Everything uploaded so far, reachable from "View all" on the Add material
// screen. Deliberately *not* the Materials tab in a second window: no subject
// pills, no multi-select, no delete. This screen finds a document and opens
// it; managing the library stays in one place.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../core/widgets/widgets.dart';
import '../documents/document_screen.dart';
import 'material_browser.dart';
import 'materials_view_model.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Pushed on top of the Add material modal rather than over it, so
            // it takes a back arrow.
            const SfModalHeader(
              title: 'History',
              leadingIcon: Icons.arrow_back_rounded,
            ),
            Expanded(
              child: MaterialBrowser(
                // No progress bars here. History answers "what have I added,
                // and when" — how far through each one you are is what the
                // Materials tab is for.
                showProgress: false,
                emptyTitle: 'Nothing uploaded yet',
                emptyBody: 'Everything you add will be listed here.',
                onPick: (material) {
                  ref
                      .read(selectedMaterialProvider.notifier)
                      .update(material.id);
                  Navigator.of(context).push(
                    sfRoute(builder: (_) => const DocumentScreen()),
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
