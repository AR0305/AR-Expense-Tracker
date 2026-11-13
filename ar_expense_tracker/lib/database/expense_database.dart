import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';

part 'expense_database.g.dart';

// Converter to store List<String> as a joined string in SQLite
class ListStringConverter extends TypeConverter<List<String>, String> {
  const ListStringConverter();

  @override
  List<String> fromSql(String fromDb) {
    if (fromDb.isEmpty) return [];
    return fromDb.split('||');
  }

  @override
  String toSql(List<String> value) {
    return value.join('||');
  }
}

// SubExpense data class
class SubExpense {
  String name;
  double amount;
  int quantity;
  SubExpense({required this.name, required this.amount, this.quantity = 1});

  Map<String, dynamic> toJson() => {'name': name, 'amount': amount, 'quantity': quantity};
  
  factory SubExpense.fromJson(Map<String, dynamic> json) {
    return SubExpense(
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      quantity: json['quantity'] as int? ?? 1,
    );
  }
}

// Converter to store List<SubExpense> as JSON in SQLite
class SubExpenseListConverter extends TypeConverter<List<SubExpense>, String> {
  const SubExpenseListConverter();

  @override
  List<SubExpense> fromSql(String fromDb) {
    if (fromDb.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(fromDb);
      return list.map((e) => SubExpense.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  String toSql(List<SubExpense> value) {
    return jsonEncode(value.map((e) => e.toJson()).toList());
  }
}

// Define tables
class ExpenseGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get icon => text().withDefault(const Constant('folder_rounded'))();
  DateTimeColumn get createdAt => dateTime()();
  RealColumn get monthlyBudget => real().nullable()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get isMonthlyBudget => boolean().withDefault(const Constant(false))();
}

@TableIndex(name: 'expenses_group_id_idx', columns: {#groupId})
@TableIndex(name: 'expenses_date_idx', columns: {#date})
@TableIndex(name: 'expenses_category_idx', columns: {#category})
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().nullable()();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get category => text()();
  TextColumn get note => text().nullable()();
  TextColumn get imagePaths => text().map(const ListStringConverter()).nullable()();
  TextColumn get subExpenses => text().map(const SubExpenseListConverter()).nullable()();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  TextColumn get recurrencePeriod => text().nullable()(); // 'Daily', 'Weekly', 'Monthly', 'Quarterly', 'Yearly'
  DateTimeColumn get nextRecurringDate => dateTime().nullable()();
  IntColumn get groupId => integer().references(ExpenseGroups, #id, onDelete: KeyAction.cascade)();
  BoolColumn get omitFromAvg => boolean().withDefault(const Constant(false))();
}

@TableIndex(name: 'custom_categories_group_id_idx', columns: {#groupId})
class CustomCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get iconName => text()();
  IntColumn get colorValue => integer()();
  IntColumn get groupId => integer().nullable()();
}

class CategoryBudgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get category => text()();
  RealColumn get amount => real()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  BoolColumn get includePastExpenses => boolean().withDefault(const Constant(true))();
  IntColumn get groupId => integer().references(ExpenseGroups, #id, onDelete: KeyAction.cascade)();
}

@DriftDatabase(tables: [ExpenseGroups, Expenses, CustomCategories, CategoryBudgets])
class ExpenseDatabase extends _$ExpenseDatabase {
  ExpenseDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 12; // Incremented for global custom categories

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            // Add the new icon column to existing tables
            await m.addColumn(expenseGroups, expenseGroups.icon);
          }
          if (from < 3) {
            // Add recurring expense columns
            await m.addColumn(expenses, expenses.isRecurring);
            await m.addColumn(expenses, expenses.recurrencePeriod);
            await m.addColumn(expenses, expenses.nextRecurringDate);
          }
          if (from < 4) {
            await m.addColumn(expenses, expenses.title);
          }
          if (from < 5) {
            await m.addColumn(expenses, expenses.subExpenses);
          }
          if (from < 6) {
            await m.createTable(customCategories);
          }
          if (from < 7) {
            await m.addColumn(expenseGroups, expenseGroups.monthlyBudget);
            await m.createTable(categoryBudgets);
          }
          if (from < 8) {
            await m.addColumn(categoryBudgets, categoryBudgets.createdAt);
            await m.addColumn(categoryBudgets, categoryBudgets.includePastExpenses);
          }
          if (from < 9) {
            await m.addColumn(expenseGroups, expenseGroups.isPinned);
            await m.addColumn(expenseGroups, expenseGroups.isArchived);
          }
          if (from < 10) {
            await m.addColumn(expenseGroups, expenseGroups.isMonthlyBudget);
          }
          if (from < 11) {
            await m.addColumn(expenses, expenses.omitFromAvg);
          }
          if (from < 12) {
            // Unbind custom categories from individual books and make groupId nullable
            await customStatement('PRAGMA foreign_keys = OFF;');
            await customStatement('''
              CREATE TABLE custom_categories_new (
                id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                name TEXT NOT NULL,
                icon_name TEXT NOT NULL,
                color_value INTEGER NOT NULL,
                group_id INTEGER
              );
            ''');
            await customStatement('''
              INSERT INTO custom_categories_new (id, name, icon_name, color_value, group_id)
              SELECT id, name, icon_name, color_value, group_id FROM custom_categories;
            ''');
            await customStatement('DROP TABLE custom_categories;');
            await customStatement('ALTER TABLE custom_categories_new RENAME TO custom_categories;');
            await customStatement('CREATE INDEX IF NOT EXISTS custom_categories_group_id_idx ON custom_categories (group_id);');
            await customStatement('PRAGMA foreign_keys = ON;');
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  // Group Queries
  Future<List<ExpenseGroup>> fetchGroups() => (select(expenseGroups)
        ..where((t) => t.isArchived.equals(false))
        ..orderBy([
          (t) => OrderingTerm(expression: t.isPinned, mode: OrderingMode.desc),
          (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
        ]))
      .get();

  Stream<List<ExpenseGroup>> watchGroups() => (select(expenseGroups)
        ..where((t) => t.isArchived.equals(false))
        ..orderBy([
          (t) => OrderingTerm(expression: t.isPinned, mode: OrderingMode.desc),
          (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
        ]))
      .watch();

  Future<List<ExpenseGroup>> fetchArchivedGroups() => (select(expenseGroups)
        ..where((t) => t.isArchived.equals(true))
        ..orderBy([
          (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
        ]))
      .get();
      
  Future<int> addGroup(String name, String iconName, {double? monthlyBudget, bool isMonthlyBudget = false, DateTime? createdAt}) {
    return into(expenseGroups).insert(
      ExpenseGroupsCompanion.insert(
        name: name,
        icon: Value(iconName),
        createdAt: createdAt ?? DateTime.now(),
        monthlyBudget: Value(monthlyBudget),
        isMonthlyBudget: Value(isMonthlyBudget),
      ),
    );
  }

  Future<void> checkpointWal() async {
    try {
      await customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
    } catch (_) {
      // Handled gracefully if not supported or not in WAL mode
    }
  }

  Future<void> deleteGroup(int id) async {
    final groupExpenses = await (select(expenses)..where((t) => t.groupId.equals(id))).get();
    for (final exp in groupExpenses) {
      if (exp.imagePaths != null) {
        for (final imgPath in exp.imagePaths!) {
          try {
            final f = File(imgPath);
            if (await f.exists()) {
              await f.delete();
            }
          } catch (_) {}
        }
      }
    }
    await (delete(expenseGroups)..where((t) => t.id.equals(id))).go();
  }

  Future<void> updateGroup(int id, String name, String icon, {double? monthlyBudget, bool? isMonthlyBudget}) async {
    await (update(expenseGroups)..where((t) => t.id.equals(id))).write(
      ExpenseGroupsCompanion(
        name: Value(name),
        icon: Value(icon),
        monthlyBudget: Value(monthlyBudget),
        isMonthlyBudget: isMonthlyBudget != null ? Value(isMonthlyBudget) : const Value.absent(),
      ),
    );
  }

  Future<void> toggleGroupPin(int id, bool isPinned) async {
    await (update(expenseGroups)..where((t) => t.id.equals(id))).write(
      ExpenseGroupsCompanion(isPinned: Value(isPinned)),
    );
  }

  Future<void> toggleGroupArchive(int id, bool isArchived) async {
    await (update(expenseGroups)..where((t) => t.id.equals(id))).write(
      ExpenseGroupsCompanion(
        isArchived: Value(isArchived),
        isPinned: Value(false), // Unpin when archiving
      ),
    );
  }

  // Expense Queries
  Future<List<Expense>> fetchExpensesForGroup(int groupId) {
    return (select(expenses)
          ..where((t) => t.groupId.equals(groupId))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  Stream<List<Expense>> watchExpensesForGroup(int groupId) {
    return (select(expenses)
          ..where((t) => t.groupId.equals(groupId))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  Future<bool> hasExpensesOnDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    final results = await (select(expenses)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(startOfDay) &
              t.date.isSmallerOrEqualValue(endOfDay))
          ..limit(1))
        .get();
    return results.isNotEmpty;
  }

  Future<int> addExpense(ExpensesCompanion expense) {
    return into(expenses).insert(expense);
  }

  Future<void> updateExpense(ExpensesCompanion expense) async {
    await update(expenses).replace(expense);
  }

  Future<void> deleteExpense(int id) async {
    final exp = await (select(expenses)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (exp != null && exp.imagePaths != null) {
      for (final imgPath in exp.imagePaths!) {
        try {
          final f = File(imgPath);
          if (await f.exists()) {
            await f.delete();
          }
        } catch (_) {}
      }
    }
    await (delete(expenses)..where((t) => t.id.equals(id))).go();
  }

  // Custom Category Queries (global across all books with deduplication)
  Future<List<CustomCategory>> fetchCustomCategories([int? groupId]) async {
    final list = await (select(customCategories)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
    return _deduplicateCategories(list);
  }

  Stream<List<CustomCategory>> watchCustomCategories([int? groupId]) {
    return (select(customCategories)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch()
        .map(_deduplicateCategories);
  }

  List<CustomCategory> _deduplicateCategories(List<CustomCategory> list) {
    final seen = <String>{};
    final result = <CustomCategory>[];
    for (final cat in list) {
      final key = cat.name.trim().toLowerCase();
      if (!seen.contains(key)) {
        seen.add(key);
        result.add(cat);
      }
    }
    return result;
  }

  Future<int> addCustomCategory(CustomCategoriesCompanion category) {
    return into(customCategories).insert(category);
  }

  Future<void> deleteCustomCategory(int id) async {
    final cat = await (select(customCategories)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (cat != null) {
      await (delete(customCategories)..where((t) => t.name.equals(cat.name))).go();
    } else {
      await (delete(customCategories)..where((t) => t.id.equals(id))).go();
    }
  }

  Future<void> deleteCustomCategoryByName(String name) async {
    await (delete(customCategories)..where((t) => t.name.equals(name))).go();
  }

  // Debug/Refactor help: clear all data
  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(expenses).go();
      await delete(expenseGroups).go();
    });
  }

  // Recurring Expenses Logic
  Future<void> processRecurringExpenses() async {
    final now = DateTime.now();
    final recurringExpenses = await (select(expenses)
      ..where((t) => t.isRecurring.equals(true)))
    .get();

    for (var exp in recurringExpenses) {
      if (exp.nextRecurringDate == null || exp.recurrencePeriod == null) continue;
      
      DateTime nextDateToProcess = exp.nextRecurringDate!;
      
      while (nextDateToProcess.isBefore(now) || nextDateToProcess.isAtSameMomentAs(now)) {
        // Find or create correct month's group
        final targetGroupName = DateFormat('MMMM yyyy').format(nextDateToProcess);
        final existingGroups = await select(expenseGroups).get();
        ExpenseGroup? targetGroup;
        for (var g in existingGroups) {
          if (g.name == targetGroupName) {
            targetGroup = g;
            break;
          }
        }
        
        int targetGroupId;
        if (targetGroup != null) {
          targetGroupId = targetGroup.id;
        } else {
          // Auto-create book for the month
          targetGroupId = await into(expenseGroups).insert(
            ExpenseGroupsCompanion.insert(
              name: targetGroupName,
              icon: const Value('folder_rounded'),
              monthlyBudget: const Value(null),
              isMonthlyBudget: const Value(true),
              createdAt: nextDateToProcess,
            ),
          );
        }

        // Check if already applied (De-duplication)
        Expression<bool> titleMatch;
        if (exp.title == null) {
          titleMatch = expenses.title.isNull();
        } else {
          titleMatch = expenses.title.equals(exp.title!);
        }

        final existingClone = await (select(expenses)..where((t) => 
          t.groupId.equals(targetGroupId) &
          t.category.equals(exp.category) &
          t.recurrencePeriod.equals(exp.recurrencePeriod!) &
          t.isRecurring.equals(false) &
          titleMatch
        )).getSingleOrNull();

        if (existingClone == null) {
          // Insert clone
          await into(expenses).insert(
            ExpensesCompanion.insert(
              amount: exp.amount,
              date: nextDateToProcess,
              category: exp.category,
              note: Value(exp.note),
              imagePaths: Value(exp.imagePaths),
              groupId: targetGroupId,
              isRecurring: const Value(false), 
              recurrencePeriod: Value(exp.recurrencePeriod), // Keep period to identify generated instances
              title: Value(exp.title),
              omitFromAvg: Value(exp.omitFromAvg),
            ),
          );
        }
        
        // Advance
        nextDateToProcess = _calculateNextDate(nextDateToProcess, exp.recurrencePeriod!);
      }
      
      // Update template with the final future date
      if (nextDateToProcess != exp.nextRecurringDate) {
        await (update(expenses)..where((t) => t.id.equals(exp.id))).write(
          ExpensesCompanion(
            nextRecurringDate: Value(nextDateToProcess),
          ),
        );
      }
    }
  }

  DateTime _addMonthsSafe(DateTime date, int monthsToAdd) {
    final newYear = date.year + ((date.month - 1 + monthsToAdd) ~/ 12);
    final newMonth = ((date.month - 1 + monthsToAdd) % 12) + 1;
    final maxDays = DateTime(newYear, newMonth + 1, 0).day;
    final newDay = date.day > maxDays ? maxDays : date.day;
    return DateTime(newYear, newMonth, newDay, date.hour, date.minute, date.second);
  }

  DateTime _calculateNextDate(DateTime current, String period) {
    switch (period) {
      case 'Daily': return current.add(const Duration(days: 1));
      case 'Weekly': return current.add(const Duration(days: 7));
      case 'Monthly': return _addMonthsSafe(current, 1);
      case 'Quarterly': return _addMonthsSafe(current, 3);
      case 'Yearly': return _addMonthsSafe(current, 12);
      default: return current.add(const Duration(days: 30));
    }
  }

  // Category Budgets logic
  Future<List<CategoryBudget>> fetchCategoryBudgets(int groupId) {
    return (select(categoryBudgets)..where((t) => t.groupId.equals(groupId))).get();
  }

  Future<void> setCategoryBudget(int groupId, String category, double amount, bool includePastExpenses) async {
    // Check if exists
    final existing = await (select(categoryBudgets)
          ..where((t) => t.groupId.equals(groupId) & t.category.equals(category)))
        .getSingleOrNull();

    if (existing != null) {
      await update(categoryBudgets).replace(
        existing.copyWith(
          amount: amount,
          includePastExpenses: includePastExpenses,
        ),
      );
    } else {
      await into(categoryBudgets).insert(
        CategoryBudgetsCompanion.insert(
          category: category,
          amount: amount,
          groupId: groupId,
          createdAt: Value(DateTime.now()),
          includePastExpenses: Value(includePastExpenses),
        ),
      );
    }
  }

  Future<void> deleteCategoryBudget(int id) async {
    await (delete(categoryBudgets)..where((t) => t.id.equals(id))).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
