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
            if (_dbRef != null && await _ingestOnce(_dbRef!, txn)) {
              await _ack([txn.id]);
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

  /// Whether the phone lets bank SMS detection run while the app is closed. Autostart (Xiaomi,
  /// Oppo, Vivo, ...) cannot be read by apps, so only its presence is reported.
  static Future<BackgroundAccessStatus> getBackgroundAccess() async {
    try {
      final map = await _channel.invokeMapMethod<String, dynamic>('getBackgroundAccess');
      return BackgroundAccessStatus(
        batteryUnrestricted: map?['batteryUnrestricted'] as bool? ?? true,
        hasAutostartSetting: map?['hasAutostartSetting'] as bool? ?? false,
        manufacturer: map?['manufacturer'] as String? ?? '',
      );
    } catch (_) {
      return const BackgroundAccessStatus(batteryUnrestricted: true, hasAutostartSetting: false, manufacturer: '');
    }
  }

  /// Shows Android's "Allow app to always run in background?" dialog.
  static Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }

  /// Opens the phone maker's Autostart screen (falls back to the app's settings page).
  static Future<void> openAutostartSettings() async {
    try {
      await _channel.invokeMethod('openAutostartSettings');
    } catch (_) {}
  }

  /// Opens this app's Android settings page (for permanently denied permissions).
  static Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod('openAppSettings');
    } catch (_) {}
  }

  /// Processes and logs any pending approved UPI transactions queued while the app was closed.
  /// The native queue is only trimmed for transactions that were saved, so a failure (or the app
  /// being killed mid-way) leaves the rest to be retried on the next start/resume.
  static Future<void> processPendingApprovedExpenses(ExpenseDatabase db) async {
    String? queueStr;
    try {
      queueStr = await _channel.invokeMethod<String>('getPendingUpiExpenses');
    } catch (_) {
      return;
    }
    if (queueStr == null || queueStr.isEmpty || queueStr == '[]') return;

    final saved = <String>[];
    for (final txn in UpiTransaction.decodeList(queueStr)) {
      try {
        if (await _ingestOnce(db, txn)) saved.add(txn.id);
      } catch (_) {
        // Stays in the native queue; retried next time
      }
    }
    await _ack(saved);
  }

  /// Tells native these transactions are saved, so they leave the approved queue.
  static Future<void> _ack(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await _channel.invokeMethod('ackUpiExpenses', ids);
    } catch (_) {}
  }

  /// Logs a transaction unless its id was already processed. Runs serially so a live event and a
  /// queue drain racing each other cannot both insert the same transaction. Returns true once the
  /// transaction is in the database (now or earlier); throws if saving failed.
  static Future<bool> _ingestOnce(ExpenseDatabase db, UpiTransaction txn) {
    final next = _serial.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getStringList(_processedIdsKey) ?? <String>[];
      if (seen.contains(txn.id)) return true;

      await logUpiTransaction(db, txn);

      // Record the id straight after the insert, before anything else can throw
      seen.add(txn.id);
      if (seen.length > _maxProcessedIds) {
        seen.removeRange(0, seen.length - _maxProcessedIds);
      }
      await prefs.setStringList(_processedIdsKey, seen);

      try {
        await NotificationService.onExpenseAdded(db);
      } catch (_) {}
      return true;
    });
    _serial = next.then<void>((_) {}, onError: (_) {});
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

  /// With no books at all, the payment month's book is created so the payment is never dropped.
  static Future<ExpenseGroup> resolveTargetBook(
    ExpenseDatabase db,
    SharedPreferences prefs,
    DateTime paymentDate,
  ) async {
    final groups = await db.fetchGroups();

    ExpenseGroup? byId(Object? id) =>
        id == null ? null : groups.where((g) => g.id.toString() == id.toString()).firstOrNull;

    final target = prefs.getString(targetBookKey);
    if (target == targetMonthBook || groups.isEmpty) {
      return _monthBook(db, groups, paymentDate);
    }

    return byId(target) ?? byId(prefs.getInt(lastOpenedGroupKey)) ?? groups.first;
  }

  /// The book named after [paymentDate]'s month ("November 2026"), created if missing.
  static Future<ExpenseGroup> _monthBook(
    ExpenseDatabase db,
    List<ExpenseGroup> groups,
    DateTime paymentDate,
  ) async {
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
    final created = (await db.fetchGroups()).where((g) => g.id == newId).firstOrNull;
    if (created == null) throw StateError('Could not create book "$monthName"');
    return created;
  }

  /// Saves an approved UPI transaction into the configured destination book. Throws on failure.
  static Future<void> logUpiTransaction(ExpenseDatabase db, UpiTransaction txn) async {
    final prefs = await SharedPreferences.getInstance();
    final targetGroup = await resolveTargetBook(db, prefs, txn.dateTime);

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
  }
}

/// See [UpiTrackingService.getBackgroundAccess].
class BackgroundAccessStatus {
  final bool batteryUnrestricted;
  final bool hasAutostartSetting;
  final String manufacturer;

  const BackgroundAccessStatus({
    required this.batteryUnrestricted,
    required this.hasAutostartSetting,
    required this.manufacturer,
  });
}
