import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'group_selection_screen.dart';

import '../providers/expense_provider.dart';
import '../providers/shared_intent_provider.dart';
import '../services/drive_sync_service.dart';
import '../services/upi_tracking_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Attempt silent sign-in and start sync if possible
    final syncService = ref.read(driveSyncServiceProvider);
    if (!syncService.isSignedIn) {
      await syncService.signInSilently();
    }
    await syncService.performSmartSync();

    // Pre-warm the database and providers to prevent haptic delay/jank
    final db = ref.read(expenseDatabaseProvider);
    await db.fetchGroups(); // Spins up SQLite engine and caches
    ref.read(groupProvider); // Initialize the provider
    await UpiTrackingService.processPendingApprovedExpenses(db);
    
    // Artificial delay to ensure the beautiful loader is visible for a moment
    await Future.delayed(const Duration(milliseconds: 1000));
    
    if (mounted) {
      final pendingUri = ref.read(pendingWidgetUriProvider);
      if (pendingUri != null || ModalRoute.of(context)?.isCurrent != true) {
        // Handled by HomeWidget or Notification deep link listener in main.dart
        return;
      }
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const GroupSelectionScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        // Material 3 Expressive Loading Indicator
        child: const SizedBox(
          width: 80,
          height: 80,
          child: LoadingIndicatorM3E(),
        ).animate()
         .fadeIn(duration: 600.ms, delay: 200.ms)
         .scale(duration: 600.ms, curve: Curves.easeOutBack),
      ),
    );
  }
}
