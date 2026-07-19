/// Purpose      : Root application widget for Hue Muse Shade AI.
/// Author       : HMEOS Engineering
/// Version      : 2.0.0
/// Dependencies : flutter/material.dart, provider,
///                core/theme/app_theme.dart,
///                core/routing/app_router.dart,
///                core/routing/app_routes.dart,
///                core/services/app_state_provider.dart,
///                core/services/navigation_provider.dart
/// Description  : Installs the Provider state tree (Business Layer
///                entry point: database-readiness state plus shell
///                tab-navigation state), applies the Material Design
///                3 theme, and configures centralized named routing
///                via AppRouter instead of a single hardcoded `home:`
///                screen.
/// Change History:
///   1.0.0 - SPR-DEP-001 - Initial creation (split out of main.dart).
///   2.0.0 - SPR-DEP-002 - Added NavigationProvider via MultiProvider.
///           Switched from `home:` to named routing (initialRoute +
///           onGenerateRoute) to support the application shell.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/routing/app_router.dart';
import 'core/routing/app_routes.dart';
import 'core/services/app_state_provider.dart';
import 'core/services/navigation_provider.dart';
import 'core/theme/app_theme.dart';

/// Root widget of the Hue Muse Shade AI application.
class HueMuseShadeAiApp extends StatelessWidget {
  const HueMuseShadeAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppStateProvider>(
          create: (_) => AppStateProvider(),
        ),
        ChangeNotifierProvider<NavigationProvider>(
          create: (_) => NavigationProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'Hue Muse Shade AI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
  }
}
