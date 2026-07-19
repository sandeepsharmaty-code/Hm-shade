# Hue Muse Shade AI — User Manual

## Getting Started

The app opens to a splash screen while it sets up its local database,
then lands on **Home**. Five tabs sit at the bottom: Home, New Shade,
Knowledge, Search, Settings.

## Home

Shows a quick summary — Products, Shades, Materials, and Pending
counts, plus a second row for the approval workflow (Approved,
Awaiting Approval, Rejected, Revisions Pending) — your most recent
recommendations, any trials waiting on lab work, and quick-action
buttons to New Shade, Manage Products, Manage Shades, Manage
Materials, Formulas, Approved Formulas, Search, and Knowledge. Pull
down to refresh.

## New Shade — the main workflow

1. **Pick a product** from the dropdown at the top. If none exist
   yet, tap **Manage Products** from Home to add one first — see
   "Product / Shade / Material Management" below.
2. **Capture or select a shade image** using the camera/gallery
   buttons.
3. Tap **Analyze Image**. You'll see:
   - A **Color Profile**: the average colour swatch, up to five
     dominant colour dots, and brightness/saturation/lightness
     percentages.
   - A **Shade Detection** result: colour family (e.g. Red, Nude,
     Blue), undertone (Warm/Cool/Neutral), whether it's dark, light,
     or mid-tone, and whether the image has one dominant colour or
     several.
4. Tap **View Top 5 Recommendations** to move to the Trial screen.

## Trial Screen

Shows up to five ranked trial formulas for your product/shade. Each
card shows a rank, confidence percentage, status, and any conflicts
found. Tap a card to reveal four actions:

- **Explanation** — why this trial was selected, why its confidence
  is what it is, which rules matched and which failed, what material
  alternatives exist, and what conflicts were found.
- **Validation** — a pass/fail checklist against 8 criteria (product/
  shade/finish/coverage compatibility, material availability, rule
  compliance, confidence threshold).
- **History** — every status change this trial has ever had.
- **Mark Ready for Lab** — moves the trial into the lab workflow and
  records the change.

Tap the compare icon in the top bar to see all five trials side by
side, with differences flagged.

## Knowledge

Four tabs:
- **Knowledge** — general knowledge base entries.
- **Approved Formulas** — every trial that's reached Approved status.
- **Rules** — every configurable business rule, with its type,
  priority, weight, and enabled/disabled state.
- **Recent Updates** — the five most recently edited knowledge
  entries.

## Product / Shade / Material Management

Reached from Home's quick actions, or from within each other (a
product row's icons open that product's shades or formulas directly).

- **Manage Products** — list, search, add, edit, and delete (soft)
  products. Fields: name, product code, category, base type,
  description.
- **Manage Shades** — same pattern, for shades. Extra: filter by
  product, and an Active/Inactive view (a deleted shade can be
  restored from the Inactive view). Fields: name, shade code,
  product, colour (hex — the closest available field to a Pantone
  reference; this version has no dedicated Pantone/coverage/
  description fields), shade family, finish, status.
- **Manage Materials** — one screen for all six raw-material types
  (Pigment, Dye, Mica, Pearl, Filler, Binder), switchable with the
  chips at the top. Same Active/Inactive-with-Restore pattern.
  Fields: name, material code, CAS number, supplier, unit, cost per
  unit, stock quantity. (Each material type also has one column
  unique to it — e.g. Pigment's Colour Index — not editable from this
  generic screen.)

Deleting anything in this app is always a **soft delete**: the record
is hidden from lists but never actually erased, and can be restored
from the Inactive view.

## Formulas

Reached from Home's "Formulas" quick action, or a product's own
"View Formulas" icon. Lists formulas grouped by product, with search
and filters for both Product and Status (including "Approved," for
jumping straight to the approval list).

Tap **+** to create a formula by hand: name, trial code, product,
shade (optional), notes, and an ingredient list — add materials with
a percentage and optional notes per line. Tap a formula to see its
full detail: product, shade, ingredients (each with a live Rule
Compliance check — approved or flagged, with alternatives if
flagged), notes, status, and its status-change history.

## Approved Formula Workflow

From a formula's detail screen, once it reaches **Lab Testing**:

- **Approve** — enter an approver name and optional notes. This
  creates a permanent approval record and locks the formula
  read-only.
- **Reject** — enter a reason. The formula moves to Rejected.
- **Request Revision** — for a rejected formula, send it back to
  Draft with revision notes for the person reworking it.

Once approved, a formula can no longer be edited or deleted directly
— **Create Revision** replaces those actions, which starts a
brand-new formula (pre-filled from the approved one) without ever
changing the original. The approved formula stays exactly as it was
approved, permanently.

## Search

Choose a category (Shades, Products, Materials, Formulas, Knowledge)
with the chips at the top, then type a query. Materials search covers
all six raw-material types at once. Formulas search includes approved
formulas — they're the same records, just further along in status.

## Settings

- **Backup Database** — saves a timestamped copy of your local
  database.
- **Restore Database** — pick a previous backup to restore. The app
  checks the file is a genuine, uncorrupted database first and
  refuses to restore anything that fails that check. A safety copy of
  your *current* database is taken automatically before restoring, in
  case you change your mind. **You must restart the app afterward**
  for the restored data to take effect.
- **Export Knowledge** — saves all Knowledge Base entries as a JSON
  file.
- **Import Knowledge** — place a file named `knowledge_import.json`
  in the app's `Documents/imports/` folder, then tap Import. (There's
  no in-app file browser in this version — you'll need a file manager
  app or a computer connection to place the file there.)
- **Clear Cache** — frees temporary storage; doesn't touch your data.
- **About Application** — version and offline-only confirmation.
- **Reset Local Data** — permanently erases everything. Requires
  confirmation; cannot be undone (there's no cloud copy — it's an
  offline app).

## Offline by design

Nothing in this app ever makes a network request. You can use it on
a plane, in a basement lab, anywhere.
