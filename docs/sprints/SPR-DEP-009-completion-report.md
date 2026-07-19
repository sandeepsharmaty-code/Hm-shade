# Sprint Completion Report — SPR-DEP-009

**Objective:** Integrate all completed engines into the Flutter
application. No engine redesign, no duplicated business logic, only
integrate approved modules.

---

## Updated Project Tree

```
lib/core/routing/app_routes.dart   (changed — added AppRoutes.trial)
lib/core/routing/app_router.dart   (changed — dispatches TrialScreen)
lib/core/database/database_helper.dart (changed — added
                                         databaseFilePath getter,
                                         no schema change)

lib/screens/
├── home_screen.dart            (rewritten — Application Summary,
│                                 Recent Recommendations, Pending Lab
│                                 Trials, Quick Actions)
├── new_shade_screen.dart       (rewritten — full workflow through
│                                 Shade Detection, hands off to
│                                 TrialScreen)
├── search_screen.dart          (rewritten — 5 search categories)
├── knowledge_base_screen.dart  (rewritten — 4 tabs)
├── settings_screen.dart        (rewritten — 6 required actions)
└── trial_screen.dart           (new — pushed route, Top 5 onward)

lib/widgets/
├── trial_status_chip.dart          (new)
└── recommendation_summary_card.dart (new)
```

## A scope decision, flagged upfront

The brief lists 6 screens (New Shade, Home, Search, Knowledge, Trial,
Settings) but the approved shell (SPR-DEP-002, frozen) has exactly 5
bottom-nav tabs. Rather than add a 6th tab — which would be a real
change to already-approved/frozen shell architecture — **Trial is a
pushed route** (`AppRoutes.trial`), reached from New Shade's workflow
and (in a future sprint) Home's Pending Lab Trials list. This keeps
`RootShellScreen` byte-for-byte unchanged.

## Updated Screens

- **New Shade**: product selector (`ProductRepository.readAll`) ->
  `ImagePickerCard` (unchanged, SPR-DEP-002) -> "Analyze Image" calls
  `ImageAnalysisEngine.analyzeImage` (SPR-DEP-008) -> renders the
  `ColorProfile` (average colour swatch, dominant-colour dots,
  brightness/saturation/lightness) and shade-detection chips (family,
  undertone, dark/light, single/multiple dominant) -> "View Top 5
  Recommendations" pushes `TrialScreen` with the detected shade
  family. Stops exactly where this sprint's INPUT list says Formula
  Recommendation Engine work belongs to TrialScreen, not duplicated
  here.
- **Home**: `Future.wait` over `ProductRepository.count()`,
  `ShadeRepository.count()`, two `TrialRepository.filter()` calls
  (ready_for_lab, lab_testing), and
  `RecommendationHistoryRepository.recent()` — Application Summary
  stat cards, Pending Lab Trials list, Recent Recommendations list,
  Quick Actions (switches `NavigationProvider` tabs). Pull-to-refresh
  via `RefreshIndicator`.
- **Search**: `ChoiceChip` category selector (Shades/Products/
  Materials/Formulas/Knowledge) + existing `SearchBox` widget
  (unchanged). Materials fans out across all six raw-material
  repositories' `search()` in parallel (`Future.wait`) and merges,
  tagged by material type.
- **Knowledge**: 4-tab `TabBar`/`TabBarView` — Knowledge Records
  (`KnowledgeRepository.readAll`), Approved Formulas
  (`TrialRepository.filter(status: approved)`), Rules
  (`RuleRepository.findAllRules(includeInactive: true)`, showing
  enabled/disabled state), Recent Updates (same knowledge read,
  sorted by `updatedAt` in-memory — no new repository method needed).
- **Settings**: kept SPR-DEP-002's real Reset Local Data, added
  Backup Database (file copy to `backups/`), Restore Database (pick a
  backup, copy it back, prompts for restart since sqflite holds the
  live file open), Export Knowledge (JSON to `exports/`), Import
  Knowledge (reads a fixed conventional path — see Known Issues),
  Clear Cache (empties the OS temp directory), About Application
  (`showAboutDialog`).
- **Trial** (new): Top 5 list via the new `RecommendationSummaryCard`
  widget; tapping a card reveals Explanation/Validation/History
  buttons plus "Mark Ready for Lab"; an app-bar action opens the
  Comparison Report across all 5. Every report is rendered from an
  engine call — this screen formats, it never computes.

## Navigation Flow

