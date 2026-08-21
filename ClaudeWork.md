# StudyFlow AI — project handoff

Read this first if you are picking this project up cold. It covers what the app
is, how it is put together, the decisions behind that structure, and the traps
already discovered so you do not rediscover them.

Last updated: 2026-08-18.

**Where the project stands.** Built from a design file as UI-only → restructured
to MVVM + Riverpod → connected to Supabase (auth, 16 tables with RLS, storage)
→ visual polish. It runs on device: sign-up, sign-in, real data on every screen,
five upload sources into a private bucket, an in-app viewer for whatever you
uploaded, persisted theme. What is *not* built is listed in §9, with a reason
for each — read that before assuming something is missing by accident.

**Invariants worth not breaking.** Each is explained in the section named:

| | |
|---|---|
| No `setState` anywhere in `lib/` | §4 |
| No `Dialog`/`AlertDialog` — every modal is a bottom sheet | §6.1 |
| No raw `MaterialPageRoute` — routes go through `sfRoute`/`sfModalRoute` | §3.2 |
| `ShellPage` holds the four tabs and nothing else | §3.2 |
| No raw `ListTile` in a sheet — it drags Material's typography in | §6.1 |
| Tests never touch the network or a platform channel | §8 |
| No hard-coded stats — say nothing rather than something false | §5.1 |
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
| Backend | `supabase_flutter` ^2.17.1 (+ `http` for streamed uploads, §5.5) |
| File picking | `file_selector` + `image_picker` (both flutter.dev) — **not** `file_picker`, see §10 |
| Web preview | `webview_flutter` (flutter.dev), for From-URL and saved links |
| PDF rendering | `pdfrx` — brings its own zoom, see §5.3.2 |
| Local storage | `shared_preferences` (theme + notifications preference) |
| Lints | `flutter_lints` ^6.0.0 |

**Health check** — both should be clean before and after any change:

```bash
flutter analyze     # expect: No issues found!
flutter test        # expect: 165 tests, all passing
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
profiles ──1:1── auth.users          full_name, is_pro  (streak_days exists
                                     but is unmaintained — §5.1)
subjects                             name, accent (enum), icon (text key)
  ├── materials                      title, page_count, storage_path, progress,
  │                                  source_url (link-only materials — §5.3)
  │     ├── summary_sections         position, title, bullets[], read
  │     ├── decks ── flashcards       question, answer, ease, interval_days, due_at
  │     └── quizzes                  
  │           └── quiz_questions     
  │                 └── quiz_options  label, body, is_correct
  ├── study_blocks                   scheduled_on, starts_at, ends_at, position, done
  ├── exams                          exam_date, exam_time, priority
  │     └── exam_materials           what it is revised from
  └── study_sessions                 started_at, duration_minutes, focus_score
quiz_attempts                        correct, total, elapsed_seconds, missed[]
chat_threads ── chat_messages        role (enum), content, sources[]
achievements                         code, earned_at   (name/detail/icon
                                     live in the app — §5.2)
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
20260817072046  starter_content_starts_unread
20260817072750  seed_guard_uses_explicit_marker
20260818084433  materials_source_url
20260820091317  exam_editor_time_priority_and_materials
20260820110100  study_blocks_link_material_or_exam
20260820130440  flashcards_difficulty
```

`profiles` gained `starter_seeded_at timestamptz` in the last one.

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
  `study_blocks.duration` — and later removed `exams.preparation` outright
  (§5.7).
- **Storage objects are keyed `<user-id>/<timestamp>-<name>`.** The bucket
  policies compare the first path segment to `auth.uid()`. That, not the bucket
  being private, is what stops one account reading another's files. Do not
  change the key format without updating the policies.
- **Deleting a material cascades its `summary_sections`, but decks and quizzes
  only lose their `material_id`** (`ON DELETE SET NULL`). They survive as
  orphans. `deleteMaterialsProvider` also removes the storage object — **row
  first, file second**, deliberately: a failed file delete leaves invisible
  wasted space, whereas deleting the file first and then failing on the row
  leaves a material that opens onto nothing.
- **Trigger functions have `EXECUTE` revoked** from `anon`/`authenticated`.
  Being `SECURITY DEFINER` they were reachable at `/rest/v1/rpc/…`. Triggers
  still fire — Postgres does not check `EXECUTE` for trigger invocation.

### 2.4 Known advisor warning (not ours)

`public.rls_auto_enable()` is flagged as a public `SECURITY DEFINER` function.
It is a **Supabase platform event trigger** that auto-enables RLS on new tables,
not something this project created. It is harmless (an event-trigger function
errors if called directly). Left alone deliberately — do not "fix" it.

### 2.5 Starter content

`seed_starter_content()` (SECURITY INVOKER) fills a brand-new account with four
subjects, three materials with a summary, a deck, a quiz, today's blocks, exams
and achievements. `HomeScreen` watches `starterContentProvider`, which calls it
once. `anon` has no `EXECUTE`; `authenticated` does.

**Everything it writes starts at zero.** Materials at `progress = 0`, sections
unread, blocks not done, exams at `preparation = 0`, achievements unearned. It
originally seeded 42% / 78% progress and two ticked blocks, which made a
brand-new account show a resume card and a streak week it had not earned —
every "what have you done" surface was lying on first run. The library is there
to explore; the progress on it has to be earned.

**The guard is `profiles.starter_seeded_at`, not "does this user have any
subject".** The old guard conflated *never seeded* with *deleted everything*,
so a user who cleared their library would have it dumped back on them at next
launch. Seeded once, ever.

To re-seed an account (the whole point of the marker being nullable):

```sql
update public.profiles set starter_seeded_at = null where id = '<user>';
```

**This is a product decision, not a technical requirement.** Without it a new
account lands on empty screens, which can read as broken rather than new.
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
    config/ai_config.dart       function name + limits. **No key** (§5.5.2)
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
                                flashcard, summary_section, quiz, profile,
                                achievement (catalogue + progress — see §5.2)
    repositories/               auth, library, planner, study, profile,
                                analytics, chat, storage, ai
  features/<name>/
    <name>_screen.dart          View
    <name>_view_model.dart      ViewModel (providers)
    chat_models.dart            Model — chat is the only feature with enough
                                model surface to warrant its own file
