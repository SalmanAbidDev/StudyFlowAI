# StudyFlow AI — project handoff

Read this first if you are picking this project up cold. It covers what the app
is, how it is put together, the decisions behind that structure, and the traps
already discovered so you do not rediscover them.

Last updated: 2026-08-12.

**Where the project stands.** Built from a design file as UI-only → restructured
to MVVM + Riverpod → connected to Supabase (auth, 16 tables with RLS, storage)
→ visual polish. It runs on device: sign-up, sign-in, real data on every screen,
PDF upload to a private bucket, persisted theme. What is *not* built is listed
in §9, with a reason for each — read that before assuming something is missing
by accident.

**Invariants worth not breaking.** Each is explained in the section named:

| | |
|---|---|
| No `setState` anywhere in `lib/` | §4 |
| No `Dialog`/`AlertDialog` — every modal is a bottom sheet | §6.1 |
| No raw `MaterialPageRoute` — routes go through `sfRoute`/`sfModalRoute` | §3.2 |
| `ShellPage` holds the four tabs and nothing else | §3.2 |
| No raw `ListTile` in a sheet — it drags Material's typography in | §6.1 |
| Tests never touch the network or a platform channel | §8 |
| `flutter analyze` clean and all tests green | §1 |

---

## 1. What this is

A Flutter study app — AI summaries, flashcards, quizzes, a planner, and a chat
over your own documents. It was built from a design file (`StudyFlow AI.html`
in a Claude design project) as UI-only, then restructured to MVVM, then
connected to Supabase.

**Toolchain**

| | |
|---|---|
| Flutter | 3.44.6 stable (Dart 3.12.2) |
| State | `flutter_riverpod` ^3.4.2 |
| Backend | `supabase_flutter` ^2.17.1 |
| File picking | `file_selector` (flutter.dev) — **not** `file_picker`, see §10 |
| Local storage | `shared_preferences` (theme choice only) |
| Lints | `flutter_lints` ^6.0.0 |

**Health check** — both should be clean before and after any change:

```bash
flutter analyze     # expect: No issues found!
flutter test        # expect: 99 tests, all passing
```

**Running it** — credentials come in at build time, so a bare `flutter run`
throws a deliberate `StateError` telling you what to do:

```bash
flutter run --dart-define-from-file=dart_define.json
```

**Pressing ▶ in the IDE needs the same argument**, or you get that same
`StateError` at startup. Both run configurations are committed and already
carry it:

- Android Studio / IntelliJ — `.idea/runConfigurations/main_dart.xml`
  (`additionalArgs`). Note `.gitignore` uses `.idea/*` plus a negation so this
  one file is versioned while the rest of `.idea/` stays ignored.
- VS Code — `.vscode/launch.json` (`toolArgs`), with debug/profile/release
  variants.

If you add a new run configuration, it needs the flag too.

---

## 2. Supabase project

**Project:** `StudyFlowAI` · ref `cwriehotskhrekxyobvt` · region ap-northeast-1
· Postgres 17 · URL `https://cwriehotskhrekxyobvt.supabase.co`

Credentials live in `dart_define.json` at the repo root, which is **gitignored**.
`dart_define.example.json` is committed as the template. **On a fresh clone this
file will not exist and the app will refuse to start** — copy the example and
fill it from the dashboard (Project Settings → API keys). Use the **publishable**
key (`sb_publishable_…`), never `service_role` — that one bypasses RLS entirely
and must never appear in the app.

```json
{
  "SUPABASE_URL": "https://cwriehotskhrekxyobvt.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "<publishable key from the dashboard>"
}
```

The SDK deprecates `anonKey` in favour of `publishableKey`; `main.dart` uses the
new parameter.

### 2.1 Schema

16 tables in `public`, **RLS enabled on every one**, 18 policies.

