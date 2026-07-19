/// Purpose      : Centralized route dispatcher for Hue Muse Shade AI.
/// Author       : HMEOS Engineering
/// Version      : 2.3.0
/// Dependencies : flutter/material.dart, app_routes.dart,
///                screens/splash_screen.dart,
///                screens/root_shell_screen.dart,
///                screens/trial_screen.dart,
///                screens/product_management_screen.dart,
///                screens/formula_list_screen.dart,
///                screens/formula_details_screen.dart,
///                screens/formula_form_screen.dart,
///                screens/shade_management_screen.dart,
///                screens/material_management_screen.dart
/// Description  : Single onGenerateRoute implementation used by
///                MaterialApp so navigation is centralized rather
///                than scattered across screens with inline
///                MaterialPageRoute construction. Unknown route names
///                resolve to a simple "route not found" screen
///                instead of crashing, per the "never crash
///                application" error-handling rule.
/// Change History:
///   1.0.0 - SPR-DEP-002 - Initial creation.
///   2.0.0 - SPR-DEP-009 - Added AppRoutes.trial dispatch. Falls back
///           to the "not found" screen if TrialScreenArgs weren't
///           supplied correctly, rather than crashing on a bad cast.
///   2.1.0 - Repair Sprint R1 - Added AppRoutes.productManagement
///           dispatch to the new ProductManagementScreen (no
///           arguments required).
///   2.2.0 - Repair Sprint R2 (Formula Workflow) - Added
///           AppRoutes.formulaList/formulaDetails/formulaEdit
///           dispatch. formulaList and formulaEdit accept optional
///           arguments (default to an empty args object if omitted
///           or the wrong type); formulaDetails requires
///           FormulaDetailsScreenArgs and falls back to the "not
///           found" screen otherwise, same as `trial`.
///   2.3.0 - Repair Sprint R5 (Missing Business Modules) - Added
///           AppRoutes.shadeManagement (optional args, same pattern
///           as formulaList) and AppRoutes.materialManagement (no
///           arguments — the screen selects among all six tables
///           in-screen).
library;

import 'package:flutter/material.dart';

import '../../screens/formula_details_screen.dart';
import '../../screens/formula_form_screen.dart';
import '../../screens/formula_list_screen.dart';
import '../../screens/material_management_screen.dart';
import '../../screens/product_management_screen.dart';
import '../../screens/root_shell_screen.dart';
import '../../screens/shade_management_screen.dart';
import '../../screens/splash_screen.dart';
import '../../screens/trial_screen.dart';
import 'app_routes.dart';

/// Resolves route names to concrete screens for the app's
/// [MaterialApp.onGenerateRoute].
class AppRouter {
  AppRouter._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute<void>(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );

      case AppRoutes.shell:
        return MaterialPageRoute<void>(
          builder: (_) => const RootShellScreen(),
          settings: settings,
        );

      case AppRoutes.productManagement:
        return MaterialPageRoute<void>(
          builder: (_) => const ProductManagementScreen(),
          settings: settings,
        );

      case AppRoutes.shadeManagement: {
        final Object? args = settings.arguments;
        return MaterialPageRoute<void>(
          builder: (_) => ShadeManagementScreen(
            args: args is ShadeManagementScreenArgs
                ? args
                : const ShadeManagementScreenArgs(),
          ),
          settings: settings,
        );
      }

      case AppRoutes.materialManagement:
        return MaterialPageRoute<void>(
          builder: (_) => const MaterialManagementScreen(),
          settings: settings,
        );

      case AppRoutes.formulaList: {
        final Object? args = settings.arguments;
        return MaterialPageRoute<void>(
          builder: (_) => FormulaListScreen(
            args: args is FormulaListScreenArgs
                ? args
                : const FormulaListScreenArgs(),
          ),
          settings: settings,
        );
      }

      case AppRoutes.formulaDetails: {
        final Object? args = settings.arguments;
        if (args is! FormulaDetailsScreenArgs) {
          return MaterialPageRoute<void>(
            builder: (_) => const _UnknownRouteScreen(
              routeName: '${AppRoutes.formulaDetails} (missing arguments)',
            ),
            settings: settings,
          );
        }
        return MaterialPageRoute<void>(
          builder: (_) => FormulaDetailsScreen(args: args),
          settings: settings,
        );
      }

      case AppRoutes.formulaEdit: {
        final Object? args = settings.arguments;
        return MaterialPageRoute<void>(
          builder: (_) => FormulaFormScreen(
            args: args is FormulaFormScreenArgs
                ? args
                : const FormulaFormScreenArgs(),
          ),
          settings: settings,
        );
      }

      case AppRoutes.trial: {
        final Object? args = settings.arguments;
        if (args is! TrialScreenArgs) {
          return MaterialPageRoute<void>(
            builder: (_) => const _UnknownRouteScreen(
              routeName: '${AppRoutes.trial} (missing arguments)',
            ),
            settings: settings,
          );
        }
        return MaterialPageRoute<void>(
          builder: (_) => TrialScreen(args: args),
          settings: settings,
        );
      }

      default:
        return MaterialPageRoute<void>(
          builder: (_) => _UnknownRouteScreen(routeName: settings.name),
          settings: settings,
        );
    }
  }
}

/// Fallback screen shown when navigation is requested to an
/// unregistered route name. Prevents an unhandled-route crash.
class _UnknownRouteScreen extends StatelessWidget {
  const _UnknownRouteScreen({required this.routeName});

  final String? routeName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not Found')),
      body: Center(
        child: Text('No screen registered for route "${routeName ?? ''}".'),
      ),
    );
  }
}
