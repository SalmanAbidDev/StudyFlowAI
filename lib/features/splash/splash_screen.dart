// lib/features/splash/splash_screen.dart
//
// The brand moment, and the app's routing decision: `Supabase.initialize`
// has already restored any stored session by the time this builds, so the
// choice of destination is synchronous — the delay is for the animation, not
// for the session.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_view_model.dart';
import '../onboarding/onboarding_screen.dart';
import '../shell/app_shell.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1900), () {
      if (!mounted) return;
      final signedIn = ref.read(isSignedInProvider);
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, animation, _) => FadeTransition(
            opacity: animation,
            // A returning user skips the value story and lands in the app.
            child: signedIn ? const AppShell() : const OnboardingScreen(),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final dark = context.isDark;
    final canvas =
        dark ? AppColors.backgroundDark : AppColors.background;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.45),
            radius: 0.95,
            colors: [
              dark ? const Color(0xFF1F1F4D) : AppColors.indigoSoft,
              canvas,
            ],
            stops: const [0, 0.7],
          ),
        ),
        child: SizedBox.expand(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SfMark(
                      size: 96,
                      radius: 28,
                      shadow: [
                        BoxShadow(
                          color: sf.brand.withValues(alpha: 0.6),
                          blurRadius: 50,
                          spreadRadius: -10,
                          offset: const Offset(0, 20),
                        ),
                      ],
                      glyphFraction: 0.5,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'StudyFlow',
                      style: AppTextStyles.displayXL.copyWith(
                        color: sf.ink,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your AI study companion',
                      style: TextStyle(
                        fontSize: 15,
                        letterSpacing: -0.1,
                        color: sf.ink3,
                      ),
                    ),
                    const SizedBox(height: 64),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        3,
                        (i) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.scheme.primary
                                .withValues(alpha: i == 1 ? 1 : 0.3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 60,
                child: Center(
                  child: SfMono(
                    'v1.0 · BUILT FOR STUDENTS',
                    size: 12,
                    color: sf.ink4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