```
profiles ──1:1── auth.users          full_name, streak_days, is_pro
subjects                             name, accent (enum), icon (text key)
  ├── materials                      title, page_count, storage_path, progress
  │     ├── summary_sections         position, title, bullets[], read
  │     ├── decks ── flashcards       question, answer, ease, interval_days, due_at
  │     └── quizzes                  
  │           └── quiz_questions     
  │                 └── quiz_options  label, body, is_correct
  ├── study_blocks                   scheduled_on, starts_at, ends_at, position, done
  ├── exams                          exam_date, preparation
  └── study_sessions                 started_at, duration_minutes, focus_score
quiz_attempts                        correct, total, elapsed_seconds, missed[]
chat_threads ── chat_messages        role (enum), content, sources[]
achievements                         code, name, detail, earned_at
```

Storage: private bucket `materials`, 50 MB cap, mime-restricted, 4 policies.

### 2.2 Migrations applied (in order)

```
20260810102456  core_profiles_and_subjects
20260810102512  library_materials_and_summaries
20260810102533  study_decks_blocks_and_exams
20260810102550  quiz_schema
20260810102609  chat_activity_and_achievements
20260810102623  materials_storage_bucket
20260810102704  revoke_execute_on_trigger_functions
20260810115615  subject_icon_and_starter_seed
20260810131459  cover_remaining_foreign_keys
```

### 2.3 Schema decisions worth preserving

- **RLS policies use `(select auth.uid())`, not bare `auth.uid()`.** The bare
  form is re-evaluated per row and degrades badly on a large table. Keep the
  `select` wrapper in any new policy.
- **`user_id` is denormalised onto child tables** (`flashcards`,
  `quiz_options`, `chat_messages`, `summary_sections`, `quiz_questions`). RLS
  becomes an index lookup instead of a join back to the parent on every row.
  New child tables should follow this.
- **A trigger creates the profile row on sign-up** (`handle_new_user` on
  `auth.users`). The app never has to handle "signed in but no profile".
- **`exams.days_left` is deliberately not stored.** It is `exam_date - today`;
  a stored copy is wrong by morning. Same reasoning killed a stored
  `study_blocks.duration`.
- **Storage objects are keyed `<user-id>/<timestamp>-<name>`.** The bucket
  policies compare the first path segment to `auth.uid()`. That, not the bucket
  being private, is what stops one account reading another's files. Do not
  change the key format without updating the policies.
- **Trigger functions have `EXECUTE` revoked** from `anon`/`authenticated`.
  Being `SECURITY DEFINER` they were reachable at `/rest/v1/rpc/…`. Triggers
  still fire — Postgres does not check `EXECUTE` for trigger invocation.

### 2.4 Known advisor warning (not ours)

`public.rls_auto_enable()` is flagged as a public `SECURITY DEFINER` function.
It is a **Supabase platform event trigger** that auto-enables RLS on new tables,
not something this project created. It is harmless (an event-trigger function
errors if called directly). Left alone deliberately — do not "fix" it.

### 2.5 Starter content

`seed_starter_content()` (SECURITY INVOKER, idempotent) fills a brand-new
account with one subject set, a material with a summary, a deck, a quiz,
today's blocks, exams and achievements. `HomeScreen` watches
`starterContentProvider`, which calls it once.

**This is a product decision, not a technical requirement.** Without it a new
account lands on six empty screens, which reads as broken rather than new.
To remove: drop the `starterContentProvider` watch in `home_screen.dart` and
the function. Nothing else depends on it.

---

## 3. Project structure — MVVM, feature-first

```
lib/
  main.dart                     init Supabase + SharedPreferences, then runApp
  app/
    app.dart                    StudyFlowApp (root MaterialApp)
    theme_mode_view_model.dart  app-scoped: themeModeProvider (persisted)
  core/
    config/supabase_config.dart --dart-define reader + startup assert
    navigation.dart             sfRoute / sfModalRoute — see §3.2
    preferences.dart            PreferencesStore seam + preferencesProvider
    theme/                      design tokens (8 files, barrel: theme.dart)
    widgets/                    shared components (barrel: widgets.dart)
      sf_sheet.dart             showSfSheet / SfSheetShell / SfConfirmSheet
      async_states.dart         SfLoadingList / SfErrorView / SfEmptyView
    view_models.dart            ValueViewModel<T>, FlagViewModel
  data/
    demo_content.dart           only the Free-vs-Pro paywall matrix now
    supabase_providers.dart     client + all repository providers
    models/                     subject, study_material, study_block, exam,
                                flashcard, summary_section, quiz, profile
    repositories/               auth, library, planner, study, profile,
                                analytics, chat, storage
  features/<name>/
    <name>_screen.dart          View
    <name>_view_model.dart      ViewModel (providers)
    chat_models.dart            Model — chat is the only feature with enough
                                model surface to warrant its own file
```

