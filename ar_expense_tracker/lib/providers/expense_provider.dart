import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../database/expense_database.dart';
import '../services/drive_sync_service.dart';
import '../services/notification_service.dart';

// Provider for the database instance (singleton)
final expenseDatabaseProvider = Provider<ExpenseDatabase>((ref) {
  final db = ExpenseDatabase();
  final syncService = ref.read(driveSyncServiceProvider);
  syncService.onBeforeBackup = () => db.checkpointWal();
  
  final subscription = db.tableUpdates().listen((updates) {
    syncService.triggerAutoBackup();
  });
  
  ref.onDispose(() {
    subscription.cancel();
    db.close();
  });
  return db;
});

// Notifier to manage the list of expense groups (Riverpod 3.0 style)
class GroupNotifier extends Notifier<List<ExpenseGroup>> {
  StreamSubscription<List<ExpenseGroup>>? _subscription;

  @override
  List<ExpenseGroup> build() {
    final db = ref.read(expenseDatabaseProvider);
    _subscription = db.watchGroups().listen((groups) {
      state = groups;
    });
    
    ref.onDispose(() {
      _subscription?.cancel();
    });
    return [];
  }

  Future<ExpenseGroup> addGroup(String name, String icon, {double? monthlyBudget, bool isMonthlyBudget = false, DateTime? createdAt}) async {
    final db = ref.read(expenseDatabaseProvider);
    final id = await db.addGroup(name, icon, monthlyBudget: monthlyBudget, isMonthlyBudget: isMonthlyBudget, createdAt: createdAt);
    final allGroups = await db.fetchGroups();
    return allGroups.firstWhere((g) => g.id == id);
  }

  Future<void> updateGroup(int id, String name, String icon, {double? monthlyBudget, bool? isMonthlyBudget}) async {
    final db = ref.read(expenseDatabaseProvider);
    await db.updateGroup(id, name, icon, monthlyBudget: monthlyBudget, isMonthlyBudget: isMonthlyBudget);
  }

  Future<void> deleteGroup(int id) async {
    final db = ref.read(expenseDatabaseProvider);
    await db.deleteGroup(id);
  }

  Future<void> togglePin(int id, bool isPinned) async {
    final db = ref.read(expenseDatabaseProvider);
    await db.toggleGroupPin(id, isPinned);
  }

  Future<void> toggleArchive(int id, bool isArchived) async {
    final db = ref.read(expenseDatabaseProvider);
    await db.toggleGroupArchive(id, isArchived);
  }
}

// Provider for the group notifier
final groupProvider = NotifierProvider<GroupNotifier, List<ExpenseGroup>>(GroupNotifier.new);


// Notifier to manage the state of expenses for a specific group (Riverpod 3.0 style)
class ExpenseNotifier extends Notifier<List<Expense>> {
  ExpenseNotifier(this.activeGroup);
  final ExpenseGroup activeGroup;
  StreamSubscription<List<Expense>>? _subscription;

  @override
  List<Expense> build() {
    final db = ref.read(expenseDatabaseProvider);
    _subscription = db.watchExpensesForGroup(activeGroup.id).listen((expenses) {
      state = expenses;
    });
    
    ref.onDispose(() {
      _subscription?.cancel();
    });
    return [];
  }

  // Add an expense
  Future<void> addExpense({
    String? title,
    required double amount,
    required DateTime date,
    required String category,
    String? note,
    List<String>? imagePaths,
    bool isRecurring = false,
    String? recurrencePeriod,
    DateTime? nextRecurringDate,
    List<SubExpense>? subExpenses,
    bool omitFromAvg = false,
  }) async {
    final db = ref.read(expenseDatabaseProvider);
    await db.addExpense(
      ExpensesCompanion.insert(
        title: Value(title),
        amount: amount,
        date: date,
        category: category,
        note: Value(note),
        imagePaths: Value(imagePaths ?? []),
        groupId: activeGroup.id,
        isRecurring: Value(isRecurring),
        recurrencePeriod: Value(recurrencePeriod),
        nextRecurringDate: Value(nextRecurringDate),
        subExpenses: Value(subExpenses ?? []),
        omitFromAvg: Value(omitFromAvg),
      ),
    );
    // Dismiss active reminder notification and schedule for tomorrow
    NotificationService.onExpenseAdded(db);
  }

