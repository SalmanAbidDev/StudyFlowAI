// Smoke tests for the StudyFlow AI UI build.
//
// Note on pumping: the Flow orb and the skeleton loaders run indefinitely
// repeating animations by design, so `pumpAndSettle` can never settle here.
// These tests advance frames explicitly instead.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_study_helper/app/app.dart';
import 'package:ai_study_helper/app/theme_mode_view_model.dart';
import 'package:ai_study_helper/core/theme/theme.dart';
import 'package:ai_study_helper/data/supabase_providers.dart';
import 'package:ai_study_helper/features/auth/auth_view_model.dart';
import 'package:ai_study_helper/core/widgets/widgets.dart';
import 'package:ai_study_helper/features/analytics/analytics_screen.dart';
import 'package:ai_study_helper/features/auth/auth_screen.dart';
import 'package:ai_study_helper/features/exams/exams_screen.dart';
import 'package:ai_study_helper/features/chat/chat_screen.dart';
import 'package:ai_study_helper/features/components/components_screen.dart';
import 'package:ai_study_helper/features/flashcards/flashcards_screen.dart';
import 'package:ai_study_helper/features/onboarding/onboarding_screen.dart';
import 'package:ai_study_helper/features/premium/premium_screen.dart';
import 'package:ai_study_helper/features/quiz/quiz_result_screen.dart';
import 'package:ai_study_helper/features/quiz/quiz_screen.dart';
import 'package:ai_study_helper/features/shell/app_shell.dart';
import 'package:ai_study_helper/features/shell/shell_view_model.dart';
import 'package:ai_study_helper/features/splash/splash_screen.dart';
import 'package:ai_study_helper/features/summaries/summaries_screen.dart';
import 'package:ai_study_helper/features/upload/upload_screen.dart';

import 'package:ai_study_helper/core/preferences.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_preferences.dart';
import 'fakes/fake_repositories.dart';

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

/// Every widget under test needs a ProviderScope above it.
///
/// The auth repository is always faked: overriding at that seam means no test
/// has to initialize the Supabase singleton, so the suite stays hermetic and
/// offline. Pass [shellPage] to seed the shell onto a page other than Home,
/// and [signedIn] to start with a session.
///
/// [builder] is threaded through to MaterialApp for the text-scale sweep.
/// Takes the child rather than returning the override list, because
/// flutter_riverpod does not export the `Override` type — there is no way to
/// name it for a `List<Override>` return.
Widget _scope({
  required Widget child,
  ShellPage? shellPage,
  bool signedIn = false,
  Map<String, String>? prefs,
}) {
  return ProviderScope(
    overrides: [
      preferencesProvider.overrideWithValue(FakePreferencesStore(prefs)),
      authRepositoryProvider
          .overrideWithValue(FakeAuthRepository(signedIn: signedIn)),
      // The data layer is faked wholesale. `currentUserIdProvider` normally
      // reads the Supabase client, which does not exist here.
      currentUserIdProvider.overrideWithValue('test-user'),
      libraryRepositoryProvider.overrideWithValue(FakeLibraryRepository()),
      plannerRepositoryProvider.overrideWithValue(FakePlannerRepository()),
      studyRepositoryProvider.overrideWithValue(FakeStudyRepository()),
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      analyticsRepositoryProvider.overrideWithValue(FakeAnalyticsRepository()),
      chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
      storageRepositoryProvider.overrideWithValue(FakeStorageRepository()),
      if (shellPage != null)
        initialShellPageProvider.overrideWithValue(shellPage),
    ],
    child: child,
  );
}

Widget _app(
  Widget home, {
  ThemeData? theme,
  ShellPage? shellPage,
  TransitionBuilder? builder,
  bool signedIn = false,
  Map<String, String>? prefs,
}) {
  return _scope(
    shellPage: shellPage,
    signedIn: signedIn,
    prefs: prefs,
    child: MaterialApp(
      theme: theme ?? AppTheme.light,
      builder: builder,
      home: home,
    ),
  );
}

/// The real app widget, which brings its own MaterialApp.
Widget _wholeApp({bool signedIn = false, Map<String, String>? prefs}) =>
    _scope(signedIn: signedIn, prefs: prefs, child: const StudyFlowApp());