17 feature folders: analytics, auth, chat, components, exams, flashcards, home,
materials, onboarding, planner, premium, profile, quiz, shell, splash,
summaries, upload.

`features/shell/` is the tab scaffold, not a screen: `app_shell.dart` holds the
IndexedStack, the floating nav bar and the system-back policy (§3.3);
`shell_view_model.dart` holds `ShellPage`. Only four of the seventeen features
are reachable from the tab bar — the rest are pushed.

**Why flat inside each feature** rather than `view/` + `view_model/`
subfolders: with one or two files each that is depth without information. The
`_screen` / `_view_model` / `_models` suffixes carry the MVVM roles.

**Where state lives is decided by lifetime**, not by convenience:

- `themeModeProvider` → `lib/app/` because the theme outlives every screen.
- `shellPageProvider` → `features/shell/` because the shell owns navigation;
  Home, Planner, Profile, Exams and Insights all import it.
- Everything else is feature-private.

### 3.1 Persistence

Only one thing is stored locally: the theme choice, under the key
`ThemeModeViewModel.storageKey` (`'theme_mode'`), holding a `ThemeMode.name`.

`main()` awaits `SharedPreferences.getInstance()` **before** `runApp` and
injects it via `preferencesProvider.overrideWithValue(...)`. That is what makes
`ThemeModeViewModel.build()` a synchronous read, so the very first frame is
already the right theme — no flash of light before dark loads.

**It is stored locally rather than on the `profiles` row on purpose.** The theme
has to be correct on Splash and Auth, where there is no session to read a
profile with. Adding cross-device sync later means writing *both*, not moving it.

`PreferencesStore` is a deliberate seam (`lib/core/preferences.dart`) wrapping
`SharedPreferences`, mirroring how the app depends on repositories rather than
on `SupabaseClient`. Tests inject `FakePreferencesStore`, so the plugin and its
platform channel never enter the suite. An unrecognised stored value falls back
to `ThemeMode.system` rather than throwing.

---

### 3.2 Navigation

All navigation is Cupertino — horizontal slide plus the swipe-from-the-left
back gesture, on every platform. Nothing constructs a route inline; everything
goes through `lib/core/navigation.dart`:

| Helper | Transition | Use for |
|---|---|---|
| `sfRoute(builder: …)` | slide in from the right | screens with a **back arrow** |
| `sfModalRoute(builder: …)` | slide up from the bottom | screens with a **close ✕** |

**The affordance decides the helper.** Upload, Flashcards, Quiz, Quiz results
and Premium have a ✕ and are modal; Chat, Summaries, Auth and the shell have a
back arrow and are pushes. A modal deliberately has no back-swipe — it is
dismissed by its own button.

`AppTheme` also sets `pageTransitionsTheme` to `CupertinoPageTransitionsBuilder`
for every `TargetPlatform`. The helpers do not consult it (a `CupertinoPageRoute`
brings its own transition), so it is purely a safety net: any route added later
as a `MaterialPageRoute`, or pushed from inside a package, still matches instead
of standing out.

Two gotchas:

- **`CupertinoPageTransitionsBuilder` is not in `material.dart`** in Flutter
  3.44 despite the Material docs referencing it. It lives in
  `cupertino/route.dart`; `app_theme.dart` imports it with a `show` clause.
- Splash → Onboarding keeps its bespoke `PageRouteBuilder` fade. It is a brand
  moment, not a navigation step, and a horizontal slide would be wrong there.

