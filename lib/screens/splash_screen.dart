/// Purpose      : Splash screen for Hue Muse Shade AI. Initializes
///                the local SQLite database on first launch and
///                transitions to the application shell.
/// Author       : HMEOS Engineering
/// Version      : 1.1.0
/// Dependencies : flutter/material.dart, provider,
///                core/database/database_helper.dart,
///                core/di/service_locator.dart,
///                core/services/app_state_provider.dart,
///                core/routing/app_routes.dart
/// Description  : Entry screen of the offline shade-development
///                workflow. Performs SQLite table creation (see
///                DatabaseHelper, resolved via ServiceLocator) before
///                navigating to the bottom-navigation application
///                shell, with basic error handling surfaced to the
///                user if initialization fails.
/// Change History:
///   1.0.0 - SPR-DEP-001 - Initial creation. Navigated directly to
///           HomeScreen via inline MaterialPageRoute.
///   1.1.0 - SPR-DEP-002 - Resolves DatabaseHelper via ServiceLocator
///           instead of the static singleton directly. Navigates to
///           the named shell route (AppRoutes.shell) instead of a
///           hardcoded screen, now that the shell exists.
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../core/database/database_helper.dart';
import '../core/di/service_locator.dart';
import '../core/routing/app_routes.dart';
import '../core/services/app_state_provider.dart';

/// Displays the Hue Muse Shade AI brand mark while the local database
/// initializes, then navigates to the application shell.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Touch the database to force table creation via onCreate.
      final DatabaseHelper databaseHelper =
          ServiceLocator.instance.get<DatabaseHelper>();
      await databaseHelper.database;

      if (!mounted) {
        return;
      }

      context.read<AppStateProvider>().setDatabaseReady();

      // Brief, deliberate pause so the brand mark is perceivable.
      await Future<void>.delayed(const Duration(milliseconds: 600));

      if (!mounted) {
        return;
      }

      await Navigator.of(context).pushReplacementNamed(AppRoutes.shell);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('SplashScreen: database initialization failed: $error');
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage =
            'Unable to initialize local database. Please restart the app.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.palette,
              size: 96,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Hue Muse Shade AI',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Offline Shade Development',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 32),
            if (_errorMessage == null)
              const CircularProgressIndicator()
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
