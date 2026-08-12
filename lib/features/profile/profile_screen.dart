// lib/features/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme_mode_view_model.dart';
import '../../core/navigation.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_screen.dart';
import '../auth/auth_view_model.dart';
import '../home/home_view_model.dart';
import '../premium/premium_screen.dart';
import '../shell/shell_view_model.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  /// Maps an achievement's stable code to its badge. Unknown codes still
  /// render — a badge added server-side shows up with a neutral icon rather
  /// than crashing an older build.
  static ({IconData icon, int accent}) _badge(String code) => switch (code) {
        'hot_streak' => (icon: Icons.local_fire_department_rounded, accent: 0),
        'quiz_ace' => (icon: Icons.emoji_events_outlined, accent: 1),
        'card_master' => (icon: Icons.style_outlined, accent: 2),
        'deep_focus' => (icon: Icons.my_location_rounded, accent: 3),
        _ => (icon: Icons.star_outline_rounded, accent: 3),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sf = context.sf;
    final scheme = context.scheme;
    final profile = ref.watch(profileProvider).value;
    final achievements = ref.watch(achievementsProvider).value ?? const [];
    final email = ref.watch(sessionProvider)?.user.email ?? '';
    final accents = [sf.coral, sf.amber, sf.violet, scheme.primary];

    return ListView(
      padding: EdgeInsets.only(bottom: sfNavContentInset(context)),
      children: [
        // Hero
        Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [sf.indigoSoft, sf.indigoSoft.withValues(alpha: 0)],
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SfAvatar(
                        initials: profile?.initials ?? '·',
                        size: 64,
                        background: sf.brand,
                        foreground: Colors.white,
                      ),
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: sf.amber,
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 3,
                            ),
                          ),
                          child: const Icon(Icons.star_rounded,
                              size: 11, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.displayName ?? 'Loading…',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.heading.copyWith(
                            fontSize: 22,
                            letterSpacing: -0.5,
                            color: sf.ink,
                          ),
                        ),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: sf.ink3),
                        ),
                        const SizedBox(height: 6),
                        SfChip(
                          (profile?.isPro ?? false) ? 'Pro' : 'Free plan',
                          icon: Icons.star_rounded,
                          small: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  for (final s in <({String label, String value, Color color})>[
                    (label: 'Streak', value: '12d', color: sf.coralInk),
                    (label: 'Studied', value: '124h', color: scheme.primary),
                    (label: 'Mastered', value: '342', color: sf.emeraldInk),
                  ]) ...[
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: SfCard(
                          radius: AppRadius.md,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 8),
                          onTap: () => ref
                              .read(shellPageProvider.notifier)
                              .go(ShellPage.analytics),
                          child: Column(
                            children: [
                              Text(
                                s.value,
                                style: TextStyle(
                                  fontFamily: AppTextStyles.fontUi,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.6,
                                  color: s.color,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                s.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: sf.ink3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // Achievements
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
          child: SectionHeader(
            'Achievements',
            action: 'View all',
            onAction: () {},
          ),
        ),
        // Content-sized, not a fixed strip height — see the note on Home's
        // recent-materials rail.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // Room for the card shadow — see Home's recent-materials rail.
          padding: const EdgeInsets.fromLTRB(
            22,
            AppShadows.smBleedTop,
            22,
            AppShadows.smBleedBottom,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              for (final a in achievements.map(
                (row) => (
                  icon: _badge(row.code).icon,
                  name: row.name,
                  meta: row.detail,
                  color: accents[_badge(row.code).accent],
                  earned: row.earned,
                ),
              ))
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Opacity(
                    opacity: a.earned ? 1 : 0.55,
                    child: SizedBox(
                      width: 120,
                      child: SfCard(
                        padding: const EdgeInsets.all(14),
                        radius: AppRadius.md + 2,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: a.earned
                                    ? LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          a.color,
                                          a.color.withValues(alpha: 0.7),
                                        ],
                                      )
                                    : null,
                                color: a.earned
                                    ? null
                                    : scheme.surfaceContainerHigh,
                                boxShadow: a.earned
                                    ? AppShadows.resolve(
                                        [
                                          BoxShadow(
                                            color: a.color
                                                .withValues(alpha: 0.33),
                                            blurRadius: 16,
                                            spreadRadius: -4,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                        Theme.of(context).brightness,
                                      )
                                    : null,
                              ),
                              child: Icon(
                                a.icon,
                                size: 20,
                                color: a.earned ? Colors.white : sf.ink4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              a.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.1,
                                color: sf.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              a.meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  TextStyle(fontSize: 10, color: sf.ink3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Settings
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingsGroup(
                heading: 'Preferences',
                rows: [
                  _SettingsRow(
                    icon: Icons.settings_outlined,
                    label: 'Account',
                    detail: 'Email, password',
                    onTap: () {},
                  ),
                  _SettingsRow(
                    icon: Icons.notifications_none_rounded,
                    label: 'Notifications',
                    detail: 'Daily reminders on',
                    onTap: () {},
                  ),
                  _SettingsRow(
                    icon: Icons.visibility_outlined,
                    label: 'Appearance',
                    detail: themeModeLabel(ref.watch(themeModeProvider)),
                    onTap: () => _pickTheme(context, ref),
                  ),
                  _SettingsRow(
                    icon: Icons.show_chart_rounded,
                    label: 'Insights & analytics',
                    detail: 'Focus score, subject split',
                    onTap: () => ref
                        .read(shellPageProvider.notifier)
                        .go(ShellPage.analytics),
                  ),
                  _SettingsRow(
                    icon: Icons.volume_up_outlined,
                    label: 'Sounds & haptics',
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingsGroup(
                heading: 'Account',
                rows: [
                  _SettingsRow(
                    icon: Icons.star_rounded,
                    label: 'Manage subscription',
                    onTap: () => Navigator.of(context).push(
                      sfModalRoute(
                          builder: (_) => const PremiumScreen()),
                    ),
                  ),
                  _SettingsRow(
                    icon: Icons.shield_outlined,
                    label: 'Privacy & data',
                    onTap: () {},
                  ),
                  _SettingsRow(
                    icon: Icons.logout_rounded,
                    label: 'Sign out',
                    danger: true,
                    onTap: () => _confirmSignOut(context, ref),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickTheme(BuildContext context, WidgetRef ref) async {
    final chosen = await _showSfSheet<ThemeMode>(
      context,
      (_) => const _ThemeSheet(),
    );

    // No rebuild to schedule by hand: the Appearance row watches
    // themeModeProvider, so writing it is enough.
    if (chosen != null) ref.read(themeModeProvider.notifier).select(chosen);
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    // A sheet rather than a dialog: it matches the appearance picker, and a
    // destructive confirmation reads better rising from the same edge the rest
    // of the app's decisions come from.
    final confirmed = await _showSfSheet<bool>(
      context,
      (_) => const _SignOutSheet(),
    );

    // Null when dismissed by tapping the scrim or swiping down.
    if (confirmed != true) return;

    // Clear the session first, then unwind the stack — navigating first would
    // leave the shell briefly rendering with a token that is about to die.
    await ref.read(authControllerProvider.notifier).signOut();
    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      sfRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }
}

// ─── Sheets ───────────────────────────────────────────────────────────────

/// Opens a sheet built from the design tokens rather than Material's defaults.
///
/// The transparent background is what lets the shell own its corners, border
/// and grabber — and it is also why `showDragHandle` must be off: the theme
/// enables it globally, and Flutter paints that handle *above* the builder, so
/// against a transparent background it floats on the scrim beside ours.
Future<T?> _showSfSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.textPrimary.withValues(alpha: 0.45),
    showDragHandle: false,
    builder: builder,
  );
}

/// The chrome every sheet in this app shares: canvas background, rounded top,
/// hairline border, grabber, and bottom safe-area padding.
class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Container(
      decoration: BoxDecoration(
        // The canvas colour, so cards inside sit on it as they do on any other
        // screen. Using `surface` here would make them vanish into their own
        // background.
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Destructive confirmation. Coral throughout, because the accent is what
/// tells you this one is not routine.
class _SignOutSheet extends StatelessWidget {
  const _SignOutSheet();

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;

    return _SheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Centred rather than left-aligned like the picker: this is one
          // focused question, not a list to scan.
          Center(
            child: SoftIconTile(
              icon: Icons.logout_rounded,
              color: sf.coralInk,
              background: sf.coralSoft,
              width: 56,
              height: 56,
              radius: 18,
              iconSize: 26,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Sign out?',
            textAlign: TextAlign.center,
            style: AppTextStyles.heading.copyWith(
              fontSize: 20,
              letterSpacing: -0.5,
              color: sf.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "You'll need to sign in again to reach your library. Nothing is "
            'deleted.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTextStyles.fontUi,
              fontSize: 13,
              height: 1.45,
              color: sf.ink3,
            ),
          ),
          const SizedBox(height: 22),
          // Stacked rather than side by side: at a large text scale two
          // buttons in a Row would each be squeezed to a few characters.
          SfButton(
            'Sign out',
            variant: SfButtonVariant.coral,
            size: SfButtonSize.lg,
            expand: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 8),
          SfButton(
            'Cancel',
            variant: SfButtonVariant.ghost,
            size: SfButtonSize.lg,
            expand: true,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

// ─── Appearance sheet ─────────────────────────────────────────────────────

/// Theme picker. Built from the design tokens rather than `ListTile`, which
/// carries Material's own typography and would read as a different app.
class _ThemeSheet extends ConsumerWidget {
  const _ThemeSheet();

  static ({IconData icon, String blurb}) _detail(ThemeMode mode) =>
      switch (mode) {
        ThemeMode.system => (
            icon: Icons.brightness_auto_rounded,
            blurb: 'Follows your device setting',
          ),
        ThemeMode.light => (
            icon: Icons.light_mode_rounded,
            blurb: 'Bright surfaces, soft shadows',
          ),
        ThemeMode.dark => (
            icon: Icons.dark_mode_rounded,
            blurb: 'Dimmed for late sessions',
          ),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sf = context.sf;
    final current = ref.watch(themeModeProvider);

    return _SheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SfEyebrow('Appearance', color: sf.ink3),
                const SizedBox(height: 6),
                Text(
                  'How StudyFlow looks',
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 20,
                    letterSpacing: -0.5,
                    color: sf.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final mode in ThemeMode.values) ...[
            _ThemeOption(
              mode: mode,
              selected: current == mode,
              icon: _detail(mode).icon,
              blurb: _detail(mode).blurb,
              onTap: () => Navigator.of(context).pop(mode),
            ),
            if (mode != ThemeMode.values.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.selected,
    required this.icon,
    required this.blurb,
    required this.onTap,
  });

  final ThemeMode mode;
  final bool selected;
  final IconData icon;
  final String blurb;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? sf.indigoSoft : scheme.surface,
        borderRadius: AppRadius.brLg,
        // The selected row is carried by a brand-tinted border rather than a
        // fill alone, so it still reads in dark mode where the soft wash is
        // nearly the surface colour.
        border: Border.all(
          color: selected
              ? scheme.primary.withValues(alpha: 0.45)
              : scheme.outline,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.brLg,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.brLg,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                SoftIconTile(
                  icon: icon,
                  color: selected ? scheme.primary : sf.ink2,
                  background: selected
                      ? scheme.surface
                      : scheme.surfaceContainerHigh,
                  width: 40,
                  height: 40,
                  radius: 12,
                  iconSize: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        themeModeLabel(mode),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontUi,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: selected ? scheme.primary : sf.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        blurb,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontUi,
                          fontSize: 12,
                          color: sf.ink3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Reserving the tick's footprint whether or not it is shown
                // keeps the labels from shifting as the selection moves.
                SizedBox(
                  width: 22,
                  height: 22,
                  child: selected
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: context.isDark
                                ? AppColors.textPrimary
                                : Colors.white,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.heading, required this.rows});

  final String heading;
  final List<_SettingsRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: SfEyebrow(heading, color: context.sf.ink3),
        ),
        SfCard(
          padding: EdgeInsets.zero,
          clip: true,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, color: context.scheme.outline),
                rows[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.detail,
    this.danger = false,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;
    final tint = danger ? sf.coralInk : sf.ink;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    danger ? sf.coralSoft : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 16, color: tint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tint,
                    ),
                  ),
                  if (detail != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        detail!,
                        style: TextStyle(fontSize: 11, color: sf.ink3),
                      ),
                    ),
                ],
              ),
            ),
            if (!danger)
              Icon(Icons.chevron_right_rounded, size: 18, color: sf.ink4),
          ],
        ),
      ),
    );
  }
}