**Only the four tabs belong in the shell.** `ShellPage` has exactly `home`,
`materials`, `planner`, `profile`. Exams and Insights were once extra
`IndexedStack` children and had to be moved out, because a page with no route
of its own:

1. gets no transition — it just appears;
2. keeps the floating tab bar drawn on top of it;
3. gives the system back button nothing to pop, so **Android closes the app**;
4. needs a hardcoded "back" target, which was wrong from half its entry points
   (Exams always returned to Planner even when opened from Home).

All four symptoms were reported as bugs. If a screen needs a back arrow, push
it — do not add it to `ShellPage`.

### 3.3 System back

`AppShell` wraps itself in `PopScope(canPop: false)` and decides what back
means at the root:

- **Off Home** → return to Home. The tab bar is lateral navigation, so back
  should unwind it before it unwinds the app.
- **On Home** → an `SfConfirmSheet` asking before leaving. Confirm calls
  `SystemNavigator.pop()`; cancel or scrim-dismiss stays put.

`canPop: false` is required: the shell is the root route, so letting the pop
through closes the app. Pushed routes on top of the shell are unaffected —
the topmost route handles back, so Exams/Insights/Chat pop normally.

---

## 4. Riverpod conventions and version traps

**Riverpod 3.4.2 differs from most tutorials and from v2.** These cost real
debugging time:

| Trap | Reality in 3.4.2 |
|---|---|
| `AsyncValue.valueOrNull` | **Does not exist.** `value` is already nullable — use `.value`. |
| `Override` type | **Not exported by `flutter_riverpod`.** You cannot write `List<Override>`. Pass the child into a helper that builds the `ProviderScope` instead (see `test/widget_test.dart::_scope`). |
| `AutoDisposeNotifier` / `AutoDisposeAsyncNotifier` | **Merged away.** Use plain `Notifier` / `AsyncNotifier` with `NotifierProvider.autoDispose<…>` / `AsyncNotifierProvider.autoDispose<…>`. |
| `StateProvider`, `StateNotifierProvider` | Live in `src/providers/legacy/`. Not used here — everything is `Notifier`/`AsyncNotifier`. |

**autoDispose is a behavioural decision, not a default.** The rule this project
follows, which reproduces what the pre-Riverpod `State` objects did:

- Shell-resident screens (Home, Materials, Planner, Insights) live in an
  `IndexedStack` that never disposes → their providers are **not** autoDispose,
  so a tab switch preserves state.
- Pushed routes (Quiz, Chat, Flashcards, Upload, Summaries, Onboarding, Auth,
  Premium) died with the route → their providers **are** autoDispose, so
  reopening gives a clean slate. Without this, reopening the quiz would resume
  the previous run's score.

**Timers belong to the provider, not the widget.** Quiz clock, chat's 1.4 s fake
latency: created in `build()`, cancelled via `ref.onDispose`. This removed
several `if (!mounted) return` guards.

**`AppShell` has no `initialPage` argument.** Seed it with a `ProviderScope`
override of `initialShellPageProvider`. A widget argument would force mutating
navigation state in `initState`, which is the wrong shape.

**There is no `setState` anywhere in `lib/`** — deliberately. `StatefulWidget`
is still used, but only for controllers (`AnimationController`,
`TextEditingController`, `ScrollController`, `PageController`) and Splash's
navigation timer. Those are not application state and should stay put.

---

## 5. Async UI

Every view model that touches the network exposes `AsyncValue`. Every screen
handles all three states using the shared widgets in
`core/widgets/async_states.dart`:

- `SfLoadingList` — skeletons, not a spinner. Sizes itself to the available
  height via `LayoutBuilder`, because it is used both inside an `Expanded`
  (bounded) and as a list child (unbounded).
- `SfErrorView` — always offers retry. Translates errors:
  `SocketException`/`ClientException` → "Can't reach the server", JWT errors →
  "Your session expired". Never shows a raw Postgrest string.
- `SfEmptyView` — distinct from an error, and the more common state on a fresh
  account.

