# Hue Muse Shade AI — Risk Register

| # | Risk | Likelihood | Impact | Owner action needed |
|---|---|---|---|---|
| 1 | Codebase has never been compiled; unknown compile errors may exist | Cannot estimate — genuinely unmeasured | High if present | Run `flutter pub get && flutter analyze` immediately; this is the single highest-priority action before anything else in this register matters |
| 2 | `flutter test` may reveal failing assertions in the ~70 written-but-unexecuted test cases | Low-Medium (each was hand-traced) | Medium | Run `flutter test`; fix any failures — they'd indicate a genuine logic error, not just a missing feature |
| 3 | Performance at real data volumes is unmeasured (startup, memory, recommendation-pipeline latency) | Unknown | Medium-High | Load-test with realistic product/shade/trial/material counts on a target device |
| 4 | Android-version-specific incompatibility across the 8-14 target range | Unknown | Medium | Install and manually walk the Release Candidate Checklist on real/emulated devices spanning that range |
| 5 | `image` package (added SPR-DEP-008) may have API surface changes vs. what was coded against (never compiled) | Low-Medium | Medium | First `flutter analyze` run will surface this immediately if present |
| 6 | Restore Database's file-permission behavior on scoped-storage Android versions (10+) is unverified | Unknown | Medium | Device-test Backup -> Restore explicitly on Android 10+ |
| 7 | ~~Product-creation gap (no UI) blocks real usage~~ | N/A | N/A | **RESOLVED (R1)** — Product Management screen shipped. The same gap for Shade and all six raw-material tables, found independently by R4's trace, is **RESOLVED (R5)**. |
| 8 | No integration/widget test coverage means regressions in future changes won't be caught automatically | Reduced, not eliminated | Medium, compounding over time | **PARTIALLY ADDRESSED (R6)** — ten widget tests and two engine unit tests now exist, built on a real (not mocked) in-memory-database harness. None have been executed yet — running them is still the owner action needed, same as risks 1-6. |
| 9 | `Settings` table's 4-record-type overload could become unmanageable if a 5th type is ever needed | Low near-term | Low-Medium long-term | Revisit the frozen-database constraint before adding a 5th type |
| 10 | Several business-domain weights/thresholds are engineering judgment calls, not confirmed business decisions | Certain (documented) | Low for code stability, potentially High for recommendation quality in practice | Review and tune `RuleModel` weights and ranking constants against real formulation data |
| 11 | Import Knowledge's fixed-path UX may confuse non-technical lab staff | Medium | Low-Medium | Add a real file picker in a future sprint, or document the workaround clearly for end users |
| 12 | Revision lineage (R3) is a `notes`-text convention, not a real foreign key — a user could coincidentally type similar text, producing a false lineage link or a false "Revisions Pending" dashboard count | Low | Low | Accepted trade-off given the frozen schema; revisit only if a real `parent_trial_id` column is ever approved |
| 13 | No `trial_code` uniqueness enforcement (schema or app level) for formulas or revisions | Low-Medium | Low-Medium | Add a client-side uniqueness check, or a `UNIQUE` constraint if a schema change is ever approved |

## How to read this register

Risks 1-6 are about **whether the code works at all** — they can only
be resolved by actually running the Flutter toolchain, something no
environment across the original 12 sprints or Repair Sprints R1-R6
has had access to. Risks 9-13 are about **product completeness and
tuning** — real, but independent of whether the current code compiles
and runs correctly. Risks 7-8 have moved from "certain gap" to
"resolved" or "partially addressed" specifically because of R1-R6's
work, tracked here rather than silently dropped from the register.