```

19 feature folders: analytics, auth, categories, chat, components, documents,
exams, flashcards, home, materials, onboarding, planner, premium, profile,
quiz, shell, splash, summaries, upload.

**There is a server half too**, which is easy to miss because it is not Dart:

```
supabase/functions/ai/index.ts   the only thing that talks to Gemini (§5.5.2)
```

It is deployed separately from the app — changing the model, a prompt or the
daily allowance is a function deploy, not a release. Nothing in `lib/` holds
an API key.

`exams/` is three screens: the list, `exam_editor_screen.dart` (add and edit
share one screen) and `exam_detail_screen.dart`.

`materials/` carries more than its own tab, because five surfaces now show the
library (§5.5.1): `material_browser.dart` (the shared row and searchable list),
`history_screen.dart`, `pick_material_screen.dart`, and
`generated_empty_view.dart`. It also owns the AI-facing pieces that three
features share: `generate_view_model.dart` and `generate_button.dart` (the
`GenerateBar` under every empty practice screen) and `study_progress.dart`
(§5.5.3).

`planner/` is the screen plus `block_editor_screen.dart` (add and edit share
one screen, like the exam editor).

Two of those are one screen apart and easy to confuse: **`documents/` is what
opens when you tap a material** (the file itself — §5.3.2), and `summaries/`
is the AI section list behind its Summarize button. `summaries_view_model.dart`
still owns `selectedMaterialProvider` and `summaryMaterialProvider`, which both
screens read — set the selection *before* pushing either.

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

**The affordance decides the helper.** Upload, Paste text, Flashcards, Quiz,
Quiz results, Category and Premium have a ✕ and are modal; Chat, Document,
Summaries, Auth and the shell have a back arrow and are pushes. A modal deliberately has no back-swipe — it is
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
- Pushed routes (Quiz, Chat, Flashcards, Upload, Document, Summaries, History,
  Pick material, Onboarding, Auth, Premium) died with the route → their
  providers **are** autoDispose, so reopening gives a clean slate. Without
  this, reopening the quiz would resume the previous run's score — and
  `documentBytesProvider` would keep every PDF you had opened resident for the
  session.
- **Two exceptions, both deliberate:** `selectedMaterialProvider` (which
  document the app is working on) and `chatDocumentProvider` (which document
  Flow is holding) are **not** autoDispose. They are set by one screen and read
  by the next, so disposing them with the route that set them would lose the
  answer between the picker and the deck.

**Timers belong to the provider, not the widget.** The quiz clock is created in
`build()` and cancelled via `ref.onDispose`. This removed several
`if (!mounted) return` guards. (Chat used to hold a second one — a 1.4 s fake
latency before a scripted reply. Both are gone; see §5.6.)

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

### 5.1 Say nothing rather than something false

Home shipped from the design full of hard-coded claims — a five-day streak, a
resume card, "3 tasks · 2h 15m", "you scored 60% last time". All of it read as
real. Every one is now derived, and **the empty case hides or states itself
rather than rendering a zero**:

| Surface | Source | With nothing to show |
|---|---|---|
| Streak week strip | `weekActivityProvider` — this week's `study_blocks` | no ticks; today is a dot, future days dimmer |
| Pick up where you left off | `resumeMaterialProvider` — `0 < progress < 1` | **whole section absent** |
| Today subtitle | `todaySummaryProvider` | `label` is null → header shows just "Today" |
| Next exam | `nextExamProvider` | message only — no countdown, no `0% prepared` bar |
| Flow suggests | `flowSuggestionProvider` | "Nothing to suggest yet"; button hidden |
| Recent materials | `materialsProvider` | an upload prompt; "All" action hidden |

**Profile's three stat cards** went the same way. They were `'12d'`, `'124h'`
and `'342'` — string literals shown to every account. `profileStatsProvider`
now derives all three, and Home's streak hero reads the same provider so the
two screens cannot disagree.

The interesting part is *what they are derived from*. Two obvious sources were
wrong: **`profiles.streak_days` is a stored column nothing ever writes**, and
**`study_sessions` is never inserted into** (§9). Reading either would have
swapped three hard-coded numbers for three permanently stuck ones — arguably
worse, because a stuck zero looks like a working feature.

| Card | Source | Why that one |
|---|---|---|
| Streak | consecutive days with a completed `study_blocks` row | `setBlockDone` writes it on every tick |
| Studied | summed minutes of completed blocks | same rows, and start/end times are real |
| Mastered | `flashcards.interval_days >= 21` | `reviewCard` writes it |

`streakFrom` does **not** break the streak when today has nothing ticked yet —
the day is still running, so it counts back from yesterday in that case.
Breaking someone's streak at breakfast is the version of this that gets
uninstalled. A block with no start/end time counts toward the streak but
contributes zero minutes: it happened, we just cannot say for how long.

`masteredCount()` is deliberately separate from `stats()`'s range filter —
mastery is a running total, not something that happened this week, so it must
not change when Insights switches between Week and Year.

Every path that ticks a block (`toggleBlockDoneProvider` **and**
`PlannerBlocks.toggleDone`) invalidates `profileStatsProvider` and
`weekActivityProvider`. Both, not one — the Planner had its own toggle that
would otherwise have moved the checkbox without moving the streak.

Two rules worth carrying to other screens:

- **An absent section beats an empty card.** "Pick up where you left off" on a
  fresh account is a promise the app cannot keep, so it is not rendered at all.
- **Do not render a zero for a thing that does not exist.** The exam card used
  to show `—` above a 0%-filled bar labelled "0% prepared", describing an exam
  nobody had scheduled.
- **"Nothing matched" is not "nothing here yet".** Materials distinguishes
  them (`materialsFilteredToNothingProvider`): a search with no hits offers
  *Clear search*, an empty library points at the header ＋. Showing an upload
  prompt to someone whose library is full but whose query missed is nonsense.

**`flowSuggestionProvider` is a rule, not a model.** There is still no AI (§9).
It reasons over real rows in priority order — a quiz attempt below 80% names
the missed topic and the true score; failing that, the least-progressed
material; failing that, nothing. Returning null is a valid outcome and the
card handles it. Do not "improve" this by inventing copy.

**`plannerNoteProvider` is the same shape**, for the gradient line under the
Planner's week strip. That line used to read "Flow planned your day around
your Organic Chem final in 9d" on *every* account — a claim about work Flow
had not done, naming an exam that did not exist, on libraries with nothing in
them. It is now gated on having uploaded something (`latestMaterial()`): no
material → the banner is absent; material but no exam → it asks for an exam
date; material and an exam → it names that exam and counts down to it, with
`0` and `1` days rendered as "today" and "tomorrow" rather than "in 0d". The
screen reads `.value`, so a loading fetch is also "say nothing" and the list
never gets shoved down by a late arrival.

### 5.1.1 One source of truth per subject — derive, do not re-query

**Every question about the library is answered downstream of
`materialsProvider`.** "Pick up where you left off"
(`resumeMaterialProvider`), Flow's fallback suggestion
(`flowSuggestionProvider`) and the Planner banner (`plannerNoteProvider`) all
`await ref.watch(materialsProvider.future)` and filter in Dart.

They used to be three independent repository queries — `resumeMaterial()`,
`leastProgressed()`, `latestMaterial()` — each its own cached `FutureProvider`.
That meant every writer had to remember to invalidate all of them by name, and
**nothing ever invalidated `flowSuggestionProvider` at all**: deleting the last
document left Home recommending it, indefinitely, until the app restarted. The
first two repository methods are deleted so the pattern cannot come back.

`StudyMaterial` carries `updatedAt` for this — "most recently touched" is not
"most recently added", and the resume order would otherwise have quietly
changed when the query moved into Dart.

The rule generalises: **a second way to ask the same question is a second
thing to invalidate, and the one you forget is the bug.** If a new provider
needs to know something about the library, derive it here rather than adding a
query.

The exception is a *different* subject. `flowSuggestionProvider` also reads the
latest quiz attempt, which the library knows nothing about, so
`QuizController.recordAttempt` invalidates it explicitly.

### 5.2 Catalogue in the app, progress in the database

`achievementCatalogue` in `data/models/achievement.dart` defines what badges
exist — code, name, criterion, icon, accent. The `achievements` table stores
only `code` + `earned_at`: *which* ones this user has earned.

It was the other way round, seeded as four rows per account, and that was
wrong three ways: every user carried a duplicate of the same list, adding a
badge would need a backfill across all of them, and **deleting the rows made
the feature vanish from the UI** rather than showing an unearned set. That last
one is how it was found — a content reset emptied the table and the Profile
rail rendered nothing under a live "Achievements" header.

`achievementsProvider` composes the two and is **never empty**, sorted earned
first. Anything with a fixed set of options and per-user progress against it
belongs in this shape.

### 5.3 Upload sources

`UploadSource` (`upload_view_model.dart`) is the single list of where a
material can come from: `pdf`, `camera`, `photos`, `text`, `url`. Both surfaces
iterate `UploadSource.values` — the sheet behind "Browse files" and the "Or add
from" grid on the Add-material screen — so the two cannot drift apart. The grid
lays out two per row and leaves the odd cell empty rather than stretching the
last tile.

`usesPicker` is true for the three that open a system picker and run through
`pickAndUpload`. `text` and `url` produce a material too, but from their own
screens — there is no file on disk to pick, so `pickAndUpload` throws
`UnsupportedError` if one reaches it, which would be a caller bug.

**Paste text** (`PasteTextScreen` + `paste_text_view_model.dart`) uploads the
body as `text/plain` into the same bucket, so nothing downstream has to know it
was never a file. Two gates, both *stated* rather than left to a dim button:
under `kMinWords` (50) there is not enough to study, over `kMaxWords` (1000) it
should have been a document. **The ceiling is soft** — typing past it is
allowed and the counter turns coral, because truncating a long paste silently
loses its tail. `countWords` splits on `\s+` after trimming; `split(' ').length`
miscounts newlines and trailing spaces in both directions. The title field
pre-fills from the opening words and stops tracking the body the moment the
user types in it (`_titleEdited`, with `_writingTitle` guarding the
controller's own listener against this class's writes).

**From URL** (`_UrlSheet` → `UrlPreviewScreen`) saves **only the link**, in
`materials.source_url` — there is no file, so `storage_path` cannot carry it.
The sheet checks reachability with a **600 ms debounce** (one request per
hostname, not per keystroke) and a **generation counter** so a slow earlier
request cannot overwrite a newer verdict. `_reach` tries HEAD then GET: plenty
of sites answer 405 or 403 to HEAD while serving the page fine. `normaliseUrl`
adds `https://` when the scheme is missing — nobody types it — and rejects a
host with no dot as a typo rather than a site. The preview screen renders the
page in a `WebViewWidget` and reads its `<title>` for the material name, since
a raw URL is unreadable in a list; it says on screen that only the link is
saved, because "Proceed" over a rendered page otherwise reads as "save this
page".

Presentation (`sourceStyle`) lives in the screen, not on the enum: the colours
are theme lookups and the view model has no `BuildContext`.

