// Smoke tests for the StudyFlow AI UI build.
//
// Note on pumping: the Flow orb and the skeleton loaders run indefinitely
// repeating animations by design, so `pumpAndSettle` can never settle here.
// These tests advance frames explicitly instead.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_study_helper/main.dart';
import 'package:ai_study_helper/screens/app_shell.dart';
import 'package:ai_study_helper/screens/auth_screen.dart';
import 'package:ai_study_helper/screens/chat_screen.dart';
import 'package:ai_study_helper/screens/components_screen.dart';
import 'package:ai_study_helper/screens/flashcards_screen.dart';
import 'package:ai_study_helper/screens/onboarding_screen.dart';
import 'package:ai_study_helper/screens/premium_screen.dart';
import 'package:ai_study_helper/screens/quiz_result_screen.dart';
import 'package:ai_study_helper/screens/quiz_screen.dart';
import 'package:ai_study_helper/screens/splash_screen.dart';
import 'package:ai_study_helper/screens/summaries_screen.dart';
import 'package:ai_study_helper/screens/upload_screen.dart';
import 'package:ai_study_helper/theme/theme.dart';
import 'package:ai_study_helper/widgets/widgets.dart';

/// Give every test an iPhone-sized surface — these are phone layouts, and the
/// default 800x600 test window is the wrong shape for them.
void _usePhoneSurface(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

/// A small Android phone. Plenty of devices report a width in the 340–360dp
/// range, and side-by-side cards get proportionally narrower there — which is
/// where labels sized against a 390dp reference start to overflow.
const _narrowPhone = Size(340, 760);

/// Advance a fixed number of frames — enough for a route transition to finish.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

void main() {
  testWidgets('splash shows the brand, then advances to onboarding',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(const StudyFlowApp());

    expect(find.text('StudyFlow'), findsOneWidget);
    expect(find.text('Your AI study companion'), findsOneWidget);

    // Splash auto-advances after ~1.9s.
    await tester.pump(const Duration(seconds: 2));
    await _settle(tester);

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('AI summaries from any material.'), findsOneWidget);
  });

  testWidgets('onboarding pages through to auth, and auth enters the shell',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(const StudyFlowApp());
    await tester.pump(const Duration(seconds: 2));
    await _settle(tester);

    for (final title in [
      'Flashcards that learn how you forget.',
      'A study plan that bends around your week.',
      'The best students study unlimited.',
    ]) {
      await tester.tap(find.text('Continue'));
      await _settle(tester);
      expect(find.text(title), findsOneWidget);
    }

    await tester.tap(find.text('Get Started'));
    await _settle(tester);
    expect(find.byType(AuthScreen), findsOneWidget);

    await tester.tap(find.text('Sign in'));
    await _settle(tester);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.text('Morning, Alex 👋'), findsOneWidget);
  });

  testWidgets('tab bar switches between the shell destinations',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await _settle(tester);

    expect(find.byType(FloatingNavBar), findsOneWidget);

    await tester.tap(find.text('Materials'));
    await _settle(tester);
    expect(find.text('Stereochemistry & Chirality'), findsWidgets);

    await tester.tap(find.text('Planner'));
    await _settle(tester);
    expect(find.text('May 6 · 4h 15m planned today'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await _settle(tester);
    expect(find.text('Alex Morgan'), findsOneWidget);
  });

  testWidgets('quiz reveals the answer on tap and scores the run',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await _settle(tester);

    // Home → Quiz quick action.
    await tester.tap(find.text('Quiz'));
    await _settle(tester);
    expect(find.text('Which statement about diastereomers is correct?'),
        findsOneWidget);

    // Answering reveals the explanation.
    await tester.tap(
      find.text('They are stereoisomers that are not mirror images'),
    );
    await _settle(tester);
    expect(find.text('EXPLANATION'), findsOneWidget);

    // Walk to the end and land on the result screen.
    await tester.tap(find.text('Next question'));
    await _settle(tester);
    await tester.tap(find.text('Next question'));
    await _settle(tester);
    await tester.tap(find.text('See results'));
    await _settle(tester);

    expect(find.text('SCORE'), findsOneWidget);
  });

  testWidgets('flashcards flip to reveal the answer', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await _settle(tester);

    await tester.tap(find.text('Flashcards'));
    await _settle(tester);

    expect(find.text('What defines a chiral molecule?'), findsOneWidget);
    expect(find.text('Answer'), findsNothing);

    await tester.tap(find.text('What defines a chiral molecule?'));
    await _settle(tester);

    expect(find.text('Answer'), findsOneWidget);
  });

  testWidgets('chat answers a suggested prompt with a scripted reply',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));
    await _settle(tester);

    await tester.tap(find.text('Quiz me on this'));
    await tester.pump();

    // The scripted reply arrives after the simulated 1.4s latency; settling
    // also lets the transcript scroll the new bubble into view.
    await tester.pump(const Duration(milliseconds: 1500));
    await _settle(tester);

    expect(
      find.textContaining("I'll pull 10 questions from chapter 4"),
      findsOneWidget,
    );
  });

  // Every screen, in both brightnesses. Any overflow or layout assertion in
  // one of these fails the test, which is the point.
  group('renders without layout errors', () {
    final screens = <String, Widget Function()>{
      'splash': SplashScreen.new,
      'onboarding': OnboardingScreen.new,
      'auth': AuthScreen.new,
      'shell/home': AppShell.new,
      'shell/materials': () => const AppShell(initialPage: ShellPage.materials),
      'shell/planner': () => const AppShell(initialPage: ShellPage.planner),
      'shell/profile': () => const AppShell(initialPage: ShellPage.profile),
      'shell/exams': () => const AppShell(initialPage: ShellPage.exams),
      'shell/analytics': () => const AppShell(initialPage: ShellPage.analytics),
      'upload': UploadScreen.new,
      'chat': ChatScreen.new,
      'summaries': SummariesScreen.new,
      'flashcards': FlashcardsScreen.new,
      'quiz': QuizScreen.new,
      'quizResult': () => const QuizResultScreen(
            correct: 8,
            total: 10,
            elapsedSeconds: 402,
            missed: ['Q3 · Assigning R/S priority', 'Q7 · Meso compounds'],
          ),
      'premium': PremiumScreen.new,
      'components': ComponentsScreen.new,
    };

    for (final brightness in Brightness.values) {
      for (final entry in screens.entries) {
        testWidgets('${entry.key} · ${brightness.name}', (tester) async {
          _usePhoneSurface(tester);
          await tester.pumpWidget(
            MaterialApp(
              theme: brightness == Brightness.dark
                  ? AppTheme.dark
                  : AppTheme.light,
              home: entry.value(),
            ),
          );
          await _settle(tester);
          expect(tester.takeException(), isNull);
        });
      }
    }

    // Text-driven sizing is the main source of overflow: the test font's
    // metrics are not the device's, so a box that "just fits" here can still
    // clip on hardware. Re-render at larger text scales, and on a narrower
    // phone, to flush out anything that hard-codes room for text.
    for (final scale in [1.15, 1.3]) {
      for (final entry in screens.entries) {
        testWidgets('${entry.key} · textScale $scale', (tester) async {
          _usePhoneSurface(tester);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery.withClampedTextScaling(
                minScaleFactor: scale,
                maxScaleFactor: scale,
                child: child!,
              ),
              home: entry.value(),
            ),
          );
          await _settle(tester);
          expect(tester.takeException(), isNull);
        });
      }
    }

    for (final entry in screens.entries) {
      testWidgets('${entry.key} · narrow phone', (tester) async {
        _usePhoneSurface(tester, size: _narrowPhone);
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.light, home: entry.value()),
        );
        await _settle(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
