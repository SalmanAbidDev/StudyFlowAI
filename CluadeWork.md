# StudyFlow AI — project handoff

Read this first if you are picking this project up cold. It covers what the app
is, how it is put together, the decisions behind that structure, and the traps
already discovered so you do not rediscover them.

Last updated: 2026-08-10.

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
| File picking | `file_picker` ^11.0.3, `path` ^1.9.1 |
| Lints | `flutter_lints` ^6.0.0 |

**Health check** — both should be clean before and after any change:

```bash
flutter analyze     # expect: No issues found!
flutter test        # expect: 93 tests, all passing
```

**Running it** — credentials come in at build time, so a bare `flutter run`
will throw a deliberate `StateError` telling you what to do:

```bash
flutter run --dart-define-from-file=dart_define.json
```

---

## 2. Supabase project

**Project:** `StudyFlowAI` · ref `cwriehotskhrekxyobvt` · region ap-northeast-1
· Postgres 17 · URL `https://cwriehotskhrekxyobvt.supabase.co`

Credentials live in `dart_define.json` at the repo root, which is **gitignored**.
`dart_define.example.json` is committed as the template. If the real file is
missing on a new machine, copy the example and fill it from the dashboard
(Project Settings → API keys). Use the **publishable** key (`sb_publishable_…`),
never `service_role` — that one bypasses RLS entirely and must never appear in
the app.

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
  main.dart                     runApp + Supabase.initialize only
  app/
    app.dart                    StudyFlowApp (root MaterialApp)
    theme_mode_view_model.dart  app-scoped: themeModeProvider
  core/
    config/supabase_config.dart --dart-define reader + startup assert
    theme/                      design tokens (8 files, barrel: theme.dart)
    widgets/                    shared components (barrel: widgets.dart)
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

**Why flat inside each feature** rather than `view/` + `view_model/`
subfolders: with one or two files each that is depth without information. The
`_screen` / `_view_model` / `_models` suffixes carry the MVVM roles.

**Where state lives is decided by lifetime**, not by convenience:

- `themeModeProvider` → `lib/app/` because the theme outlives every screen.
- `shellPageProvider` → `features/shell/` because the shell owns navigation;
  Home, Planner, Profile, Exams and Insights all import it.
- Everything else is feature-private.

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
`DashedBorderBox`, `MarkedText`, and the custom-painted brand marks
(`SfMark`, `SfLogo`, `FlowOrb`, `GoogleGlyph`).

Fonts: the design specifies Geist / Geist Mono. The TTFs are **not vendored**,
so Flutter falls back to the platform font. Sizes, weights and tracking still
apply, so layout is unaffected. `pubspec.yaml` has a commented-out `fonts:`
block ready if you drop the files into `assets/fonts`.

Dark mode: `AppShadows.resolve()` returns an empty list in dark, where the
design uses borders for separation instead. Several visual bugs are therefore
light-mode-only.

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

---

## 8. Tests

`test/widget_test.dart` — 93 tests:

- 6 flow tests (splash → onboarding → auth → shell, empty-submit rejection,
  stored-session routing, tab switching, quiz run, flashcard flip, chat reply).
- A layout sweep: every screen × both brightnesses × text scales 1.15 and 1.3 ×
  a narrow 340×760 phone. The narrow pass exists because a real device reported
  `smallestScreenWidthDp=359` and the suite was only testing 390.

**The suite is hermetic — it never initialises Supabase and never touches the
network.** The whole data layer is faked at the repository seam
(`test/fakes/`). If you add a repository, add a fake and register it in
`_scope()` or every screen test will fail with "You must initialize the
supabase instance".

Two harness notes:

- `pumpAndSettle` **cannot** be used: `FlowOrb` and `SfSkeleton` repeat
  indefinitely by design, so the tree never settles. Use the `_settle()` helper
  that pumps a fixed number of frames.
- To find an overflow's source, temporarily replace
  `expect(tester.takeException(), isNull)` with `expect(1, 1); // DEBUG` and
  re-run — `takeException` swallows the creator chain that names the file and
  line.

---

## 9. Standing constraints and open work

**Not built, and each for a stated reason:**

- **Google / Apple sign-in.** Needs provider credentials configured in the
  Supabase dashboard (a Google Cloud OAuth client, an Apple Services ID). The
  buttons currently say so plainly rather than pretending. Wiring them also
  needs a deep-link intent-filter in `AndroidManifest.xml`.
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
- **Premium is a paywall mockup.** No billing.

**Android manifest:** `INTERNET` is declared (Flutter's debug manifest grants it
implicitly, so release builds would otherwise fail where debug worked).
`android:enableOnBackInvokedCallback` is **not** set — the log warning about it
is benign, and enabling it changes back-gesture behaviour, so it was left as a
decision for the owner.

---

## 10. Working notes for whoever picks this up

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