```
Splash -> Shell (5 tabs, unchanged)
  Home --Quick Action--> New Shade tab (NavigationProvider.selectTab)
  Home --Quick Action--> Search tab
  Home --Quick Action--> Knowledge tab
  New Shade --"View Top 5"--> [pushed] Trial Screen
                                  (Navigator.pushNamed, AppRoutes.trial,
                                   TrialScreenArgs(productId, shadeFamily))
  Trial Screen --back--> New Shade (Navigator pop, standard back stack)
```

## UI Flow Diagram

```
Select Image (ImagePickerCard, real image_picker)
        v
Image Analysis (ImageAnalysisEngine.analyzeImage)
        v
Color Profile (ColorProfile: average/dominant colours,
                brightness/saturation/lightness — rendered as
                swatches + stat text)
        v
Shade Detection (ImageColorClassification: family, undertone,
                  dark/light, single/multiple dominant — rendered as
                  Material 3 Chips)
        v
[push] Trial Screen
        v
Top 5 Recommendations (RecommendationSummaryCard list,
                        TrialGeneratorEngine.generateTopFive)
        v
Recommendation Details (tap a card -> Explanation / Validation /
                         History bottom sheets, Compare-all sheet)
        v
Trial Selection (tap "Mark Ready for Lab" on the chosen card)
        v
Ready for Lab (TrialWorkflowManager.transition -> audit trail
                recorded -> list refreshes)
```

## Widget Structure

New reusable widgets (both under `lib/widgets/`, both consumed by 2+
screens so they earned a shared file rather than staying screen-local
private classes):
- `TrialStatusChip` — colour-coded per `TrialStatus`, used by
  `RecommendationSummaryCard` and `HomeScreen`'s Pending Lab Trials.
- `RecommendationSummaryCard` — rank/name/confidence/status/conflict
  count, used by `TrialScreen`'s list.

Screen-local composition (kept private to their one screen, per the
existing project convention — e.g. `_ColorProfileSection` in
`new_shade_screen.dart`, `_ComparisonSheet`/`_ValidationSheet`/
`_ExplanationSheet`/`_HistorySheet` in `trial_screen.dart`) is not
duplicated across files.

## Integration Details

Every screen change in this sprint calls an **existing, unmodified**
engine or repository through `ServiceLocator` — grep-verified zero
engine files changed this sprint (only `database_helper.dart` gained
one getter, and `app_routes.dart`/`app_router.dart` gained one route
— neither is an engine). Engines connected, matching the brief's
"CONNECT EXISTING ENGINES" list:

| Engine | Connected from |
|---|---|
| `ImageAnalysisEngine` | New Shade Screen |
| `ShadeEngine` | (transitively, via `ImageAnalysisEngine`) |
| `KnowledgeEngine` | Search Screen (Knowledge category), Trial Screen (transitively via `FormulaRecommendationEngine`) |
| `RuleEngine` | Knowledge Screen (Rules tab), transitively everywhere else |
| `RecommendationEngine` | Trial Screen (transitively via `FormulaRecommendationEngine`/`TrialGeneratorEngine`) |
| `FormulaRecommendationEngine` | Trial Screen (transitively via `TrialGeneratorEngine`) |
| `TrialGeneratorEngine` | Trial Screen |
| `TrialWorkflowManager` | Trial Screen ("Mark Ready for Lab", audit history) |

## Testing Strategy

1. **No new pure-logic units this sprint** — UI integration wires
   existing, already-tested engines/repositories to widgets; there's
   no new deterministic algorithm to unit-test in isolation this time.
   All prior-sprint tests (database, repository CRUD, match/rule/
   ranker/conversion/dominant-colour logic) remain unaffected —
   verified by re-running the full static suite (balance, imports,
   duplicate-class scan) across all 105 files.
2. **Widget tests (not written, flagged as a gap).** Flutter's
   `flutter_test` supports `WidgetTester`-based widget tests
   (pumping a screen, tapping buttons, asserting rendered text) — none
   were added this sprint. Given ENV-001 (no Flutter SDK to actually
   run `flutter test` against a widget tree, which needs the full
   framework, unlike the pure-Dart unit tests written so far), adding
   untested widget-test code would be lower-value than usual. Flagged
   as the natural next testing investment once ENV-001 is resolved.