void main() {
  testWidgets('splash shows the brand, then advances to onboarding',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_wholeApp());

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
    await tester.pumpWidget(_wholeApp());
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

    // Credentials are required now — the form rejects an empty submit rather
    // than walking straight into the shell.
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'alex.morgan@uni.edu',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'studyflow',
    );

    await tester.tap(find.text('Sign in'));
    await _settle(tester);
    expect(find.byType(AppShell), findsOneWidget);
    // The greeting is time-of-day dependent, so match the name, not the whole
    // string — otherwise the suite passes only before noon.
    expect(find.textContaining('Alex 👋'), findsOneWidget);
  });

  testWidgets('an empty sign-in is rejected instead of entering the shell',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const AuthScreen()));
    await _settle(tester);

    await tester.tap(find.text('Sign in'));
    await _settle(tester);

    expect(find.text('Enter your email and password.'), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });

  testWidgets('a stored session skips onboarding and opens the shell',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const SplashScreen(), signedIn: true));

    await tester.pump(const Duration(seconds: 2));
    await _settle(tester);

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('tab bar switches between the shell destinations',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const AppShell()));
    await _settle(tester);

    expect(find.byType(FloatingNavBar), findsOneWidget);

    await tester.tap(find.text('Materials'));
    await _settle(tester);
    expect(find.text('Stereochemistry & Chirality'), findsWidgets);

    await tester.tap(find.text('Planner'));
    await _settle(tester);
    expect(find.text('Stereochem · Read Ch 4'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await _settle(tester);
    expect(find.text('Alex Morgan'), findsOneWidget);
  });

  // The layout sweep cannot reach a bottom sheet — it is not built until
  // something taps it open.
  testWidgets('the appearance sheet opens and applies a theme',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const AppShell(), shellPage: ShellPage.profile));
    await _settle(tester);

    await tester.tap(find.text('Appearance'));
    await _settle(tester);

    expect(find.text('How StudyFlow looks'), findsOneWidget);
    for (final label in ['System', 'Light', 'Dark']) {
      expect(find.text(label), findsWidgets);
    }
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Follows your device setting'));
    await _settle(tester);

    // Sheet dismissed, and the Appearance row reflects the choice.
    expect(find.text('How StudyFlow looks'), findsNothing);
    expect(find.text('System'), findsOneWidget);
  });

  // System back at the shell root. `popRoute` is what the OS back button
  // triggers, so this exercises the real path rather than a tapped widget.
  testWidgets('system back returns to Home before offering to exit',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(
      _app(const AppShell(), shellPage: ShellPage.profile),
    );
    await _settle(tester);
    expect(find.text('Alex Morgan'), findsOneWidget);

    // Off Home: back unwinds the tab, and must not offer to close.
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.text('Close StudyFlow?'), findsNothing);
    expect(find.textContaining('Alex 👋'), findsOneWidget);

    // On Home: back asks first.
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.text('Close StudyFlow?'), findsOneWidget);

    // Cancelling leaves the app exactly where it was.
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(find.text('Close StudyFlow?'), findsNothing);
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('exams and insights open as routes, over the tab bar',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const AppShell()));
    await _settle(tester);

    // Home → Next exam card. It starts below the fold, and a ListView builds
    // lazily even with explicit children, so it has to be scrolled into
    // existence rather than just into view.
    await tester.scrollUntilVisible(
      find.text('Organic Chem Final'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await _settle(tester);
    await tester.tap(find.text('Organic Chem Final'));
    await _settle(tester);

    expect(find.byType(ExamsScreen), findsOneWidget);
    // A pushed route covers the shell, so its nav bar is gone.
    expect(find.byType(FloatingNavBar), findsNothing);

    // System back pops the route rather than leaving the app.
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.byType(ExamsScreen), findsNothing);
    expect(find.byType(FloatingNavBar), findsOneWidget);
  });

  testWidgets('a stored theme is applied on launch', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(
      _wholeApp(prefs: {ThemeModeViewModel.storageKey: 'dark'}),
    );
    await _settle(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('picking a theme writes it to preferences', (tester) async {
    _usePhoneSurface(tester);
    final store = FakePreferencesStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [preferencesProvider.overrideWithValue(store)],
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            home: TextButton(
              onPressed: () =>
                  ref.read(themeModeProvider.notifier).select(ThemeMode.dark),
              child: Text(themeModeLabel(ref.watch(themeModeProvider))),
            ),
          ),
        ),
      ),
    );

    expect(find.text('System'), findsOneWidget);
    expect(store.getString(ThemeModeViewModel.storageKey), isNull);

    await tester.tap(find.byType(TextButton));
    await tester.pump();

    expect(find.text('Dark'), findsOneWidget);
    expect(store.getString(ThemeModeViewModel.storageKey), 'dark');
  });

  testWidgets('the sign-out dialog can be dismissed without signing out',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(
      _app(const AppShell(), shellPage: ShellPage.profile, signedIn: true),
    );
    await _settle(tester);

    // The row is the last item on a long settings list.
    await tester.ensureVisible(find.text('Sign out'));
    await _settle(tester);
    await tester.tap(find.text('Sign out'));
    await _settle(tester);

    expect(find.text('Sign out?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Cancel'));
    await _settle(tester);

    // Dialog gone, still on Profile — the hero has scrolled away, so assert on
    // the settings row rather than the name — and still signed in.
    expect(find.text('Sign out?'), findsNothing);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(AuthScreen), findsNothing);
  });

  testWidgets('quiz reveals the answer on tap and scores the run',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const AppShell()));
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

    // Walk to the end and land on the result screen. The fake quiz has two
    // questions, so one "Next" then "See results".
    await tester.tap(find.text('Next question'));
    await _settle(tester);
    await tester.tap(find.text('See results'));
    await _settle(tester);

    expect(find.text('SCORE'), findsOneWidget);
  });

  testWidgets('flashcards flip to reveal the answer', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const AppShell()));
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
    await tester.pumpWidget(_app(const ChatScreen()));
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
    /// Seeds the shell to open on [page] instead of Home.
    ({Widget Function() home, ShellPage? shellPage}) shellOn(ShellPage page) =>
        (home: AppShell.new, shellPage: page);

    ({Widget Function() home, ShellPage? shellPage}) plain(
      Widget Function() home,
    ) =>
        (home: home, shellPage: null);

    final screens = {
      'splash': plain(SplashScreen.new),
      'onboarding': plain(OnboardingScreen.new),
      'auth': plain(AuthScreen.new),
      'shell/home': plain(AppShell.new),
      'shell/materials': shellOn(ShellPage.materials),
      'shell/planner': shellOn(ShellPage.planner),
      'shell/profile': shellOn(ShellPage.profile),
      // Pushed routes now, not shell pages — render them directly.
      'exams': plain(ExamsScreen.new),
      'analytics': plain(AnalyticsScreen.new),
      'upload': plain(UploadScreen.new),
      'chat': plain(ChatScreen.new),
      'summaries': plain(SummariesScreen.new),
      'flashcards': plain(FlashcardsScreen.new),
      'quiz': plain(QuizScreen.new),
      'quizResult': plain(
        () => const QuizResultScreen(
          correct: 8,
          total: 10,
          elapsedSeconds: 402,
          missed: ['Q3 · Assigning R/S priority', 'Q7 · Meso compounds'],
        ),
      ),
      'premium': plain(PremiumScreen.new),
      'components': plain(ComponentsScreen.new),
    };

    for (final brightness in Brightness.values) {
      for (final entry in screens.entries) {
        testWidgets('${entry.key} · ${brightness.name}', (tester) async {
          _usePhoneSurface(tester);
          await tester.pumpWidget(
            _app(
              entry.value.home(),
              theme: brightness == Brightness.dark
                  ? AppTheme.dark
                  : AppTheme.light,
              shellPage: entry.value.shellPage,
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
            _app(
              entry.value.home(),
              shellPage: entry.value.shellPage,
              builder: (context, child) => MediaQuery.withClampedTextScaling(
                minScaleFactor: scale,
                maxScaleFactor: scale,
                child: child!,
              ),
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
          _app(entry.value.home(), shellPage: entry.value.shellPage),
        );
        await _settle(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
