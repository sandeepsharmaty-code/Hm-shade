# Hue Muse Shade AI — Database Documentation

**Engine**: SQLite (via `sqflite`). **File**: `hue_muse_shade_ai.db`,
in the app's private document storage. **Current schema version**: 5.

## The 14 approved tables

| Table | Purpose |
|---|---|
| `Product_Master` | Cosmetic product lines (Nail Polish, Lipstick, etc.) |
| `Shade_Master` | Named colour shades under a product |
| `Pigment_Master` | Raw pigment materials |
| `Dye_Master` | Raw dye materials |
| `Mica_Master` | Raw mica materials |
| `Pearl_Master` | Raw pearl-pigment materials |
| `Filler_Master` | Raw filler materials |
| `Binder_Master` | Raw binder/resin materials |
| `Blend_Template_Master` | Reusable formulation base templates |
| `Trial_Formula` | Candidate/in-progress formulas |
| `Formula_Material` | Material line items within a trial (child of Trial_Formula) |
| `Approved_Formula` | Approval record for a trial (child of Trial_Formula) |
| `Knowledge_Base` | Searchable knowledge entries |
| `Settings` | App settings **+ configurable rules + recommendation history + trial audit trail** (see below) |

Every table has the standard audit columns `id`, `is_active`
(soft-delete flag), `created_at`, `updated_at`, plus domain columns
specific to that table (full column lists in
`lib/core/database/database_helper.dart`'s `_domainColumns` map — the
single source of truth).

## `Settings`: four record types, one table

`Settings.record_type` distinguishes:
- `'setting'` (default) — plain app configuration, not otherwise used
  by this version.
- `'rule'` — a configurable business rule (`condition_key`,
  `condition_operator`, `condition_value`, `priority`, `weight`,
  `rule_version`, `description`, reusing `is_active` for
  enabled/disabled).
- `'recommendation_history'` — a logged recommendation event
  (`input_parameters` JSON, `selected_trial_formula_id`,
  `confidence_score`, `reason_text`).
- `'trial_audit'` — a logged lab-status transition
  (`selected_trial_formula_id` reused as "the trial this is about",
  `status_from`, `status_to`, `changed_by`, `reason_text` reused,
  `related_recommendation_id`).

**This is a deliberate, documented trade-off**, not an oversight —
see Architecture Summary for why, and
`docs/sprints/SPR-DEP-011-completion-report.md` Known Issues for a
flagged concern about continuing to overload this table if a fifth
record type is ever needed.

## Schema version history

| Version | Sprint | Change |
|---|---|---|
| 1 | SPR-DEP-001 | Foundation: all 14 tables, `id`/`name`/audit columns only |
| 2 | SPR-DEP-003 | Full domain columns for all 13 Data Layer tables (`Settings` excluded — no Model existed for it yet) |
| 3 | SPR-DEP-005 | Rule-storage columns added to `Settings` |
| 4 | SPR-DEP-006 | Recommendation-history columns added to `Settings` |
| 5 | SPR-DEP-007 | Trial-audit columns added to `Settings` |
| 5 | R1-R6 (Repair Sprints) | **No schema change.** All six repair sprints operated under an explicit "Do NOT modify database schema" constraint. R2 added one repository method (`TrialRepository.updateMaterialLine()`, an `UPDATE` against the already-existing `Formula_Material` columns — no new column). Confirmed unchanged by diffing `database_helper.dart` byte-for-byte against the pre-R1 baseline after every sprint. |

Every upgrade (`_onUpgrade` in `DatabaseHelper`) is non-destructive
from v2 onward (`ALTER TABLE ADD COLUMN`, never `DROP`); v1->v2 does
drop and recreate tables, documented and justified in
`docs/sprints/SPR-DEP-003-completion-report.md` (no real device had
run the v1 schema at that point).

## Known open question

The database filename has been `hue_muse_shade_ai.db` since
SPR-DEP-001, but a later sprint's brief stated `huemuse_shade_ai.db`
(no underscore between "hue" and "muse"). The original name was kept
to avoid orphaning already-approved data — flagged for confirmation
in `docs/sprints/SPR-DEP-003-completion-report.md`, still
unconfirmed.