**Optimistic writes** where a round trip would feel broken: planner
drag-reorder applies locally then persists (reverting to the server's order on
failure); chat echoes your message immediately. `quiz_attempts` failures are
swallowed on purpose — losing a score row must not block the results screen.

**Derived, never stored** — anywhere storing would let two facts disagree:
`exam.daysLeft`, `StudyBlock.duration`/`window`, `StudyMaterial.meta`, the
Materials filter rail and its counts, and all of Insights (computed from
`study_sessions` + `flashcards`, never from counters).

---

## 6. Design system

Tokens in `core/theme/`: `AppColors`, `AppRadius`, `AppSpacing`,
`AppShadows`, `AppTextStyles`, `AppTheme`, and `SfColors` — a
`ThemeExtension` carrying brand/accent/soft-wash/ink colours. Access through
the context extension:

```dart
context.sf       // SfColors
context.scheme   // ColorScheme
context.texts    // TextTheme
context.isDark   // brightness == dark
```

Components in `core/widgets/`: `SfButton` (has `busy`), `SfCard`, `SfChip`,
`SfField`, `SfProgress` (nullable `value` = indeterminate), `SfRing`,
`SfSkeleton`, `SfEyebrow`, `SfMono`, `SoftIconTile`, `FloatingNavBar`,
`DashedBorderBox`, `MarkedText`, the async-state trio from §5, and the
custom-painted brand marks (`SfMark`, `SfLogo`, `FlowOrb`, `GoogleGlyph`).

The Flow orb in the nav bar hovers and pulses continuously (`_FlowButton` in
`floating_nav.dart`). Two controllers on deliberately mismatched periods —
2600 ms rise, 1750 ms glow — so they drift in and out of phase; a shared clock
made it read as one mechanical throb. It honours reduce-motion by parking
mid-travel. The orb is a **sibling** of the pill, not a child, because the
pill's `ClipRRect` (which exists to confine the backdrop blur) would otherwise
shear it off as it rises.

Fonts: the design specifies Geist / Geist Mono. The TTFs are **not vendored**,
so Flutter falls back to the platform font. Sizes, weights and tracking still
apply, so layout is unaffected. `pubspec.yaml` has a commented-out `fonts:`
block ready if you drop the files into `assets/fonts`.

Dark mode: `AppShadows.resolve()` returns an empty list in dark, where the
design uses borders for separation instead. Several visual bugs are therefore
light-mode-only.

### 6.1 Never use raw Material surfaces

`AlertDialog`, `ListTile` and a default `showModalBottomSheet` all bring
Material's own typography, shape and button styling. Dropped into this app they
read as if they came from a different product — this was reported as "doesn't
look suitable with the rest of the application" and had to be redone.

**Everything modal is a bottom sheet, and there are no `Dialog`s left.** The
sign-out confirmation started as an `AlertDialog`, was rebuilt as a custom
`Dialog`, and is now a sheet — sheets read as more considered, and having one
modal idiom is worth more than picking the "correct" one per case.

The primitives live in `core/widgets/sf_sheet.dart`:

- **`showSfSheet<T>()`** — the only way to open a sheet. Transparent
  background, branded scrim, `showDragHandle: false`.
- **`SfSheetShell`** — the shared chrome: canvas background, 28pt top corners,
  hairline border, grabber, bottom safe-area padding. Every sheet wraps its
  content in it, so they cannot drift apart.
- **`SfConfirmSheet`** — a yes/no question: centred icon, heading, body, then
  stacked confirm/cancel buttons. `destructive: true` (the default) makes it
  coral. Used for sign-out and for the exit-app confirmation. Pops `true`/
  `false`; a scrim or swipe dismiss yields **null**, which callers must treat
  as "not confirmed".

Feature-specific sheets stay with their feature — `_ThemeSheet` in
`profile_screen.dart` is a picker rather than a confirmation, so it wraps
`SfSheetShell` directly with a left-aligned eyebrow + heading and option cards.

Specifics learned building these:

