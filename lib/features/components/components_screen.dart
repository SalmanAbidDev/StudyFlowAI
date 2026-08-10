// lib/features/components/components_screen.dart
//
// Living reference for the design system. Not part of the product flow —
// reachable from Profile so the primitives can be eyeballed in both themes.

import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';

class ComponentsScreen extends StatelessWidget {
  const ComponentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  SfIconButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Component library',
                          style: AppTextStyles.heading.copyWith(
                            fontSize: 22,
                            letterSpacing: -0.5,
                            color: sf.ink,
                          ),
                        ),
                        SfMono('v1.0 · design system reference',
                            color: sf.ink3),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                children: [
                  _Section(
                    title: 'Buttons',
                    children: [
                      SfButton('Primary', onPressed: () {}),
                      SfButton('Secondary',
                          variant: SfButtonVariant.secondary,
                          onPressed: () {}),
                      SfButton('Soft',
                          variant: SfButtonVariant.soft, onPressed: () {}),
                      SfButton('Coral',
                          variant: SfButtonVariant.coral, onPressed: () {}),
                      SfButton('Emerald',
                          variant: SfButtonVariant.emerald,
                          icon: Icons.check_rounded,
                          onPressed: () {}),
                      SfButton('Ghost',
                          variant: SfButtonVariant.ghost,
                          trailingIcon: Icons.arrow_forward_rounded,
                          onPressed: () {}),
                    ],
                  ),
                  _Section(
                    title: 'Chips',
                    children: const [
                      SfChip('Indigo'),
                      SfChip('Lavender', tone: SfTone.lavender),
                      SfChip('Mastered',
                          tone: SfTone.emerald, icon: Icons.check_rounded),
                      SfChip('Streak',
                          tone: SfTone.coral,
                          icon: Icons.local_fire_department_rounded),
                      SfChip('Pro',
                          tone: SfTone.amber, icon: Icons.star_rounded),
                      SfChip('Default', tone: SfTone.neutral),
                    ],
                  ),
                  _Section(
                    title: 'Inputs',
                    stack: true,
                    children: const [
                      SfField(
                          icon: Icons.mail_outline_rounded,
                          hint: 'email@uni.edu'),
                      SfSearchBar(hint: 'Search materials'),
                    ],
                  ),
                  _Section(
                    title: 'Progress',
                    stack: true,
                    children: [
                      const SfProgress(value: 0.7),
                      SfProgress(value: 0.4, color: sf.coral),
                      Row(
                        children: [
                          for (final r in <({double v, Color c, String l})>[
                            (v: 0.8, c: sf.emerald, l: '80'),
                            (v: 0.45, c: scheme.primary, l: '45'),
                            (v: 0.6, c: sf.coral, l: '60'),
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: SfRing(
                                value: r.v,
                                size: 48,
                                color: r.c,
                                child: SfMono(r.l,
                                    size: 11,
                                    weight: FontWeight.w700,
                                    color: sf.ink),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  _Section(
                    title: 'Avatars',
                    children: [
                      SfAvatar(
                          initials: 'AM',
                          size: 40,
                          background: sf.brand,
                          foreground: Colors.white),
                      SfAvatar(
                          initials: 'MK',
                          size: 40,
                          background: sf.lavenderSoft,
                          foreground: sf.violetInk),
                      SfAvatar(
                          initials: 'JS',
                          size: 40,
                          background: sf.coralSoft,
                          foreground: sf.coralInk),
                      SfAvatar(
                          initials: 'RA',
                          size: 40,
                          background: sf.emeraldSoft,
                          foreground: sf.emeraldInk),
                    ],
                  ),
                  _Section(
                    title: 'Brand',
                    children: const [
                      SfLogo(size: 26),
                      FlowOrb(size: 28),
                      GoogleGlyph(size: 26),
                    ],
                  ),
                  _Section(
                    title: 'Loading skeleton',
                    stack: true,
                    children: const [
                      SfCard(
                        child: Row(
                          children: [
                            SfSkeleton(width: 36, height: 36, radius: 10),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FractionallySizedBox(
                                    widthFactor: 0.7,
                                    child: SfSkeleton(height: 10),
                                  ),
                                  SizedBox(height: 6),
                                  FractionallySizedBox(
                                    widthFactor: 0.4,
                                    child: SfSkeleton(height: 8),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  _Section(
                    title: 'Empty state',
                    stack: true,
                    children: [
                      SfCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            SoftIconTile(
                              icon: Icons.description_outlined,
                              color: scheme.primary,
                              background: sf.indigoSoft,
                              width: 56,
                              height: 56,
                              radius: 18,
                              iconSize: 26,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No materials yet',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: sf.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Upload a PDF or paste your notes to begin.',
                              style:
                                  TextStyle(fontSize: 12, color: sf.ink3),
                            ),
                            const SizedBox(height: 14),
                            SfButton(
                              'Upload',
                              size: SfButtonSize.sm,
                              icon: Icons.file_upload_outlined,
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  _Section(
                    title: 'Error / toast',
                    stack: true,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: sf.coralSoft,
                          borderRadius: AppRadius.brMd,
                          border: Border.all(
                              color: sf.coral.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded,
                                size: 18, color: sf.coral),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Couldn't reach Flow. Tap to retry.",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: sf.coralInk,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  _Section(
                    title: 'Modal',
                    stack: true,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: AppRadius.brLg,
                          border: Border.all(color: scheme.outline),
                          boxShadow: AppShadows.resolve(
                              AppShadows.lg, Theme.of(context).brightness),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delete deck?',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: sf.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "This deck has 24 cards. This can't be undone.",
                              style:
                                  TextStyle(fontSize: 12, color: sf.ink3),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: SfButton(
                                    'Cancel',
                                    variant: SfButtonVariant.secondary,
                                    size: SfButtonSize.sm,
                                    expand: true,
                                    onPressed: () {},
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SfButton(
                                    'Delete',
                                    variant: SfButtonVariant.coral,
                                    size: SfButtonSize.sm,
                                    expand: true,
                                    onPressed: () {},
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.stack = false,
  });

  final String title;
  final List<Widget> children;

  /// Lay the samples out in a column instead of a wrap.
  final bool stack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SfEyebrow(title, size: 10, color: context.sf.ink3),
          const SizedBox(height: 10),
          if (stack)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  children[i],
                ],
              ],
            )
          else
            Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}
