import '../utils/haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import '../providers/expense_provider.dart';
import '../database/expense_database.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/theme_provider.dart';
import '../utils/font_utils.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'archived_groups_screen.dart';
import 'package:intl/intl.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import '../providers/custom_category_provider.dart';
import '../providers/budget_provider.dart';
import '../services/drive_sync_service.dart';
import '../widgets/micro_interactions.dart';
import 'splash_screen.dart';
import '../widgets/sync_status_chip.dart';
import '../widgets/dynamic_icon_bg.dart';

class GroupSelectionScreen extends ConsumerWidget {
  const GroupSelectionScreen({super.key});

  void _showGroupDialog(
    BuildContext context,
    WidgetRef ref, {
    ExpenseGroup? existingGroup,
  }) {
    showDialog(
      context: context,
      builder: (context) => _GroupDialog(existingGroup: existingGroup),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupProvider);

    return Scaffold(
      body: Stack(
        children: [
        CustomMaterialIndicator(
        backgroundColor: Theme.of(context).colorScheme.surface,
        onRefresh: () async {
          Haptics.mediumImpact();
          final syncService = ref.read(driveSyncServiceProvider);
          if (!syncService.isSignedIn) {
            final signedIn = await syncService.signInSilently() || await syncService.signIn();
            if (!signedIn) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in required for Drive Sync.')));
              }
              return;
            }
          }
          try {
            final db = ref.read(expenseDatabaseProvider);
            final result = await syncService.performSmartSync(
              force: true,
              onBeforeDownload: () async {
                await db.close();
              },
            );
            if (context.mounted) {
              if (result == SyncResult.downloaded) {
                ref.invalidate(expenseDatabaseProvider);
                ref.invalidate(groupProvider);
                ref.invalidate(expenseProvider);
                ref.invalidate(customCategoryProvider);
                ref.invalidate(categoryBudgetProvider);
                
                Navigator.pushAndRemoveUntil(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const SplashScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    transitionDuration: const Duration(milliseconds: 800),
                  ),
                  (route) => false,
                );
              } else if (result == SyncResult.uploaded) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Synced to Google Drive successfully.')));
              } else if (result == SyncResult.upToDate) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Local data is up to date.')));
              }
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
            }
          }
        },
        indicatorBuilder: (context, controller) {
          return const Padding(
            padding: EdgeInsets.all(4.0),
            child: LoadingIndicatorM3E(),
          );
        },
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: Text(
                  'Expense Books',
                  style: FontUtils.getFontTextStyle(
                    ref.watch(titleFontProvider),
                    TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                backgroundColor: Theme.of(context).colorScheme.surface,
                surfaceTintColor: Theme.of(context).colorScheme.primary,
                pinned: true,
                scrolledUnderElevation: 2,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: () {
                      Haptics.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ArchivedGroupsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.archive_outlined),
                    tooltip: 'Archived Books',
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      Haptics.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings_rounded),
                    tooltip: 'Settings',
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(20),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),

              if (groups.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DynamicIconBg(
                          padding: 32,
                          color: Theme.of(context).colorScheme.primaryContainer.withAlpha(100),
                          child: Icon(
                            Icons.collections_bookmark_rounded,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'No Expense Books',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the button below to add your first expense book.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0, duration: 600.ms, curve: Curves.easeOutCubic),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final group = groups[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _GroupHorizontalCard(group: group, index: index)
                            .animate()
                            .slideY(begin: 0.1, end: 0, duration: 250.ms, curve: Curves.easeOutCubic)
                            .fadeIn(duration: 250.ms),
                      );
                    }, childCount: groups.length),
                  ),
                ),
            ],
          ),
        ),
      ),
      const SyncStatusChip(),
      ],
      ),
      floatingActionButton: PressableButton(
        scaleFactor: 0.88,
        onTap: () {
          Haptics.lightImpact();
          _showGroupDialog(context, ref);
        },
        child: FloatingActionButton.extended(
          onPressed: null,
          icon: DynamicIconBg(
            padding: 6,
            color: Theme.of(context).colorScheme.primary.withAlpha(50),
            child: Icon(Icons.add_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
          ),
          label: Text(
            'New Book', 
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 15, 
              color: Theme.of(context).colorScheme.primary
            ),
          ),
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ).animate().scale(delay: 300.ms, duration: 500.ms, curve: Curves.easeOutBack),
    );
  }
}