- **A transparent sheet must also pass `showDragHandle: false`.** `AppTheme`
  sets `showDragHandle: true`, and Flutter draws that handle *above* the
  builder's content. With a transparent background it floats on the scrim
  beside the sheet's own grabber — two handles, one apparently in mid-air.
  `_showSfSheet` handles this; the theme default is left on so a sheet keeping
  the standard surface still gets one. Rule: if you take over the background,
  you take over the handle.
- **A sheet body sits on `scaffoldBackgroundColor`, not `scheme.surface`.**
  Cards inside it are `surface`; using `surface` for both makes the rows vanish
  into their own background.
- **A selected row needs a border, not just a fill.** In dark mode
  `sf.indigoSoft` is nearly the surface colour, so a fill alone barely reads.
- **Stack modal buttons, do not put them in a `Row`.** At text scale 1.3 two
  side-by-side `SfButton`s each ellipsis to a few characters.
- `SfButtonVariant.secondary` is `bg: scheme.surface`, so it is near-invisible
  *on* a surface. Use `ghost` for a quiet action on a card.
- **Write modal tests against text, not widget type.** The sign-out test
  survived the `AlertDialog` → `Dialog` → sheet migration untouched because it
  looks for `'Sign out?'` and `'Cancel'` rather than `find.byType(Dialog)`.

---

## 7. Layout traps already hit (do not reintroduce)

These were real device bugs, each with a general lesson:

1. **Fixed-height horizontal rails clip text.** A `SizedBox(height: 118)` around
   a rail of text-driven cards overflowed by 1px on a real device because the
   device font is taller than the test font. Rails are now content-sized
   (`SingleChildScrollView` + `IntrinsicHeight` + stretched `Row`).
2. **A content-sized scroll view clips its children's shadows.**
   `SingleChildScrollView` defaults to `Clip.hardEdge`, so the rail is exactly
   as tall as the cards and shears `AppShadows.sm` off. Fixed with vertical
   padding sized by `AppShadows.smBleedTop` / `smBleedBottom` — padding sits
   *inside* the viewport, unlike `Clip.none` which would let cards spill
   sideways.
3. **The floating nav bar's `SafeArea` moves it, but constants don't follow.**
   On three-button-navigation devices the pill floats a system inset higher.
   Use `sfNavContentInset(context)` for bottom padding — never
   `kFloatingNavHeight` alone.
4. **`ClipRRect` around a `BackdropFilter` clips its children too.** The Flow
   orb was sheared when it rose above the pill. It is now a **sibling** of the
   pill in a `Stack(clipBehavior: Clip.none)`, with a `SizedBox(_kFlowSize)`
   holding its slot in the nav row.
5. **`CrossAxisAlignment.stretch` in an unbounded `ListView` throws.** Wrap in
   `IntrinsicHeight`.
6. **A `BoxDecoration` with `borderRadius` requires a *uniform* border.** The
   planner's subject stripe is a clipped child, not a `Border.left`.
7. **`late final` + `AnimationController` is a disposal hazard.** A lazy field
   whose first read lands in `dispose()` builds a Ticker against a dead
   element. Assign controllers in `initState`.
8. **Uppercase + letter-spacing measures wider than it looks** — trailing
   tracking counts. `SfEyebrow` wraps its text in `FittedBox(scaleDown)` and
   should be given a `Flexible` parent in constrained rows.
9. **A loading placeholder can overflow the space it stands in for.**
   `SfLoadingList` sizes its row count with `LayoutBuilder`, because it is used
   both inside an `Expanded` (bounded) and as a list child (unbounded).
10. **A fixed-height card cannot hold text at every scale.** The 360pt
    flashcard faces let their middle band flex and scroll; at text scale 1.3
    the question alone exceeded the card.

---

## 8. Tests

`test/widget_test.dart` — 99 tests:

- Flow tests: splash → onboarding → auth → shell, empty-submit rejection,
  stored-session routing, tab switching, quiz run, flashcard flip, chat reply.
- Modal tests: the appearance sheet opens/applies, the sign-out dialog opens and
  cancels. **The layout sweep cannot reach these** — a sheet or dialog is not
  built until something taps it open, so any new one needs its own test.
