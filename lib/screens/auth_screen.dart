// lib/screens/auth_screen.dart
//
// Sign-in. Nothing is authenticated — any tap on the primary CTA or a social
// button drops straight into the app shell.

import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../widgets/widgets.dart';
import 'app_shell.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController(text: 'alex.morgan@uni.edu');
  final _password = TextEditingController(text: 'studyflow');
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _enter() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;

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
                    "Welcome back.\nLet's keep the streak.",
                    style: AppTextStyles.displayL.copyWith(
                      fontSize: 34,
                      letterSpacing: -1.2,
                      height: 1.05,
                      color: sf.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to pick up where you left off.',
                    style: TextStyle(fontSize: 14, color: sf.ink3),
                  ),
                  const SizedBox(height: 28),
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
                    obscure: _obscure,
                    trailingIcon: _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    onTrailingTap: () => setState(() => _obscure = !_obscure),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {},
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
                  const SizedBox(height: 18),
                  SfButton(
                    'Sign in',
                    size: SfButtonSize.lg,
                    expand: true,
                    trailingIcon: Icons.arrow_forward_rounded,
                    onPressed: _enter,
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
                    onTap: _enter,
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
                    onTap: _enter,
                    child: const GoogleGlyph(size: 20),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
              child: Text.rich(
                TextSpan(
                  text: 'New to StudyFlow? ',
                  style: TextStyle(fontSize: 13, color: sf.ink3),
                  children: [
                    TextSpan(
                      text: 'Create an account',
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
          ],
        ),
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
