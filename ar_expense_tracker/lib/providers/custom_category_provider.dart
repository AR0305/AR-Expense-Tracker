import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../database/expense_database.dart';
import '../services/drive_sync_service.dart';
import 'expense_provider.dart';

// Notifier to manage custom categories across all books with reactive updates and cloud sync
class CustomCategoryNotifier extends Notifier<List<CustomCategory>> {
  CustomCategoryNotifier([this.activeGroup]);
  final ExpenseGroup? activeGroup;
  StreamSubscription<List<CustomCategory>>? _subscription;

  @override
  List<CustomCategory> build() {
    final db = ref.read(expenseDatabaseProvider);
    _subscription = db.watchCustomCategories().listen((categories) {
      state = categories;
    });

    ref.onDispose(() {
      _subscription?.cancel();
    });
    return [];
  }

  Future<void> addCategory(String name, String iconName, int colorValue) async {
    final db = ref.read(expenseDatabaseProvider);
    await db.addCustomCategory(
      CustomCategoriesCompanion.insert(
        name: name,
        iconName: iconName,
        colorValue: colorValue,
        groupId: activeGroup != null ? Value(activeGroup!.id) : const Value.absent(),
      ),
    );
    // Explicitly trigger auto-backup and mark unsynced changes
    ref.read(driveSyncServiceProvider).triggerAutoBackup();
  }

  Future<void> deleteCategory(int id) async {
    final db = ref.read(expenseDatabaseProvider);
    await db.deleteCustomCategory(id);
    // Explicitly trigger auto-backup and mark unsynced changes
    ref.read(driveSyncServiceProvider).triggerAutoBackup();
  }
}

final customCategoryProvider = NotifierProvider.family<CustomCategoryNotifier, List<CustomCategory>, ExpenseGroup>(CustomCategoryNotifier.new);