class _GroupHorizontalCard extends ConsumerWidget {
  final ExpenseGroup group;
  final int index;

  const _GroupHorizontalCard({required this.group, required this.index});

  static const List<Color> _accentColors = [
    Color(0xFF4B39EF),
    Color(0xFFE91E63),
    Color(0xFF009688),
    Color(0xFFFF9800),
    Color(0xFF673AB7),
    Color(0xFF2196F3),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expenseProvider(group));
    final totalSpent = expenses.fold(0.0, (sum, e) => sum + e.amount);
    
    // Find last active date
    DateTime lastActive = group.createdAt;
    for (var e in expenses) {
      if (e.date.isAfter(lastActive)) lastActive = e.date;
    }
    
    String lastActiveText;
    final now = DateTime.now();
    final difference = now.difference(lastActive).inDays;
    if (difference == 0 && now.day == lastActive.day) {
      lastActiveText = 'Today';
    } else if (difference == 1 || (difference == 0 && now.day != lastActive.day)) {
      lastActiveText = 'Yesterday';
    } else {
      lastActiveText = DateFormat('MMM d, yyyy').format(lastActive);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = group.monthlyBudget != null 
        ? (totalSpent / group.monthlyBudget!).clamp(0.0, 1.0) 
        : 0.0;
        
    Color progressColor = Theme.of(context).colorScheme.primary;
    if (progress > 0.9) {
      progressColor = Theme.of(context).colorScheme.error;
    } else if (progress > 0.75) {
      progressColor = Colors.orange;
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withAlpha(isDark ? 40 : 80),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(20),
        child: PressableButton(
          scaleFactor: 0.97,
          onTap: () {
            Haptics.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => HomeScreen(group: group)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    DynamicIconBg(
                      padding: 14,
                      color: _accentColors[index % _accentColors.length].withAlpha(30),
                      child: Icon(
                        _getIconData(group.icon),
                        color: _accentColors[index % _accentColors.length],
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  group.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.2,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              if (group.isPinned) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.push_pin_rounded, 
                                  size: 14, 
                                  color: Theme.of(context).colorScheme.primary
                                ),
                              ]
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${expenses.length} records • Active $lastActiveText',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withAlpha(150),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AnimatedCounter(
                      value: totalSpent,
                      decimalDigits: 0,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Total',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(120),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 4),

                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha(120),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onSelected: (value) async {
                    Haptics.lightImpact();
                    if (value == 'edit') {
                      showDialog(
                        context: context,
                        builder: (context) =>
                            _GroupDialog(existingGroup: group),
                      );
                    } else if (value == 'pin') {
                      await ref.read(groupProvider.notifier).togglePin(group.id, !group.isPinned);
                    } else if (value == 'archive') {
                      await ref.read(groupProvider.notifier).toggleArchive(group.id, true);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${group.name} archived')),
                        );
                      }
                    } else if (value == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Book?'),
                          content: const Text(
                            'This will delete all expenses inside this book. This cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        Haptics.heavyImpact();
                        await ref
                            .read(groupProvider.notifier)
                            .deleteGroup(group.id);
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    if (group.isPinned)
                      const PopupMenuItem(
                        value: 'pin',
                        child: Text('Unpin from top'),
                      )
                    else
                      const PopupMenuItem(
                        value: 'pin',
                        child: Text('Pin to top'),
                      ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit Book'),
                    ),
                    const PopupMenuItem(
                      value: 'archive',
                      child: Text('Archive Book'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete Book', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
            if (group.monthlyBudget != null) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Budget: ₹${NumberFormat('#,##0').format(group.monthlyBudget)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}% used',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: progressColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 14,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        width: constraints.maxWidth * progress,
                        decoration: BoxDecoration(
                          color: progressColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'flight_rounded':
        return Icons.flight_rounded;
      case 'home_rounded':
        return Icons.home_rounded;
      case 'directions_car_rounded':
        return Icons.directions_car_rounded;
      case 'shopping_bag_rounded':
        return Icons.shopping_bag_rounded;
      case 'restaurant_rounded':
        return Icons.restaurant_rounded;
      case 'work_rounded':
        return Icons.work_rounded;
      case 'favorite_rounded':
        return Icons.favorite_rounded;
      case 'folder_rounded':
      default:
        return Icons.folder_rounded;
    }
  }
}

class _GroupDialog extends ConsumerStatefulWidget {
  final ExpenseGroup? existingGroup;

  const _GroupDialog({this.existingGroup});

  @override
  ConsumerState<_GroupDialog> createState() => _GroupDialogState();
}

class _GroupDialogState extends ConsumerState<_GroupDialog> {
  final _controller = TextEditingController();
  final _budgetController = TextEditingController();
  late String _selectedIcon;
  bool _useDateAsName = false;

  @override
  void initState() {
    super.initState();
    _useDateAsName = widget.existingGroup?.isMonthlyBudget ?? false;
    _controller.text = widget.existingGroup?.name ?? '';
    if (widget.existingGroup?.monthlyBudget != null) {
      _budgetController.text = widget.existingGroup!.monthlyBudget!
          .toStringAsFixed(0);
    }
    _selectedIcon = widget.existingGroup?.icon ?? 'folder_rounded';
  }

  final List<Map<String, dynamic>> _icons = [
    {'name': 'folder_rounded', 'icon': Icons.folder_rounded},
    {'name': 'flight_rounded', 'icon': Icons.flight_rounded},
    {'name': 'home_rounded', 'icon': Icons.home_rounded},
    {'name': 'directions_car_rounded', 'icon': Icons.directions_car_rounded},
    {'name': 'shopping_bag_rounded', 'icon': Icons.shopping_bag_rounded},
    {'name': 'restaurant_rounded', 'icon': Icons.restaurant_rounded},
    {'name': 'work_rounded', 'icon': Icons.work_rounded},
    {'name': 'favorite_rounded', 'icon': Icons.favorite_rounded},
  ];

  @override
  void dispose() {
    _controller.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Row(
        children: [
          Icon(
            widget.existingGroup != null
                ? Icons.edit_rounded
                : Icons.collections_bookmark_rounded,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            widget.existingGroup != null ? 'Edit Book' : 'Create Book',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('Lock Budget to Month', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
              subtitle: const Text('Sets the book name to the current month and year', style: TextStyle(fontSize: 12)),
              value: _useDateAsName,
              contentPadding: EdgeInsets.zero,
              activeThumbColor: Theme.of(context).colorScheme.primary,
              onChanged: (val) {
                Haptics.selectionClick();
                setState(() {
                  _useDateAsName = val;
                  if (val) {
                    _controller.text = DateFormat('MMMM yyyy').format(DateTime.now());
                  } else {
                    _controller.clear();
                  }
                });
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Book Name',
                hintText: 'e.g., Tokyo Trip, Daily Bills',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                prefixIcon: const Icon(Icons.bookmark_outline_rounded),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Monthly Budget (Optional)',
                hintText: 'e.g., 20000',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Select Icon',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _icons.map((iconData) {
                final isSelected = _selectedIcon == iconData['name'];
                return InkWell(
                  onTap: () {
                    Haptics.lightImpact();
                    setState(() {
                      _selectedIcon = iconData['name'];
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withAlpha(100),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                      ),
                    ),
                    child: Icon(
                      iconData['icon'],
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Haptics.lightImpact();
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Haptics.lightImpact();
            final name = _controller.text.trim();
            final budgetText = _budgetController.text.trim();
            final budget = budgetText.isNotEmpty
                ? double.tryParse(budgetText)
                : null;

            if (name.isNotEmpty) {
              if (widget.existingGroup != null) {
                ref
                    .read(groupProvider.notifier)
                    .updateGroup(
                      widget.existingGroup!.id,
                      name,
                      _selectedIcon,
                      monthlyBudget: budget,
                      isMonthlyBudget: _useDateAsName,
                    );
              } else {
                ref
                    .read(groupProvider.notifier)
                    .addGroup(name, _selectedIcon, monthlyBudget: budget, isMonthlyBudget: _useDateAsName);
              }
              Navigator.pop(context);
            }
          },
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text(widget.existingGroup != null ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}



