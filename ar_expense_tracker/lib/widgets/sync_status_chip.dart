import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/drive_sync_service.dart';

class SyncStatusChip extends ConsumerWidget {
  const SyncStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncService = ref.watch(driveSyncServiceProvider);
    
    return ValueListenableBuilder<SyncState>(
      valueListenable: syncService.syncState,
      builder: (context, state, _) {
        final bool showChip = state.isSyncing || state.syncStatus.isNotEmpty;
        if (!showChip) return const SizedBox.shrink();

        return Positioned(
          bottom: 100, // Positioned above the Floating Action Button
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.isSyncing) ...[
                    if (state.syncProgress >= 0)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          value: state.syncProgress,
                          strokeWidth: 2,
                        ),
                      )
                    else
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    const SizedBox(width: 12),
                  ] else ...[
                    Icon(Icons.check_circle, size: 18, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    state.syncStatus,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (state.syncProgress >= 0 && state.isSyncing) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${(state.syncProgress * 100).toInt()}%',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      syncService.clearStatusWithDelay(doneMessage: '');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(Icons.close_rounded, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ).animate(key: ValueKey(state.syncStatus))
             .slideY(begin: 1.5, end: 0, duration: 400.ms, curve: Curves.easeOutQuart)
             .fadeIn(duration: 400.ms),
          ),
        );
      },
    );
  }
}
