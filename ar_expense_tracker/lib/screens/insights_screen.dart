import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/expense_provider.dart';
import '../database/expense_database.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:intl/intl.dart';
import '../providers/custom_category_provider.dart';
import '../providers/budget_provider.dart';
import '../utils/category_utils.dart';
import '../providers/theme_provider.dart';
import '../utils/font_utils.dart';
import '../widgets/dynamic_icon_bg.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  final ExpenseGroup group;

  const InsightsScreen({super.key, required this.group});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  int touchedIndex = -1;

  void _showCategoryExpenses(BuildContext context, String category, Color color, List<Expense> expenses) {
    final catExpenses = expenses.where((e) => e.category == category).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      category,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: catExpenses.length,
                  separatorBuilder: (ctx, idx) => Divider(
                    height: 1,
                    color: Theme.of(context).colorScheme.outlineVariant.withAlpha(50),
                  ),
                  itemBuilder: (ctx, idx) {
                    final exp = catExpenses[idx];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      title: Text(
                        exp.title != null && exp.title!.isNotEmpty ? exp.title! : exp.category,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exp.note != null && exp.note!.isNotEmpty 
                                ? '${DateFormat.yMMMd().format(exp.date)} • ${exp.note!}'
                                : DateFormat.yMMMd().format(exp.date),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                            ),
                          ),
                          if (exp.subExpenses != null && exp.subExpenses!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.receipt_long_rounded,
                                    size: 12,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${exp.subExpenses!.length} items',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      trailing: Text(
                        NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(exp.amount),
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expenseProvider(widget.group));
    final customCategories = ref.watch(customCategoryProvider(widget.group));
    final categoryBudgets = ref.watch(categoryBudgetProvider(widget.group));
    
    final metrics = ref.watch(expenseMetricsProvider(widget.group));
    final sortedCategories = ref.watch(categoryTotalsProvider(widget.group));
    final total = metrics.total;

    final List<PieChartSectionData> pieSections = [];

    for (int i = 0; i < sortedCategories.length; i++) {
      final entry = sortedCategories[i];
      final percentage = total == 0 ? 0 : (entry.value / total) * 100;
      final isTouched = i == touchedIndex;
      final fontSize = isTouched ? 16.0 : 12.0;
      final radius = isTouched ? 60.0 : 50.0;
      final titleColor = isTouched ? Colors.white : Colors.white.withAlpha(200);

      pieSections.add(
        PieChartSectionData(
          color: CategoryUtils.getColor(entry.key, customCategories),
          value: entry.value,
          title: percentage > 5 ? '${percentage.toStringAsFixed(0)}%' : '',
          radius: radius,
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: titleColor,
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              'Insights',
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
          if (expenses.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('No expenses to analyze yet.')),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: ShapeDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.tertiary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: ContinuousRectangleBorder(
                          borderRadius: BorderRadius.circular(64),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(30),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_rounded,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Total Expenses',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: 0.5, end: 0, duration: 600.ms, curve: Curves.easeOutBack),
                          const SizedBox(height: 16),
                          Text(
                            NumberFormat.currency(symbol: '₹ ', decimalDigits: 0).format(total),
                            style: GoogleFonts.outfit(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 48,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.5,
                            ),
                          ).animate().fadeIn(delay: 300.ms, duration: 600.ms).scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 600.ms, curve: Curves.elasticOut),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                    .slideY(begin: 0.1, end: 0, duration: 600.ms, curve: Curves.easeOutQuart),
                    
                    const SizedBox(height: 40),
                    
                    // Chart
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.pie_chart_rounded,
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Spending Distribution',
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 300.ms, duration: 600.ms).slideX(begin: -0.1, end: 0, duration: 600.ms, curve: Curves.easeOutQuart),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              pieTouchData: PieTouchData(
                                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                  setState(() {
                                    if (!event.isInterestedForInteractions ||
                                        pieTouchResponse == null ||
                                        pieTouchResponse.touchedSection == null) {
                                      touchedIndex = -1;
                                      return;
                                    }
                                    final newIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                    if (event is FlTapUpEvent && newIndex != -1) {
                                      final category = sortedCategories[newIndex].key;
                                      final color = CategoryUtils.getColor(category, customCategories);
                                      _showCategoryExpenses(context, category, color, expenses);
                                    }
                                    touchedIndex = newIndex;
                                  });
                                },
                              ),
                              sections: pieSections,
                              centerSpaceRadius: 70,
                              sectionsSpace: 4,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                touchedIndex == -1 ? Icons.pie_chart_rounded : Icons.category_rounded, 
                                size: 28, 
                                color: Theme.of(context).colorScheme.onSurface.withAlpha(100)
                              ),
                              const SizedBox(height: 4),
                              Text(
                                touchedIndex == -1 
                                  ? '${sortedCategories.length} Cats'
                                  : sortedCategories[touchedIndex].key,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                                ),
                              ),
                              if (touchedIndex != -1)
                                Text(
                                  NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(sortedCategories[touchedIndex].value),
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 500.ms, duration: 800.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), duration: 800.ms, curve: Curves.elasticOut),
                    
                    const SizedBox(height: 40),

                    // Categories List
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.category_rounded,
                            color: Theme.of(context).colorScheme.onTertiaryContainer,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Category Breakdown',
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 600.ms, duration: 600.ms).slideX(begin: -0.1, end: 0, duration: 600.ms, curve: Curves.easeOutQuart),
                    const SizedBox(height: 16),
                    Container(
                      decoration: ShapeDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(isDark ? 30 : 60),
                        shape: ContinuousRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
                        ),
                      ),
                      child: Column(
                        children: sortedCategories.asMap().entries.map((entry) {
                          final index = entry.key;
                          final category = entry.value.key;
                          final amount = entry.value.value;
                          final percentage = total == 0 ? 0 : amount / total;
                          final color = CategoryUtils.getColor(category, customCategories);
                          
                          return Column(
                            children: [
                              ListTile(
                                onTap: () => _showCategoryExpenses(context, category, color, expenses),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                leading: DynamicIconBg(
                                  width: 36,
                                  height: 36,
                                  padding: 0,
                                  color: color.withAlpha(25),
                                  child: Center(
                                    child: CategoryUtils.getIconWidget(
                                      category, 
                                      customCategories,
                                      size: 20,
                                      color: color,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  category,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                ),
                                subtitle: Text(
                                  '${(percentage * 100).toStringAsFixed(0)}% of total',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: Text(
                                  NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(amount),
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              if (categoryBudgets.any((b) => b.category == category))
                                Builder(
                                  builder: (context) {
                                     final budget = categoryBudgets.firstWhere((b) => b.category == category);
                                     final currentMonthExpenses = expenses.where((e) {
                                       if (e.category != category) return false;
                                       if (widget.group.isMonthlyBudget) {
                                         return e.date.year == widget.group.createdAt.year && e.date.month == widget.group.createdAt.month;
                                       }
                                       return true;
                                     }).toList();
                                     
                                     double currentMonthSpent = 0;
                                     for (var exp in currentMonthExpenses) {
                                       if (!budget.includePastExpenses && budget.createdAt != null && exp.date.isBefore(budget.createdAt!)) {
                                         continue;
                                       }
                                       currentMonthSpent += exp.amount;
                                     }
                                     
                                     final rawPercent = budget.amount > 0 ? (currentMonthSpent / budget.amount) : 0.0;
                                     final percent = rawPercent.clamp(0.0, 1.0);
                                     
                                     return Padding(
                                       padding: const EdgeInsets.only(left: 72, right: 20, bottom: 12),
                                       child: Column(
                                         crossAxisAlignment: CrossAxisAlignment.start,
                                         children: [
                                           Row(
                                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                             children: [
                                               Text(
                                                 '${(rawPercent * 100).toInt()}% of Budget',
                                                style: TextStyle(
                                                  color: percent >= 0.9 ? Theme.of(context).colorScheme.error : color,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                '${NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(currentMonthSpent)} / ${NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(budget.amount)}',
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: LinearProgressIndicator(
                                              value: percent,
                                              minHeight: 8,
                                              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                percent >= 0.9 ? Theme.of(context).colorScheme.error : color,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                ),
                              if (index < sortedCategories.length - 1)
                                Divider(
                                  height: 1,
                                  indent: 52,
                                  endIndent: 20,
                                  color: Theme.of(context).colorScheme.outlineVariant.withAlpha(isDark ? 50 : 100),
                                ),
                            ],
                          );
                        }).toList(),
                      ),
                    ).animate().fadeIn(delay: 700.ms, duration: 600.ms).slideY(begin: 0.1, end: 0, duration: 600.ms, curve: Curves.easeOutQuart),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
