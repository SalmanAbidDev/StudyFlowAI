// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';

import '../app/theme_controller.dart';
import '../theme/theme.dart';
import '../widgets/widgets.dart';
import 'app_shell.dart';
import 'components_screen.dart';
import 'premium_screen.dart';
import 'splash_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;

    return ListView(
      padding: const EdgeInsets.only(bottom: kFloatingNavHeight + 24),
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
                        initials: 'AM',
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
                          'Alex Morgan',
                          style: AppTextStyles.heading.copyWith(
                            fontSize: 22,
                            letterSpacing: -0.5,
                            color: sf.ink,
                          ),
                        ),
                        Text(
                          'alex.morgan@uni.edu',
                          style: TextStyle(fontSize: 13, color: sf.ink3),
                        ),
                        const SizedBox(height: 6),
                        const SfChip(
                          'Pro · Renewal Aug 12',
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
                          onTap: () =>
                              AppShellScope.of(context).go(ShellPage.analytics),
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
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              for (final a in <({
                IconData icon,
                String name,
                String meta,
                Color color,
                bool earned
              })>[
                (
                  icon: Icons.local_fire_department_rounded,
                  name: 'Hot streak',
                  meta: '10 days',
                  color: sf.coral,
                  earned: true
                ),
                (
                  icon: Icons.emoji_events_outlined,
                  name: 'First quiz',
                  meta: 'Score 100%',
                  color: sf.amber,
                  earned: true
                ),
                (
                  icon: Icons.style_outlined,
                  name: 'Card master',
                  meta: '300 cards',
                  color: sf.violet,
                  earned: true
                ),
                (
                  icon: Icons.my_location_rounded,
                  name: 'Sniper',
                  meta: '90% accuracy',
                  color: scheme.primary,
                  earned: false
                ),
              ])
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
                    detail: themeModeLabel(themeModeNotifier.value),
                    onTap: _pickTheme,
                  ),
                  _SettingsRow(
                    icon: Icons.show_chart_rounded,
                    label: 'Insights & analytics',
                    detail: 'Focus score, subject split',
                    onTap: () =>
                        AppShellScope.of(context).go(ShellPage.analytics),
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
                heading: 'Connections',
                rows: [
                  _SettingsRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Calendar',
                    detail: 'Google · Connected',
                    onTap: () {},
                  ),
                  _SettingsRow(
                    icon: Icons.apple,
                    label: 'Apple ID',
                    detail: 'Linked',
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
                      MaterialPageRoute(
                          builder: (_) => const PremiumScreen()),
                    ),
                  ),
                  _SettingsRow(
                    icon: Icons.shield_outlined,
                    label: 'Privacy & data',
                    onTap: () {},
                  ),
                  _SettingsRow(
                    icon: Icons.science_outlined,
                    label: 'Component library',
                    detail: 'Design system reference',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ComponentsScreen()),
                    ),
                  ),
                  _SettingsRow(
                    icon: Icons.logout_rounded,
                    label: 'Sign out',
                    danger: true,
                    onTap: _confirmSignOut,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickTheme() async {
    final chosen = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in ThemeMode.values)
              ListTile(
                leading: Icon(switch (mode) {
                  ThemeMode.system => Icons.brightness_auto_outlined,
                  ThemeMode.light => Icons.light_mode_outlined,
                  ThemeMode.dark => Icons.dark_mode_outlined,
                }),
                title: Text(themeModeLabel(mode)),
                trailing: themeModeNotifier.value == mode
                    ? Icon(Icons.check_rounded, color: context.scheme.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(mode),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (chosen == null) return;
    themeModeNotifier.value = chosen;
    if (mounted) setState(() {});
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          "You'll be taken back to the start of the flow.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.sf.coralInk,
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
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