**Two bucket constraints are duplicated client-side, deliberately**
(`_mimeByExtension` and `_maxBytes`). Without them the server rejects the file
*after* it has been transferred and the user gets a raw `StorageException`
instead of a sentence. They mirror `allowed_mime_types` and the 50 MB cap in
§2.1 — **change one, change the other.** The upload also states its
`contentType` rather than letting storage sniff it, because a camera capture
arriving as `application/octet-stream` is rejected on a file the bucket should
accept.

Camera captures get a generated name and a dated title (`Scan · Aug 18, 14:32`)
— image_picker hands back a cache name like `image_picker_1234.jpg`, which
would otherwise become the material's title. They are also downscaled
(`maxWidth: 2400, imageQuality: 85`): a full-resolution capture is a slow
upload on a phone connection and no more legible.

### 5.3.1 Library multi-select

Long-press a material to start a selection; after that a plain tap toggles
rows, a tick box animates in on the left of **every** row, the header becomes
"N selected", the search bar and subject pills fold away, and a ⋮ button
appears beside the ＋ holding one action: Delete.

- **`materialSelectionProvider` is a `Set<String>`, and empty *is* "not
  selecting"** (`materialSelectionModeProvider` derives it). There is no second
  bool to fall out of step with the set — the usual failure being a mode with
  nothing selected, or ticks showing with the mode off.
- **In selection mode a tap toggles instead of opening.** Otherwise the two
  gestures compete and you open a document you meant to tick.
- **`_SelectionBox` animates the *space*, not just the box** —
  `Align(widthFactor:)` inside a `ClipRect`, so the row slides over to make
  room rather than having a tick appear on top of it.
- **System back unwinds a selection before the tab.** `AppShell._handleBack`
  checks selection first, then the tab, then offers to close the app. Losing a
  multi-select to a stray back is the same annoyance as losing a form.
- **`deleteMaterialsProvider` returns the failures rather than throwing.** A
  batch is not all-or-nothing; reporting "3 deleted" when two succeeded is the
  wrong lie in the wrong direction, so the snackbar says "Couldn't delete 1 of
  3" instead.
- The confirmation copy is count-aware, and the ⋮ sheet states the scope
  before offering the action — a destructive menu that does not say what it
  acts on is how people delete more than they meant to.

### 5.3.2 The document screen

Tapping a material opens `DocumentScreen`, which **shows the thing** rather
than describing it. It replaced a screen whose header said "Summary" for every
material and whose body was a list of AI sections — so an uploaded PDF was
never actually visible anywhere in the app.

- The header eyebrow is `material.kind.label` — **PDF / Image / Text / Link**.
- `StudyMaterial.kind` reads `mime_type` first, then falls back to the storage
  path's extension, because rows written before `mime_type` was recorded have
  none. A `source_url` with no `storage_path` is a Link; a material with both
  is an upload.
- PDFs use `pdfrx`, which brings **its own** pinch-zoom and page scrolling — do
  not wrap it in an `InteractiveViewer`, two zoom handlers on one surface fight
  each other. Images do use one (`maxScale: 8`). `PdfViewer.data` takes a
  `sourceName` that acts as a **cache key**: it is the material id, because two
  documents sharing one name would show each other's pages. Note `maxScale` on
  `PdfViewerParams` is deprecated in favour of
  `PdfViewerSizeDelegateProviderLegacy`.
- Text renders in a `SelectableText`. A note you typed is text you may want to
  copy back out, and there is no other route off that screen.
- `documentTextProvider` decodes with `allowMalformed: true` — the bytes came
  from someone's clipboard and one bad byte should not turn the whole note into
  an error screen.
- Bytes come from `storageRepository.download()` through the authenticated
  client, not a signed URL — the bucket is private and this avoids minting a
  URL just to read our own file. `documentBytesProvider` is **autoDispose**: a
  PDF is megabytes and holding the last one you opened for the rest of the
  session is a memory leak with a nicer name.
- A Link renders centred and is tappable, opening a read-only WebView.
  Deliberately *not* `UrlPreviewScreen` — that one ends in "Proceed" and
  creates a material, which on something already in the library would file it
  twice.
- The action row is `[▣ Flashcards] [Quiz me] [◉]`. Flashcards and Quiz me keep
  their labels; the Flow orb alone takes the slot a dead Share button used to
  hold. The orb goes in `SfButton`'s `leading` slot — including on
  `SfButton.iconOnly`, which now takes either an `icon` glyph or a `leading`
  widget — because the orb is painted, not a font character.
- **Summarize is the header's icon button**, in the slot a bookmark used to
  hold: the same `SfIconButton` the bookmark was, with `auto_awesome_rounded`
  in place of the bookmark glyph and tinted `scheme.primary` — it is the one
  control on the screen that invokes Flow. It pushes `SummariesScreen`, which
  keeps the expandable sections and lost its own action row. Its provenance
  banner is conditional now (§5.5.2), and the screen **generates** the summary
  rather than reading a seeded one.

  Two placements were tried and rejected before that. A **floating gradient
  pill** over the bottom-right of the viewer, on the reasoning that a document
  wants every pixel of height — wrong the moment the body became the real
  document rather than a summary, because the pill then sat *on top* of the
  thing it was asking you to read, worst on a PDF where it covered the corner
  of the page. Then the **same pill moved into the header**, which fixed the
  overlap but spent a third of the header's width on a word the icon already
  says. A header slot is an icon slot.

- **The bookmark is gone from both screens**, and
  `summaryBookmarkedProvider` with it. It toggled a flag nothing persisted and
  nothing read, so the only thing it did was forget your bookmark as soon as
  you left the screen. Summaries' trailing slot is now an empty `SizedBox` of
  the same width, so the title keeps its measure. Bookmarks are worth having —
  as a column and a repository method, not as an icon that appears to work.

### 5.3.3 Profile preferences

- **Account** (`AccountScreen`) shows the signed-in email and nothing to edit
  it with. Changing an email in Supabase means a confirmation round trip to
  *both* addresses, which is a different feature from "what am I signed in
  as" — so the row says why it is fixed rather than presenting a greyed-out
  field the user keeps tapping. The address comes from the session
  (`accountEmailProvider`), not `profiles`, which does not carry it.
- **Change password** is a sheet on that screen. Length and match are checked
  *before* the round trip, so the user is told by a sentence rather than by a
  raw `AuthException`. `auth.updateUser` refreshes the session, so this does
  **not** sign them out — the sheet says so.
- **Notifications is a `Switch`, not a chevron.** There is one thing to decide
  and it is on or off; a screen to decide it on would be a screen with a single
  switch in it. `_SettingsRow` grew a `toggle`/`onToggle` pair and asserts a
  row does not do both — one that navigates *and* toggles promises two
  different things. The whole row is the tap target, not just the switch.
- The preference is stored locally like the theme. **Nothing schedules a
  reminder** (§9), so it records what the user asked for rather than describing
  anything happening.
- **Sounds & haptics is gone.** It was an inert row.
- **`Privacy & data` is the one row left with `onTap: () {}`.** It survived
  because a privacy screen is a real thing this app will need, not because it
  works. Either build it or delete it — do not leave a third inert row.

The Insights range control (Week / Month / Year) moved out of the header to its
own full-width row under the title, each third `Expanded` with
`HitTestBehavior.opaque` so the whole segment is tappable rather than just the
glyph. Beside the heading it had to shrink to fit, which made three cramped tap
targets out of the space one deserves.

### 5.4 Filing an upload — the one screen that cannot be dismissed

`CategoryScreen` opens the moment an upload lands and stays until a category is
chosen. It has **no back arrow, no close button, and `PopScope(canPop: false)`**,
and Upload reaches it with `pushReplacement` so there is nothing underneath to
fall back to. That is deliberate: "Unfiled" was every material's subject because
nothing ever asked, and an optional prompt would have left it exactly as
common.

"Category" is the existing **`subjects`** table, not a parallel taxonomy —
subjects already drive the accent, the icon, the Materials filter pills and the
Insights split, so a second concept would have meant two of everything.

- The user's own categories come first, then `categorySuggestions` (in
  `data/models/subject.dart`) **minus anything they already own**, matched
  case-insensitively. Offering "Physics" to someone who has a Physics category
  is how you get two of them.
- Nothing is written until Continue. The suggestions are a catalogue in the
  app, not seeded rows (the §5.2 pattern).
- `ensureSubject` find-or-creates by name, matching **in Dart, not with
  `ilike`** — a name containing `%` or `_` would be read as a wildcard. There
  is no unique constraint on `(user_id, name)`, so this is the only thing
  preventing duplicates.
