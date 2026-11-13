import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../providers/expense_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/font_utils.dart';
import '../database/expense_database.dart';
import '../providers/custom_category_provider.dart';
import '../utils/category_utils.dart';
import '../screens/add_expense_screen.dart';
import '../widgets/dynamic_icon_bg.dart';

class ManageRecurringScreen extends ConsumerWidget {
  final ExpenseGroup group;

  const ManageRecurringScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fetch ALL recurring templates globally
    final allExpensesAsync = ref.watch(allRecurringExpensesProvider);
    final recurringTemplates = allExpensesAsync.value ?? [];
    
    final customCategories = ref.watch(customCategoryProvider(group));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              'Manage Recurring',
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
          if (recurringTemplates.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.autorenew_rounded,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(50),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No active recurring expenses',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final expense = recurringTemplates[index];
                    final categoryColor = CategoryUtils.getColor(expense.category, customCategories);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        decoration: ShapeDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(isDark ? 30 : 80),
                          shape: ContinuousRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DynamicIconBg(
                                width: 48,
                                height: 48,
                                padding: 0,
                                alignment: Alignment.center,
                                color: categoryColor.withAlpha(30),
                                child: CategoryUtils.getIconWidget(
                                  expense.category,
                                  customCategories,
                                  size: 24,
                                  color: categoryColor,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      expense.title != null && expense.title!.isNotEmpty ? expense.title! : expense.category,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(expense.amount),
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 20,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: ShapeDecoration(
                                        color: Theme.of(context).colorScheme.surfaceContainerHigh.withAlpha(150),
                                        shape: ContinuousRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.update_rounded,
                                            size: 14,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            expense.recurrencePeriod ?? 'Unknown',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (expense.nextRecurringDate != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Next: ${DateFormat('MMM dd, yyyy').format(expense.nextRecurringDate!)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                                        ),
                                      ),
                                    ]
                                  ],
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                                    tooltip: 'Edit Recurring',
                                    style: IconButton.styleFrom(
                                      backgroundColor: Theme.of(context).colorScheme.primaryContainer.withAlpha(100),
                                      minimumSize: const Size(40, 40),
                                      padding: EdgeInsets.zero,
                                      shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    ),
                                    onPressed: () {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        useSafeArea: true,
                                        isDismissible: false,
                                        enableDrag: false,
                                        backgroundColor: Colors.transparent,
                                        builder: (ctx) => AddExpenseScreen(
                                          group: group,
                                          existingExpense: expense,
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  IconButton(
                                    icon: Icon(Icons.arrow_forward_rounded, color: Theme.of(context).colorScheme.tertiary, size: 20),
                                    tooltip: 'Apply to Book',
                                    style: IconButton.styleFrom(
                                      backgroundColor: Theme.of(context).colorScheme.tertiaryContainer.withAlpha(100),
                                      minimumSize: const Size(40, 40),
                                      padding: EdgeInsets.zero,
                                      shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    ),
                                    onPressed: () {
                                      _showApplyBottomSheet(context, ref, expense);
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  IconButton(
                                    icon: Icon(Icons.close_rounded, color: Theme.of(context).colorScheme.error, size: 20),
                                    tooltip: 'Stop Recurring',
                                    style: IconButton.styleFrom(
                                      backgroundColor: Theme.of(context).colorScheme.errorContainer.withAlpha(100),
                                      minimumSize: const Size(40, 40),
                                      padding: EdgeInsets.zero,
                                      shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    ),
                                    onPressed: () {
                                      _showStopRecurringDialog(context, ref, expense);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: recurringTemplates.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showStopRecurringDialog(BuildContext context, WidgetRef ref, Expense expense) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop Recurring?'),
        content: const Text(
          'This will stop generating future expenses. Your past expenses will remain in your history.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final db = ref.read(expenseDatabaseProvider);
              await (db.update(db.expenses)..where((t) => t.id.equals(expense.id))).write(
                const ExpensesCompanion(
                  isRecurring: drift.Value(false),
                ),
              );
              
              if (context.mounted) {
                Navigator.pop(ctx);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }

  void _showApplyBottomSheet(BuildContext context, WidgetRef ref, Expense expense) async {
    final db = ref.read(expenseDatabaseProvider);
    final allGroups = await db.fetchGroups();
    
    // Filter only month locked books
    final monthGroups = allGroups.where((g) {
      bool isLockedToMonth = g.isMonthlyBudget;
      if (!isLockedToMonth) {
        try {
          DateFormat('MMMM yyyy').parseStrict(g.name);
          isLockedToMonth = true;
        } catch (_) {}
      }
      return isLockedToMonth;
    }).toList();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Apply to Book',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (monthGroups.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No monthly books found.', textAlign: TextAlign.center),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: monthGroups.length,
                    itemBuilder: (context, index) {
                      final targetGroup = monthGroups[index];
                      return ListTile(
                        leading: Icon(
                          Icons.folder_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(targetGroup.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        onTap: () async {
                          Navigator.pop(ctx);
                          
                          DateTime targetDate = DateTime.now();
                          try {
                            targetDate = DateFormat('MMMM yyyy').parseStrict(targetGroup.name);
                          } catch (_) {}
                          
                          // Insert cloned expense
                          await db.addExpense(ExpensesCompanion.insert(
                            amount: expense.amount,
                            date: targetDate,
                            category: expense.category,
                            note: drift.Value(expense.note),
                            imagePaths: drift.Value(expense.imagePaths),
                            groupId: targetGroup.id,
                            isRecurring: const drift.Value(false),
                            recurrencePeriod: drift.Value(expense.recurrencePeriod),
                            title: drift.Value(expense.title),
                            omitFromAvg: drift.Value(expense.omitFromAvg),
                          ));
                          
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Applied to ${targetGroup.name}')),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      }
    );
  }
}

