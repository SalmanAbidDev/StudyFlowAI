// lib/features/auth/auth_screen.dart
//
// Real Supabase email/password auth. The one screen covers both signing in
// and creating an account; `authModeProvider` decides which.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../shell/app_shell.dart';
import 'auth_view_model.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

/// Stateful only for the field controllers; every flag is a provider.
class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthMode mode) async {
    final ok = await ref.read(authControllerProvider.notifier).submit(
          mode: mode,
          email: _email.text,
          password: _password.text,
          fullName: _name.text,
        );
    if (!ok || !mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
      (route) => false,
    );
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (email.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter your email address first.')),
      );
      return;
    }
    await ref.read(authRepositoryProvider).sendPasswordReset(email);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Reset link sent to $email.')),
    );
  }

  void _socialUnavailable(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$provider sign-in needs the provider enabled in the Supabase '
          'dashboard first.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;
    final obscure = ref.watch(passwordObscuredProvider);
    final mode = ref.watch(authModeProvider);
    final request = ref.watch(authControllerProvider);
    final isSignUp = mode == AuthMode.signUp;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SfIconButton(
                  icon: Icons.arrow_back_rounded,
                  size: 36,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 8),
                children: [
                  const SfLogo(size: 26),
                  const SizedBox(height: 28),
                  Text(
                    isSignUp
                        ? 'Start your\nstudy streak.'
                        : "Welcome back.\nLet's keep the streak.",
                    style: AppTextStyles.displayL.copyWith(
                      fontSize: 34,
                      letterSpacing: -1.2,
                      height: 1.05,
                      color: sf.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isSignUp
                        ? 'Create an account to sync across your devices.'
                        : 'Sign in to pick up where you left off.',
                    style: TextStyle(fontSize: 14, color: sf.ink3),
                  ),
                  const SizedBox(height: 28),
                  if (isSignUp) ...[
                    SfField(
                      controller: _name,
                      icon: Icons.person_outline_rounded,
                      hint: 'Full name',
                      keyboardType: TextInputType.name,
                    ),
                    const SizedBox(height: 12),
                  ],
                  SfField(
                    controller: _email,
                    icon: Icons.mail_outline_rounded,
                    hint: 'Email',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  SfField(
                    controller: _password,
                    icon: Icons.lock_outline_rounded,
                    hint: 'Password',
                    obscure: obscure,
                    trailingIcon: obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    onTrailingTap:
                        ref.read(passwordObscuredProvider.notifier).toggle,
                  ),
                  const SizedBox(height: 10),
                  if (!isSignUp)
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: _resetPassword,
                        child: Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ),
                  if (request.hasError) ...[
                    const SizedBox(height: 14),
                    _AuthError(message: '${request.error}'),
                  ],
                  const SizedBox(height: 18),
                  SfButton(
                    isSignUp ? 'Create account' : 'Sign in',
                    size: SfButtonSize.lg,
                    expand: true,
                    trailingIcon: Icons.arrow_forward_rounded,
                    busy: request.isLoading,
                    onPressed: () => _submit(mode),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: Divider(color: scheme.outline)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: SfEyebrow('or', color: sf.ink4, tracking: 1),
                      ),
                      Expanded(child: Divider(color: scheme.outline)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SocialButton(
                    label: 'Continue with Apple',
                    background: context.isDark ? Colors.white : Colors.black,
                    foreground: context.isDark ? Colors.black : Colors.white,
                    onTap: () => _socialUnavailable('Apple'),
                    child: Icon(
                      Icons.apple,
                      size: 22,
                      color: context.isDark ? Colors.black : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SocialButton(
                    label: 'Continue with Google',
                    background: scheme.surface,
                    foreground: scheme.onSurface,
                    bordered: true,
                    onTap: () => _socialUnavailable('Google'),
                    child: const GoogleGlyph(size: 20),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
              child: GestureDetector(
                onTap: () => ref.read(authModeProvider.notifier).update(
                      isSignUp ? AuthMode.signIn : AuthMode.signUp,
                    ),
                child: Text.rich(
                  TextSpan(
                    text: isSignUp
                        ? 'Already have an account? '
                        : 'New to StudyFlow? ',
                    style: TextStyle(fontSize: 13, color: sf.ink3),
                    children: [
                      TextSpan(
                        text: isSignUp ? 'Sign in' : 'Create an account',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline failure under the form — a snackbar would be gone before someone
/// finishes reading why their password was rejected.
class _AuthError extends StatelessWidget {
  const _AuthError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: sf.coralSoft,
        borderRadius: AppRadius.brMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: sf.coralInk),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: sf.coralInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.child,
    required this.onTap,
    this.bordered = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Widget child;
  final VoidCallback onTap;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadius.brMd,
          border:
              bordered ? Border.all(color: context.scheme.outline) : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.brMd,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.brMd,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                child,
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontUi,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: foreground,
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
