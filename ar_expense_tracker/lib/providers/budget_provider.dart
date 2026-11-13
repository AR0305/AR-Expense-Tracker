import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/expense_database.dart';
import 'expense_provider.dart';

class CategoryBudgetNotifier extends Notifier<List<CategoryBudget>> {
  CategoryBudgetNotifier(this.activeGroup);
  final ExpenseGroup activeGroup;

  @override
  List<CategoryBudget> build() {
    _loadBudgets();
    return [];
  }

  Future<void> _loadBudgets() async {
    final db = ref.read(expenseDatabaseProvider);
    state = await db.fetchCategoryBudgets(activeGroup.id);
  }

  Future<void> setBudget(String category, double amount, bool includePastExpenses) async {
    final db = ref.read(expenseDatabaseProvider);
    await db.setCategoryBudget(activeGroup.id, category, amount, includePastExpenses);
    await _loadBudgets();
  }

  Future<void> deleteBudget(int id) async {
    final db = ref.read(expenseDatabaseProvider);
    await db.deleteCategoryBudget(id);
    await _loadBudgets();
  }
}

final categoryBudgetProvider = NotifierProvider.family<CategoryBudgetNotifier, List<CategoryBudget>, ExpenseGroup>(CategoryBudgetNotifier.new);
