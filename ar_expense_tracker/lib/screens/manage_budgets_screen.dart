import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/budget_provider.dart';
import '../providers/custom_category_provider.dart';
import '../database/expense_database.dart';
import '../utils/category_utils.dart';
import '../providers/expense_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/font_utils.dart';
import '../widgets/category_picker_sheet.dart';
import '../widgets/dynamic_icon_bg.dart';

class ManageBudgetsScreen extends ConsumerStatefulWidget {
  final ExpenseGroup group;
  const ManageBudgetsScreen({super.key, required this.group});

  @override
  ConsumerState<ManageBudgetsScreen> createState() => _ManageBudgetsScreenState();
}

class _ManageBudgetsScreenState extends ConsumerState<ManageBudgetsScreen> {
  final _amountController = TextEditingController();
  bool _includePastExpenses = true;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _showAmountDialog(BuildContext context, String category, double currentSpent, {CategoryBudget? existing}) {
    if (existing != null) {
      _amountController.text = existing.amount.toStringAsFixed(0);
      _includePastExpenses = existing.includePastExpenses;
    } else {
      _amountController.clear();
      _includePastExpenses = true;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(existing != null ? 'Edit Budget' : 'Set Category Budget'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Monthly Limit',
                    prefixIcon: Icon(Icons.currency_rupee_rounded),
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Include earlier expenses this month', style: TextStyle(fontSize: 14)),
                  value: _includePastExpenses,
                  onChanged: (val) {
                    setState(() {
                      _includePastExpenses = val;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                if (currentSpent > 0 && _includePastExpenses) ...[
                  const SizedBox(height: 12),
                  ActionChip(
                    avatar: const Icon(Icons.flash_on_rounded, size: 16),
                    label: Text('Use current spent (${NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(currentSpent)})'),
                    onPressed: () {
                      _amountController.text = currentSpent.toStringAsFixed(0);
                    },
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer.withAlpha(100),
                    side: BorderSide(color: Theme.of(context).colorScheme.primaryContainer),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (_amountController.text.isNotEmpty) {
                    final amount = double.tryParse(_amountController.text);
                    if (amount != null && amount > 0) {
                      ref.read(categoryBudgetProvider(widget.group).notifier).setBudget(category, amount, _includePastExpenses);
                      Navigator.pop(ctx);
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final budgets = ref.watch(categoryBudgetProvider(widget.group));
    final customCategories = ref.watch(customCategoryProvider(widget.group));
    
    // Calculate current month's expenses per category to show progress
    final expenses = ref.watch(expenseProvider(widget.group));
    final relevantExpenses = expenses.where((e) {
      if (widget.group.isMonthlyBudget) {
        return e.date.year == widget.group.createdAt.year && e.date.month == widget.group.createdAt.month;
      }
      return true;
    }).toList();
    
    double calculateSpentForCategory(String category) {
      final budget = budgets.where((b) => b.category == category).firstOrNull;
      double spent = 0;
      for (var exp in relevantExpenses.where((e) => e.category == category)) {
        if (budget != null && !budget.includePastExpenses && budget.createdAt != null) {
          if (exp.date.isBefore(budget.createdAt!)) continue;
        }
        spent += exp.amount;
      }
      return spent;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              'Category Budgets',
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
          if (budgets.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(50),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No category budgets set',
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
                    final budget = budgets[index];
                    final categoryColor = CategoryUtils.getColor(budget.category, customCategories);
                    final spent = calculateSpentForCategory(budget.category);
                    final percent = (spent / budget.amount).clamp(0.0, 1.0);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        onTap: () => _showAmountDialog(context, budget.category, spent, existing: budget),
                        borderRadius: BorderRadius.circular(40),
                        child: Container(
                          decoration: ShapeDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(isDark ? 30 : 80),
                            shape: ContinuousRectangleBorder(
                              borderRadius: BorderRadius.circular(80),
                              side: BorderSide(
                                color: percent >= 0.9 ? Theme.of(context).colorScheme.error.withAlpha(100) : Colors.transparent,
                              )
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  DynamicIconBg(
                                    width: 40,
                                    height: 40,
                                    padding: 0,
                                    alignment: Alignment.center,
                                    color: categoryColor.withAlpha(30),
                                    child: CategoryUtils.getIconWidget(
                                      budget.category,
                                      customCategories,
                                      size: 20,
                                      color: categoryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      budget.category,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                    color: Theme.of(context).colorScheme.error,
                                    onPressed: () {
                                      ref.read(categoryBudgetProvider(widget.group).notifier).deleteBudget(budget.id);
                                    },
                                  )
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${(percent * 100).toInt()}% Used',
                                    style: TextStyle(
                                      color: percent >= 0.9 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '${NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(spent)} of ${NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(budget.amount)}',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: percent,
                                  minHeight: 8,
                                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    percent >= 0.9 ? Theme.of(context).colorScheme.error : categoryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: budgets.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(60)),
        onPressed: () {
          CategoryPickerSheet.show(
            context,
            group: widget.group,
            onCategorySelected: (category) {
              // Check if a budget already exists for this category
              final existing = budgets.where((b) => b.category == category).firstOrNull;
              final spent = calculateSpentForCategory(category);
              _showAmountDialog(context, category, spent, existing: existing);
            },
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Budget'),
      ),
    );
  }
}