- Typing beats a selected chip, and each clears the other, so the screen never
  shows two answers to one question.
- A failed write leaves the screen up with the error and the button live. The
  user is trapped, so the failure path has to stay recoverable — do not make it
  a dead end.

`pickAndUpload` returns the created `StudyMaterial?` rather than a bool,
because the filing step needs its id.

### 5.5 Real upload progress

The percentage on the upload card is measured, not a timer. **The storage SDK
exposes no progress callback** — `upload()` builds a MultipartRequest and hands
the whole body over at once, so there is nothing to observe. The choice was a
real number or an invented one.

`StorageRepository.uploadMaterial` therefore takes an optional `onProgress`.
With it, `_uploadStreamed` sends the same POST as a streamed request through a
`_CountingRequest`, which counts chunks inside `finalize()`. Counting there,
rather than pushing into a `StreamedRequest` sink, is what keeps **backpressure**
intact: the http client pulls at the rate the socket accepts, so the count
tracks the transfer instead of racing ahead and buffering the whole file in
memory. Without `onProgress` the SDK path is used unchanged.

The endpoint, headers and auth token are read off the live client
(`_client.storage.url`, `.headers`, `auth.currentSession`) rather than rebuilt,
so a URL or token change follows automatically. **The cost is the SDK's retry
and backoff**, which this path does not have (§9).

Two honesty details that are easy to undo by accident:

- **Progress is capped at 0.99 while the request is open.** The count measures
  bytes handed to the socket, not bytes acknowledged; the tail of a file is
  still in flight when the count hits the total. It snaps to 1.0 only once the
  response lands, which is the one moment it is true.
- **The ETA is null until there is a sample worth using** (>1s elapsed and >2%
  sent). `transferLabel` then falls back to the size alone. An estimate from
  the first 50ms swings wildly, and "0s left" for ten seconds is worse than no
  claim at all.

`SfProgress(animated: true)` is the in-flight treatment: the width eases
between values and a highlight travels across the fill. Leave `animated` off
for settled progress on a library row. Two things about `_LiveBar`'s fill,
both of which have already gone wrong once:

- **Do not use `FractionallySizedBox`** — its default alignment is centre, so
  the bar grows outward from the middle. It takes an explicit width from
  `LayoutBuilder` instead.
- **It needs an explicit `height` too.** A Stack gives non-positioned children
  *loose* constraints and every box under the fill sizes to its child, so a
  width-only `SizedBox` collapses to zero height and leaves the grey track
  showing alone — a bar that appears never to fill. The test asserts width,
  height *and* that the decoration carries a gradient; asserting width alone
  is what let this ship.

The card sits **above** "Or add from", not below: a transfer in flight is the
most important thing on the screen while it runs, and underneath two rows of
tiles it fell off the bottom of a phone viewport.

### 5.5.1 The library, reachable from everywhere

The library used to be a destination — the Materials tab, and nothing else
could see it. Five surfaces need it now, so there is **one row widget and one
searchable list**, in `features/materials/material_browser.dart`:

- `MaterialRow` — icon, title, meta, progress. The Materials tab passes its
  selection tick as `leading`; nothing else does. A copy per screen is how the
  progress bar ends up on four of them and the fifth quietly loses it.
- `MaterialBrowser` — the whole library with a search box over it. Its query is
  **local state, not a provider**: the Materials tab keeps its own in
  `materialsQueryProvider`, and sharing one would mean typing in History
  silently filtering the tab behind it. The matching itself is
  `filterMaterials()`, a plain function both paths call.

Who uses it:

| Surface | Picking a document means |
| --- | --- |
| Materials tab | Open it (or tick it, mid-selection) |
| Add material → History | Open it. Three most recent inline, "View all" for the rest |
| History screen | Open it. Search only — no pills, no multi-select, no delete, and `showProgress: false`: the question here is what was added, not how far through it you are |
| Flashcards / Quiz picker | Build practice from it |
| Flow's "Read from" sheet | Hand it to Flow as context |

**`selectedMaterialProvider` and `currentMaterialProvider` moved out of
Summaries** into `materials_view_model.dart`. "Which document is open" is a
fact about the library; four features read it, and three of them were importing
a fourth feature's file for something that was never about summaries.

**Flashcards and Quiz ask *before* they open, but only when they have to.** From
Home nothing has been chosen, so `PickMaterialScreen` asks. From a document the
answer is already known and both screens open straight onto it — asking again
would be asking a question the app can see the answer to. Neither takes the
document as a constructor argument; both read `selectedMaterialProvider`, which
is what makes the two entry points the same screen.

`deckProvider` and `quizDataProvider` are scoped to that selection
(`deckForMaterial` / `quizForMaterial`), falling back to the newest of either
when there is no selection at all. `GeneratedEmptyView` names the document — "*Chapter 4* has
no cards yet" — with the Generate button under it. **That copy has been wrong
twice**: first "Upload a document and Flow will build a deck from it", which
was wrong once a document had been picked, then "once its AI is connected,
which it isn't yet", which stopped being true the day it was. User-facing copy
that describes the state of the *project* rather than the state of the *data*
goes stale silently — prefer the latter.

### 5.5.2 The AI

**The provider is Google Gemini** (`gemini-3.7-flash`), reached over raw HTTP.
There is no Dart SDK for it and none is needed.

**The key is never in the app.** Everything goes through the `ai` Supabase Edge
Function (`supabase/functions/ai/index.ts`), which holds `GEMINI_API_KEY` as a
server-side secret. This is not caution for its own sake: earlier in this
project we pulled the Supabase project URL straight out of a release APK with
`grep` on `libapp.so`, and a key compiled into the binary comes out the same
way. `lib/core/config/ai_config.dart` holds the function name and the limits —
**no secret, deliberately**, and the file says so.

Setting the key is a dashboard step, not a rebuild: **Edge Functions → Secrets
→ `GEMINI_API_KEY`**. The model and the daily allowance live in the function,
so changing either is a redeploy rather than an app release.

**The function reads through the caller's JWT and never uses the service-role
key.** Row Level Security is what stops one user's material id resolving to
another user's document; a service-role client would make that a bug away
instead of impossible.

**How a document reaches the model** — `sourceParts()` in the function:

| Kind | What is sent |
| --- | --- |
| PDF, image | The file itself, base64 `inline_data`, capped at 15MB per request |
| Text | The decoded text |
| Link | The URL plus `tools: [{"type": "url_context"}]` — Gemini fetches the page itself |

Nothing is summarised or truncated on the way. When the header says Flow is
reading Chapter 4, it is reading Chapter 4.

**Overload is retried, then routed around.** Gemini answers a busy model with
`503 UNAVAILABLE` — "this model is currently experiencing high demand" — which
is about *that model*, not the request. `MODEL_CHAIN` gives the primary one
extra go after ~900ms and then moves down to `gemini-3.6-flash` and
`gemini-2.5-flash`, immediately, because a busy model stays busy. Every model
in the chain supports both `url_context` and `response_schema`, which the link
and generation paths depend on — **check that before adding one**. Only
429/500/502/503/504 are retried; a 400 names a real problem with the request
and retrying it would just cost time and money. The model that served a request
is logged, so `query_logs` says which one answered.

**Generation is structured, not parsed out of prose.** Cards, questions and
summary sections all come back through `response_schema`, so the shape is
guaranteed by the API rather than by a regex over markdown. Four cards and four
questions, from `AiConfig.generatedItemCount`; a summary is 3–6 sections of
2–4 bullets, because how many sections a document has is a property of the
document rather than a number to fix.

**All three empty screens carry the same `GenerateBar`** — Flashcards, Quiz and
Summaries. Summaries' provenance banner is now hidden when there is nothing to
describe: it used to read "Generated by Flow · 0 pages → 0 sections" over an
empty screen, crediting work nobody had done, and its refresh icon said
"Regenerating needs the AI service" and did nothing. The icon rewrites the
summary now, and shows a spinner while it does.

**The app writes the generated rows, not the function.** They go in under the
user's own session, so RLS applies to them like everything else. Generating
replaces rather than appends — a second press on an empty screen would
otherwise silently double the deck.

**The daily chat allowance is enforced server-side** by counting the user's own
`chat_messages` rows for the day. A client-side tally would reset on reinstall
and could be edited by anyone who wanted more. The client sends its UTC offset
so "midnight" is the user's midnight; that is a convenience, not a security
boundary — spoofing it shifts the window and does not lift the cap.

**An answer is saved to the thread it was asked in, but only *shown* if that
conversation is still on screen.** Switching documents mid-answer would
otherwise drop a reply about Chapter 4 into last week's lecture notes.