  // Update an expense
  Future<void> updateExpense({
    required int id,
    String? title,
    required double amount,
    required DateTime date,
    required String category,
    String? note,
    List<String>? imagePaths,
    bool? isRecurring,
    String? recurrencePeriod,
    DateTime? nextRecurringDate,
    List<SubExpense>? subExpenses,
    bool? omitFromAvg,
  }) async {
    final db = ref.read(expenseDatabaseProvider);
    await db.updateExpense(
      ExpensesCompanion(
        id: Value(id),
        title: Value(title),
        amount: Value(amount),
        date: Value(date),
        category: Value(category),
        note: Value(note),
        imagePaths: Value(imagePaths ?? []),
        groupId: Value(activeGroup.id),
        isRecurring: isRecurring != null ? Value(isRecurring) : const Value.absent(),
        recurrencePeriod: recurrencePeriod != null ? Value(recurrencePeriod) : const Value.absent(),
        nextRecurringDate: nextRecurringDate != null ? Value(nextRecurringDate) : const Value.absent(),
        subExpenses: subExpenses != null ? Value(subExpenses) : const Value.absent(),
        omitFromAvg: omitFromAvg != null ? Value(omitFromAvg) : const Value.absent(),
      ),
    );
    NotificationService.onExpenseAdded(db);
  }

  // Delete an expense
  Future<void> deleteExpense(int id) async {
    final db = ref.read(expenseDatabaseProvider);
    await db.deleteExpense(id);
    NotificationService.checkAndScheduleReminders(db);
  }
}

// Family provider to scope expenses to a specific group ID
final expenseProvider = NotifierProvider.family<ExpenseNotifier, List<Expense>, ExpenseGroup>(ExpenseNotifier.new);

// Derived Provider for category totals
final categoryTotalsProvider = Provider.family<List<MapEntry<String, double>>, ExpenseGroup>((ref, activeGroup) {
  final expenses = ref.watch(expenseProvider(activeGroup));
  final Map<String, double> categoryTotals = {};
  
  for (var exp in expenses) {
    categoryTotals[exp.category] = (categoryTotals[exp.category] ?? 0) + exp.amount;
  }
  
  final sortedCategories = categoryTotals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
    
  return sortedCategories;
});

// Derived Provider for expense metrics (total, daily average, earliest date)
class ExpenseMetrics {
  final double total;
  final double dailyAverage;
  final DateTime? earliestDate;

  ExpenseMetrics({required this.total, required this.dailyAverage, this.earliestDate});
}

final expenseMetricsProvider = Provider.family<ExpenseMetrics, ExpenseGroup>((ref, activeGroup) {
  final expenses = ref.watch(expenseProvider(activeGroup));
  
  if (expenses.isEmpty) {
    return ExpenseMetrics(total: 0.0, dailyAverage: 0.0, earliestDate: null);
  }
  
  final total = expenses.fold(0.0, (sum, item) => sum + item.amount);
  final earliestDate = expenses.map((e) => e.date).reduce((a, b) => a.isBefore(b) ? a : b);
  final avgTotal = expenses.where((e) => !e.omitFromAvg).fold(0.0, (sum, item) => sum + item.amount);

  int days;
  if (activeGroup.isMonthlyBudget) {
    final monthEnd = DateTime(activeGroup.createdAt.year, activeGroup.createdAt.month + 1, 0);
    final now = DateTime.now();

    if (now.year == activeGroup.createdAt.year && now.month == activeGroup.createdAt.month) {
      days = now.day;
    } else if (now.isAfter(monthEnd)) {
      days = monthEnd.day;
    } else {
      days = 1;
    }
  } else {
    final now = DateTime.now();
    days = now.difference(earliestDate).inDays + 1;
  }

  if (days < 1) days = 1;
  final dailyAverage = avgTotal / days;
  
  return ExpenseMetrics(total: total, dailyAverage: dailyAverage, earliestDate: earliestDate);
});

// Global provider for all recurring expenses across all groups
final allRecurringExpensesProvider = StreamProvider<List<Expense>>((ref) {
  final db = ref.watch(expenseDatabaseProvider);
  return (db.select(db.expenses)..where((t) => t.isRecurring.equals(true))).watch();
});
