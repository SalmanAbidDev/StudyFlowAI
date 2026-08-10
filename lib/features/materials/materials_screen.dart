// lib/features/materials/materials_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/demo_content.dart';
import '../summaries/summaries_screen.dart';
import '../upload/upload_screen.dart';
import 'materials_view_model.dart';

class MaterialsScreen extends ConsumerWidget {
  const MaterialsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sf = context.sf;
    final filter = ref.watch(materialsFilterProvider);
    final items = ref.watch(visibleMaterialsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Materials',
                  style: AppTextStyles.displayL.copyWith(color: sf.ink),
                ),
              ),
              SfIconButton(
                icon: Icons.add_rounded,
                size: 40,
                iconSize: 20,
                filled: true,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UploadScreen()),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
          child: SfSearchBar(hint: 'Search 12 documents…', onTap: () {}),
        ),
        // Content-sized so the pills grow with the text rather than
        // overflowing a fixed rail height.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            children: [
              for (var i = 0; i < demoLibraryFilters.length; i++)
                _FilterPill(
                  label: demoLibraryFilters[i].label,
                  count: demoLibraryFilters[i].count,
                  active: i == filter,
                  isLast: i == demoLibraryFilters.length - 1,
                  onTap: () =>
                      ref.read(materialsFilterProvider.notifier).update(i),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: items.isEmpty
              ? _EmptyLibrary(
                  onUpload: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UploadScreen()),
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

class _MaterialRow extends StatelessWidget {
  const _MaterialRow({required this.material});

  final StudyMaterial material;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final accent = material.accent.color(context);

    return SfCard(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SummariesScreen()),
      ),
      child: Row(
        children: [
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

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onUpload});

  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    return Center(
      child: Padding(
        // Offsets the centred empty state above the pill so it reads as
        // vertically centred in the space the user can actually see.
        padding: EdgeInsets.fromLTRB(
            22, 0, 22, sfNavContentInset(context, extra: 0)),
        child: SfCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SoftIconTile(
                icon: Icons.description_outlined,
                color: context.scheme.primary,
                background: sf.indigoSoft,
                width: 56,
                height: 56,
                radius: 18,
                iconSize: 26,
              ),
              const SizedBox(height: 12),
              Text(
                'Nothing here yet',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: sf.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Upload a PDF or paste your notes to begin.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: sf.ink3),
              ),
              const SizedBox(height: 14),
              SfButton(
                'Upload',
                size: SfButtonSize.sm,
                icon: Icons.file_upload_outlined,
                onPressed: onUpload,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