### 5.5.3 Progress is earned now

Three columns had setters nothing ever called: `materials.progress`,
`flashcards.interval_days` (via `reviewCard`) and, before it was deleted,
`exams.preparation`. The first two are written now.

- **`reviewCard` is called.** "Again" and "Got it" under a card used to be pure
  navigation — nothing was written down, so the SM-2 scheduling never ran and
  "342 mastered" on the profile could never become true. They read Previous and
  Next now: **Next is the only one that records anything**, because going back
  is not a judgement about a card. On the last card it reads **Done**, records
  that card and pops the deck — the last card is the one that takes a material
  to 100%, so skipping the write there would leave the day's task permanently
  one card short of ticking.
- **A material's progress is `(cards reviewed + questions answered) / (cards +
  questions)`**, computed in `progressByMaterial()` from facts already in the
  tables: a card counts once `interval_days` leaves zero, a quiz counts once a
  run is in `quiz_attempts`. There is no per-question row, so a quiz is
  all-or-nothing **by design rather than by accident**.
- `StudyProgress.value` is `double?` — **null when nothing has been generated**,
  because "no cards exist" and "none of them are done" are different things and
  only the second is a 0% worth drawing.
- `syncStudyProgressProvider` writes it back to `materials.progress` — which is
  what makes exam preparation (§5.7) move — and then **ticks off any of today's
  blocks pointing at that material.**

**Home's task tick is a readout, not a control.** It used to toggle `done` on
tap, which made "I have finished this" a claim you could make without doing
anything, and let you untick something you had genuinely completed. It now
reports the bar beneath it. There is nothing to uncheck because the tap decides
nothing — the semantics say `isReadOnly` for the same reason.

### 5.5.4 Flashcards: Next and Previous, and a difficulty that is real

The two buttons under a card were **Again** and **Got it** — a correctness
judgement. They are **Previous** and **Next** now, which say where you are
going. Consequences worth knowing before changing either:

- **Only Next records anything.** Going back is not a judgement about a card,
  so Previous is pure navigation. Next calls `reviewCard`, and that write is
  what the progress bar, `materials.progress` and the day's auto-ticking task
  all rest on (§5.5.3).
- **On the last card Next becomes Done**, records that card, and pops the deck.
  The last card is the one that takes a material to 100%, so a Done that only
  popped would leave every task permanently one card short of ticking. The
  write is a round trip, so the button shows a spinner sized to the icon —
  a button that looks idle while it works reads as broken.
- **Previous is disabled on the first card**, at 45% opacity, rather than
  responding by doing nothing.
- **Restart goes to card one** from wherever you are. It used to only un-flip
  the current card, which is what tapping the card already does.
- **The settings button is gone.** Its `onPressed` was empty.

**"Mastery: 60%" is gone**, and its replacement needed a schema change rather
than a rename. Renaming the buttons removed the only correctness signal, so
there is nothing to *infer* difficulty from: no ease curve, no lapse count.
Difficulty is a property of the card instead — `flashcards.difficulty`, 1 to 5,
**rated by the model that wrote the card**, filling the five dots green through
coral. It is nullable, and cards generated before the column existed read "Not
rated" rather than being given an invented number.

### 5.5.5 The quiz stores answers instead of counting them

Adding a **Previous** button broke an assumption nothing had needed to state:
the score was a running total, incremented on each pick. That is safe only
while the sole direction is forward. With a back button, answering a question,
going back and answering again would have counted it twice.

`QuizRun.answers` is now a `Map<int, String>` — question index to the option
picked — and **`correct`, `missed`, `picked` and `revealed` are all derived
from it**. Re-picking an answered question is ignored, so a score cannot be
improved by persistence. A test walks back and forward and asserts 2/2 rather
than 3/2.

The rest of that screen:

- **Next question / See results is disabled until the question is answered.**
  **Skip** used to sit beside it, which let a quiz be finished having answered
  none of it — and then wrote that run to `quiz_attempts` as though it meant
  something.
- **Previous appears from the second question**, never on the first.
- **The countdown is gone from the header.** `elapsed` still counts, because
  the results screen reports how long the run took; there is just no
  per-question timer rushing a revision exercise.
- **See results shows a spinner.** It writes the attempt and syncs progress,
  which can tick off today's task — a round trip the button used to hide.

### 5.5.6 Flow suggests goes where it points

Home's suggestion card opened the **chat** whatever it had just said, so
"Retry your last quiz — you scored 60%" led to a conversation *about* the quiz
instead of to the quiz. `FlowSuggestion` carries a `FlowTarget` now
(`document` / `quiz` / `chat`) and a `materialId`, and the card opens that.

The quiz branch needed the data layer to help: `latestAttempt()` embeds
`quizzes(material_id)` so the suggestion can reopen the quiz for the document
it was actually about rather than whichever is newest.

**Also removed from Home:** the resume card's thumbnail had `p.42` printed in
the corner — the same page number on every document, whatever it was.

### 5.6 Chat holds nothing but real turns

The chat screen used to open on a scripted exchange about stereochemistry and
answer anything typed from a five-entry match table in `chat_models.dart`. It
was the most convincing thing in the app and the least real — it read as a
working AI over documents the account had never held. All of it is gone:
`openingTranscript`, `chatScript`, `ChatRepository.reset`, and the seeding in
`currentThreadId`. **Existing seeded rows were deleted from the database too** —
dropping the code that writes them does nothing about the ones already written,
and the user would have carried on seeing them.

What replaced it:

- **A thread starts empty.** The transcript renders an `SfEmptyView` instead of
  an empty `ListView`, worded differently depending on whether the library has
  anything in it.
- **The transcript is top-anchored and grows downward**, and `_pinToEnd`
  follows the end only once it overflows. See §5.6.1 — this one was got wrong
  twice before it was got right.
- **Sending still works and still persists.** The question goes to
  `chat_messages` so the history is there the day a model can read it.
- **`ChatSession.notice`** carries the "no AI yet" line. It is deliberately
  *not* a `ChatMessage`: it is never persisted, so it cannot end up in the
  context a real model is later handed, and it renders outside the transcript
  as app chrome rather than as a turn in the conversation. An apologetic canned
  *reply* would have been the same lie in a smaller font.
- **The header names the one document Flow is holding** — see §5.6.2. It said
  "Reading 3 docs" on every account (hard-coded), then counted the library
  (still wrong: Flow reads *one* document, the one you hand it).
- **The composer lost its mic** (dictation was a dead `onPressed: () {}`) and
  the header lost its refresh button — it existed only to re-seed the script,
  and there is nothing left to reset.
- **Answers are real** (§5.5.2). The composer's send guard lives *inside*
  `_send`, not on the button's `onTap`: enabled-ness depends on state the
  composer only learns about on the next frame, and a tap arriving before that
  frame was silently swallowed — which is exactly how a test caught it.
- **The suggestion chips** are five questions about the held document:
  `Summarize it`, `Explain like I'm 5`, `Key takeaways`, `Give me an example`,
  `What might I be asked?`. Two constraints they all meet — none names specific
  content ("Summarize ch.4" named a chapter no upload had) and none promises an
  action ("Quiz me on this" and "Make flashcards" promised things nothing
  performs). The rail scrolls, so the list can grow.

`typing` and `_TypingBubble` survive unused-but-wired: the moment a model call
lands it needs exactly that state, and the plumbing is three lines that already
work.

### 5.6.0 The transcript loaded backwards — read this before touching layout

**`ChatRepository.messages()` sorted the conversation newest-first**, because
postgrest-dart declares `order(column, {bool ascending = false})`. A bare
`.order('created_at')` reads as "oldest first" and does the exact opposite.

The symptom pointed straight at the scroll view and away from the cause: while
you typed, the order was **right**, because `send()` appends the new message to
the list already in memory. Reopen the screen and it was **reversed**, because
that is the first time the rows are re-read. Two rounds of scroll-anchoring
changes were spent on it (§5.6.1) before anyone read the query.

Every bare `.order()` in `lib/` had the same defect — flashcards, study blocks,
summary sections, exams and the subject list were all sorted backwards and
nobody had noticed only because those tables were empty. All of them now pass
`ascending:` explicitly, and `test/query_conventions_test.dart` fails the build
if a bare one is ever added again. **The fakes cannot catch this class of bug**:
they return their backing list, so every test sees the order the repository
*meant*. The source is the only place it is visible.

### 5.6.1 Where the transcript sits — two wrong answers first

**The rule: the conversation starts under the header and grows downward. A new
message appears below the last one and never moves anything already on screen.
Only when the thread outgrows the viewport does the view scroll, and then it
stays at the newest message.**

