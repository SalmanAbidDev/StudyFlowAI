// lib/features/materials/materials_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/study_material.dart';
import '../../data/models/subject.dart';
import '../documents/document_screen.dart';
import '../summaries/summaries_view_model.dart';
import '../upload/upload_screen.dart';
import 'materials_view_model.dart';

class MaterialsScreen extends ConsumerStatefulWidget {
  const MaterialsScreen({super.key});

  @override
  ConsumerState<MaterialsScreen> createState() => _MaterialsScreenState();
}

/// Stateful only for the search field's controller — the query itself is a
/// provider, because the filtering happens in the view model.
class _MaterialsScreenState extends ConsumerState<MaterialsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The three-dots menu. Only ever holds Delete — a menu whose single item is
  /// destructive does not need padding out with actions nobody asked for.
  Future<void> _showSelectionActions(BuildContext context) async {
    final selected = ref.read(selectedMaterialsProvider);
    if (selected.isEmpty) return;

    final action = await showSfSheet<_MaterialAction>(
      context,
      (_) => _SelectionActionsSheet(count: selected.length),
    );
    if (action != _MaterialAction.delete || !context.mounted) return;

    final many = selected.length > 1;
    final confirmed = await showSfSheet<bool>(
      context,
      (_) => SfConfirmSheet(
        icon: Icons.delete_outline_rounded,
        title: many
            ? 'Delete ${selected.length} materials?'
            : 'Delete this material?',
        body: many
            ? 'They will be removed along with their uploaded files, '
                'summaries, decks and quizzes. This cannot be undone.'
            : '"${selected.first.title}" and its summary, deck and quizzes '
                'will be removed. This cannot be undone.',
        confirmLabel: 'Delete',
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final failed = await ref.read(deleteMaterialsProvider)(selected);
    ref.read(materialSelectionProvider.notifier).clear();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failed.isEmpty
              ? (many
                  ? 'Deleted ${selected.length} materials.'
                  : 'Deleted "${selected.first.title}".')
              // Names the shortfall rather than claiming a clean sweep.
              : "Couldn't delete ${failed.length} of ${selected.length}.",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final filter = ref.watch(materialsFilterProvider);
    final filters = ref.watch(libraryFiltersProvider);
    final library = ref.watch(materialsProvider);
    final items = ref.watch(visibleMaterialsProvider);
    final filteredToNothing = ref.watch(materialsFilteredToNothingProvider);
    final selected = ref.watch(materialSelectionProvider);
    final selecting = ref.watch(materialSelectionModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selecting ? '${selected.length} selected' : 'Materials',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.displayL.copyWith(color: sf.ink),
                ),
              ),
              // Appears only with something to act on, so the menu can never
              // open onto an empty selection.
              if (selecting) ...[
                SfIconButton(
                  icon: Icons.more_vert_rounded,
                  size: 40,
                  iconSize: 20,
                  onPressed: () => _showSelectionActions(context),
                ),
                const SizedBox(width: 8),
              ],
              SfIconButton(
                icon: Icons.add_rounded,
                size: 40,
                iconSize: 20,
                filled: true,
                onPressed: () => Navigator.of(context).push(
                  sfModalRoute(builder: (_) => const UploadScreen()),
                ),
              ),
            ],
          ),
        ),
        // Search and the subject pills fold away for the duration: neither is
        // any use mid-selection, and their absence is what makes the mode
        // unmistakable.
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: selecting
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                      child: SfSearchBar(
                        hint:
                            'Search ${library.value?.length ?? 0} documents…',
                        controller: _search,
                        onChanged:
                            ref.read(materialsQueryProvider.notifier).update,
                        onClear: () {
                          _search.clear();
                          ref.read(materialsQueryProvider.notifier).update('');
                        },
                      ),
                    ),
                    // Content-sized so the pills grow with the text rather
                    // than overflowing a fixed rail height.
                    if (filters.length > 1)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Row(
                          children: [
                            for (var i = 0; i < filters.length; i++)
                              _FilterPill(
                                label: filters[i].label,
                                count: filters[i].count,
                                active: i == filter,
                                isLast: i == filters.length - 1,
                                onTap: () => ref
                                    .read(materialsFilterProvider.notifier)
                                    .update(i),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: library.when(
            loading: () => const SfLoadingList(rows: 5),
            error: (error, _) => SfErrorView(
              error: error,
              onRetry: () => ref.invalidate(materialsProvider),
            ),
            data: (_) => items.isEmpty
                // The bottom inset offsets the centred state above the nav
                // pill, so it reads as centred in the space actually visible.
                ? Padding(
                    padding: EdgeInsets.only(
                      bottom: sfNavContentInset(context, extra: 0),
                    ),
                    // "Nothing matched" and "nothing here yet" are different
                    // problems with different fixes.
                    child: filteredToNothing
                        ? SfEmptyView(
                            icon: Icons.search_off_rounded,
                            title: 'No matches',
                            body: 'Nothing in your library matches that. Try '
                                'another word, or clear the filter.',
                            actionLabel: 'Clear search',
                            onAction: () {
                              _search.clear();
                              ref
                                  .read(materialsQueryProvider.notifier)
                                  .update('');
                              ref
                                  .read(materialsFilterProvider.notifier)
                                  .update(0);
                            },
                          )
                        // No action button: uploading is the ＋ in the header,
                        // and one control per job beats the same job offered
                        // twice on the same screen.
                        : const SfEmptyView(
                            icon: Icons.description_outlined,
                            title: 'Nothing here yet',
                            body: 'Tap ＋ to upload a PDF or paste your notes.',
                          ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                        22, 0, 22, sfNavContentInset(context)),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) =>
                        _MaterialRow(material: items[i]),
                  ),
          ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.count,
    required this.active,
    required this.isLast,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final fg = active
        ? (context.isDark ? AppColors.textPrimary : Colors.white)
        : context.sf.ink2;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(right: isLast ? 0 : 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? scheme.primary : scheme.surface,
          borderRadius: AppRadius.brSm,
          border: Border.all(color: active ? scheme.primary : scheme.outline),
        ),
        child: Row(
          children: [
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
            const SizedBox(width: 6),
            SfMono('$count', color: fg.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}

class _MaterialRow extends ConsumerWidget {
  const _MaterialRow({required this.material});

  final StudyMaterial material;

  void _open(BuildContext context, WidgetRef ref) {
    // Tell Summaries which document to open before pushing it, so the screen
    // doesn't have to guess.
    ref.read(selectedMaterialProvider.notifier).update(material.id);
    Navigator.of(context).push(
      sfRoute(builder: (_) => const DocumentScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sf = context.sf;
    final scheme = context.scheme;
    final accent = material.accent.color(context);
    final selecting = ref.watch(materialSelectionModeProvider);
    final selected =
        ref.watch(materialSelectionProvider).contains(material.id);

    return SfCard(
      padding: const EdgeInsets.all(14),
      // In selection mode a tap ticks rather than opens — otherwise the two
      // gestures fight, and opening a document you meant to tick is a
      // surprise that costs a round trip back.
      onTap: () => selecting
          ? ref.read(materialSelectionProvider.notifier).toggle(material.id)
          : _open(context, ref),
      onLongPress: () =>
          ref.read(materialSelectionProvider.notifier).start(material.id),
      color: selected ? sf.indigoSoft : null,
      borderColor: selected ? scheme.primary : null,
      child: Row(
        children: [
          _SelectionBox(visible: selecting, checked: selected),
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
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 18, color: sf.ink4),
        ],
      ),
    );
  }
}


// ─── Selection ────────────────────────────────────────────────────────────

/// The tick box that slides in on the left of every row when selection starts.
///
/// `Align(widthFactor:)` inside a `ClipRect` is what animates the *space* as
/// well as the box — the rest of the row slides over to make room instead of
/// the box appearing on top of it.
class _SelectionBox extends StatelessWidget {
  const _SelectionBox({required this.visible, required this.checked});

  final bool visible;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return TweenAnimationBuilder<double>(
      tween: Tween(end: visible ? 1 : 0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => ClipRect(
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: t,
          child: Opacity(opacity: t, child: child),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: checked ? scheme.primary : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: checked ? scheme.primary : scheme.outlineVariant,
              width: 2,
            ),
          ),
          child: checked
              ? Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: context.isDark ? AppColors.textPrimary : Colors.white,
                )
              : null,
        ),
      ),
    );
  }
}

enum _MaterialAction { delete }

/// The three-dots menu for the current selection. Returns the chosen action
/// and closes; the caller confirms and runs it, so this sheet stays ignorant
/// of what deleting involves.
class _SelectionActionsSheet extends StatelessWidget {
  const _SelectionActionsSheet({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;

    return SfSheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Saying how many is the whole point: a destructive menu that does
          // not state its scope is how people delete more than they meant to.
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 14),
            child: Text(
              count == 1 ? '1 material selected' : '$count materials selected',
              style: TextStyle(
                fontFamily: AppTextStyles.fontUi,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: sf.ink,
              ),
            ),
          ),
          _SheetAction(
            icon: Icons.delete_outline_rounded,
            label: count == 1 ? 'Delete' : 'Delete $count',
            destructive: true,
            onTap: () => Navigator.of(context).pop(_MaterialAction.delete),
          ),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;
    final tint = destructive ? sf.coralInk : sf.ink;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: scheme.outline),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.brLg,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.brLg,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 20, color: tint),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontUi,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: tint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
