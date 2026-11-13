import 'dart:ui' as ui;
import '../utils/haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import '../providers/expense_provider.dart';
import '../providers/custom_category_provider.dart';
import '../database/expense_database.dart';
import '../services/export_service.dart';
import '../services/drive_sync_service.dart';
import '../services/upi_tracking_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/font_utils.dart';
import 'add_expense_screen.dart';
import '../providers/budget_provider.dart';
import '../widgets/sync_status_chip.dart';
import '../widgets/expandable_expense_card.dart';
import 'splash_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';
import 'manage_recurring_screen.dart';
import 'manage_budgets_screen.dart';
import '../widgets/micro_interactions.dart';
import '../widgets/undo_snackbar_content.dart';
import 'package:home_widget/home_widget.dart';
import '../providers/theme_provider.dart';
import '../providers/shared_intent_provider.dart';
import 'share_group_selection_dialog.dart';
import '../widgets/dynamic_icon_bg.dart';
import 'group_selection_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final ExpenseGroup group;
  final bool autoOpenAddExpense;
  final bool autoOpenInsights;
  final double? initialAddExpenseAmount;
  final String? initialAddExpenseTitle;
  final String? initialAddExpenseCategory;
  final String? initialAddExpenseNote;

  const HomeScreen({
    super.key,
    required this.group,
    this.autoOpenAddExpense = false,
    this.autoOpenInsights = false,
    this.initialAddExpenseAmount,
    this.initialAddExpenseTitle,
    this.initialAddExpenseCategory,
    this.initialAddExpenseNote,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _searchQuery = '';
  String? _selectedCategory;
  bool _isReady = false;
  bool _hasInitialWidgetUpdated = false;
  final Set<int> _pendingDeletes = {};

  @override
  void initState() {
    super.initState();
    // Defer building the heavy animated list until the route transition starts
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _isReady = true);
    });

    _checkAutoOpen();

    // Remember the last opened book: default destination for auto-tracked payments
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setInt(UpiTrackingService.lastOpenedGroupKey, widget.group.id),
    );
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.autoOpenAddExpense && !oldWidget.autoOpenAddExpense) ||
        (widget.autoOpenInsights && !oldWidget.autoOpenInsights)) {
      _checkAutoOpen();
    }
  }

  void _checkAutoOpen() {
    if (widget.autoOpenAddExpense) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => AddExpenseScreen(
              group: widget.group,
              initialAmount: widget.initialAddExpenseAmount,
              initialTitle: widget.initialAddExpenseTitle,
              initialCategory: widget.initialAddExpenseCategory,
              initialNote: widget.initialAddExpenseNote,
            ),
          );
        }
      });
    } else if (widget.autoOpenInsights) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InsightsScreen(group: widget.group),
            ),
          );
        }
      });
    }
  }

  Future<void> _handleSharedImage(
    String imagePath,
    BuildContext context,
  ) async {
    final groups = ref.read(groupProvider);
    ExpenseGroup? selectedGroup;

    if (groups.length == 1) {
      selectedGroup = groups.first;
    } else {
      selectedGroup = await showModalBottomSheet<ExpenseGroup>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (ctx) => ShareGroupSelectionDialog(imagePath: imagePath),
      );
    }

    if (!context.mounted) return;

    if (selectedGroup != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (ctx) => AddExpenseScreen(
          group: selectedGroup!,
          prefilledImagePath: imagePath,
        ),
      );
    }
  }

  void _updateHomeWidget(
    ExpenseGroup activeGroup,
    ExpenseMetrics metrics,
    List<Expense> expenses,
  ) async {
    final formattedTotal = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(metrics.total);
    final formattedDailyAvg = '₹${metrics.dailyAverage.toStringAsFixed(0)}/day';

    // Primary Seed Color & Theme
    final appSeedColor = ref.read(appColorProvider);
    // ignore: deprecated_member_use
    await HomeWidget.saveWidgetData<int>('primary_color', appSeedColor.value);

    // Group Name & Title
    await HomeWidget.saveWidgetData<String>(
      'group_id',
      activeGroup.id.toString(),
    );
    await HomeWidget.saveWidgetData<String>('group_name', activeGroup.name);
    await HomeWidget.saveWidgetData<String>('title', activeGroup.name);
    await HomeWidget.saveWidgetData<String>('amount', formattedTotal);
    await HomeWidget.saveWidgetData<String>('daily_avg', formattedDailyAvg);
    await HomeWidget.saveWidgetData<String>('tx_count', '${expenses.length} ${expenses.length == 1 ? "txn" : "txns"}');

    // Budget Calculations
    if (activeGroup.monthlyBudget != null &&
        activeGroup.monthlyBudget! > 0) {
      final budget = activeGroup.monthlyBudget!;
      final percent = ((metrics.total / budget) * 100).clamp(0, 100).toInt();
      final remaining = budget - metrics.total;

      final String budgetStatus;
      if (remaining >= 0) {
        budgetStatus =
            '₹${NumberFormat.compact(locale: 'en_IN').format(remaining)} left • $percent%';
      } else {
        budgetStatus =
            'Over by ₹${NumberFormat.compact(locale: 'en_IN').format(remaining.abs())} • $percent%';
      }

      await HomeWidget.saveWidgetData<bool>('has_budget', true);
      await HomeWidget.saveWidgetData<String>('budget_status', budgetStatus);
      await HomeWidget.saveWidgetData<int>('budget_percent', percent);
    } else {
      await HomeWidget.saveWidgetData<bool>('has_budget', false);
      await HomeWidget.saveWidgetData<String>('budget_status', '');
      await HomeWidget.saveWidgetData<int>('budget_percent', 0);
    }

    // Latest Expense Snippet
    if (expenses.isNotEmpty) {
      final latest = expenses.first;
      final title = (latest.title != null && latest.title!.isNotEmpty)
          ? latest.title!
          : latest.category;
      final formattedAmt = NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: 0,
      ).format(latest.amount);
      final dateStr = DateFormat('d MMM').format(latest.date);
      await HomeWidget.saveWidgetData<String>(
        'last_expense',
        '$title • $formattedAmt • $dateStr',
      );
    } else {
      await HomeWidget.saveWidgetData<String>('last_expense', '');
    }

    // Render the FAB matching the exact shape setting of the app
    final activeShape = ref.read(iconShapeProvider);
    final isLight = appSeedColor.computeLuminance() > 0.5;
    final iconColor = isLight ? Colors.black : Colors.white;
    
    await HomeWidget.renderFlutterWidget(
      Directionality(
        textDirection: ui.TextDirection.ltr,
        child: Container(
          width: 120,
          height: 120,
          decoration: ShapeDecoration(
            color: appSeedColor,
            shape: DynamicIconBg.getShapeBorder(activeShape),
          ),
          child: Center(
            child: Icon(Icons.add_rounded, color: iconColor, size: 60),
          ),
        ),
      ),
      logicalSize: const Size(120, 120),
      key: 'fab_icon_bitmap',
    );

    await HomeWidget.saveWidgetData<String>('amount_bitmap', '');
    await HomeWidget.updateWidget(androidName: 'AddExpenseWidgetProvider');
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupProvider);
    final activeGroup = groups.firstWhere(
      (g) => g.id == widget.group.id,
      orElse: () => widget.group,
    );

    final allExpenses = ref
        .watch(expenseProvider(activeGroup))
        .where((e) => !_pendingDeletes.contains(e.id))
        .toList();

    final metrics = ref.watch(expenseMetricsProvider(activeGroup));
    final total = metrics.total;

    ref.listen(expenseMetricsProvider(activeGroup), (previous, next) {
      if (previous?.total != next.total) {
        _updateHomeWidget(activeGroup, next, allExpenses);
      }
    });

    ref.listen<String?>(sharedImagePathProvider, (previous, next) {
      if (next != null) {
        // Clear the provider so we don't trigger again
        Future.microtask(
          () => ref.read(sharedImagePathProvider.notifier).clear(),
        );
        _handleSharedImage(next, context);
      }
    });

    // Initial widget update once on screen mount
    if (!_hasInitialWidgetUpdated) {
      _hasInitialWidgetUpdated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateHomeWidget(activeGroup, metrics, allExpenses);

        // Check if there was a pending intent from cold start
        final initialSharedPath = ref.read(sharedImagePathProvider);
        if (initialSharedPath != null) {
          ref.read(sharedImagePathProvider.notifier).clear();
          _handleSharedImage(initialSharedPath, context);
        }
      });
    }

    // Apply search and filtering
    var expenses = allExpenses;
    if (_searchQuery.isNotEmpty) {
      expenses = expenses.where((e) {
        final search = _searchQuery.toLowerCase();
        final matchesTitle = e.title?.toLowerCase().contains(search) ?? false;
        final matchesNote = e.note?.toLowerCase().contains(search) ?? false;
        final matchesCategory = e.category.toLowerCase().contains(search);
        final matchesSubExpenses = e.subExpenses?.any((sub) => sub.name.toLowerCase().contains(search)) ?? false;
        return matchesTitle || matchesCategory || matchesNote || matchesSubExpenses;
      }).toList();
    }
    if (_selectedCategory != null) {
      expenses = expenses
          .where((e) => e.category == _selectedCategory)
          .toList();
    }

    return PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const GroupSelectionScreen(),
            ),
          );
        }
      },
      child: Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          CustomMaterialIndicator(
            backgroundColor: Theme.of(context).colorScheme.surface,
            onRefresh: () async {
              Haptics.mediumImpact();
              final syncService = ref.read(driveSyncServiceProvider);
              if (!syncService.isSignedIn) {
                final signedIn =
                    await syncService.signInSilently() ||
                    await syncService.signIn();
                if (!signedIn) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sign in required for Drive Sync.'),
                      ),
                    );
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
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const SplashScreen(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                        transitionDuration: const Duration(milliseconds: 800),
                      ),
                      (route) => false,
                    );
                  } else if (result == SyncResult.uploaded) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Synced to Google Drive successfully.'),
                      ),
                    );
                  } else if (result == SyncResult.upToDate) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Local data is up to date.'),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
                }
              }
            },
            indicatorBuilder: (context, controller) {
              return const Padding(
                padding: EdgeInsets.all(4.0),
                child: LoadingIndicatorM3E(),
              );
            },
            child: CustomScrollView(
              slivers: [
                SliverAppBar.large(
                  leading: IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    tooltip: 'Back to Expense Books',
                    onPressed: () {
                      Haptics.lightImpact();
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GroupSelectionScreen(),
                          ),
                        );
                      }
                    },
                  ),
                  title: Text(
                    activeGroup.name,
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
                  actions: [
                    IconButton(
                      icon: Icon(
                        Icons.savings_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      tooltip: 'Manage Category Budgets',
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        padding: const EdgeInsets.all(8),
                      ),
                      onPressed: () {
                        Haptics.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ManageBudgetsScreen(group: activeGroup),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.event_repeat_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      tooltip: 'Manage Recurring',
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        padding: const EdgeInsets.all(8),
                      ),
                      onPressed: () {
                        Haptics.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ManageRecurringScreen(group: activeGroup),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.insights_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      tooltip: 'Insights',
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        padding: const EdgeInsets.all(8),
                      ),
                      onPressed: () {
                        Haptics.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                InsightsScreen(group: activeGroup),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.ios_share_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      tooltip: 'Export',
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        padding: const EdgeInsets.all(8),
                      ),
                      onPressed: () {
                        Haptics.lightImpact();
                        ExportService.exportAndShareExpenses(
                          activeGroup,
                          allExpenses,
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.settings_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      tooltip: 'Settings',
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        padding: const EdgeInsets.all(8),
                      ),
                      onPressed: () {
                        Haptics.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 8.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Builder(
                          builder: (context) {
                            final dailyAverage = metrics.dailyAverage;

                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                24,
                                24,
                                24,
                              ),
                              decoration: ShapeDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: ContinuousRectangleBorder(
                                  borderRadius: BorderRadius.circular(64),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary.withAlpha(25),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.account_balance_wallet_rounded,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Total Spent',
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Expanded(
                                        child: AnimatedCounter(
                                          value: total,
                                          prefix: '₹ ',
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                            fontSize: 48,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -1.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                            horizontal: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimary
                                                .withAlpha(15),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Daily Average',
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onPrimary
                                                      .withAlpha(180),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                NumberFormat.currency(
                                                  symbol: '₹ ',
                                                  decimalDigits: 0,
                                                ).format(dailyAverage),
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.onPrimary,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                            horizontal: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimary
                                                .withAlpha(15),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Transactions',
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onPrimary
                                                      .withAlpha(180),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${allExpenses.length}',
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.onPrimary,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        if (activeGroup.monthlyBudget != null &&
                            activeGroup.monthlyBudget! > 0) ...[
                          const SizedBox(height: 16),
                          Builder(
                            builder: (context) {
                              final totalSpent = allExpenses.fold(
                                0.0,
                                (sum, item) => sum + item.amount,
                              );
                              final percent =
                                  (totalSpent /
                                          activeGroup.monthlyBudget!)
                                      .clamp(0.0, 1.0);

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Monthly Budget',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withAlpha(150),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${(percent * 100).toInt()}% Used',
                                        style: TextStyle(
                                          color: percent >= 0.9
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.error
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  HapticBudgetMeter(percent: percent),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(totalSpent)} of ${NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(activeGroup.monthlyBudget)}',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withAlpha(150),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ] else ...[
                          const SizedBox(height: 16),
                          PressableButton(
                            onTap: () {
                              Haptics.mediumImpact();
                              _showSetBudgetDialog(context, activeGroup);
                            },
                            scaleFactor: 0.96,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer.withAlpha(80),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withAlpha(30),
                                ),
                              ),
                              child: Row(
                                children: [
                                  DynamicIconBg(
                                    padding: 8,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withAlpha(40),
                                    child: Icon(
                                      Icons.track_changes_rounded,
                                      size: 20,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Set a Monthly Budget',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                        Text(
                                          'Track your spending for this book',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer
                                                .withAlpha(180),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Transactions',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    letterSpacing: 0.5,
                                  ),
                            ),
                            Text(
                              'Swipe to delete',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Search transactions...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withAlpha(100),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 0,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilterChip(
                                label: const Text('All'),
                                selected: _selectedCategory == null,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedCategory = null;
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              ...allExpenses
                                  .map((e) => e.category)
                                  .toSet()
                                  .map(
                                    (category) => Padding(
                                      padding: const EdgeInsets.only(
                                        right: 8.0,
                                      ),
                                      child: FilterChip(
                                        label: Text(category),
                                        selected: _selectedCategory == category,
                                        onSelected: (selected) {
                                          setState(() {
                                            _selectedCategory = selected
                                                ? category
                                                : null;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                        if (_searchQuery.isNotEmpty || _selectedCategory != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${expenses.length} transaction${expenses.length == 1 ? '' : 's'} found',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              Text(
                                'Filtered: ${NumberFormat.currency(symbol: '₹', decimalDigits: 2).format(expenses.fold<double>(0.0, (sum, e) => sum + e.amount))}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        const Divider(height: 1, thickness: 1),
                      ],
                    ),
                  ),
                ),

                // List of Expenses
                expenses.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 64,
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No expenses yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(duration: 600.ms, delay: 300.ms),
                      )
                    : !_isReady
                    ? SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child:
                                  Container(
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest
                                              .withAlpha(50),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                      )
                                      .animate(
                                        onPlay: (controller) =>
                                            controller.repeat(),
                                      )
                                      .shimmer(
                                        duration: 1200.ms,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface.withAlpha(20),
                                      ),
                            ),
                            childCount: 5,
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final expense = expenses[index];
                            final isFirst = index == 0;
                            final isDifferentDay =
                                isFirst ||
                                expenses[index - 1].date.day !=
                                    expense.date.day ||
                                expenses[index - 1].date.month !=
                                    expense.date.month ||
                                expenses[index - 1].date.year !=
                                    expense.date.year;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isDifferentDay)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 16.0,
                                      bottom: 8.0,
                                      left: 8.0,
                                      right: 8.0,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          DateFormat(
                                            'EEEE, MMM d',
                                          ).format(expense.date),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        Text(
                                          NumberFormat.currency(
                                            symbol: '₹',
                                            decimalDigits: 0,
                                          ).format(
                                            expenses
                                                .where(
                                                  (e) =>
                                                      e.date.year ==
                                                          expense.date.year &&
                                                      e.date.month ==
                                                          expense.date.month &&
                                                      e.date.day ==
                                                          expense.date.day,
                                                )
                                                .fold(
                                                  0.0,
                                                  (sum, item) =>
                                                      sum + item.amount,
                                                ),
                                          ),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Dismissible(
                                      key: ValueKey(expense.id),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.errorContainer,
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(
                                          right: 24,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onErrorContainer,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              Icons.delete_sweep_rounded,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onErrorContainer,
                                              size: 24,
                                            ),
                                          ],
                                        ),
                                      ),
                                      onDismissed: (direction) {
                                        Haptics.mediumImpact();
                                        _deleteExpenseWithUndo(
                                          expense,
                                          context,
                                          ref,
                                        );
                                      },
                                      child: ExpandableExpenseCard(
                                        expense: expense,
                                        group: activeGroup,
                                        dailyTotal: expenses
                                            .where(
                                              (e) =>
                                                  e.date.year ==
                                                      expense.date.year &&
                                                  e.date.month ==
                                                      expense.date.month &&
                                                  e.date.day ==
                                                      expense.date.day,
                                            )
                                            .fold(
                                              0.0,
                                              (sum, item) => sum + item.amount,
                                            ),
                                      ),
                                    )
                                    .animate(
                                      delay: (index * 60).ms,
                                    ) // Staggered entrance
                                    .slideY(
                                      begin: 0.1,
                                      end: 0,
                                      duration: 350.ms,
                                      curve: Curves.easeOutCubic,
                                    )
                                    .fadeIn(duration: 350.ms)
                                    .scaleXY(
                                      begin: 0.95,
                                      end: 1.0,
                                      duration: 350.ms,
                                      curve: Curves.easeOutCubic,
                                    ),
                              ],
                            );
                          }, childCount: expenses.length),
                        ),
                      ),
              ],
            ),
          ),
          const SyncStatusChip(),
        ],
      ),
      floatingActionButton:
          PressableButton(
            scaleFactor: 0.88,
            onTap: () {
              Haptics.lightImpact();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                isDismissible: false,
                enableDrag: false,
                shape: const ContinuousRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(80)),
                ),
                builder: (ctx) => AddExpenseScreen(group: activeGroup),
              );
            },
            child: FloatingActionButton.extended(
              onPressed: null,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              label: Text(
                'Add Expense',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              icon: DynamicIconBg(
                padding: 6,
                color: Theme.of(context).colorScheme.primary.withAlpha(50),
                child: Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ).animate().scale(
            delay: 300.ms,
            duration: 500.ms,
            curve: Curves.easeOutBack,
          ),
      ),
    );
  }

  void _deleteExpenseWithUndo(
    Expense expense,
    BuildContext context,
    WidgetRef ref,
  ) {
    setState(() {
      _pendingDeletes.add(expense.id);
    });

    final notifier = ref.read(expenseProvider(widget.group).notifier);

    ScaffoldMessenger.of(context).clearSnackBars();
    final controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Center(
          child: UndoSnackbarContent(
            durationSeconds: 10,
            onUndo: () {
              ScaffoldMessenger.of(
                context,
              ).hideCurrentSnackBar(reason: SnackBarClosedReason.action);
            },
          ),
        ),
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.only(bottom: 24),
      ),
    );

    controller.closed.then((reason) {
      if (reason == SnackBarClosedReason.action) {
        if (mounted) {
          setState(() {
            _pendingDeletes.remove(expense.id);
          });
        }
      } else {
        notifier.deleteExpense(expense.id);
        if (mounted) {
          setState(() {
            _pendingDeletes.remove(expense.id);
          });
        }
      }
    });
  }

  void _showSetBudgetDialog(BuildContext context, ExpenseGroup group) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Monthly Budget'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Budget Amount (₹)',
            prefixText: '₹ ',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                Haptics.mediumImpact();
                await ref
                    .read(groupProvider.notifier)
                    .updateGroup(
                      group.id,
                      group.name,
                      group.icon,
                      monthlyBudget: val,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class HapticBudgetMeter extends StatefulWidget {
  final double percent;
  const HapticBudgetMeter({super.key, required this.percent});

  @override
  State<HapticBudgetMeter> createState() => _HapticBudgetMeterState();
}

class _HapticBudgetMeterState extends State<HapticBudgetMeter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _lastHapticTick = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = Tween<double>(
      begin: 0,
      end: widget.percent,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.addListener(() {
      int currentTick = (_animation.value * 15)
          .floor(); // Vibrate every ~6.6% filled
      if (currentTick > _lastHapticTick) {
        _lastHapticTick = currentTick;
        Haptics.selectionClick();
      }
    });

    _controller.forward();
  }

  @override
  void didUpdateWidget(HapticBudgetMeter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percent != widget.percent) {
      _lastHapticTick = 0;
      _animation = Tween<double>(begin: _animation.value, end: widget.percent)
          .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
          );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: 14,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: constraints.maxWidth * _animation.value,
                  decoration: BoxDecoration(
                    color: widget.percent >= 0.9
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