Both failed attempts are worth keeping written down — not least because
neither was the actual bug (§5.6.0), and both looked right:

1. **Plain `ListView` + `animateTo(maxScrollExtent)`.** Correct layout, unreliable
   follow: a short thread has no scroll extent, so the call was a no-op, and on
   a long one `maxScrollExtent` is an *estimate* while children are still being
   laid out lazily, so a single call can land short of the end.
2. **`reverse: true`.** Pins content to the bottom edge. This is what chat apps
   are assumed to do, and it is wrong for a thread shorter than the screen:
   every message already on screen **climbs upward** each time you send. That
   is the "my message moves to the top" complaint — caused by the fix for it.

What is there now is `_pinToEnd`, which does nothing at all until the content
actually overflows:

- `maxScrollExtent - offset < 1` → already at the end (a short thread always
  is, at 0) → return. Nothing scrolls, nothing moves.
- First time it must travel, it **jumps** rather than animating — opening a long
  thread should start at the newest message, not slide down to it — and calls
  itself again next frame, because the extent grows as more children get
  measured. It terminates: each jump forces more of the list to be laid out.
- Every later arrival animates.

**Do not "fix" this by reversing the list.** The three tests in §8 pin all of
it: a short thread starting at the top, an existing message not moving when a
new one arrives, and a long thread opening on the newest message.

---

### 5.6.2 One document, one conversation

Flow holds **one** document at a time — `chatDocumentProvider`, a nullable id.
`null` is a real state with a name ("No document selected"), not a placeholder
for one. `chatMaterialProvider` resolves it against the live library, so a
document deleted elsewhere cannot go on being named in the header.

It is set from three places: the "Read from" sheet behind the header's document
icon, Home's **Flow suggests** card, and the **orb on the document screen**.
The last two both hand over a document already named on screen — opening Flow
while reading a document and being told "No document selected" asked you to go
and find the thing in front of you. The
card's callback takes the whole `FlowSuggestion` for exactly that reason —
`FlowSuggestion.material` is null on the retry-your-quiz branch, which names a
topic rather than a file.

**Each document gets its own thread.** `chat_threads.material_id` was in the
schema and unused; `currentThreadId(userId, materialId:)` now finds or creates
the thread for that document, and switching documents switches transcripts.
Two reasons: asking about a chapter and asking about last week's lecture notes
are different conversations, and one shared transcript would mean handing a
model context from a document the question is not about.

One trap in that query: **`.eq('material_id', null)` does not express IS NULL**
in PostgREST. The general no-document thread would never be found again and a
fresh one would be created on every open. It uses `.isFilter('material_id',
null)`.

`FakeChatRepository` keys its transcripts by thread id for the same reason —
a single shared list would let a test pass while the app leaked one document's
conversation into another's.

### 5.6.3 The planner

One day at a time, chosen from a strip that scrolls through months.

**Blocks are held in drag order, not clock order.** The times are labels; the
sequence is yours, persisted as `position`. That is also why **nothing warns
about overlapping times** — warning that 08:00 and 08:30 collide, while telling
you the clock does not decide the order, would be the screen contradicting
itself.

**Every block points at a material or an exam.** `material_id` and `exam_id`,
both `ON DELETE SET NULL` and deliberately not `CASCADE`: deleting a document
must not silently delete Thursday morning off someone's plan, so the block
survives with its title as plain text. A free-text option was built and then
removed — a plan made of loose sentences cannot be opened, cannot inherit a
subject colour, and cannot tell an exam what it is revising. `isValid`
therefore requires a link, not just a title and a day.

Linking fills the title and inherits the material's subject, which is what
gives the accent stripe meaning. `BlockDraft.autoTitle` records the last title
the editor filled in, so it can tell **its own** title from **yours**: an
auto-filled one is replaced when you point the block elsewhere, a typed one
survives. Without it, typing "Past paper" and then attaching the document threw
the typing away.

**Times are start + length, and both are optional.** The editor collects a
start and a duration; the *end* is computed at save and still written to
`ends_at`, so every existing duration and hours-studied calculation keeps
working untouched — no schema change for time. A block with no start is a task
for that day and contributes nothing to the day's hours.

**The strip is bounded, not infinite**, and bounded at exactly the range
`blockCountsProvider` loads — `plannerDaysBack` before today to
`plannerDaysForward` after. A cell beyond that range would show no count, which
would be claiming "nothing planned" about a day nobody had asked the database
about. Its height comes from `_stripHeight(context)`, computed from the text
scaler: a flat 70 overflowed at scale 1.3, and a tighter formula still missed
by 1.1px. **Do not put a constant back there.**

**The row has no tick.** Tap opens what it points at, long-press gives Edit and
Delete, handle drags. Completing a block is something you do to *today*, and
today is Home's job — the Planner is where you arrange days you are not in. A
done block still reads as done, struck through. `onTap` is null on a block with
no link (rows written before the editor required one) — a row that highlights
and then does nothing is worse than one that does not highlight.

**Ticking lives on Home, on the checkbox alone.** The whole card used to toggle
done, which made "show me this document" and "I have finished it" the same
gesture; the card now opens the block's target and only the box completes it.
The box carries `Semantics(label: 'Mark done', checked:, container: true)` —
without `container` the card's tap handler swallows it and a screen reader
never mentions the control that completes the task.

**Ticking a block moves the streak and the hours studied, and nothing else.**
Not the linked material's progress: a block cannot know how much of a 200-page
PDF it covered, and a guess would push an invented number into exam preparation
(§5.7). `_refreshPlanner` is the one place that fans out the invalidations, so
a new writer cannot forget half of them.

### 5.6.4 The streak counts finished days, not visited ones

`completedBlocks()` filtered to `done = true`, which made a day with one of four
blocks ticked indistinguishable from a day with all four ticked — and the streak
counted both. It is `blockHistory()` now, unfiltered, carrying `done` per row,
because **"was this day finished" cannot be answered from the finished rows
alone**.

`profileStatsProvider` counts a day only when every block on it is done. Hours
studied still come from each finished block, so the two numbers measure
different things on purpose: hours are work done, the streak is days completed.
`weekActivityProvider`'s `DayState.done` uses the same rule, so the strip and
the streak cannot disagree.

**Repetition is "Copy this day…"**, a row under the last block, rather than
recurrence rules. It copies times, links and order; **`done` is never copied** —
a plan for next Tuesday that arrived already ticked would claim work nobody had
done.

### 5.7 Exams, and a percentage that had to be earned

The exam cards were drawn against a `preparation` column that **nothing in the
app ever wrote**. Shipped as-is, every bar would have read 0% forever — the
same trap as `profiles.streak_days` (§5.1). The column is **dropped**.
Preparation is derived instead: the mean reading progress of the materials
attached to the exam.

That is what makes "no materials added" a real state rather than a placeholder.
`ExamPrep.preparation` returns **`double?`, and null is not zero** — "nothing to
measure" and "measured, and you have done none of it" are different things to
tell someone. Every surface honours it: the list row swaps its bar for the
words, the featured card adds "tap to add them", Home's next-exam card says the
same, and the detail screen's Flashcards / Quiz / Flow buttons are **disabled**
until something is attached, because there is nothing to build them from.

The detail screen carries **no practice row**. Flashcards, Quiz and Flow all
run on one document at a time, and every attached document is already a row
with those actions a tap away — buttons at the bottom would have had to guess
which of the attached documents they meant.

`exam_materials` is a join table, not a column: a document can matter to more
than one exam, and an exam is revised from more than one document. Both foreign
keys cascade, so deleting either end cleans up after itself.
`setExamMaterials` deletes-then-inserts rather than diffing — the set is small,
the sheet hands over exactly what it wants attached, and a diff is three more
chances to leave a row behind for no saved round trip.

`examPrepsProvider` derives from `materialsProvider`, not from its own progress
query (§5.1.1), so reading a document moves its exams' preparation with it and
deleting one takes it out of the average.

**Two more things the design was faking.** The featured card printed the
literal string `THU · MAY 15 · 9:00 AM` and the words `High priority` on
whatever exam happened to be next. Both are now columns — `exam_time` (nullable;
plenty of exams are "some time that Thursday", and forcing a made-up 9:00 would
put a time on the card nobody chose) and a `exam_priority` enum. The eyebrow
reads "Next up" when the exam is not a high one.

The empty state has **no action button** — adding is the ＋ in the header, and
one control per job beats the same job offered twice on one screen. It briefly
had a centred "Add an exam" button, which both duplicated the ＋ and broke the
shape every other empty screen shares (§6.1).