3. **Manual verification steps** (for you to run once `flutter pub
   get`/`run` works): Home shows real counts once products/shades
   exist; New Shade produces a ColorProfile from any gallery image;
   Trial Screen's Top 5 list, Comparison/Validation/Explanation
   sheets, and "Mark Ready for Lab" all reflect real repository state
   afterward (check via Knowledge screen's Rules tab or a fresh Home
   load).

## Self Review

- OK **No duplicated business logic** — every scoring/validation/
  comparison/explanation computation happens inside an engine;
  screens only call and render. Grep-verified zero SQL/`db.*` calls
  in `lib/screens/` and `lib/widgets/`.
- OK **No direct SQLite access** — confirmed above.
- OK **Repository Layer only** — every repository/engine access goes
  through `ServiceLocator.instance.get<T>()`, matching the existing
  DI pattern from every prior sprint.
- OK **Complete engine integration** — all 8 named engines connected
  (table above); the other 15 registered engines are reached
  transitively through them (e.g. `RuleEngine` underlies
  `MaterialMatchingEngine`, `RecommendationEngine`, and more), exactly
  as their own sprints designed them to compose.
- OK **Offline only** — no new dependency, no network code introduced.
- OK **Material Design 3** — all new UI uses existing M3-themed
  widgets (`AppCard`, `AppButton`, `Chip`, `ChoiceChip`, `TabBar`,
  `NavigationBar` via the unchanged shell) and `Theme.of(context)`
  colours/text styles; no hardcoded colours introduced.
- NOT CONFIRMED **Production Ready (compile-verified)** — **cannot
  confirm**, see ENV-001. Static checks (brace/paren balance, import
  resolution — including a real missing-import bug caught and fixed
  before shipping, see Known Issues — package cross-check,
  duplicate-class scan, unused-catch-clause scan, no-SQL-in-UI scan)
  across all 105 `.dart` files pass clean.

## Known Issues

**Carried forward, still open:**
1. **ENV-001 (High, unresolved).** No Flutter SDK in this sandbox —
   this sprint especially would benefit from a real build, since
   widget trees, `Navigator`/route-argument casts, and
   `showModalBottomSheet`/`showAboutDialog` usage are exactly the kind
   of thing that only a real Flutter runtime can fully verify.
2. All prior sprints' open questions (DB filename, column schemas,
   rule/ranking weights, transition graph, `image` dependency) — no
   response yet.
3. No repository-backed engine tests — unaffected by this sprint,
   backlog remains.

**New this sprint:**
4. **A real bug was caught and fixed during self-review**:
   `trial_screen.dart` used `ITrialGeneratorEngine` without importing
   `trial_generator_engine.dart` — would have been a compile error.
   Caught by an automated cross-check (every capitalized identifier
   in each changed file verified against its defining file being
   imported) before this report was written, not by a real compiler
   (still unavailable, ENV-001). Flagging the process, not just the
   fix, since it's the kind of mistake only a real `flutter analyze`
   would normally catch first.
5. **Import Knowledge has no file picker** — reads a fixed path
   (`Documents/imports/knowledge_import.json`) instead. No file-picker
   package is in `pubspec.yaml`, and adding one (like `image` last
   sprint) felt like a bigger unilateral dependency decision than this
   sprint's UI-integration scope warranted. Flagging as a real UX
   limitation, not hiding it.
6. **Restore Database requires a manual app restart** — `sqflite`
   holds the live database file open, so overwriting it mid-session
   doesn't take effect until reopened. The screen tells the user this;
   there's no in-app restart mechanism (Flutter has no built-in
   "restart my own app" API without a plugin).
7. **"Recent Analysis" is not separately tracked** — `ColorProfile`
   has no repository (SPR-DEP-008 didn't persist it, and this sprint
   didn't add one), so Home's "Recent Analysis" requirement is
   satisfied by showing Recent Recommendations instead, which is the
   closest real, persisted proxy. Flagged rather than fabricating a
   separate feed.
8. **`databaseFilePath` getter added to `DatabaseHelper`** — a single
   getter, not a schema or architecture change, needed for Backup/
   Restore to locate the live `.db` file. Noted since "do not redesign
   any existing engine" was this sprint's explicit instruction (this
   is `core/database/`, not an engine, and it's additive-only).

## Ready For Approval

**Conditionally**, same basis as every prior sprint. Final sign-off
needs `flutter pub get && flutter analyze && flutter test && flutter
run` — this sprint's UI surface in particular needs a real device/
emulator pass to be confident about, beyond what static analysis in
this sandbox can offer. Per the Stop Rule, not continuing to
SPR-DEP-010 until you approve.
