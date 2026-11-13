import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/expense_database.dart';
import '../models/upi_transaction.dart';
import 'notification_service.dart';

class UpiTrackingService {
  static const MethodChannel _channel = MethodChannel('com.example.ar_expense_tracker/upi_tracking');
  static bool _initialized = false;
  static ExpenseDatabase? _dbRef;

  /// Native queues every approved transaction AND pushes it live, so the same `id` can arrive twice
  /// (live event, then again when the queue is drained on resume). Track processed ids to log once.
  static const String _processedIdsKey = 'upi_processed_txn_ids';
  static const int _maxProcessedIds = 200;
  static Future<void> _serial = Future.value();

  /// Timeout before an unanswered UPI prompt is logged automatically. 0 = off.
  static const String autoConfirmMinutesKey = 'upi_auto_confirm_minutes';
  static const int defaultAutoConfirmMinutes = 1;
  static const List<int> autoConfirmMinuteOptions = [0, 1, 2, 5, 10, 15, 30];

  /// Initializes live MethodChannel callbacks for real-time approved UPI transactions
  static void initialize(ExpenseDatabase db) {
    _dbRef = db;
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onUpiExpenseApproved') {
        final jsonStr = call.arguments as String?;
        if (jsonStr != null && jsonStr.isNotEmpty) {
          try {
            final json = jsonDecode(jsonStr);
            final txn = UpiTransaction.fromJson(json);
            if (_dbRef != null) {
              await _ingestOnce(_dbRef!, txn);
            }
          } catch (_) {}
        }
      }
    });
  }

  /// Bank SMS auto-tracking toggle (read natively as `flutter.bank_sms_tracking_enabled`).
  static const String bankSmsEnabledKey = 'bank_sms_tracking_enabled';

  /// True when both RECEIVE_SMS and READ_SMS are granted.
  static Future<bool> isSmsPermissionGranted() async {
    try {
      return await _channel.invokeMethod<bool>('isSmsPermissionGranted') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Shows the Android SMS permission dialog. Returns true if granted.
  static Future<bool> requestSmsPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestSmsPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens this app's Android settings page (for permanently denied permissions).
  static Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod('openAppSettings');
    } catch (_) {}
  }

  /// Processes and logs any pending approved UPI transactions queued while the app was closed
  static Future<void> processPendingApprovedExpenses(ExpenseDatabase db) async {
    try {
      final queueStr = await _channel.invokeMethod<String>('getPendingUpiExpenses');
      if (queueStr == null || queueStr.isEmpty || queueStr == '[]') return;

      final list = UpiTransaction.decodeList(queueStr);
      for (final txn in list) {
        await _ingestOnce(db, txn);
      }
    } catch (_) {}
  }

  /// Logs a transaction unless its id was already processed. Runs serially so a live event and a
  /// queue drain racing each other cannot both insert the same transaction.
  static Future<void> _ingestOnce(ExpenseDatabase db, UpiTransaction txn) {
    final next = _serial.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getStringList(_processedIdsKey) ?? <String>[];
      if (seen.contains(txn.id)) return;

      await logUpiTransaction(db, txn);

      seen.add(txn.id);
      if (seen.length > _maxProcessedIds) {
        seen.removeRange(0, seen.length - _maxProcessedIds);
      }
      await prefs.setStringList(_processedIdsKey, seen);
    });
    _serial = next.catchError((_) {});
    return next;
  }

  static Future<int> getAutoConfirmMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(autoConfirmMinutesKey) ?? defaultAutoConfirmMinutes;
  }

  static Future<void> setAutoConfirmMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(autoConfirmMinutesKey, minutes);
  }

  /// Note = source details (UPI ID, ref, account) + where it was tracked from.
  static String _buildNote(UpiTransaction txn) {
    const source = 'Auto-tracked via Bank SMS';
    final details = txn.note.trim();
    return details.isEmpty ? source : '$details\n$source';
  }

  /// Destination book setting. Missing / empty = last opened book; [targetMonthBook] = the book
  /// named after the payment's month ("November 2026"), created if missing; otherwise a book id.
  static const String targetBookKey = 'upi_target_group_id';
  static const String targetMonthBook = 'MONTH';

  /// Book id saved by HomeScreen every time a book is opened.
  static const String lastOpenedGroupKey = 'last_opened_group_id';

  static Future<ExpenseGroup?> resolveTargetBook(
    ExpenseDatabase db,
    SharedPreferences prefs,
    DateTime paymentDate,
  ) async {
    final groups = await db.fetchGroups();
    if (groups.isEmpty) return null;

    ExpenseGroup? byId(Object? id) =>
        id == null ? null : groups.where((g) => g.id.toString() == id.toString()).firstOrNull;

    final target = prefs.getString(targetBookKey);
    if (target == targetMonthBook) {
      final monthName = DateFormat('MMMM yyyy').format(paymentDate);
      final existing = groups.where((g) => g.name == monthName).firstOrNull;
      if (existing != null) return existing;
      final newId = await db.into(db.expenseGroups).insert(
            ExpenseGroupsCompanion.insert(
              name: monthName,
              icon: const Value('folder_rounded'),
              isMonthlyBudget: const Value(true),
              createdAt: DateTime(paymentDate.year, paymentDate.month),
            ),
          );
      return (await db.fetchGroups()).where((g) => g.id == newId).firstOrNull ?? groups.first;
    }

    return byId(target) ?? byId(prefs.getInt(lastOpenedGroupKey)) ?? groups.first;
  }

  /// Directly saves an approved UPI transaction into the configured destination book
  static Future<void> logUpiTransaction(ExpenseDatabase db, UpiTransaction txn) async {
    final prefs = await SharedPreferences.getInstance();
    final targetGroup = await resolveTargetBook(db, prefs, txn.dateTime);
    if (targetGroup == null) return;

    await db.addExpense(
      ExpensesCompanion.insert(
        title: Value(txn.merchant),
        amount: txn.amount,
        date: txn.dateTime,
        category: txn.category,
        groupId: targetGroup.id,
        note: Value(_buildNote(txn)),
        isRecurring: const Value(false),
        omitFromAvg: const Value(false),
        imagePaths: const Value([]),
        subExpenses: const Value([]),
      ),
    );

    await NotificationService.onExpenseAdded(db);
  }
}
