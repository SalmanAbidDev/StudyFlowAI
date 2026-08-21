// lib/features/materials/material_browser.dart
//
// One library row, and one searchable list of them.
//
// The library is now reachable from five places — the Materials tab, Add
// material's history, the History screen, and the Flashcards and Quiz pickers.
// They all draw the same row, so it is defined once here; a copy per screen is
// how the progress bar ends up on four of them and the fifth quietly loses it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/study_material.dart';
import '../../data/models/subject.dart';
import 'materials_view_model.dart';

/// A document as a tappable card: icon, title, meta, and how far through it
/// you are.
///
/// [leading] is the Materials tab's selection tick — nothing else passes one.
class MaterialRow extends StatelessWidget {
  const MaterialRow({
    super.key,
    required this.material,
    this.onTap,
    this.onLongPress,
    this.leading,
    this.selected = false,
    this.showProgress = true,
    this.trailing,
  });

  final StudyMaterial material;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? leading;
  final bool selected;
  final bool showProgress;

  /// Defaults to a chevron. Pass something else where tapping does not open a
  /// new screen — a chevron that leads nowhere is a small lie.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;
    final accent = material.accent.color(context);

    return SfCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      onLongPress: onLongPress,
      color: selected ? sf.indigoSoft : null,
      borderColor: selected ? scheme.primary : null,
      child: Row(
        children: [
          ?leading,
          SoftIconTile(
            icon: material.icon,
            color: accent,
            width: 44,
            height: 52,
            radius: 10,
            iconSize: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  material.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                    color: sf.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(material.meta,
                    style: TextStyle(fontSize: 11, color: sf.ink3)),
                if (showProgress) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SfProgress(
                          value: material.progress,
                          color: accent,
                          height: 4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 34,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: SfMono(
                            '${(material.progress * 100).round()}%',
                            size: 10,
                            color: sf.ink3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          trailing ??
              Icon(Icons.chevron_right_rounded, size: 18, color: sf.ink4),
        ],
      ),
    );
  }
}

/// The whole library with a search box over it, for a screen whose only job is
/// picking one.
///
/// The query is **local state**, not a provider: the Materials tab has its own
/// in `materialsQueryProvider`, and sharing one would mean typing in the
/// History screen silently filtered the tab behind it.
class MaterialBrowser extends ConsumerStatefulWidget {
  const MaterialBrowser({
    super.key,
    required this.onPick,
    this.emptyTitle = 'Nothing here yet',
    this.emptyBody = 'Upload a PDF or paste your notes to get started.',
    this.padding = const EdgeInsets.fromLTRB(22, 0, 22, 24),
    this.showProgress = true,
  });

  final void Function(StudyMaterial material) onPick;
  final String emptyTitle;
  final String emptyBody;
  final EdgeInsets padding;
  final bool showProgress;

  @override
  ConsumerState<MaterialBrowser> createState() => _MaterialBrowserState();
}

class _MaterialBrowserState extends ConsumerState<MaterialBrowser> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setQuery(String value) => setState(() => _query = value);

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(materialsProvider);
    final all = library.value ?? const <StudyMaterial>[];
    final items = filterMaterials(all, _query);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hidden on an empty library: a search box over nothing is furniture.
        if (all.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(
                widget.padding.left, 0, widget.padding.right, 12),
            child: SfSearchBar(
              hint: 'Search ${all.length} '
                  '${all.length == 1 ? 'document' : 'documents'}…',
              controller: _search,
              onChanged: _setQuery,
              onClear: () {
                _search.clear();
                _setQuery('');
              },
            ),
          ),
        Expanded(
          child: library.when(
            loading: () => const SfLoadingList(rows: 5),
            error: (error, _) => SfErrorView(
              error: error,
              onRetry: () => ref.invalidate(materialsProvider),
            ),
            data: (_) => items.isEmpty
                // "Nothing matched" and "nothing here yet" are different
                // problems with different fixes.
                ? (all.isEmpty
                    ? SfEmptyView(
                        icon: Icons.description_outlined,
                        title: widget.emptyTitle,
                        body: widget.emptyBody,
                      )
                    : SfEmptyView(
                        icon: Icons.search_off_rounded,
                        title: 'No matches',
                        body: 'Nothing in your library matches that.',
                        actionLabel: 'Clear search',
                        onAction: () {
                          _search.clear();
                          _setQuery('');
                        },
                      ))
                : ListView.separated(
                    padding: widget.padding.copyWith(top: 0),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => MaterialRow(
                      material: items[i],
                      showProgress: widget.showProgress,
                      onTap: () => widget.onPick(items[i]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
