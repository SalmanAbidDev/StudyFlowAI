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
import 'package:ai_study_helper/features/materials/materials_view_model.dart';
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
      studyRepositoryProvider
          .overrideWithValue(FakeStudyRepository(empty: emptyAccount)),
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
  bool emptyAccount = false,
}) {
  return _scope(
    shellPage: shellPage,
    signedIn: signedIn,
    prefs: prefs,
    emptyAccount: emptyAccount,
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

    // And the summary is one tap away rather than occupying the body.
    expect(find.text('Summarize'), findsOneWidget);
    await tester.tap(find.text('Summarize'));
    await _settle(tester);
    expect(find.byType(SummariesScreen), findsOneWidget);
    expect(find.textContaining('Generated by Flow'), findsOneWidget);
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

    expect(find.text('No quiz yet'), findsOneWidget);
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