The editor refuses to save without a title and a date, by disabling the button
rather than accepting the input and explaining afterwards. Its date picker's
`firstDate` is today: `upcomingExams()` filters on `exam_date >= today`, so a
past date would file the exam straight out of the list you just added it to.

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

**The rule is about surfaces, not controls.** `Switch.adaptive` (the
Notifications row), `InkWell`, `CircularProgressIndicator` and `TextField` are
all fine — they are behaviour with no chrome of their own, and each is given
the app's colours where it has any. What is banned is a Material widget that
paints a *container*: a dialog, a tile, a card, a sheet.

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
- **Pick the button variant from what is behind it.** `secondary` is
  `bg: scheme.surface` + outline, `ghost` is transparent and borderless.
  On the **canvas** (any sheet body — §6.1) use `secondary`; ghost there is
  just floating text, which is how the confirm sheets shipped a Cancel button
  nobody could see. On a **surface** (inside a card) it inverts: `secondary`
  disappears into its own background and `ghost` is the right quiet action.
  This bit once, by carrying the dialog-era choice over when the confirmation
  became a sheet — the background changed, the variant did not.
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
11. **A `GridView` cell is a fixed box — do not size it with
    `childAspectRatio`.** A ratio tuned at scale 1.0 overflows at 1.3. The
    achievements grid uses `mainAxisExtent` computed from the text scale
    (`MediaQuery.textScalerOf(context).scale(14) / 14`, since there is no
    plain factor getter), and lets the text block inside `Flex` so the status
    chip stays pinned to the bottom of every card.
12. **A `TextField` keeps the theme's borders unless you override *all* of
    them.** `AppTheme.inputDecorationTheme` sets `filled: true` and a primary
    `focusedBorder`; setting only `border: InputBorder.none` leaves
    `enabledBorder`, `focusedBorder`, `errorBorder` and the fill in place, so a
    field inside a styled container draws a **second, inner box that lights up
    on focus while the real container stays dim**. Kill `filled` and every
    border by name, and put the focus treatment on the container — `SfField`
    and the paste-text note box both do. A `FocusNode` is a `Listenable`, so
    `ListenableBuilder` drives that highlight without `setState`.
13. **A bottom sheet does not avoid the keyboard.** It is laid out against the
    whole screen, so a sheet containing a text field sits behind the keyboard
    it just raised. `SfSheetShell` pads by `MediaQuery.viewInsetsOf(context)
    .bottom`, outside its `SafeArea` (the two do not stack — with the keyboard
    up the bottom safe inset is zero). Every sheet gets this; do not re-solve
    it per sheet. Note the padding is the shell's *outermost* widget, so
    `getRect(find.byType(SfSheetShell))` still spans to the screen bottom —
    assert on the content, not the shell.
14. **A bottom sheet is capped at 9/16 of the screen and its content spills
    rather than the sheet growing.** The five-row upload source picker
    overflowed by 37px on a short phone and 112px at 340×700. `showSfSheet`
    now passes `isScrollControlled: true` with a 90%-of-height constraint, and
    `SfSheetShell` wraps its child in `Flexible(SingleChildScrollView(...))`
    so a sheet that reaches the ceiling scrolls instead of clipping. The
    shell's Column is still `MainAxisSize.min`, so short sheets are unchanged
    — this only lifts the ceiling. **Any new sheet gets this for free; do not
    solve a tall sheet by deleting rows from it.**

---

## 8. Tests

`test/query_conventions_test.dart` — one source-level invariant: every
`.order()` in `lib/` must state `ascending:`. See §5.6.0 for the bug that
earned it.

`test/widget_test.dart` — 229 tests. `FakeAiRepository` is the seam that
keeps them offline; `FakeLibraryRepository(summarised: false)` models a
document nobody has summarised yet, which is the state the Summarize button
exists for and which an empty account cannot express:

- Flow tests: splash → onboarding → auth → shell, empty-submit rejection,
  stored-session routing, tab switching, quiz run, flashcard flip, and chat —
  which now asserts on *absence*: an empty opening transcript, no scripted
  reply on a 3 s wait, no mic, no refresh, and a header count that tracks the
  fake library instead of always saying three. Three more pin the transcript's
  position (§5.6.1): short threads start at the top, an existing message does
  not move when a new one arrives, and a long thread opens on the newest. See
  §9 for why the short-thread case is the one that matters.
- Planner (§5.6.3): adding an untimed block, a start plus a length becoming a
  09:00 – 10:30 window, ticking / editing / deleting a block, the day line
  counting hours *and* tasks *and* completion, copying a day onto another and
  finding the copies unticked, and that a block cannot be saved with nothing to
  point at. Home's tick is tested with the semantics tree on, so it also proves
  the control is reachable to a screen reader — and that tapping the card opens
  the document rather than completing it. A `ProviderContainer` test pins the
  streak refusing a partly finished day (§5.6.4).
- The AI (§5.5.2), with the Edge Function faked at the repository seam so the
  suite stays hermetic — no key, no network: generating from an empty deck, an
  empty quiz and an empty summary each asks for the *selected* document, a
  generation failure is readable and leaves the button offered, a question
  carries the held document with it, and the daily allowance disables the
  composer rather than letting a question be typed that cannot be sent.
- Practice navigation (§5.5.4, §5.5.5): the last card reads **Done** and pops
  the deck; the quiz refuses to move on until the question is answered, offers
  **Previous** only from the second question, and — the one that matters —
  **walking back and answering again still scores 2/2, not 3/2**. That test
  exists because adding a back button silently broke a running-total score.
- Exams (§5.7): adding one through the editor and finding it in the list, the
  featured card reading the row rather than a fixed string, preparation moving
  to 42% then 71% as materials are attached (a mean no single document has, so
  it can only be the derived value), and deleting one from its detail screen.
- Integration walks, one per route the library is now reachable by (§5.5.1):
  Add material → History → a document; Home → Flashcards → picker → cards;
  a document → straight to its cards, *skipping* the picker; a document with
  nothing generated naming itself in the empty state; and for Flow, that the
  header names the held document, that each document keeps its own transcript,
  and that "Flow suggests" hands its document over.
- Modal tests: the appearance sheet opens/applies, sign-out opens and cancels,
  the upload source sheet fits a short screen and clears the keyboard, and the
  library selection menu deletes **behind a confirmation** — that one pins the
  *cancel* path, where a bug destroys data silently. **The layout sweep cannot
  reach modals** — a sheet is not built until something taps it open, so any new
  one needs its own test.
- Feature tests: Home's empty vs populated states, materials search (title,
  subject, no-match, clear), multi-select and system-back, achievements
  catalogue + View all navigation, the mandatory Category screen, paste-text
  word gates, the document screen's header/actions, the Notifications switch,
  the Account screen's locked email, and password-change validation — that last
  one asserts the repository was **not** called on each rejected attempt, not
  just that an error appeared.
- Geometry assertions where a layout rule is the requirement: the Insights
  range control sits below the title and spans the width, the live progress bar
  fills from the left, a sheet clears the keyboard, and the chat transcript
  rests on the bottom of its viewport. These are the ones worth writing
  carefully — the first version of three of them passed against the bug they
  were written for. The chat one is instructive twice over. The first draft
  sent **20** messages and asserted the newest was on screen, which passed with
  the bug present, because an overflowing list ends up at the bottom either
  way; only a *short* thread tells the layouts apart. **Pick the case where the
  bug and the fix differ, not the case that looks most realistic.** Then the
  rewritten test passed against a layout the user still rejected — it asserted
  the position the transcript settled at, when what they cared about was
  whether anything **moved**. A geometry test that measures one frame cannot
  see motion; measure the same widget before and after the change. And the
  whole exercise was chasing the wrong layer: the real defect was a reversed
  SQL sort (§5.6.0). **When state is right while you edit it and wrong after a
  reload, suspect the read, not the view.**
- Pure-logic tests that need no widget at all, in `ProviderContainer` or plain
  `test()`: `MaterialKind` detection, `streakFrom`, `normaliseUrl`,
  `ProfileStats` labels, and library staleness (§5.1.1). **Prefer these when
  the thing under test is a rule** — the widget-level version of the staleness
  test passed against the bug it was written for, because the card it asserted
  on was below the fold and never built.
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
- `_scope()` takes `prefs:` for seeding stored preferences, `signedIn:` for
  starting with a session, and **`emptyAccount:`** for a brand-new account with
  no materials, blocks or exams — which is the only way to reach Home's empty
  states (§5.1).
- The repository fakes are the contract: adding a method to a repository breaks
  `fake_repositories.dart` at compile time until it is implemented there too.
  That is deliberate — a fake that silently lags the real thing tests nothing.

---