- Theme persistence: a stored value is applied on launch; picking one writes it.
- A layout sweep: every screen × both brightnesses × text scales 1.15 and 1.3 ×
  a narrow 340×760 phone. The narrow pass exists because a real device reported
  `smallestScreenWidthDp=359` and the suite was only testing 390.

**The suite is hermetic — it never initialises Supabase, never touches the
network, and never loads the shared_preferences plugin.** Everything is faked at
a seam (`test/fakes/`). If you add a repository, add a fake and register it in
`_scope()` or every screen test will fail with "You must initialize the supabase
instance".

Harness notes:

- `pumpAndSettle` **cannot** be used: `FlowOrb` and `SfSkeleton` repeat
  indefinitely by design, so the tree never settles. Use the `_settle()` helper
  that pumps a fixed number of frames.
- To find an overflow's source, temporarily replace
  `expect(tester.takeException(), isNull)` with `expect(1, 1); // DEBUG` and
  re-run — `takeException` swallows the creator chain that names the file and
  line.
- Anything low on the Profile settings list (Sign out, for one) starts below the
  fold — call `tester.ensureVisible` before tapping. Once scrolled there, the
  profile hero is off-screen, so do not assert on the user's name.
- **`ensureVisible` is not enough for Home.** `ListView(children: […])` still
  builds lazily, so a card below the fold is not in the tree at all and
  `ensureVisible` throws `Bad state: No element`. Use
  `tester.scrollUntilVisible(finder, delta, scrollable: …)`, which scrolls
  until the widget is *created*.
- Use `tester.binding.handlePopRoute()` to exercise the **system** back button.
  Tapping an in-app back widget does not go through `PopScope`.
- `_scope()` takes `prefs:` for seeding stored preferences and `signedIn:` for
  starting with a session.

---

## 9. Standing constraints and open work

**Not built, and each for a stated reason:**

- **Google sign-in.** Needs a Google Cloud OAuth client configured in the
  Supabase dashboard. The button currently says so plainly rather than
  pretending. Wiring it also needs a deep-link intent-filter in
  `AndroidManifest.xml`. (The Apple button was removed from the Auth screen.)
- **The AI.** Chat replies still come from the scripted table in
  `chat_models.dart`; summaries and quizzes are seeded rows. The *transcript*
  is real (persisted to `chat_threads`/`chat_messages`). Wiring an LLM was kept
  deliberately separate from wiring the backend.
- **`study_sessions` is never written.** Table, `logSession()` and the Insights
  charts all exist, but nothing calls it — there is no study timer in the UI
  yet. Insights will read zero until one is added. **This is the most likely
  next task.**
- **Summary bookmarking is in-memory.** No bookmarks table; inventing one to
  back a single icon is schema the app does not need yet.
- **Upload progress is indeterminate.** The Supabase SDK reports no byte counts
  for a single upload, so `SfProgress` takes a nullable value. A fabricated
  percentage would look better and be a lie.
- **Search bar is decorative.** Tapping does nothing; no search is implemented.
- **No pull-to-refresh anywhere.** Home and Materials both had a
  `RefreshIndicator`; both were removed on request. Their providers are *not*
  autoDispose (shell-resident), so data now refreshes only on restart or via an
  explicit `invalidate` — upload invalidates the library, ticking a task
  invalidates today's blocks. **Editing a block in the Planner will not update
  Home's "Today" list** until something rebuilds it. Wire an invalidate if that
  becomes visible.
- **Premium is a paywall mockup.** No billing.

**Deliberately removed — do not "restore" these thinking they were lost:**

- **Profile → Connections group** (Calendar, Apple ID). Both rows were inert
  with hard-coded "Connected"/"Linked" details.
- **Profile → Component library row.** `ComponentsScreen` still exists and is
  still covered by 6 sweep tests, so it works as a design reference — there is
  just no route to it any more.
- **Auth back button.** Auth is now a dead end: arriving from Onboarding leaves
  no way back to the value story. Normal for a sign-in screen; noted in case it
  should change.
