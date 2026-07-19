# Hue Muse Shade AI — Release Notes
## Version 1.1.0 (Candidate)

**Status: source-complete (R1-R6 additions included), build-unverified.**
See `docs/sprints/SPR-DEP-012-completion-report.md` for the original
"unverified" baseline and `docs/release/R6_Production_Readiness_Report.md`
for what Repair Sprint R6 (Production Readiness & QA) added and still
could not execute.

---

## What's in this release

**Offline cosmetic colour shade development app.** No internet, no
cloud, no login — all data stays on-device in a local SQLite
database.

### Core workflow
- **Product / Shade / Material Management** *(Repair Sprints R1, R5)*:
  full Create/Edit/Delete (soft)/Restore/Search for Products, Shades
  (filterable by product, Active/Inactive view), and all six
  raw-material categories (one generic screen, not six) — closing the
  gap where these entities existed in the database but had no way to
  be created through the app.
- **New Shade**: pick a product, capture or select a gallery image,
  get deterministic colour analysis (dominant colours, average
  colour, brightness/saturation/lightness, CIELAB colour-distance
  data) and shade classification (family, undertone, dark/light,
  single/multiple dominant colour) — then jump straight to ranked
  trial recommendations for that shade.
- **Trial Recommendations**: Top 5 ranked trial formulas per request,
  each with a confidence score, matched/failed rule breakdown,
  material-availability and alternative-material data, conflict
  detection (product/shade mismatch, inactive/missing material,
  disabled rule, low confidence), and a side-by-side comparison
  report.
- **Formula Workflow** *(Repair Sprint R2)*: a manual counterpart to
  AI-generated trials — create/edit/search formulas directly, add
  ingredients with live per-line Rule Compliance, and move a formula
  through Draft → Ready for Lab → Lab Testing.
- **Approved Formula Workflow** *(Repair Sprint R3)*: Approve (with
  approver name/notes, creating a real approval record) and Reject
  (with a required reason) from Lab Testing; a rejected formula can
  be sent back for revision. Approved formulas are locked read-only —
  changes go through Create Revision, which starts a brand-new
  formula and never touches the approved one's data.
- **Lab Workflow**: trials move through Draft -> Ready for Lab -> Lab
  Testing -> Approved/Rejected -> Archived, with every transition
  permanently recorded in an audit trail (who, when, from/to status,
  reason).
- **Dashboard**: Products, Shades, Materials, Pending, Approved,
  Awaiting Approval, Rejected, and Revisions Pending counts, all
  reading live from the repositories above.
- **Knowledge Base**: approved formulas, configurable business rules,
  and general knowledge records, all searchable.
- **Search**: across shades, products, materials (all six raw-material
  categories), formulas (including approved ones), and knowledge in
  one place.
- **Settings**: Backup/Restore Database (with corruption validation
  and a pre-restore safety snapshot), Export/Import Knowledge, Clear
  Cache, and a full data reset.

### Configurable business rules
Every recommendation decision — product match, shade family match,
finish match, coverage match, per-material-type approval, alternative-
material fallback — is driven by editable rules with priority, weight,
and enabled/disabled state, not hardcoded thresholds.

### Data Layer
14 approved tables covering products, shades, six raw-material
categories, trial formulas, approved formulas, knowledge base, and
settings (which also hosts configurable rules, recommendation
history, and the trial audit trail — see Technical Documentation for
why).

---

## What's *not* in this release

- No formulation chemistry, pigment-ratio calculation, or ingredient
  estimation anywhere — by design. This app organizes and ranks
  existing formulas; it never invents new ones.
- No AI, no machine learning, no camera-based object/face detection.
  Colour analysis is deterministic pixel sampling and colour-space
  math.
- No file picker for Import Knowledge (reads a fixed conventional
  path instead — see User Manual).
- A formal "approve" workflow existed at the repository level since
  the original 12 sprints (`TrialRepository.approveTrial()`) but had
  no screen calling it until Repair Sprint R3.

## Known limitations at ship time

See `docs/release/KNOWN_ISSUES.md` for the full list. Headline item,
unchanged since the original release candidate and every repair
sprint since (R1 through R6): **this build has never been compiled**
— no Flutter SDK has been available in any environment that has
touched this code. Repair Sprint R6 added real widget and unit test
*code* for the areas the original release lacked coverage for, but
running it — along with `flutter analyze`/`flutter build` — remains
the one step no environment so far has been able to perform.

## Requirements

- Android 8.0 (API 26) or later (per the approved target range;
  untested on any specific version — see Device Compatibility).
- No internet connection required or used at any point.
- Camera and/or photo library permission for shade image capture.
