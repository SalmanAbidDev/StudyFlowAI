// lib/features/profile/account_screen.dart
//
// The signed-in identity. The email is shown but not editable — changing it in
// Supabase means a confirmation round trip to both addresses, which is a
// different feature from "what am I signed in as".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import 'profile_view_model.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sf = context.sf;
    final scheme = context.scheme;
    final email = ref.watch(accountEmailProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
              child: Row(
                children: [
                  SfIconButton(
                    icon: Icons.arrow_back_rounded,
                    size: 38,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Account',
                      style: AppTextStyles.displayL
                          .copyWith(fontSize: 28, color: sf.ink),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
                children: [
                  SfEyebrow('Signed in as', color: sf.ink3),
                  const SizedBox(height: 10),
                  SfCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        SoftIconTile(
                          icon: Icons.alternate_email_rounded,
                          color: scheme.primary,
                          background: sf.indigoSoft,
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
                                email ?? 'Not signed in',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppTextStyles.fontUi,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                  color: sf.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              // Says why it is fixed, rather than leaving a
                              // greyed-out field the user keeps tapping.
                              Text(
                                'Your email cannot be changed here.',
                                style:
                                    TextStyle(fontSize: 12, color: sf.ink3),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.lock_outline_rounded,
                            size: 16, color: sf.ink4),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SfEyebrow('Security', color: sf.ink3),
                  const SizedBox(height: 10),
                  SfCard(
                    padding: EdgeInsets.zero,
                    clip: true,
                    child: InkWell(
                      onTap: () => showSfSheet<void>(
                        context,
                        (_) => const _PasswordSheet(),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Icon(Icons.key_outlined,
                                  size: 16, color: sf.ink),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Change password',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: sf.ink,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                size: 18, color: sf.ink4),
                          ],
                        ),
                      ),
                    ),
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

/// Two fields and a save. A sheet rather than a screen: it is one small task,
/// and the app has no Dialogs (§6.1).
class _PasswordSheet extends ConsumerStatefulWidget {
  const _PasswordSheet();

  @override
  ConsumerState<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends ConsumerState<_PasswordSheet> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(passwordChangeProvider.notifier).submit(
          password: _password.text,
          confirmation: _confirm.text,
        );
    if (!ok || !mounted) return;

    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Password changed.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final state = ref.watch(passwordChangeProvider);

    return SfSheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Change password',
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 20,
                    letterSpacing: -0.5,
                    color: sf.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'You will stay signed in on this device.',
                  style: TextStyle(fontSize: 13, color: sf.ink3),
                ),
              ],
            ),
          ),
          SfField(
            controller: _password,
            hint: 'New password',
            icon: Icons.lock_outline_rounded,
            obscure: true,
          ),
          const SizedBox(height: 8),
          SfField(
            controller: _confirm,
            hint: 'Repeat it',
            icon: Icons.lock_outline_rounded,
            obscure: true,
          ),
          if (state.error case final error?) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 16, color: sf.coralInk),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: sf.coralInk,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          SfButton(
            'Save password',
            size: SfButtonSize.lg,
            expand: true,
            busy: state.saving,
            onPressed: state.saving ? null : _submit,
          ),
        ],
      ),
    );
  }
}