## 9. Standing constraints and open work

**Not built, and each for a stated reason:**

- **Google sign-in.** Needs a Google Cloud OAuth client configured in the
  Supabase dashboard. The button currently says so plainly rather than
  pretending. Wiring it also needs a deep-link intent-filter in
  `AndroidManifest.xml`. (The Apple button was removed from the Auth screen.)
- **~~The AI~~ — built (§5.5.2).** Gemini, behind the `ai` Edge Function.
  Flashcards, quizzes and summaries are generated from the real document; Flow
  answers from it. What is *still* rule-based and deliberately so: Home's "Flow
  suggests" card is a deterministic rule over real rows, not a model (§5.1),
  and the Planner's Flow note is the same. **The ✨ button on the Planner still
  does nothing** — auto-planning a week is its own feature and is not built.
- **`study_sessions` is never written.** Table, `logSession()` and the Insights
  charts all exist, but nothing calls it — there is no study timer in the UI
  yet. Insights will read zero until one is added. **This is the most likely
  next task.**
- **Generation costs money and nothing meters it.** The 5-a-day cap covers
  *chat only* (§5.5.2). Flashcards, quizzes and summaries are unlimited, and
  each call uploads the whole document again — a 10MB PDF summarised four times
  is 40MB of input billed. No per-user quota, no caching of a document between
  calls, no view of spend.
- **Generation replaces silently.** A second press deletes the existing deck,
  quiz or summary and writes a new one with no confirmation. That is right for
  the empty-screen button it was built for and wrong for the regenerate icon on
  Summaries, which can discard a summary you were reading.
- **A failed generation can leave nothing behind.** Delete-then-insert is not a
  transaction: if the insert fails after the delete, the old content is gone
  and the new never arrived. Small window; the fix is a Postgres function.
- **Quiz progress is all-or-nothing.** No per-question row exists, so a quiz
  counts once an attempt is recorded and not before (§5.5.3). Answering three
  of four and leaving shows nothing.
- **Nothing sends a notification.** The Profile switch is real and persists
  (§5.3.3), but there is no notification plugin, no permission request and no
  scheduler behind it — it records what the user asked for, not something
  happening. Wiring it needs `flutter_local_notifications` plus
  `POST_NOTIFICATIONS` in the manifest (Android 13+) and a daily schedule.
  **Do not add copy claiming a reminder time until that exists.**
- **Summary bookmarking is in-memory.** No bookmarks table; inventing one to
  back a single icon is schema the app does not need yet.
- **The email cannot be changed.** Shown and locked on the Account screen
  (§5.3.3). Supabase needs a confirmation round trip to both the old and new
  address, which is its own flow with its own failure states.
- **~~A saved URL is never fetched~~ — it is now.** Gemini's `url_context`
  tool fetches the page at generation and chat time (§5.5.2). The app still
  stores only the URL and never caches the page, so **a link material is only
  as good as the page being up and public** — paywalled, login-walled and
  JS-only pages will produce thin results or none.
- **Upload retries are gone on the progress path.** Getting a real percentage
  meant streaming the body ourselves (§5.5), which skips the SDK's automatic
  retry/backoff. A dropped connection now fails the upload instead of retrying.
- **Nothing awards achievements.** The catalogue, the screen, the rail and the
  `earned_at` column all exist, but no code ever writes it — no rule watches a
  streak or a quiz score. Every badge stays locked until that half is built.
  **A likely next task**, alongside `study_sessions`.
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
- **Profile → Sounds & haptics row.** It was inert, and there is no audio or
  haptic feedback anywhere in the app to configure.
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
- **~~`setState`~~ — no longer zero, and the claim was wrong before anyone
  noticed.** There are **12 calls across 10 files**. Every one is genuinely
  local view state nothing else reads: a form's in-flight `busy` flag, a
  sheet's tick selection, a search box's query, a focus highlight. Application
  state is still provider state. The rule that mattered was never "no
  `setState`" but "nothing another screen needs to see lives in a widget".
  **Do not put a count back in this file** — it will rot again.
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

**`image_picker` (also flutter.dev) handles camera and gallery**, which
file_selector cannot do — it opens no capture intent and no system photo
picker. It builds cleanly on AGP 9 (verified with `flutter build apk --debug`).
Both plugins return a `cross_file` `XFile`, so everything past the pick is
shared; import image_picker with `show ImagePicker, ImageSource` to keep the
two `XFile` exports from clashing.

**General rule:** if a plugin fails with "cannot find symbol" on its own plugin
class, check whether its `android/build.gradle` has migrated to built-in Kotlin
before assuming a caching problem.

### 10.1 Manifest

`INTERNET` is declared explicitly — Flutter's debug manifest grants it
implicitly, so a release build would otherwise fail where debug worked.
`android:enableOnBackInvokedCallback` is deliberately **not** set; the log
warning about it is benign and enabling it changes back-gesture behaviour.

**`android.permission.CAMERA` is deliberately absent, and adding it breaks the
camera.** ACTION_IMAGE_CAPTURE does not require it — the camera app services
the request. But once an app *declares* it, the platform refuses to launch that
intent until the permission has also been granted at runtime, and nothing here
requests runtime permissions. Adding the line without adding that plumbing
turns "Scan with camera" into a SecurityException. If you ever do want an
explicit prompt, the permission and a runtime-request package have to arrive
together.

`READ_EXTERNAL_STORAGE` is capped at `maxSdkVersion="32"`. From Android 13 the
photo picker and SAF hand back a pre-granted URI, so no storage permission is
involved; `READ_MEDIA_IMAGES` is not declared for the same reason, and
declaring it would drag in a Play Store permissions declaration form for
nothing.

The `<queries>` block lists IMAGE_CAPTURE, GET_CONTENT (`image/*`) and
OPEN_DOCUMENT (`application/pdf`). From Android 11 these are needed for
**package visibility**: without them the intent resolves to nothing and the
picker silently fails to open even though the handling app is installed.

### 10.2 Launcher icons

Sources live in `assets/android/` and `assets/ios/` — generator output, kept
in the repo so the icons can be regenerated or re-cut without hunting for the
original export. **`assets/` is not declared in `pubspec.yaml`**, so nothing in
it is bundled into the app; it is a source folder, not an asset folder. Keep it
that way, or every icon size ships inside the APK for no reason.

Android, in `android/app/src/main/res/`:

- `mipmap-{l,m,h,xh,xxh,xxxh}dpi/ic_launcher.png` + `_round.png` — the legacy
  icons, used below API 26. They are *shaped* (transparent corners), which is
  correct for legacy but would be wrong for an adaptive foreground.
- `mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher_foreground.png` — 108dp at each
  density (108/162/216/324/432 px). ldpi has no foreground; Android downscales.
- `mipmap-anydpi-v26/ic_launcher.xml` + `_round.xml` — the adaptive icon, which
  wins on API 26+. Background is `@color/ic_launcher_background`, defined in
  `values/ic_launcher_background.xml` as **#beb4e6**. **Re-copy that file
  whenever the icons are regenerated** — the colour is part of the icon, and a
  stale one leaves the artwork sitting on last week's background.
- The manifest declares **both** `android:icon` and `android:roundIcon`.
  `roundIcon` only matters below API 26 (above it the launcher masks the
  adaptive icon itself), but minSdk is well under that.

The generator also emits `playstore-icon.png`, `ic_launcher-web.png` and
`iTunesArtwork@{1,2,3}x.png`. None are used by either build and all have been
deleted. **A 512×512 opaque square is required by the Play Console at
submission** — regenerate one then; do not go looking for it here.

iOS, in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`:

- The 15 PNGs, plus the 1024 marketing icon. The generator names that one
  `ItunesArtwork@2x.png`; it is copied in as **`Icon-App-1024x1024@1x.png`**,
  which is what Flutter's `Contents.json` references.
- **`Contents.json` was left as Flutter generated it** rather than taking the
  generator's. The generator's version declares an `iphone` `76x76@2x` slot,
  which is not a real iPhone icon size, and points the marketing slot at
  `ItunesArtwork@2x.png`.
- **The alpha channel was stripped from all 15.** App Store Connect rejects an
  app icon that carries one, even a fully opaque one. Every pixel was verified
  opaque first, so the conversion is lossless — the files got ~30% smaller as a
  side effect. If you ever regenerate these, strip alpha again: Xcode on
  Windows cannot warn you, and the rejection arrives at upload time.

Verified in a real `--release` APK, not just on disk: `aapt2 dump badging`
resolves `icon`/`roundIcon` to the adaptive XML, whose background resolves to
`#ffc1bbe8`, and all four foreground densities are present in `res/`.

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