- **Auth "Continue with Apple" button.** Only Google remains.
- **Home / Materials pull-to-refresh** — see the bullet above for what that
  costs.
- **Every `Dialog` and `AlertDialog`.** All modals are bottom sheets now (§6.1).
  `grep showDialog lib/` returns nothing, and that is intentional.
- **`setState`.** Zero occurrences in `lib/`. Controllers still live in
  `StatefulWidget`s (§4), but nothing calls `setState`.
- **`ShellPage.exams` and `ShellPage.analytics`.** Exams and Insights are
  pushed routes now, not tabs. Putting them back in the enum reintroduces four
  reported bugs at once — see §3.2.

---

## 10. Android build notes

**This project is on AGP 9.0.1** (`android/settings.gradle.kts`), which is what
Flutter 3.44's template generates. AGP 9 compiles Kotlin through **built-in
Kotlin** rather than a separately applied Kotlin Gradle Plugin, and that breaks
plugins which have not migrated.

**Do not use `file_picker`.** Version 11.0.3 has this in its `android/build.gradle`:

```groovy
def isAgp9OrAbove = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION
    .tokenize('.')[0].toInteger() >= 9
apply plugin: 'com.android.library'
if (!isAgp9OrAbove) { apply plugin: 'org.jetbrains.kotlin.android' }
```

On AGP 9 it skips KGP but never opts into built-in Kotlin, so its `.kt` sources
are silently not compiled. The build then fails at Java link time with:

```
GeneratedPluginRegistrant.java:24: error: cannot find symbol
  ...new com.mr.flutter.plugin.filepicker.FilePickerPlugin();
symbol: class FilePickerPlugin
```

The misleading part is that the class *does* exist in the package — it just was
never built. `flutter clean` does not help; this is not a stale artifact.

`file_picker` **10.3.3** works (it always applies KGP) but emits the "plugins
that apply Kotlin Gradle Plugin (KGP)" deprecation warning and will break on a
future Flutter. Pinning to it is a stopgap, not a fix.

**We use `file_selector` instead.** `file_selector_android` applies only
`com.android.library` and configures a top-level `kotlin { }` block — the
correct AGP 9 pattern — and it is flutter.dev first-party, so it tracks Flutter
releases. API in `upload_view_model.dart`:

```dart
const documents = XTypeGroup(label: 'Documents', extensions: [...]);
final XFile? picked = await openFile(acceptedTypeGroups: [documents]);
// picked.path / .name / .mimeType / await picked.length()
```

`XTypeGroup` on Android needs `extensions` **or** `mimeTypes` non-empty or it
throws `ArgumentError`.

**General rule:** if a plugin fails with "cannot find symbol" on its own plugin
class, check whether its `android/build.gradle` has migrated to built-in Kotlin
before assuming a caching problem.

**Manifest:** `INTERNET` is declared explicitly — Flutter's debug manifest grants
it implicitly, so a release build would otherwise fail where debug worked.
`android:enableOnBackInvokedCallback` is deliberately **not** set; the log
warning about it is benign and enabling it changes back-gesture behaviour.

---

## 11. Working notes for whoever picks this up

- **PowerShell corrupts UTF-8 on rewrite.** `Get-Content -Raw` +
  `Set-Content -Encoding utf8` in PS 5.1 double-encodes em-dashes (`—` →
  `â€”`). Use the Edit/Write tools, or `sed` via Git Bash, for text edits. This
  file and the codebase are full of em-dashes.
- **`python` is not on PATH** on this machine; `node` is. Prefer `sed` for bulk
  edits.
- **The IDE may open the project through WSL** (`/mnt/c/...`) while
  `.dart_tool/package_config.json` holds Windows paths (`file:///C:/...`,
  `file:///D:/flutter_sdk/...`). If the analyser reports unresolved imports that
  `flutter analyze` does not, that mismatch — or a stale analysis server after a
  dependency change — is the cause. Restart the Dart Analysis Server first.
- Run `flutter analyze` **and** `flutter test` after any change. Both were clean
  at the time of writing and should stay that way.
