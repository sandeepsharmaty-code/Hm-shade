/// Purpose      : Shared interface for the six raw-material models.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : none (pure Dart)
/// Description  : PigmentModel, DyeModel, MicaModel, PearlModel,
///                FillerModel, and BinderModel are separate concrete
///                classes (matching six separate approved tables),
///                but share an identical shape. This interface lets
///                RecommendationEngine (SPR-DEP-004) read any of them
///                polymorphically — via each repository's own typed
///                readById — without resorting to dynamic dispatch,
///                per this sprint's SOLID/Clean Architecture
///                requirement.
/// Change History:
///   1.0.0 - SPR-DEP-004 - Initial creation. Implemented by all six
///           raw-material models.
library;

/// Common shape shared by every raw-material master model.
abstract class RawMaterialModel {
  int? get id;
  String get name;
  String get materialCode;
  String? get casNumber;
  String? get supplier;
  String get unit;
  double get costPerUnit;
  double get stockQuantity;
  bool get isActive;
}
