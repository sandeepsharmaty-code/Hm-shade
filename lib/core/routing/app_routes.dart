/// Purpose      : Centralized route name constants for Hue Muse
///                Shade AI.
/// Author       : HMEOS Engineering
/// Version      : 2.3.0
/// Dependencies : none (pure Dart)
/// Description  : Single source of truth for named routes so no
///                screen hardcodes a route string.
/// Change History:
///   1.0.0 - SPR-DEP-002 - Initial creation.
///   2.0.0 - SPR-DEP-009 - Added `trial`, dispatched by AppRouter to
///           the new TrialScreen. Kept the 5-tab shell exactly as
///           approved (SPR-DEP-002) rather than adding a 6th bottom
///           tab — Trial is reached by push (from New Shade's
///           workflow or Home's "Pending Lab Trials"), not as a tab.
///   2.1.0 - Repair Sprint R1 - Added `productManagement`, dispatched
///           by AppRouter to the new ProductManagementScreen. Same
///           push-not-tab rationale as `trial`.
///   2.2.0 - Repair Sprint R2 (Formula Workflow) - Added
///           `formulaList`, `formulaDetails`, `formulaEdit`. Same
///           push-not-tab rationale as `trial`/`productManagement`.
///   2.3.0 - Repair Sprint R5 (Missing Business Modules) - Added
///           `shadeManagement`, `materialManagement`. Same
///           push-not-tab rationale as every other management screen.
library;

/// Named route identifiers used throughout the app.
class AppRoutes {
  AppRoutes._();

  /// Splash screen — initial route, performs SQLite bootstrap.
  static const String splash = '/';

  /// Root application shell — bottom navigation host for Home,
  /// New Shade, Knowledge Base, Search, and Settings tabs.
  static const String shell = '/shell';

  /// Trial detail screen — pushed with a `productId` (int) and
  /// optional `shadeFamily` (String) as route arguments.
  static const String trial = '/trial';

  /// Product Management screen — pushed with no arguments from
  /// Home's "Manage Products" quick action. Lists, creates, edits,
  /// and soft-deletes Product_Master records. Kept off the 5-tab
  /// shell for the same reason as `trial` above.
  static const String productManagement = '/product-management';

  /// Formula List screen — pushed with an optional
  /// FormulaListScreenArgs (a nullable `productId`). No arguments
  /// shows every formula grouped by product (Home's "Formulas" quick
  /// action); a `productId` shows only that product's formulas
  /// (Product Management's "View Formulas" action — R2-008).
  static const String formulaList = '/formula-list';

  /// Formula Details screen — pushed with a required
  /// FormulaDetailsScreenArgs (`trialFormulaId`).
  static const String formulaDetails = '/formula-details';

  /// Formula create/edit screen — pushed with an optional
  /// FormulaFormScreenArgs (`existingTrialFormulaId` for edit,
  /// `productId` to pre-select a product when creating).
  static const String formulaEdit = '/formula-edit';

  /// Shade Management screen — pushed with an optional
  /// ShadeManagementScreenArgs (a nullable `productId`, same
  /// pre-select-but-changeable pattern as `formulaList`).
  static const String shadeManagement = '/shade-management';

  /// Raw Material Management screen — pushed with no arguments. One
  /// screen covers all six material tables (Pigment/Dye/Mica/Pearl/
  /// Filler/Binder), selected in-screen.
  static const String materialManagement = '/material-management';

  // Reserved for future module sprints. Not yet dispatched by
  // AppRouter; declared here so route names are agreed in advance
  // and future sprints don't invent ad hoc strings.
  static const String newShadeCapture = '/new-shade/capture';
  static const String knowledgeBaseDetail = '/knowledge-base/detail';
}
