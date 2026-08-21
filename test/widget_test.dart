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
import 'package:ai_study_helper/core/config/ai_config.dart';
import 'package:ai_study_helper/core/startup_failure_app.dart';
import 'package:ai_study_helper/core/theme/theme.dart';
import 'package:ai_study_helper/data/repositories/ai_repository.dart';
import 'package:ai_study_helper/data/supabase_providers.dart';
import 'package:ai_study_helper/features/auth/auth_view_model.dart';
import 'package:ai_study_helper/core/widgets/widgets.dart';
import 'package:ai_study_helper/features/analytics/analytics_screen.dart';
import 'package:ai_study_helper/features/auth/auth_screen.dart';
import 'package:ai_study_helper/features/exams/exam_detail_screen.dart';
import 'package:ai_study_helper/features/exams/exam_editor_screen.dart';
import 'package:ai_study_helper/features/exams/exams_screen.dart';
import 'package:ai_study_helper/features/chat/chat_screen.dart';
import 'package:ai_study_helper/features/components/components_screen.dart';
import 'package:ai_study_helper/features/flashcards/flashcards_screen.dart';
import 'package:ai_study_helper/features/onboarding/onboarding_screen.dart';
import 'package:ai_study_helper/features/premium/premium_screen.dart';
import 'package:ai_study_helper/features/profile/account_screen.dart';
import 'package:ai_study_helper/features/profile/achievements_screen.dart';
import 'package:ai_study_helper/features/quiz/quiz_result_screen.dart';
import 'package:ai_study_helper/features/quiz/quiz_screen.dart';
import 'package:ai_study_helper/features/shell/app_shell.dart';
import 'package:ai_study_helper/features/shell/shell_view_model.dart';
import 'package:ai_study_helper/features/splash/splash_screen.dart';
import 'package:ai_study_helper/features/summaries/summaries_screen.dart';
import 'package:ai_study_helper/features/documents/document_screen.dart';
import 'package:ai_study_helper/features/upload/upload_screen.dart';
import 'package:ai_study_helper/features/upload/upload_view_model.dart';
import 'package:ai_study_helper/features/upload/paste_text_screen.dart';
import 'package:ai_study_helper/features/upload/url_view_model.dart';
import 'package:ai_study_helper/features/home/home_view_model.dart';
import 'package:ai_study_helper/features/materials/history_screen.dart';
import 'package:ai_study_helper/features/materials/materials_view_model.dart';
import 'package:ai_study_helper/features/materials/pick_material_screen.dart';
import 'package:ai_study_helper/features/planner/block_editor_screen.dart';
import 'package:ai_study_helper/features/planner/planner_view_model.dart';
import 'package:ai_study_helper/features/profile/profile_view_model.dart';
import 'package:ai_study_helper/features/categories/category_screen.dart';
import 'package:ai_study_helper/data/models/study_material.dart';
import 'package:ai_study_helper/data/models/subject.dart';

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
  bool emptyAccount = false,
  FakeLibraryRepository? library,
  FakeChatRepository? chat,
  FakeAiRepository? ai,
  FakeStudyRepository? study,
}) {
  return ProviderScope(
    overrides: [
      preferencesProvider.overrideWithValue(FakePreferencesStore(prefs)),
      authRepositoryProvider
          .overrideWithValue(FakeAuthRepository(signedIn: signedIn)),
      // The data layer is faked wholesale. `currentUserIdProvider` normally
      // reads the Supabase client, which does not exist here.
      currentUserIdProvider.overrideWithValue('test-user'),
      // A caller-supplied instance when the test needs to inspect what was
      // written to it afterwards.
      libraryRepositoryProvider.overrideWithValue(
        library ?? FakeLibraryRepository(empty: emptyAccount),
      ),
      plannerRepositoryProvider
          .overrideWithValue(FakePlannerRepository(empty: emptyAccount)),
      studyRepositoryProvider.overrideWithValue(
        study ?? FakeStudyRepository(empty: emptyAccount),
      ),
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      analyticsRepositoryProvider.overrideWithValue(FakeAnalyticsRepository()),
      // A caller-supplied instance survives a pumpWidget, which is how a test
      // reopens a screen against a transcript it already wrote.
      chatRepositoryProvider.overrideWithValue(chat ?? FakeChatRepository()),
      // No network, no key: the Edge Function seam is faked like every other
      // repository, so the suite stays hermetic.
      aiRepositoryProvider.overrideWithValue(ai ?? FakeAiRepository()),
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
  bool emptyAccount = false,
  FakeChatRepository? chat,
  FakeAiRepository? ai,
  FakeStudyRepository? study,
  FakeLibraryRepository? library,
}) {
  return _scope(
    shellPage: shellPage,
    signedIn: signedIn,
    prefs: prefs,
    emptyAccount: emptyAccount,
    chat: chat,
    ai: ai,
    study: study,
    library: library,
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

  testWidgets('achievements show the whole catalogue and View all opens it',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(
      _app(const AppShell(), shellPage: ShellPage.profile),
    );
    await _settle(tester);

    // The catalogue comes from the app, so the rail renders even though the
    // fake reports only one earned badge.
    expect(find.text('1 of 6 earned'), findsOneWidget);
    expect(find.text('Hot streak'), findsWidgets);

    await tester.tap(find.text('View all'));
    await _settle(tester);

    expect(find.byType(AchievementsScreen), findsOneWidget);
    // Earned and locked both listed.
    expect(find.text('Locked'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('materials search filters the library', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(
      _app(const AppShell(), shellPage: ShellPage.materials),
    );
    await _settle(tester);

    expect(find.text(kFakeMaterialTitle), findsOneWidget);
    expect(find.text('Monetary Policy Lecture'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'monetary');
    await _settle(tester);

    expect(find.text(kFakeMaterialTitle), findsNothing);
    expect(find.text('Monetary Policy Lecture'), findsOneWidget);

    // Matching the subject, not just the title.
    await tester.enterText(find.byType(TextField), 'organic');
    await _settle(tester);
    expect(find.text(kFakeMaterialTitle), findsOneWidget);
    expect(find.text('Monetary Policy Lecture'), findsNothing);

    // A query with no hits gets its own empty state, distinct from an empty
    // library.
    await tester.enterText(find.byType(TextField), 'zzzz');
    await _settle(tester);
    expect(find.text('No matches'), findsOneWidget);
    expect(find.text('Nothing here yet'), findsNothing);

    await tester.tap(find.text('Clear search'));
    await _settle(tester);
    expect(find.text(kFakeMaterialTitle), findsOneWidget);
  });

  testWidgets('long-pressing a material starts a selection', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(
      _app(const AppShell(), shellPage: ShellPage.materials),
    );
    await _settle(tester);

    // Nothing selected: no menu button, and search and pills are in place.
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    expect(find.byType(SfSearchBar), findsOneWidget);

    await tester.longPress(find.text(kFakeMaterialTitle));
    await _settle(tester);

    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    // Search and the subject pills fold away for the duration.
    expect(find.byType(SfSearchBar), findsNothing);

    // A second row joins the selection on a plain tap — no long-press needed
    // once the mode is running.
    await tester.tap(find.text('Monetary Policy Lecture'));
    await _settle(tester);
    expect(find.text('2 selected'), findsOneWidget);

    // And tapping a selected row again takes it back out.
    await tester.tap(find.text('Monetary Policy Lecture'));
    await _settle(tester);
    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('system back leaves a selection before it leaves the tab',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(
      _app(const AppShell(), shellPage: ShellPage.materials),
    );
    await _settle(tester);

    // Read the nav bar rather than the page: every tab stays mounted inside
    // the shell's IndexedStack, so finding a screen proves nothing about
    // which one is showing.
    SfNavTab activeTab() =>
        tester.widget<FloatingNavBar>(find.byType(FloatingNavBar)).active;

    await tester.longPress(find.text(kFakeMaterialTitle));
    await _settle(tester);
    expect(find.text('1 selected'), findsOneWidget);

    // First back clears the selection and stays on the tab…
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    expect(find.text('1 selected'), findsNothing);
    expect(activeTab(), SfNavTab.materials);

    // …and only the second unwinds it.
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(activeTab(), SfNavTab.home);
  });

  testWidgets('the selection menu deletes, behind a confirmation',
      (tester) async {
    final library = FakeLibraryRepository();
    _usePhoneSurface(tester);
    await tester.pumpWidget(
      _scope(
        library: library,
        shellPage: ShellPage.materials,
        child: MaterialApp(theme: AppTheme.light, home: const AppShell()),
      ),
    );
    await _settle(tester);

    await tester.longPress(find.text(kFakeMaterialTitle));
    await _settle(tester);
    await tester.tap(find.text('Monetary Policy Lecture'));
    await _settle(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await _settle(tester);
    expect(find.text('2 materials selected'), findsOneWidget);

    await tester.tap(find.text('Delete 2'));
    await _settle(tester);

    // Destructive actions are confirmed, never immediate.
    expect(find.text('Delete 2 materials?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(library.deleted, isEmpty);
    expect(find.text(kFakeMaterialTitle), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Confirming does go through — both rows, and the selection ends with it.
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await _settle(tester);
    await tester.tap(find.text('Delete 2'));
    await _settle(tester);
    await tester.tap(find.text('Delete'));
    await _settle(tester);

    expect(library.deleted, hasLength(2));
    expect(find.text(kFakeMaterialTitle), findsNothing);
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    expect(find.text('Nothing here yet'), findsOneWidget);
  });

  // ─── Document kind ──────────────────────────────────────────────────────

  group('a material knows what it is', () {
    StudyMaterial of({String? mime, String? path, String? url}) =>
        StudyMaterial(
          id: 'm',
          title: 't',
          progress: 0,
          accent: SubjectAccent.indigo,
          icon: Icons.description_outlined,
          subjectName: 'Unfiled',
          pageCount: null,
          mimeType: mime,
          storagePath: path,
          sourceUrl: url,
        );

    test('reads the mime type first', () {
      expect(of(mime: 'application/pdf', path: 'u/a.pdf').kind,
          MaterialKind.pdf);
      expect(of(mime: 'image/jpeg', path: 'u/a.jpg').kind, MaterialKind.image);
      expect(of(mime: 'text/plain', path: 'u/a.txt').kind, MaterialKind.text);
    });

    test('falls back to the extension on rows written before mime_type', () {
      expect(of(path: 'u/scan-1.png').kind, MaterialKind.image);
      expect(of(path: 'u/note-1.txt').kind, MaterialKind.text);
      expect(of(path: 'u/paper.pdf').kind, MaterialKind.pdf);
    });

    test('a link has no file at all', () {
      expect(of(url: 'https://example.com').kind, MaterialKind.link);
      // …but a stored file wins: a material with both is an upload.
      expect(
        of(url: 'https://example.com', mime: 'image/png', path: 'u/a.png').kind,
        MaterialKind.image,
      );
    });

    test('every kind has a label for the header', () {
      expect(MaterialKind.values.map((k) => k.label).toList(),
          ['PDF', 'Image', 'Text', 'Link']);
    });
  });

  testWidgets('opening a material shows its type and the new action row',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const DocumentScreen()));
    await _settle(tester);

    // The header names the type rather than calling everything "Summary".
    expect(find.text('Summary'), findsNothing);
    expect(find.text('PDF'), findsOneWidget);

    // Flashcards and Quiz me keep their labels; the orb alone takes the slot
    // the dead Share button had.
    expect(find.text('Flashcards'), findsOneWidget);
    expect(find.text('Quiz me'), findsOneWidget);
    expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
    expect(
      find.descendant(
        of: find.byType(SfButton),
        matching: find.byType(FlowOrb),
      ),
      findsOneWidget,
    );

    // Summarize is the header's icon button — the same button the bookmark
    // was, with a different glyph. Not a labelled pill, and not floating over
    // the document it is asking you to read.
    expect(find.text('Summarize'), findsNothing);

    final button = tester.getRect(find.byIcon(Icons.auto_awesome_rounded));
    final title = tester.getRect(find.text(kFakeMaterialTitle));
    expect(
      button.center.dy,
      closeTo(title.center.dy, 24),
      reason: 'Summarize should sit on the header row, not over the document',
    );

    await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
    await _settle(tester);
    expect(find.byType(SummariesScreen), findsOneWidget);
    expect(find.textContaining('Generated by Flow'), findsOneWidget);
  });

  // The bookmark toggled a flag nothing persisted and nothing read — it forgot
  // your bookmark the moment you left the screen. Gone from both screens that
  // had one, rather than left looking functional.
  testWidgets('no bookmark survives on either document screen',
      (tester) async {
    _usePhoneSurface(tester);

    for (final screen in <Widget>[
      const DocumentScreen(),
      const SummariesScreen(),
    ]) {
      await tester.pumpWidget(_app(screen));
      await _settle(tester);
      expect(find.byIcon(Icons.bookmark_rounded), findsNothing);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsNothing);
    }
  });

  // ─── Profile stats ──────────────────────────────────────────────────────

  group('streak', () {
    final today = DateTime(2026, 8, 18);
    DateTime ago(int days) => today.subtract(Duration(days: days));

    test('counts consecutive days back from today', () {
      expect(streakFrom({today, ago(1), ago(2)}, today), 3);
    });

    test('survives today not being done yet', () {
      // The day is still running; breaking the streak at breakfast because
      // nothing has been ticked yet would be infuriating and wrong.
      expect(streakFrom({ago(1), ago(2)}, today), 2);
    });

    test('breaks on a missed day', () {
      expect(streakFrom({today, ago(2), ago(3)}, today), 1);
      // Nothing yesterday or today, so whatever came before does not count.
      expect(streakFrom({ago(2), ago(3)}, today), 0);
    });

    test('is zero with no completed blocks', () {
      expect(streakFrom(const {}, today), 0);
    });
  });

  test('profile stats come from completed blocks, not stored counters',
      () async {
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('test-user'),
        plannerRepositoryProvider.overrideWithValue(FakePlannerRepository()),
        analyticsRepositoryProvider.overrideWithValue(FakeAnalyticsRepository()),
      ],
    );
    addTearDown(container.dispose);

    // The fake has three consecutive completed days of 90 minutes each.
    final stats = await container.read(profileStatsProvider.future);
    expect(stats.streakLabel, '3d');
    expect(stats.studiedLabel, '4h');
    expect(stats.masteredLabel, '342');
  });

  // One block of four ticked used to keep a streak alive, which made it a
  // measure of opening the app rather than of finishing a day.
  test('a partly finished day does not count toward the streak', () async {
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('test-user'),
        plannerRepositoryProvider.overrideWithValue(
          FakePlannerRepository(partialToday: true),
        ),
        analyticsRepositoryProvider.overrideWithValue(FakeAnalyticsRepository()),
      ],
    );
    addTearDown(container.dispose);

    // Today has one block done and one outstanding, so the streak resumes at
    // yesterday: three fully completed days become two.
    final stats = await container.read(profileStatsProvider.future);
    expect(stats.streakLabel, '2d');
    // The hours are unaffected — every finished block still counts.
    expect(stats.studiedLabel, '4h');
  });

  test('a fresh account shows zeroes, not the old placeholders', () async {
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('test-user'),
        plannerRepositoryProvider
            .overrideWithValue(FakePlannerRepository(empty: true)),
        analyticsRepositoryProvider.overrideWithValue(FakeAnalyticsRepository()),
      ],
    );
    addTearDown(container.dispose);

    final stats = await container.read(profileStatsProvider.future);
    expect(stats.streakLabel, '0d');
    expect(stats.studiedLabel, '0h');
  });

  testWidgets('Profile renders the derived stats, not the old literals',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(
      _app(const AppShell(), shellPage: ShellPage.profile),
    );
    await _settle(tester);

    expect(find.text('3d'), findsOneWidget);
    expect(find.text('4h'), findsOneWidget);
    expect(find.text('342'), findsOneWidget);

    // The literals that used to be there.
    expect(find.text('12d'), findsNothing);
    expect(find.text('124h'), findsNothing);
  });

  // ─── Profile preferences ────────────────────────────────────────────────

  testWidgets('Notifications is a switch, and Sounds & haptics is gone',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(
      _app(const AppShell(), shellPage: ShellPage.profile, signedIn: true),
    );
    await _settle(tester);

    expect(find.text('Sounds & haptics'), findsNothing);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Daily reminders on'), findsOneWidget);

    // A switch, not a chevron into a screen with one switch on it.
    final toggle = find.byType(Switch);
    expect(toggle, findsOneWidget);
    expect(tester.widget<Switch>(toggle).value, isTrue);

    await tester.tap(toggle);
    await _settle(tester);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(find.text('Daily reminders off'), findsOneWidget);
  });

  testWidgets('Account opens a screen with the email locked', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(
      _app(const AppShell(), shellPage: ShellPage.profile, signedIn: true),
    );
    await _settle(tester);

    await tester.tap(find.text('Account').last);
    await _settle(tester);

    expect(find.byType(AccountScreen), findsOneWidget);
    expect(find.text('alex.morgan@uni.edu'), findsOneWidget);
    // Shown, not editable — and it says so rather than leaving a greyed field.
    expect(find.text('Your email cannot be changed here.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Change password'), findsOneWidget);
  });

  testWidgets('changing the password validates before it writes',
      (tester) async {
    final auth = FakeAuthRepository(signedIn: true);
    _usePhoneSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesProvider.overrideWithValue(FakePreferencesStore(null)),
          authRepositoryProvider.overrideWithValue(auth),
        ],
        child: const MaterialApp(home: AccountScreen()),
      ),
    );
    await _settle(tester);

    await tester.tap(find.text('Change password'));
    await _settle(tester);

    final fields = find.byType(TextField);
    Future<void> submit(String a, String b) async {
      await tester.enterText(fields.first, a);
      await tester.enterText(fields.last, b);
      await tester.tap(find.text('Save password'));
      await _settle(tester);
    }

    // Too short, then mismatched — both refused before any round trip.
    await submit('abc', 'abc');
    expect(find.text('Use at least 6 characters.'), findsOneWidget);
    expect(auth.changedPassword, isNull);

    await submit('longenough', 'different');
    expect(find.text('The two do not match.'), findsOneWidget);
    expect(auth.changedPassword, isNull);

    await submit('longenough', 'longenough');
    expect(auth.changedPassword, 'longenough');
    expect(find.byType(SfSheetShell), findsNothing);
  });

  testWidgets('the Insights range control spans the screen under the title',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const AnalyticsScreen()));
    await _settle(tester);

    final title = tester.getRect(find.text('Insights'));
    final week = tester.getRect(find.text('Week'));
    final year = tester.getRect(find.text('Year'));

    // Below the title, not beside it.
    expect(week.top, greaterThan(title.bottom));

    // And spread across the full width rather than huddled at one end.
    expect(week.left, lessThan(390 * 0.25));
    expect(year.right, greaterThan(390 * 0.75));
  });

  test('under an hour reads in minutes rather than rounding to zero', () {
    const stats = ProfileStats(
      streakDays: 1,
      studiedMinutes: 45,
      cardsMastered: 0,
    );
    expect(stats.studiedLabel, '45m');
  });

  // Deleting the last document left Home still recommending it: "Flow
  // suggests" ran its own query and nothing ever invalidated it. Everything
  // that answers a question about the library now derives from the library, so
  // one invalidation reaches all of them.
  //
  // Asserted on the providers rather than through the widget tree on purpose.
  // Home's Flow card is below the fold and built lazily, so an unscrolled
  // `expect(find.textContaining(...), findsNothing)` passes whatever the card
  // says — which is exactly how the first version of this test passed against
  // the bug it was written for.
  test('emptying the library clears everything derived from it', () async {
    final library = FakeLibraryRepository();
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('test-user'),
        libraryRepositoryProvider.overrideWithValue(library),
        plannerRepositoryProvider.overrideWithValue(FakePlannerRepository()),
        studyRepositoryProvider.overrideWithValue(FakeStudyRepository()),
        storageRepositoryProvider.overrideWithValue(FakeStorageRepository()),
      ],
    );
    addTearDown(container.dispose);

    // With a library, all three describe it.
    final suggestion = await container.read(flowSuggestionProvider.future);
    expect(suggestion?.text, contains(kFakeMaterialTitle));
    expect(
      (await container.read(resumeMaterialProvider.future))?.title,
      kFakeMaterialTitle,
    );
    expect(await container.read(plannerNoteProvider.future), isNotNull);

    // Delete every material, the way the selection menu does.
    final all = await container.read(materialsProvider.future);
    expect(await container.read(deleteMaterialsProvider)(all), isEmpty);

    // …and now none of them do, without anyone having invalidated them by
    // name.
    expect(await container.read(flowSuggestionProvider.future), isNull);
    expect(await container.read(resumeMaterialProvider.future), isNull);
    expect(await container.read(plannerNoteProvider.future), isNull);
  });

  // Home on a brand-new account: every section that describes something the
  // user has not done yet must either hide or say so plainly.
  testWidgets('Home shows honest empty states on a new account',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const AppShell(), emptyAccount: true));
    await _settle(tester);

    // Nothing to resume → the whole section is absent, not an empty card.
    expect(find.text('Pick up where you left off'), findsNothing);

    // The Today header must not claim tasks that do not exist.
    expect(find.textContaining('tasks ·'), findsNothing);
    expect(find.textContaining('Nothing scheduled today'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('No exams scheduled'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('No exams scheduled'), findsOneWidget);
    // No countdown and no preparation bar for an exam that does not exist.
    expect(find.textContaining('% prepared'), findsNothing);
    expect(find.textContaining('Nothing to suggest yet'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('Upload a PDF'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Upload a PDF'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home shows real data when the account has some',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const AppShell()));
    await _settle(tester);

    // Resume section appears, naming the part-read material.
    expect(find.text('Pick up where you left off'), findsOneWidget);
    expect(find.text(kFakeMaterialTitle), findsWidgets);

    // Two blocks of 90m + 45m.
    expect(find.text('2 tasks · 2h 15m'), findsOneWidget);
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

    // Home → Quiz quick action → the picker, which is the new step: from
    // Home nothing has been chosen, so it asks what to be quizzed on.
    await tester.tap(find.text('Quiz'));
    await _settle(tester);
    expect(find.text('Pick a document to be quizzed on.'), findsOneWidget);

    await tester.tap(find.text(kFakeMaterialTitle));
    await _settle(tester);
    expect(find.text('Which statement about diastereomers is correct?'),
        findsOneWidget);

    // Answering reveals the explanation.
    await tester.tap(
      find.text('They are stereoisomers that are not mirror images'),
    );
    await _settle(tester);
    expect(find.text('EXPLANATION'), findsOneWidget);

    await tester.tap(find.text('Next question'));
    await _settle(tester);

    // The second question has a Previous button; the first did not.
    expect(find.text('Previous'), findsOneWidget);
    // And "See results" is refused until this one is answered too. Skip used
    // to sit here, which let a quiz be finished having answered none of it.
    expect(
      tester.widget<SfButton>(find.widgetWithText(SfButton, 'See results'))
          .onPressed,
      isNull,
      reason: 'moving on should need an answer',
    );

    await tester.tap(find.text('Stereocenter'));
    await _settle(tester);
    await tester.tap(find.text('See results'));
    await _settle(tester);

    expect(find.text('SCORE'), findsOneWidget);
    // Both answered correctly.
    expect(find.text('2/2'), findsWidgets);
  });

  // Going back used to be impossible, so the score could be a running total.
  // With a Previous button it cannot be: answers are stored per question.
  testWidgets('going back and forward does not double-count the score',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const QuizScreen()));
    await _settle(tester);

    await tester.tap(
      find.text('They are stereoisomers that are not mirror images'),
    );
    await _settle(tester);
    await tester.tap(find.text('Next question'));
    await _settle(tester);

    // Back to question one — the answer is still shown, and still stands.
    await tester.tap(find.text('Previous'));
    await _settle(tester);
    expect(find.text('EXPLANATION'), findsOneWidget);

    // Tapping the same option again changes nothing.
    await tester.tap(
      find.text('They are stereoisomers that are not mirror images'),
    );
    await _settle(tester);

    await tester.tap(find.text('Next question'));
    await _settle(tester);
    await tester.tap(find.text('Stereocenter'));
    await _settle(tester);
    await tester.tap(find.text('See results'));
    await _settle(tester);

    // Two questions, two answers — not three.
    expect(find.text('2/2'), findsWidgets);
  });

  testWidgets('flashcards flip to reveal the answer', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const AppShell()));
    await _settle(tester);

    await tester.tap(find.text('Flashcards'));
    await _settle(tester);
    expect(find.text('Pick a document to make cards from.'), findsOneWidget);

    await tester.tap(find.text(kFakeMaterialTitle));
    await _settle(tester);

    expect(find.text('What defines a chiral molecule?'), findsOneWidget);
    expect(find.text('Answer'), findsNothing);

    await tester.tap(find.text('What defines a chiral molecule?'));
    await _settle(tester);

    expect(find.text('Answer'), findsOneWidget);
  });

  testWidgets('the last card says Done and closes the deck', (tester) async {
    _usePhoneSurface(tester);
    // Pushed, the way the app pushes it — "Done" pops, and a screen that is
    // the only route has nothing to pop.
    await tester.pumpWidget(
      _app(const AppShell(), shellPage: ShellPage.materials),
    );
    await _settle(tester);
    await tester.tap(find.text(kFakeMaterialTitle));
    await _settle(tester);
    await tester.tap(find.text('Flashcards'));
    await _settle(tester);

    // Two cards in the fake deck. On the first, forward is "Next"; Previous
    // has nowhere to go.
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Done'), findsNothing);
    expect(
      tester.widget<Opacity>(
        find.ancestor(
          of: find.text('Previous'),
          matching: find.byType(Opacity),
        ),
      ).opacity,
      lessThan(1),
      reason: 'the first card has nothing before it',
    );

    await tester.tap(find.text('Next'));
    await _settle(tester);

    // Last card: nothing to be next to.
    expect(find.text('Next'), findsNothing);
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await _settle(tester);

    expect(find.byType(FlashcardsScreen), findsNothing);
  });

  // The bug these pin: with nothing to study, both screens rendered only a
  // centred empty state — no header, so the sole way out was a "Back" button
  // parked in the middle of the page.
  testWidgets('flashcards with no deck close from the header, not the body',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(
      _app(const FlashcardsScreen(), emptyAccount: true),
    );
    await _settle(tester);

    expect(find.text('No cards yet'), findsOneWidget);
    expect(find.text('Back'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(SfModalHeader),
        matching: find.byIcon(Icons.close_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('quiz with no questions closes from the header, not the body',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const QuizScreen(), emptyAccount: true));
    await _settle(tester);

    expect(find.text('No questions yet'), findsOneWidget);
    expect(find.text('Back'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(SfModalHeader),
        matching: find.byIcon(Icons.close_rounded),
      ),
      findsOneWidget,
    );
  });

  // Each screen offers its primary action once, in the header — not again as
  // a button sitting in the empty state or pinned above the nav pill.
  testWidgets('empty Materials and Planner point at the header ＋',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(
      _app(const AppShell(), shellPage: ShellPage.materials,
          emptyAccount: true),
    );
    await _settle(tester);

    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.widgetWithText(SfButton, 'Upload'), findsNothing);

    await tester.tap(find.text('Planner'));
    await _settle(tester);

    expect(find.text('Nothing planned'), findsOneWidget);
    expect(find.text('Add a study block'), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);

    // Nothing uploaded, so Flow has nothing to plan from and says nothing —
    // it used to claim it had planned the day around an exam that did not
    // exist, on an account with no documents at all.
    expect(find.textContaining('Flow'), findsNothing);
  });

  testWidgets('Planner names the real exam Flow is planning around',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(
      _app(const AppShell(), shellPage: ShellPage.planner),
    );
    await _settle(tester);

    expect(
      find.textContaining('Flow is planning around'),
      findsOneWidget,
    );
    expect(
      find.textContaining('your Organic Chem Final in 9d'),
      findsOneWidget,
    );
  });

  // "Browse files" used to jump straight into the document picker. Two of the
  // five sources are not files on disk, so it asks first.
  testWidgets('Add material asks which source', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const UploadScreen()));
    await _settle(tester);

    await tester.tap(find.text('Browse files'));
    await _settle(tester);

    final sheet = find.byType(SfSheetShell);
    for (final label in [
      'PDF document',
      'Scan with camera',
      'Photo library',
      'Paste text',
      'From URL',
    ]) {
      expect(
        find.descendant(of: sheet, matching: find.text(label)),
        findsOneWidget,
        reason: '$label is missing from the source sheet',
      );
    }

    // "From URL" opens its own sheet rather than a file picker, and refuses
    // to go on until the address has actually been checked.
    await tester.tap(
      find.descendant(of: sheet, matching: find.text('From URL')),
    );
    await _settle(tester);

    expect(find.text('Paste a link and we will check it is reachable.'),
        findsOneWidget);
    expect(
      tester
          .widget<SfButton>(find.widgetWithText(SfButton, 'Continue'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('Paste text gates on the word count', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const PasteTextScreen()));
    await _settle(tester);

    SfButton continueButton() =>
        tester.widget<SfButton>(find.widgetWithText(SfButton, 'Continue'));

    expect(find.text('At least 50 words'), findsOneWidget);
    expect(continueButton().onPressed, isNull);

    // Too few: says how far off, rather than just staying dim.
    final body = find.byType(TextField).last;
    await tester.enterText(body, List.filled(20, 'word').join(' '));
    await tester.pump();
    expect(find.text('20 words — 50 needed'), findsOneWidget);
    expect(continueButton().onPressed, isNull);

    // Enough.
    await tester.enterText(body, List.filled(60, 'word').join(' '));
    await tester.pump();
    expect(find.text('60 words'), findsOneWidget);
    expect(continueButton().onPressed, isNotNull);

    // Over the ceiling: allowed on screen, but not allowed through.
    await tester.enterText(body, List.filled(1200, 'word').join(' '));
    await tester.pump();
    expect(find.text('1200 / 1000 words — too long'), findsOneWidget);
    expect(continueButton().onPressed, isNull);
  });

  // The note box drew a second, inner box that lit up on focus while the real
  // container stayed dim: `AppTheme.inputDecorationTheme` sets a filled
  // surface and a primary `focusedBorder`, and overriding only `border` leaves
  // the rest of it in place.
  testWidgets('the note field draws no border of its own', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const PasteTextScreen()));
    await _settle(tester);

    final decoration =
        tester.widget<TextField>(find.byType(TextField).last).decoration!;

    expect(decoration.filled, isFalse);
    for (final border in [
      decoration.border,
      decoration.enabledBorder,
      decoration.focusedBorder,
      decoration.errorBorder,
      decoration.focusedErrorBorder,
    ]) {
      expect(border, InputBorder.none);
    }
  });

  testWidgets('a sheet with a text field clears the keyboard', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const UploadScreen()));
    await _settle(tester);

    await tester.tap(find.text('Browse files'));
    await _settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(SfSheetShell),
        matching: find.text('From URL'),
      ),
    );
    await _settle(tester);

    // Raise the keyboard. A bottom sheet is laid out against the whole screen,
    // so without an explicit viewInsets padding it sits behind it.
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();

    // Measured on the button, not on SfSheetShell: the keyboard padding is
    // the shell's outermost widget, so the shell's own box still reaches the
    // bottom of the screen while its content sits above it. What matters is
    // that the thing you have to tap is reachable.
    final button = tester.getRect(find.widgetWithText(SfButton, 'Continue'));
    expect(button.bottom, lessThanOrEqualTo(844 - 320 + 0.5));

    // And the field you are typing into is above it too.
    final field = tester.getRect(find.byType(SfField));
    expect(field.bottom, lessThanOrEqualTo(844 - 320 + 0.5));
  });

  testWidgets('the title pre-fills from the body until it is edited',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const PasteTextScreen()));
    await _settle(tester);

    final title = find.byType(TextField).first;
    final body = find.byType(TextField).last;

    // Seven words or fewer are taken whole.
    await tester.enterText(body, 'Mitochondria are the powerhouse of the cell');
    await tester.pump();
    expect(
      tester.widget<TextField>(title).controller!.text,
      'Mitochondria are the powerhouse of the cell',
    );

    // Longer bodies are cut to the opening words, with the trailing comma
    // stripped so the title is not "…of the cell,".
    await tester.enterText(
      body,
      'Mitochondria are the powerhouse of the cell, which is why they matter',
    );
    await tester.pump();
    expect(
      tester.widget<TextField>(title).controller!.text,
      'Mitochondria are the powerhouse of the cell…',
    );

    // Once the user types their own, the body stops overwriting it.
    await tester.enterText(title, 'Cell biology');
    await tester.enterText(body, 'Something else entirely written here now');
    await tester.pump();
    expect(tester.widget<TextField>(title).controller!.text, 'Cell biology');
  });

  test('a URL is normalised before it is checked or saved', () {
    // Nobody types the scheme.
    expect(normaliseUrl('example.com')?.toString(), 'https://example.com');
    expect(
      normaliseUrl('  http://a.example.com/x?y=1 ')?.toString(),
      'http://a.example.com/x?y=1',
    );

    // A host with no dot is a typo, not a site; other schemes are not pages.
    expect(normaliseUrl('notaurl'), isNull);
    expect(normaliseUrl('example.'), isNull);
    expect(normaliseUrl('ftp://example.com'), isNull);
    expect(normaliseUrl(''), isNull);
  });

  // Five rows and a header overflowed the sheet by 37px on a shorter phone:
  // Flutter caps a bottom sheet at 9/16 of the screen unless it is told
  // otherwise, and the content spills instead of the sheet growing.
  testWidgets('the source sheet fits a short screen', (tester) async {
    _usePhoneSurface(tester, size: const Size(340, 700));
    await tester.pumpWidget(_app(const UploadScreen()));
    await _settle(tester);

    await tester.tap(find.text('Browse files'));
    await _settle(tester);

    expect(tester.takeException(), isNull);
    // Still reads as a sheet rather than filling the screen.
    expect(
      tester.getSize(find.byType(SfSheetShell)).height,
      lessThanOrEqualTo(700 * 0.9),
    );
    expect(
      find.descendant(of: find.byType(SfSheetShell), matching: find.text('From URL')),
      findsOneWidget,
    );
  });

  // ─── Filing an upload into a category ───────────────────────────────────

  StudyMaterial fresh() => StudyMaterial(
        id: 'm-new',
        title: 'Thermodynamics notes',
        progress: 0,
        accent: SubjectAccent.indigo,
        icon: Icons.science_outlined,
        subjectName: 'Unfiled',
        pageCount: null,
      );

  testWidgets('the category screen cannot be dismissed without a choice',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(CategoryScreen(material: fresh())));
    await _settle(tester);

    // No escape hatch of any kind — that is what makes it mandatory.
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);

    // Continue is inert until something is chosen.
    final button = tester.widget<SfButton>(
      find.widgetWithText(SfButton, 'Continue'),
    );
    expect(button.onPressed, isNull);

    // And the system back button leaves it exactly where it was.
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.byType(CategoryScreen), findsOneWidget);
  });

  testWidgets('picking a suggested category files the material',
      (tester) async {
    final library = FakeLibraryRepository();
    _usePhoneSurface(tester);
    await tester.pumpWidget(
      _scope(
        library: library,
        child: MaterialApp(
          theme: AppTheme.light,
          home: CategoryScreen(material: fresh()),
        ),
      ),
    );
    await _settle(tester);

    // The user's own category is offered first, so a second upload lands next
    // to the first rather than spawning a near-duplicate.
    expect(find.text('Organic Chemistry'), findsOneWidget);

    await tester.tap(find.text('Physics'));
    await _settle(tester);
    await tester.tap(find.text('Continue'));
    await _settle(tester);

    expect(library.filed['m-new'], isNotNull);
    expect(library.named('m-new'), 'Physics');
  });

  testWidgets('a typed category wins over a selected chip', (tester) async {
    final library = FakeLibraryRepository();
    _usePhoneSurface(tester);
    await tester.pumpWidget(
      _scope(
        library: library,
        child: MaterialApp(
          theme: AppTheme.light,
          home: CategoryScreen(material: fresh()),
        ),
      ),
    );
    await _settle(tester);

    await tester.tap(find.text('Physics'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'Thermodynamics');
    await _settle(tester);

    await tester.tap(find.text('Continue'));
    await _settle(tester);

    expect(library.named('m-new'), 'Thermodynamics');
  });

  // Plain pumps, never pumpAndSettle: the live bar runs a repeating sheen and
  // would never settle.
  testWidgets('the live progress bar fills from the left', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: SfProgress(value: 0.5, animated: true),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final bar = find.byType(SfProgress);
    final fill = find.descendant(
      of: bar,
      matching: find.byWidgetPredicate((w) => w is SizedBox && w.width != null),
    );

    expect(fill, findsOneWidget);
    expect(tester.getSize(fill).width, closeTo(100, 1));
    // Height as well as width. A Stack loosens its non-positioned children,
    // so a fill with only a width collapses to nothing and leaves the grey
    // track on its own — which looks like a bar that never fills.
    expect(tester.getSize(fill).height, greaterThan(0));
    // Anchored left. FractionallySizedBox — the obvious way to write this —
    // defaults to centre alignment, which grows the fill outward from the
    // middle and does not read as progress at all.
    expect(
      tester.getTopLeft(fill).dx,
      closeTo(tester.getTopLeft(bar).dx, 1),
    );

    // And it is the brand gradient, not a flat colour.
    final painted = tester.widget<DecoratedBox>(
      find.descendant(of: fill, matching: find.byType(DecoratedBox)).first,
    );
    expect((painted.decoration as BoxDecoration).gradient, isNotNull);
  });

  test('the transfer label only promises a time when there is one', () {
    const running = UploadState(
      stage: UploadStage.uploading,
      byteSize: 4404019,
      secondsLeft: 12,
    );
    expect(running.transferLabel, '4.2 MB · 12s left');

    // No sample yet, so no estimate — not "0s left".
    const noEstimate = UploadState(
      stage: UploadStage.uploading,
      byteSize: 4404019,
    );
    expect(noEstimate.transferLabel, '4.2 MB');
  });

  // The screen used to open on a scripted exchange about stereochemistry and
  // answer anything typed from a canned table. Both read as a working AI.
  testWidgets('chat opens empty and invents nothing', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const ChatScreen()));
    await _settle(tester);

    expect(find.text('Ask Flow anything'), findsOneWidget);
    expect(find.textContaining('enantiomers'), findsNothing);
    expect(find.textContaining('Stereochem.pdf'), findsNothing);

    // The two openers that survived, and the ones that did not.
    expect(find.text('Summarize it'), findsOneWidget);
    expect(find.text("Explain like I'm 5"), findsOneWidget);
    expect(find.text('Quiz me on this'), findsNothing);
    expect(find.text('Make flashcards'), findsNothing);

    // No dictation, and no way to wipe a thread that starts wiped.
    expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
  });

  testWidgets('a question is answered, and the held document goes with it',
      (tester) async {
    _usePhoneSurface(tester);
    final ai = FakeAiRepository();
    await tester.pumpWidget(_app(const ChatScreen(), ai: ai));
    await _settle(tester);

    // Hold a document first — the whole point is that Flow is given it.
    await tester.tap(find.byIcon(Icons.description_outlined));
    await _settle(tester);
    await tester.tap(find.text(kFakeMaterialTitle).last);
    await _settle(tester);

    await tester.tap(find.text('Summarize it'));
    await _settle(tester);

    // The question is in the transcript — as a bubble, not just as a chip.
    expect(find.text('Summarize it'), findsNWidgets(2));
    // And an answer came back.
    expect(find.textContaining('Answer about m1'), findsOneWidget);

    // The held document was actually passed, rather than only named in the
    // header. This is the difference the whole feature turns on.
    expect(ai.asked.single.materialId, 'm1');
    expect(ai.asked.single.question, 'Summarize it');
  });

  testWidgets('the daily allowance is shown, then stops the composer',
      (tester) async {
    _usePhoneSurface(tester);
    // One question left.
    final ai = FakeAiRepository(used: AiConfig.dailyChatLimit - 1);
    await tester.pumpWidget(_app(const ChatScreen(), ai: ai));
    await _settle(tester);

    expect(find.textContaining('1 of 5 questions left today'), findsOneWidget);

    await tester.tap(find.text('Summarize it'));
    await _settle(tester);

    expect(find.text('No questions left today'), findsWidgets);
    expect(
      tester.widget<TextField>(find.byType(TextField)).enabled,
      isFalse,
      reason: 'a question that cannot be sent should not be typeable',
    );

    // The next attempt never reaches the service.
    await tester.tap(find.text("Explain like I'm 5"));
    await _settle(tester);
    expect(ai.asked.length, 1);
  });

  // Flow is already reachable from the nav bar orb and the "Flow suggests"
  // card, so the fourth quick action goes to Exams instead of a third way in.
  testWidgets('the fourth quick action opens Exams, not the chat',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const AppShell()));
    await _settle(tester);

    expect(find.text('Ask Flow'), findsNothing);

    await tester.tap(find.text('Exams'));
    await _settle(tester);

    expect(find.byType(ExamsScreen), findsOneWidget);
    expect(find.byType(ChatScreen), findsNothing);
  });

  // A build with no credentials used to draw no frame at all, leaving Android
  // showing the launcher icon forever — twice diagnosed by pulling libapp.so
  // out of the APK. Now something renders and says what to do.
  testWidgets('a startup failure renders instead of hanging', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(const StartupFailureApp(
      title: 'Supabase is not configured',
      detail: 'This build was compiled without the project URL.',
      fix: 'flutter build apk --release --dart-define-from-file=…',
    ));
    await _settle(tester);

    expect(find.text('Supabase is not configured'), findsOneWidget);
    expect(find.textContaining('--dart-define-from-file'), findsOneWidget);
  });

  // ── Phase: the AI ───────────────────────────────────────────────────────

  group('generation', () {
    testWidgets('an empty deck offers to generate one, and does',
        (tester) async {
      _usePhoneSurface(tester);
      final ai = FakeAiRepository();
      final study = FakeStudyRepository(empty: true);
      await tester.pumpWidget(
        _app(const FlashcardsScreen(), ai: ai, study: study),
      );
      await _settle(tester);

      expect(find.text('No cards yet'), findsOneWidget);
      await tester.tap(find.text('Generate flashcards'));
      await _settle(tester);

      // It asked for the selected document, not "whatever was newest".
      expect(ai.generated, ['m1']);
    });

    testWidgets('an empty summary offers to generate one', (tester) async {
      _usePhoneSurface(tester);
      final ai = FakeAiRepository();
      // A document that nobody has summarised yet — not an empty account,
      // which would have nothing to summarise and disable the button.
      await tester.pumpWidget(
        _app(
          const SummariesScreen(),
          ai: ai,
          library: FakeLibraryRepository(summarised: false),
        ),
      );
      await _settle(tester);

      expect(find.text('No summary yet'), findsOneWidget);
      // The banner is absent with nothing to describe — it used to read
      // "Generated by Flow · 0 sections" over an empty screen.
      expect(find.textContaining('Generated by Flow'), findsNothing);

      await tester.tap(find.text('Summarize this'));
      await _settle(tester);
      expect(ai.generated, ['m1']);
    });

    testWidgets('an empty quiz offers to generate one', (tester) async {
      _usePhoneSurface(tester);
      final ai = FakeAiRepository();
      await tester.pumpWidget(
        _app(const QuizScreen(), ai: ai, study: FakeStudyRepository(empty: true)),
      );
      await _settle(tester);

      expect(find.text('No questions yet'), findsOneWidget);
      await tester.tap(find.text('Generate quiz'));
      await _settle(tester);
      expect(ai.generated, ['m1']);
    });

    // A model that can find only two ideas in a two-line note is an ordinary
    // outcome. It has to be readable, not a spinner that stops.
    testWidgets('a generation failure says what went wrong', (tester) async {
      _usePhoneSurface(tester);
      final ai = FakeAiRepository(
        failure: const AiException('Flow could not find enough in this note.'),
      );
      await tester.pumpWidget(
        _app(const FlashcardsScreen(), ai: ai, study: FakeStudyRepository(empty: true)),
      );
      await _settle(tester);

      await tester.tap(find.text('Generate flashcards'));
      await _settle(tester);

      expect(
        find.text('Flow could not find enough in this note.'),
        findsOneWidget,
      );
      // Still offered, rather than a dead screen.
      expect(find.text('Generate flashcards'), findsOneWidget);
    });
  });

  // ── Phase: the planner ──────────────────────────────────────────────────

  group('planner', () {
    Future<void> openPlanner(WidgetTester tester) async {
      _usePhoneSurface(tester);
      await tester.pumpWidget(
        _app(const AppShell(), shellPage: ShellPage.planner),
      );
      await _settle(tester);
    }

    /// Adds a block pointing at the fake library's first document.
    Future<void> addLinkedBlock(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.add_rounded));
      await _settle(tester);

      // A title alone is not enough any more: every block points at
      // something, so free text cannot be saved.
      await tester.enterText(find.byType(TextField).first, 'Past paper');
      await _settle(tester);
      expect(
        tester.widget<SfButton>(find.widgetWithText(SfButton, 'Add block'))
            .onPressed,
        isNull,
        reason: 'a block with nothing to point at should not be savable',
      );

      await tester.tap(find.text('Material'));
      await _settle(tester);
      await tester.tap(find.text(kFakeMaterialTitle).last);
      await _settle(tester);
      await tester.tap(find.text('Add block'));
      await _settle(tester);
    }

    testWidgets('a block must point at a material or an exam', (tester) async {
      await openPlanner(tester);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await _settle(tester);

      // Free text is gone. Two ways to aim a block, not three.
      expect(find.text('Just text'), findsNothing);
      expect(find.text('A document'), findsNothing);
      expect(find.text('Material'), findsOneWidget);
      expect(find.text('An exam'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await _settle(tester);

      await addLinkedBlock(tester);

      expect(find.byType(BlockEditorScreen), findsNothing);
      // The typed title survives picking a document.
      expect(find.text('Past paper'), findsOneWidget);
      // Untimed by design — a block with no clock is a task for the day.
      expect(find.text('No time set'), findsOneWidget);
    });

    // The end time is computed from the length rather than picked, so this is
    // the assertion that the arithmetic is right.
    testWidgets('a start plus a length becomes a window', (tester) async {
      await openPlanner(tester);
      await tester.tap(find.byIcon(Icons.add_rounded));
      await _settle(tester);

      await tester.enterText(find.byType(TextField).first, 'Deep work');
      await tester.tap(find.text('Optional'));
      await _settle(tester);
      // The time picker opens on 09:00 and OK accepts it.
      await tester.tap(find.text('OK'));
      await _settle(tester);

      // Picking a start gives a default hour; 1h30 makes it 09:00 – 10:30.
      await tester.tap(find.text('1h 30m'));
      await _settle(tester);
      expect(find.textContaining('09:00 – 10:30'), findsOneWidget);

      await tester.tap(find.text('Add block'));
      await _settle(tester);
      expect(find.textContaining('09:00 – 10:30'), findsOneWidget);
    });

    // Completing a block is something you do to *today*, on Home. The Planner
    // arranges days you are not in, so it has no tick at all.
    testWidgets('planner rows have no tick, and long-press edits or deletes',
        (tester) async {
      await openPlanner(tester);
      expect(find.text('Stereochem · Read Ch 4'), findsOneWidget);
      expect(find.byKey(const ValueKey('tick-b1')), findsNothing);

      // Long-press is the menu; dragging is the handle's job.
      await tester.longPress(find.text('Stereochem · Read Ch 4'));
      await _settle(tester);
      expect(find.text('Edit'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(SfButton, 'Delete'));
      await _settle(tester);

      expect(find.text('Stereochem · Read Ch 4'), findsNothing);
    });

    testWidgets('the day line counts hours, tasks and what is done',
        (tester) async {
      await openPlanner(tester);

      // The fake day holds 1h30 + 45m of timed blocks, none done.
      expect(find.textContaining('2h 15m · 0 of 2 done'), findsOneWidget);

      await addLinkedBlock(tester);

      // An untimed block adds a task without adding hours.
      expect(find.textContaining('2h 15m · 1 task · 0 of 3 done'),
          findsOneWidget);
    });

    testWidgets('copying a day duplicates its blocks, unticked',
        (tester) async {
      await openPlanner(tester);

      await tester.tap(find.text('Copy this day…'));
      await _settle(tester);

      // The first offered day is tomorrow.
      await tester.tap(find.byType(SfSelectChip).first);
      await _settle(tester);
      await tester.tap(find.textContaining('Copy to 1 day'));
      await _settle(tester);

      // Today is untouched, and tomorrow now has the same two blocks.
      expect(find.text('Stereochem · Read Ch 4'), findsOneWidget);

      final tomorrow = DateTime.now().add(const Duration(days: 1));
      await tester.tap(find.text('${tomorrow.day}').last);
      await _settle(tester);
      expect(find.text('Stereochem · Read Ch 4'), findsOneWidget);
      expect(find.textContaining('0 of 2 done'), findsOneWidget);
    });
  });

  // Home's task cards used to toggle done anywhere on the card, which made
  // "I have finished this" a claim you could make without doing anything.
  // Completion is earned now: the bar tracks the material's cards and
  // questions, and the tick reports it.
  testWidgets('a task shows its practice progress and cannot be hand-ticked',
      (tester) async {
    _usePhoneSurface(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const AppShell()));
    await _settle(tester);

    expect(find.text('Stereochem · Read Ch 4'), findsOneWidget);
    // The fake has m1 half done: 4 of its 8 cards and questions.
    expect(find.text('4 of 8'), findsOneWidget);

    // The tick is a readout, not a control — no tap action to offer.
    expect(
      tester.getSemantics(find.bySemanticsLabel('Done').first),
      matchesSemantics(
        label: 'Done',
        hasCheckedState: true,
        isChecked: false,
        // No tap action: there is nothing for a tap to decide.
        isReadOnly: true,
      ),
    );

    // Tapping the card opens the document it points at.
    await tester.tap(find.text('Stereochem · Read Ch 4'));
    await _settle(tester);
    expect(find.byType(DocumentScreen), findsOneWidget);

    semantics.dispose();
  });

  // ── Phase: exams ────────────────────────────────────────────────────────

  group('exams', () {
    /// Walks the editor: title, date, then save.
    Future<void> addExam(WidgetTester tester, String title) async {
      await tester.tap(find.byIcon(Icons.add_rounded));
      await _settle(tester);

      await tester.enterText(find.byType(TextField).first, title);
      await _settle(tester);

      // Saving is refused until there is a date — a countdown to nothing is
      // not an exam.
      expect(
        tester.widget<SfButton>(find.widgetWithText(SfButton, 'Add exam'))
            .onPressed,
        isNull,
        reason: 'a title alone should not be savable',
      );

      await tester.tap(find.text('Pick a date'));
      await _settle(tester);
      // The date picker opens on today, which is `firstDate` — accept it.
      await tester.tap(find.text('OK'));
      await _settle(tester);

      await tester.tap(find.text('Add exam'));
      await _settle(tester);
    }

    testWidgets('an exam can be added, and shows up in the list',
        (tester) async {
      _usePhoneSurface(tester);
      await tester.pumpWidget(_app(const ExamsScreen()));
      await _settle(tester);

      await addExam(tester, 'Physics midterm');

      expect(find.byType(ExamEditorScreen), findsNothing);
      expect(find.text('Physics midterm'), findsOneWidget);
    });

    // The featured card hard-coded "THU · MAY 15 · 9:00 AM" and
    // "High priority" for whatever exam happened to be next.
    testWidgets('the featured card reads the exam, not a fixed string',
        (tester) async {
      _usePhoneSurface(tester);
      await tester.pumpWidget(_app(const ExamsScreen()));
      await _settle(tester);

      expect(find.text('THU · MAY 15 · 9:00 AM'), findsNothing);
      // SfEyebrow uppercases its label.
      expect(find.text('HIGH PRIORITY'), findsOneWidget);

      // A normal-priority exam sooner than it takes the featured slot, and
      // the label goes with it.
      await addExam(tester, 'Physics midterm');
      expect(find.text('HIGH PRIORITY'), findsNothing);
      expect(find.text('NEXT UP'), findsOneWidget);
    });

    testWidgets('preparation comes from the attached materials', (tester) async {
      _usePhoneSurface(tester);
      await tester.pumpWidget(_app(const ExamsScreen()));
      await _settle(tester);

      // Nothing attached: no percentage anywhere, and it says why.
      expect(find.textContaining('No materials added'), findsWidgets);

      await tester.tap(find.text('Organic Chem Final'));
      await _settle(tester);
      expect(find.byType(ExamDetailScreen), findsOneWidget);

      // No practice row down here: each attached document is a row with those
      // actions of its own, and a set at the bottom would have to guess which
      // document it meant.
      expect(find.widgetWithText(SfButton, 'Quiz me'), findsNothing);
      expect(find.widgetWithText(SfButton, 'Flashcards'), findsNothing);

      await tester.tap(find.text('Add'));
      await _settle(tester);
      // The fake library's two documents sit at 42% and 100%.
      await tester.tap(find.text(kFakeMaterialTitle).last);
      await _settle(tester);
      await tester.tap(find.text('Save 1'));
      await _settle(tester);

      expect(find.text('42%'), findsWidgets);

      // Mean of 42% and 100%.
      await tester.tap(find.text('Add'));
      await _settle(tester);
      await tester.tap(find.text('Monetary Policy Lecture').last);
      await _settle(tester);
      await tester.tap(find.text('Save 2'));
      await _settle(tester);

      expect(find.text('71%'), findsWidgets);
    });

    testWidgets('an exam can be deleted from its detail screen',
        (tester) async {
      _usePhoneSurface(tester);
      await tester.pumpWidget(_app(const ExamsScreen()));
      await _settle(tester);

      await tester.tap(find.text('Organic Chem Final'));
      await _settle(tester);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await _settle(tester);
      await tester.tap(find.widgetWithText(SfButton, 'Delete'));
      await _settle(tester);

      expect(find.byType(ExamDetailScreen), findsNothing);
      expect(find.text('Organic Chem Final'), findsNothing);
      expect(find.text('No exams scheduled'), findsOneWidget);

      // Adding is the ＋ in the header and nowhere else. A second button in
      // the middle of the empty state duplicated it and broke the layout the
      // other empty screens share.
      expect(find.widgetWithText(SfButton, 'Add an exam'), findsNothing);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });
  });

  // ── Phase: the library, reachable from everywhere ──────────────────────

  testWidgets('Add material lists recent uploads and opens the full history',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const UploadScreen()));
    await _settle(tester);

    await tester.scrollUntilVisible(find.text('History'), 150);
    await _settle(tester);
    expect(find.text(kFakeMaterialTitle), findsOneWidget);

    await tester.tap(find.text('View all'));
    await _settle(tester);

    // The History screen: searchable, and a back arrow rather than a ✕,
    // because it is pushed on top of a modal rather than over the app.
    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.text(kFakeMaterialTitle), findsOneWidget);
    expect(find.text('Monetary Policy Lecture'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'monetary');
    await _settle(tester);
    expect(find.text(kFakeMaterialTitle), findsNothing);
    expect(find.text('Monetary Policy Lecture'), findsOneWidget);
  });

  // Opening Flow from a document and being told "No document selected" asked
  // you to go and find the thing already on screen.
  testWidgets('the orb on a document hands that document to Flow',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(
      _app(const AppShell(), shellPage: ShellPage.materials),
    );
    await _settle(tester);

    await tester.tap(find.text('Monetary Policy Lecture'));
    await _settle(tester);

    await tester.tap(
      find.descendant(of: find.byType(SfButton), matching: find.byType(FlowOrb)),
    );
    await _settle(tester);

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('No document selected'), findsNothing);
    expect(find.text('Monetary Policy Lecture'), findsOneWidget);
  });

  testWidgets('History lists uploads without progress bars', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const HistoryScreen()));
    await _settle(tester);

    expect(find.text(kFakeMaterialTitle), findsOneWidget);
    // The Materials tab is where "how far through am I" belongs; here the
    // question is only what has been added.
    expect(find.text('42%'), findsNothing);
    expect(find.byType(SfProgress), findsNothing);
  });

  testWidgets('History opens the document it was asked for', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const HistoryScreen()));
    await _settle(tester);

    await tester.tap(find.text('Monetary Policy Lecture'));
    await _settle(tester);

    expect(find.byType(DocumentScreen), findsOneWidget);
    // The one it was asked for, not merely the newest.
    expect(find.text('Monetary Policy Lecture'), findsOneWidget);
  });

  // Opened *from a document*, both practice screens already know what they are
  // about — asking again would be asking a question the app can see.
  testWidgets('a document goes straight to its cards, skipping the picker',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(
      _app(const AppShell(), shellPage: ShellPage.materials),
    );
    await _settle(tester);

    await tester.tap(find.text(kFakeMaterialTitle));
    await _settle(tester);
    await tester.tap(find.text('Flashcards'));
    await _settle(tester);

    expect(find.text('Pick a document to make cards from.'), findsNothing);
    expect(find.text('What defines a chiral molecule?'), findsOneWidget);
  });

  testWidgets('a document with nothing generated says so, and names it',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const AppShell()));
    await _settle(tester);

    await tester.tap(find.text('Flashcards'));
    await _settle(tester);

    // Only `m1` has a deck in the fake, which is the realistic shape.
    await tester.tap(find.text('Monetary Policy Lecture'));
    await _settle(tester);

    expect(find.text('No cards yet'), findsOneWidget);
    expect(
      find.textContaining('Monetary Policy Lecture'),
      findsOneWidget,
      reason: 'the empty state should name the document it is empty for',
    );
    // Not the old copy, which told you to upload a document you had just
    // picked from a list of documents you had uploaded.
    expect(find.textContaining('Upload a document'), findsNothing);
  });

  // The transcript grows *downward* from under the header. This was briefly
  // bottom-anchored (`reverse: true`), which made everything already on screen
  // climb upward on every send — the thing it was supposed to fix.
  testWidgets('a short transcript starts at the top and nothing moves',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const ChatScreen()));
    await _settle(tester);

    await tester.enterText(find.byType(TextField), 'First question');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await _settle(tester);

    final transcript = tester.getRect(find.byType(ListView));
    final firstBefore = tester.getRect(find.text('First question'));
    expect(
      firstBefore.top - transcript.top,
      lessThan(48),
      reason: 'the conversation should begin under the header',
    );

    await tester.enterText(find.byType(TextField), 'Second question');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await _settle(tester);

    final firstAfter = tester.getRect(find.text('First question'));
    final second = tester.getRect(find.text('Second question'));

    // The whole complaint, in one assertion: sending must not shift a message
    // that is already on screen.
    expect(firstAfter.top, firstBefore.top,
        reason: 'an existing message must not move when a new one arrives');
    expect(second.top, greaterThan(firstAfter.top),
        reason: 'the new message belongs below the old one');
  });

  testWidgets('a reopened short chat is still at the top, in order',
      (tester) async {
    _usePhoneSurface(tester);
    final chat = FakeChatRepository();
    await tester.pumpWidget(_app(const ChatScreen(), chat: chat));
    await _settle(tester);

    for (final text in ['First question', 'Second question']) {
      await tester.enterText(find.byType(TextField), text);
      await tester.tap(find.byIcon(Icons.send_rounded));
      await _settle(tester);
    }

    // Rebuild against the same stored transcript — what navigating away and
    // back does.
    await tester.pumpWidget(_app(const ChatScreen(), chat: chat));
    await _settle(tester);

    final transcript = tester.getRect(find.byType(ListView));
    final first = tester.getRect(find.text('First question'));
    expect(first.top - transcript.top, lessThan(48));
    expect(first.top, lessThan(tester.getRect(find.text('Second question')).top));
  });

  // Once the thread outgrows the viewport, the newest message has to be the
  // one you land on — that part *is* like every other chat app.
  testWidgets('a long transcript opens at the newest message', (tester) async {
    _usePhoneSurface(tester);
    final chat = FakeChatRepository();
    // A day's real allowance is five; this is a layout test, so it is raised
    // rather than worked around.
    final ai = FakeAiRepository(limit: 100);
    await tester.pumpWidget(_app(const ChatScreen(), chat: chat, ai: ai));
    await _settle(tester);

    for (var i = 1; i <= 20; i++) {
      await tester.enterText(find.byType(TextField), 'Message $i');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await _settle(tester);
    }

    await tester.pumpWidget(_app(const ChatScreen(), chat: chat, ai: ai));
    await _settle(tester);

    expect(find.text('Message 20'), findsOneWidget);
    expect(find.text('Message 1'), findsNothing);
  });

  // The header used to say "Reading 3 docs" — hard-coded, then counted, and
  // wrong either way. Flow reads the one document you hand it.
  testWidgets('the header names the held document, and picking changes it',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const ChatScreen()));
    await _settle(tester);

    expect(find.text('No document selected'), findsOneWidget);
    expect(find.textContaining('Reading'), findsNothing);

    await tester.tap(find.byIcon(Icons.description_outlined));
    await _settle(tester);
    await tester.tap(find.text(kFakeMaterialTitle).last);
    await _settle(tester);

    expect(find.text('No document selected'), findsNothing);
    // In the header now, not just in the sheet that closed.
    expect(find.text(kFakeMaterialTitle), findsOneWidget);
  });

  testWidgets('each document gets its own conversation', (tester) async {
    _usePhoneSurface(tester);
    final chat = FakeChatRepository();
    await tester.pumpWidget(_app(const ChatScreen(), chat: chat));
    await _settle(tester);

    Future<void> hold(String title) async {
      await tester.tap(find.byIcon(Icons.description_outlined));
      await _settle(tester);
      await tester.tap(find.text(title).last);
      await _settle(tester);
    }

    await hold(kFakeMaterialTitle);
    await tester.enterText(find.byType(TextField), 'About chemistry');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await _settle(tester);
    expect(find.text('About chemistry'), findsOneWidget);

    // A different document is a different conversation — not the same
    // transcript with a new label on it.
    await hold('Monetary Policy Lecture');
    expect(find.text('About chemistry'), findsNothing);
    expect(find.text('Ask Flow anything'), findsOneWidget);

    await hold(kFakeMaterialTitle);
    expect(find.text('About chemistry'), findsOneWidget);
  });

  testWidgets('Flow suggests opens what it suggested', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(const AppShell()));
    await _settle(tester);

    // The card names the least-read document; acting on it must open Flow
    // already holding that one rather than making you find it again.
    await tester.scrollUntilVisible(find.text('Open it'), 120,
        scrollable: find.byType(Scrollable).first);
    await _settle(tester);
    await tester.tap(find.text('Open it'));
    await _settle(tester);

    // "Open it" opens the document. The card used to open the chat whatever
    // it had just suggested.
    expect(find.byType(DocumentScreen), findsOneWidget);
    expect(find.byType(ChatScreen), findsNothing);
    expect(find.text(kFakeMaterialTitle), findsOneWidget);
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
      'blockEditor': plain(() => BlockEditorScreen(day: DateTime.now())),
      'exams': plain(ExamsScreen.new),
      'examEditor': plain(ExamEditorScreen.new),
      'examDetail': plain(ExamDetailScreen.new),
      'analytics': plain(AnalyticsScreen.new),
      'achievements': plain(AchievementsScreen.new),
      'account': plain(AccountScreen.new),
      'upload': plain(UploadScreen.new),
      'pasteText': plain(PasteTextScreen.new),
      'category': plain(
        () => CategoryScreen(
          material: StudyMaterial(
            id: 'm1',
            title: kFakeMaterialTitle,
            progress: 0,
            accent: SubjectAccent.indigo,
            icon: Icons.science_outlined,
            subjectName: 'Unfiled',
            pageCount: null,
          ),
        ),
      ),
      'history': plain(HistoryScreen.new),
      'pickFlashcards': plain(
        () => const PickMaterialScreen(tool: StudyTool.flashcards),
      ),
      'pickQuiz': plain(() => const PickMaterialScreen(tool: StudyTool.quiz)),
      'chat': plain(ChatScreen.new),
      'summaries': plain(SummariesScreen.new),
      'document': plain(DocumentScreen.new),
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
