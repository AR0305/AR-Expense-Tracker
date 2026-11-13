import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/expense_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/font_utils.dart';
import '../database/expense_database.dart';
import '../utils/haptics.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ArchivedGroupsScreen extends ConsumerStatefulWidget {
  const ArchivedGroupsScreen({super.key});

  @override
  ConsumerState<ArchivedGroupsScreen> createState() => _ArchivedGroupsScreenState();
}

class _ArchivedGroupsScreenState extends ConsumerState<ArchivedGroupsScreen> {
  List<ExpenseGroup> _archivedGroups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArchivedGroups();
  }

  Future<void> _loadArchivedGroups() async {
    final db = ref.read(expenseDatabaseProvider);
    final groups = await db.fetchArchivedGroups();
    if (mounted) {
      setState(() {
        _archivedGroups = groups;
        _isLoading = false;
      });
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'home_rounded': return Icons.home_rounded;
      case 'flight_takeoff_rounded': return Icons.flight_takeoff_rounded;
      case 'work_rounded': return Icons.work_rounded;
      case 'school_rounded': return Icons.school_rounded;
      case 'favorite_rounded': return Icons.favorite_rounded;
      case 'directions_car_rounded': return Icons.directions_car_rounded;
      case 'shopping_bag_rounded': return Icons.shopping_bag_rounded;
      case 'restaurant_rounded': return Icons.restaurant_rounded;
      default: return Icons.folder_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              'Archived Books',
              style: FontUtils.getFontTextStyle(
                ref.watch(titleFontProvider),
                TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            backgroundColor: Theme.of(context).colorScheme.surface,
            surfaceTintColor: Theme.of(context).colorScheme.primary,
            pinned: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_archivedGroups.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No archived books',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ).animate().fadeIn().slideY(begin: 0.1, end: 0),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final group = _archivedGroups[index];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
                      shape: ContinuousRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getIconData(group.icon),
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        title: Text(
                          group.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Created ${group.createdAt.day}/${group.createdAt.month}/${group.createdAt.year}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.unarchive_rounded),
                              tooltip: 'Unarchive',
                              onPressed: () async {
                                Haptics.mediumImpact();
                                await ref.read(groupProvider.notifier).toggleArchive(group.id, false);
                                _loadArchivedGroups();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${group.name} unarchived')),
                                  );
                                }
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_forever_rounded,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              tooltip: 'Delete Permanently',
                              onPressed: () {
                                Haptics.heavyImpact();
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Book?'),
                                    content: Text('Are you sure you want to permanently delete "${group.name}"? This action cannot be undone.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Theme.of(context).colorScheme.error,
                                        ),
                                        onPressed: () async {
                                          Navigator.pop(ctx);
                                          await ref.read(groupProvider.notifier).deleteGroup(group.id);
                                          _loadArchivedGroups();
                                        },
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.1, end: 0, duration: 250.ms);
                  },
                  childCount: _archivedGroups.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
