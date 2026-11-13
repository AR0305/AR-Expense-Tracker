import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:math' as math;
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/theme_provider.dart';
import '../services/drive_sync_service.dart';
import '../utils/haptics.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'splash_screen.dart';
import '../providers/expense_provider.dart';
import '../providers/custom_category_provider.dart';
import '../providers/budget_provider.dart';
import '../widgets/dynamic_icon_bg.dart';
import '../widgets/font_picker_sheet.dart';
import '../utils/font_utils.dart';
import '../models/custom_reminder.dart';
import '../services/notification_service.dart';
import 'package:home_widget/home_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/update_service.dart';
import '../services/upi_tracking_service.dart';


class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with WidgetsBindingObserver {
  bool _isSyncing = false;
  double _syncProgress = 0.0;
  String _syncStatus = '';
  String? _lastSyncTime;
  String _driveUsage = 'Calculating...';
  bool _isAutoSyncEnabled = false;
  bool _isSyncImagesEnabled = true;
  String _appVersion = '';

  bool _notificationsEnabled = true;
  bool _timelyRemindersEnabled = true;
  List<CustomReminder> _customReminders = [];

  String? _upiTargetGroupId;
  String? _upiTargetGroupName;
  int _upiAutoConfirmMinutes = UpiTrackingService.defaultAutoConfirmMinutes;
  bool _bankSmsEnabled = true;
  bool _isSmsPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSyncStatus();
    _fetchDriveUsage();
    _loadAppVersion();
    _loadNotificationSettings();
    _loadUpiSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check permissions after the user returns from Android settings
    if (state == AppLifecycleState.resumed) _refreshSmsPermission();
  }

  Future<void> _refreshSmsPermission() async {
    final smsGranted = await UpiTrackingService.isSmsPermissionGranted();
    if (!mounted) return;
    setState(() {
      _isSmsPermissionGranted = smsGranted;
    });
  }

  Future<void> _loadUpiSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final targetId = prefs.getString(UpiTrackingService.targetBookKey);
    String? targetName;
    if (targetId != null && targetId.isNotEmpty && targetId != UpiTrackingService.targetMonthBook) {
      final db = ref.read(expenseDatabaseProvider);
      final groups = await db.fetchGroups();
      targetName = groups.where((g) => g.id.toString() == targetId).firstOrNull?.name;
    }
    if (mounted) {
      setState(() {
        _upiTargetGroupId = targetId;
        _upiTargetGroupName = targetName;
        _upiAutoConfirmMinutes = prefs.getInt(UpiTrackingService.autoConfirmMinutesKey) ??
            UpiTrackingService.defaultAutoConfirmMinutes;
        _bankSmsEnabled = prefs.getBool(UpiTrackingService.bankSmsEnabledKey) ?? true;
      });
    }
    await _refreshSmsPermission();
  }

  // ---------------------------------------------------------------- Bank SMS

  Future<void> _toggleBankSmsTracking(bool value) async {
    Haptics.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(UpiTrackingService.bankSmsEnabledKey, value);
    setState(() => _bankSmsEnabled = value);
    if (value && !_isSmsPermissionGranted) {
      await _requestSmsPermission();
    }
  }

  Future<void> _requestSmsPermission() async {
    final granted = await UpiTrackingService.requestSmsPermission();
    if (!mounted) return;
    setState(() => _isSmsPermissionGranted = granted);
    if (!granted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('SMS Permission Required'),
          content: const Text(
            'To detect payments from bank SMS, allow SMS access for this app. '
            'Messages are processed on this device only and are never uploaded.\n\n'
            'Open App Settings > Permissions > SMS and select Allow. '
            'On Xiaomi, Redmi and POCO phones, also allow "Read SMS" and "Notification SMS" under Other permissions.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                UpiTrackingService.openAppSettings();
              },
              child: const Text('Open App Settings'),
            ),
          ],
        ),
      );
    }
  }

  // ---------------------------------------------------------------- Destination book

  String get _targetBookLabel {
    if (_upiTargetGroupId == UpiTrackingService.targetMonthBook) return "This month's book";
    if (_upiTargetGroupName != null) return _upiTargetGroupName!;
    return 'Last opened book';
  }

  void _selectUpiTargetBook() async {
    Haptics.selectionClick();
    final db = ref.read(expenseDatabaseProvider);
    final groups = await db.fetchGroups();
    if (!mounted) return;

    final current = (_upiTargetGroupId == null || _upiTargetGroupId!.isEmpty) ? '' : _upiTargetGroupId!;

    Widget option(BuildContext ctx, String value, IconData icon, String label, {String? hint}) {
      final selected = value == current;
      final color = Theme.of(ctx).colorScheme.primary;
      return SimpleDialogOption(
        onPressed: () => Navigator.pop(ctx, value),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? color : null),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                  if (hint != null)
                    Text(hint, style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_rounded, size: 20, color: color),
          ],
        ),
      );
    }

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Save Payments To'),
        children: [
          option(ctx, '', Icons.history_rounded, 'Last opened book', hint: 'The book you viewed most recently'),
          option(ctx, UpiTrackingService.targetMonthBook, Icons.calendar_month_rounded, "This month's book",
              hint: 'Book named after the payment month, created if missing'),
          if (groups.isNotEmpty) const Divider(),
          ...groups.map((g) => option(ctx, g.id.toString(), Icons.book_rounded, g.name)),
        ],
      ),
    );

    if (result == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (result.isEmpty) {
      await prefs.remove(UpiTrackingService.targetBookKey);
    } else {
      await prefs.setString(UpiTrackingService.targetBookKey, result);
    }
    if (!mounted) return;
    setState(() {
      _upiTargetGroupId = result.isEmpty ? null : result;
      _upiTargetGroupName = groups.where((g) => g.id.toString() == result).firstOrNull?.name;
    });
  }

  // ---------------------------------------------------------------- Auto-confirm

  String _autoConfirmLabel(int minutes) {
    if (minutes <= 0) return 'Off';
    return minutes == 1 ? '1 minute' : '$minutes minutes';
  }

  void _selectUpiAutoConfirm() async {
    Haptics.selectionClick();
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Auto-Confirm'),
        children: UpiTrackingService.autoConfirmMinuteOptions.map((minutes) {
          final selected = minutes == _upiAutoConfirmMinutes;
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, minutes),
            child: Row(
              children: [
                Icon(
                  minutes == 0 ? Icons.timer_off_rounded : Icons.timer_rounded,
                  size: 20,
                  color: selected ? Theme.of(ctx).colorScheme.primary : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    minutes == 0 ? 'Off (always ask)' : 'After ${_autoConfirmLabel(minutes)}',
                    style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal),
                  ),
                ),
                if (selected) Icon(Icons.check_rounded, size: 20, color: Theme.of(ctx).colorScheme.primary),
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (result != null && result != _upiAutoConfirmMinutes) {
      await UpiTrackingService.setAutoConfirmMinutes(result);
      if (mounted) setState(() => _upiAutoConfirmMinutes = result);
    }
  }

  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _timelyRemindersEnabled = prefs.getBool('timely_reminders_enabled') ?? true;
        final customJson = prefs.getString('custom_reminders_json') ?? '';
        _customReminders = CustomReminder.decodeList(customJson);
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    Haptics.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() => _notificationsEnabled = value);
    final db = ref.read(expenseDatabaseProvider);
    await NotificationService.checkAndScheduleReminders(db);
  }

  Future<void> _toggleTimelyReminders(bool value) async {
    Haptics.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('timely_reminders_enabled', value);
    setState(() => _timelyRemindersEnabled = value);
    final db = ref.read(expenseDatabaseProvider);
    await NotificationService.checkAndScheduleReminders(db);
  }

  Future<void> _saveCustomReminders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_reminders_json', CustomReminder.encodeList(_customReminders));
    final db = ref.read(expenseDatabaseProvider);
    await NotificationService.checkAndScheduleReminders(db);
  }

  Future<void> _addCustomReminder() async {
    Haptics.selectionClick();
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 20, minute: 0),
    );
    if (time == null || !mounted) return;

    final titleController = TextEditingController(text: 'Daily Expense Check');
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Custom Reminder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Scheduled Time: ${time.format(context)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Reminder Title',
                hintText: 'e.g., Evening Expense Review',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, titleController.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (title == null || !mounted) return;

    final newReminder = CustomReminder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.isEmpty ? 'Expense Reminder' : title,
      hour: time.hour,
      minute: time.minute,
      isEnabled: true,
    );

    setState(() {
      _customReminders.add(newReminder);
    });
    await _saveCustomReminders();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder "${newReminder.title}" set for ${time.format(context)} daily!'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _toggleCustomReminder(int index, bool value) async {
    Haptics.selectionClick();
    setState(() {
      _customReminders[index] = _customReminders[index].copyWith(isEnabled: value);
    });
    await _saveCustomReminders();
  }

  Future<void> _deleteCustomReminder(int index) async {
    Haptics.selectionClick();
    setState(() {
      _customReminders.removeAt(index);
    });
    await _saveCustomReminders();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = 'v${info.version}');
    } catch (_) {}
  }

  Future<void> _fetchDriveUsage() async {
    final syncService = ref.read(driveSyncServiceProvider);
    if (!syncService.isSignedIn) {
      setState(() => _driveUsage = 'Not signed in');
      return;
    }
    final sizeInBytes = await syncService.getDriveUsage();
    if (!mounted) return;
    setState(() {
      if (sizeInBytes == 0) {
        _driveUsage = '0 KB';
      } else if (sizeInBytes < 1024 * 1024) {
        _driveUsage = '${(sizeInBytes / 1024).toStringAsFixed(2)} KB';
      } else {
        _driveUsage = '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
      }
    });
  }

  Future<void> _checkSyncStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isAutoSyncEnabled = prefs.getBool('auto_sync') ?? false;
        _isSyncImagesEnabled = prefs.getBool('sync_images') ?? true;
        _lastSyncTime = prefs.getString('last_sync_timestamp');
      });
    }
  }

  Future<void> _toggleAutoSync(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_sync', value);
    setState(() {
      _isAutoSyncEnabled = value;
    });
  }

  Future<void> _toggleSyncImages(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sync_images', value);
    setState(() {
      _isSyncImagesEnabled = value;
    });
  }

  Future<void> _toggleHaptics(double value) async {
    final intensity = HapticIntensity.values[value.toInt()];
    await Haptics.setIntensity(intensity);
    setState(() {});
    if (intensity != HapticIntensity.off) {
      Haptics.selectionClick();
    }
  }

  Future<void> _handleBackup() async {
    final syncService = ref.read(driveSyncServiceProvider);
    if (!syncService.isSignedIn) {
      final success = await syncService.signIn();
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to sign in.')));
        }
        return;
      }
      setState(() {});
    }

    setState(() {
      _isSyncing = true;
      _syncProgress = 0.0;
      _syncStatus = 'Backing up to Google Drive...';
    });

    try {
      await syncService.backupDatabase(
        onProgress: (progress) {
          setState(() {
            _syncProgress = progress;
          });
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup successful!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
      }
    } finally {
      syncService.clearStatusWithDelay();
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
        _checkSyncStatus(); // Reload to get updated last sync time
      }
    }
  }

  Future<void> _handleRestore() async {
    final syncService = ref.read(driveSyncServiceProvider);
    if (!syncService.isSignedIn) {
      final success = await syncService.signIn();
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to sign in.')));
        }
        return;
      }
      if (!mounted) return;
      setState(() {});
      // If they just signed in, auto-restore
      await _performRestore(silent: true);
      return;
    }

    await _performRestore(silent: false);
  }

  Future<void> _performRestore({bool silent = false}) async {
    final syncService = ref.read(driveSyncServiceProvider);
    if (!mounted) return;

    if (!silent) {
      // Confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore Database?'),
          content: const Text('This will overwrite all current local data with the backup from Google Drive. This cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore', style: TextStyle(color: Colors.red))),
          ],
        ),
      );

      if (confirm != true) return;
    }

    setState(() {
      _isSyncing = true;
      _syncProgress = 0.0;
      _syncStatus = 'Restoring from Google Drive...';
    });

    try {
      // Close the database to release the file lock
      final db = ref.read(expenseDatabaseProvider);
      await db.close();

      await syncService.restoreDatabase(
        onProgress: (progress) {
          setState(() {
            _syncProgress = progress;
          });
        },
      );
      
      if (mounted) {
        // Invalidate providers to force them to read the new database connection
        ref.invalidate(expenseDatabaseProvider);
        ref.invalidate(groupProvider);
        
        // Navigate to SplashScreen with a beautiful fade animation to simulate a fresh load
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const SplashScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
        setState(() {
          _isSyncing = false;
        });
      }
    } finally {
      syncService.clearStatusWithDelay();
    }
  }

  Future<void> _exportLocalBackup() async {
    Haptics.mediumImpact();
    try {
      final db = ref.read(expenseDatabaseProvider);
      await db.checkpointWal();

      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'db.sqlite'));
      if (await file.exists()) {
        final backupFileName = 'ArExpenseTracker_Backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.sqlite';
        final tempExportFile = File(p.join(dbFolder.path, backupFileName));
        await file.copy(tempExportFile.path);

        final xFile = XFile(tempExportFile.path);
        // ignore: deprecated_member_use
        await Share.shareXFiles(
          [xFile],
          text: 'ArExpenseTracker Backup ($backupFileName)',
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Database file not found.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error exporting backup: $e')));
      }
    }
  }

  Future<void> _restoreLocalBackup() async {
    Haptics.mediumImpact();
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
      );
      if (result != null && result.files.single.path != null) {
        final sourceFile = File(result.files.single.path!);
        
        if (!await sourceFile.exists() || await sourceFile.length() < 16) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid backup file.')));
          }
          return;
        }

        // Validate SQLite Header
        final headerBytes = await sourceFile.openRead(0, 16).first;
        final headerStr = String.fromCharCodes(headerBytes);
        if (!headerStr.startsWith('SQLite format 3')) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Invalid Backup File'),
                content: const Text('The selected file is not a valid SQLite database backup. Restoration was aborted to protect your data.'),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
              ),
            );
          }
          return;
        }

        if (!mounted) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Restore Local Backup?'),
            content: const Text('This will overwrite all current local data with the selected file. This cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore', style: TextStyle(color: Colors.red))),
            ],
          ),
        );

        if (confirm != true) return;
        
        final db = ref.read(expenseDatabaseProvider);
        await db.close();
        
        final dbFolder = await getApplicationDocumentsDirectory();
        final walFile = File(p.join(dbFolder.path, 'db.sqlite-wal'));
        if (await walFile.exists()) {
          try { await walFile.delete(); } catch (_) {}
        }
        final shmFile = File(p.join(dbFolder.path, 'db.sqlite-shm'));
        if (await shmFile.exists()) {
          try { await shmFile.delete(); } catch (_) {}
        }

        final destFile = File(p.join(dbFolder.path, 'db.sqlite'));
        await sourceFile.copy(destFile.path);
        
        if (mounted) {
          ref.invalidate(expenseDatabaseProvider);
          ref.invalidate(groupProvider);
          ref.invalidate(expenseProvider);
          ref.invalidate(customCategoryProvider);
          ref.invalidate(categoryBudgetProvider);

          Navigator.pushAndRemoveUntil(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const SplashScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 800),
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error restoring backup: $e')));
      }
    }
  }

  void _showColorPickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Simple Variants', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                const Color(0xFF10B981),
                const Color(0xFF3B82F6),
                const Color(0xFF8B5CF6),
                const Color(0xFFF43F5E),
                const Color(0xFFF59E0B),
                const Color(0xFF06B6D4),
                const Color(0xFF64748B),
              ].map((c) {
                final isSelected = ref.watch(appColorProvider) == c;
                final scheme = ColorScheme.fromSeed(seedColor: c, brightness: Theme.of(context).brightness);
                return GestureDetector(
                  onTap: () async {
                    Haptics.selectionClick();
                    ref.read(appColorProvider.notifier).setColor(c);
                    // ignore: deprecated_member_use
                    await HomeWidget.saveWidgetData<int>('primary_color', c.value);
                    await HomeWidget.updateWidget(androidName: 'AddExpenseWidgetProvider');
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: scheme.onPrimaryContainer, width: 3) : Border.all(color: Colors.transparent, width: 3),
                      boxShadow: isSelected ? [BoxShadow(color: scheme.primary.withAlpha(100), blurRadius: 12, spreadRadius: 2)] : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(child: Container(color: scheme.primary)),
                                  Expanded(child: Container(color: scheme.primaryContainer)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(child: Container(color: scheme.tertiary)),
                                  Expanded(child: Container(color: scheme.tertiaryContainer)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (isSelected)
                          Center(
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.check, size: 18, color: scheme.onPrimary),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.tonal(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showShapePickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Consumer(
        builder: (context, ref, child) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(100),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: AppIconShape.values.map((shape) {
                      final isSelected = ref.watch(iconShapeProvider) == shape;
                      return GestureDetector(
                        onTap: () {
                          Haptics.selectionClick();
                          ref.read(iconShapeProvider.notifier).setShape(shape);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 56,
                          height: 56,
                          decoration: ShapeDecoration(
                            shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            color: isSelected 
                                ? Theme.of(context).colorScheme.primary 
                                : Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100),
                          ),
                          child: Center(
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: ShapeDecoration(
                                shape: DynamicIconBg.getShapeBorder(shape).copyWith(
                                  side: BorderSide(
                                    color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface, 
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        DynamicIconBg(
                          padding: 12,
                          color: Theme.of(context).colorScheme.primaryContainer.withAlpha(150),
                          child: Icon(Icons.format_shapes_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Icon Shape',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ],
                    ),
                    FilledButton.tonal(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showThemePickerSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Consumer(
        builder: (context, ref, child) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('App Theme', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.brightness_auto),
                title: const Text('System Default'),
                trailing: ref.watch(themeProvider) == ThemeMode.system ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
                onTap: () {
                  ref.read(themeProvider.notifier).setTheme(ThemeMode.system);
                },
              ),
              ListTile(
                leading: const Icon(Icons.light_mode),
                title: const Text('Light'),
                trailing: ref.watch(themeProvider) == ThemeMode.light ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
                onTap: () {
                  ref.read(themeProvider.notifier).setTheme(ThemeMode.light);
                },
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode),
                title: const Text('Dark'),
                trailing: ref.watch(themeProvider) == ThemeMode.dark ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
                onTap: () {
                  ref.read(themeProvider.notifier).setTheme(ThemeMode.dark);
                },
              ),
              const Divider(height: 32),
              SwitchListTile(
                title: const Text('AMOLED Pitch Black', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Save battery with true black backgrounds', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(150), fontSize: 12)),
                value: ref.watch(isAmoledProvider),
                onChanged: (val) {
                  ref.read(isAmoledProvider.notifier).setAmoled(val);
                },
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFontPickerSheet({required bool isTitleFont}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => FontPickerSheet(initialIsTitleFont: isTitleFont),
    );
  }

  void _showTypographySubCategorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Consumer(
        builder: (context, ref, child) {
          final titleFont = ref.watch(titleFontProvider);
          final bodyFont = ref.watch(bodyFontProvider);
          final colorScheme = Theme.of(context).colorScheme;

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withAlpha(100),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.text_format_rounded, color: colorScheme.primary, size: 26),
                    const SizedBox(width: 10),
                    Text(
                      'Typography Customization',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Select font styles for titles, app headers, and body content',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),

                // Title Font Sub Item
                SettingsItem(
                  title: 'Title Font',
                  subtitle: 'Font used for titles, headers, and app bars',
                  icon: Icons.title_rounded,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showFontPickerSheet(isTitleFont: true);
                  },
                  trailing: Text(
                    titleFont,
                    style: FontUtils.getFontTextStyle(
                      titleFont,
                      TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Body Font Sub Item
                SettingsItem(
                  title: 'Body Font',
                  subtitle: 'Font used for body text, lists, and amounts',
                  icon: Icons.text_fields_rounded,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showFontPickerSheet(isTitleFont: false);
                  },
                  trailing: Text(
                    bodyFont,
                    style: FontUtils.getFontTextStyle(
                      bodyFont,
                      TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }


  Widget _sectionNote(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _valueChevron(String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const Icon(Icons.chevron_right_rounded),
      ],
    );
  }

  String get _themeLabel {
    final mode = ref.watch(themeProvider);
    if (mode != ThemeMode.light && ref.watch(isAmoledProvider)) {
      return mode == ThemeMode.dark ? 'AMOLED' : 'System · AMOLED';
    }
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncService = ref.watch(driveSyncServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ------------------------------------------------------------ Automatic Tracking
          SettingsGroup(
            title: 'Automatic Tracking',
            icon: Icons.bolt_rounded,
            initiallyExpanded: true,
            children: [
              SettingsItem(
                title: 'Bank SMS',
                subtitle: !_bankSmsEnabled
                    ? 'Off'
                    : _isSmsPermissionGranted
                        ? 'Detects debits from any Indian bank. Processed on this device.'
                        : 'SMS permission required. Tap to allow.',
                icon: _bankSmsEnabled && !_isSmsPermissionGranted ? Icons.warning_amber_rounded : Icons.sms_rounded,
                onTap: _bankSmsEnabled && !_isSmsPermissionGranted
                    ? _requestSmsPermission
                    : () => _toggleBankSmsTracking(!_bankSmsEnabled),
                trailing: Switch(
                  value: _bankSmsEnabled,
                  onChanged: _toggleBankSmsTracking,
                ),
              ),
              if (_bankSmsEnabled) ...[
                SettingsItem(
                  title: 'Save Payments To',
                  subtitle: 'Book that confirmed payments are added to',
                  icon: Icons.auto_stories_rounded,
                  trailing: _valueChevron(_targetBookLabel),
                  onTap: _selectUpiTargetBook,
                ),
                SettingsItem(
                  title: 'Auto-Confirm',
                  subtitle: _upiAutoConfirmMinutes > 0
                      ? 'Saves the payment if you don\'t respond within ${_autoConfirmLabel(_upiAutoConfirmMinutes)}. Swiping the alert away also saves it.'
                      : 'Every payment waits for Yes, No or Edit.',
                  icon: Icons.timer_rounded,
                  trailing: _valueChevron(_autoConfirmLabel(_upiAutoConfirmMinutes)),
                  onTap: _selectUpiAutoConfirm,
                ),
              ],
            ],
          ),

          // ------------------------------------------------------------ Reminders
          SettingsGroup(
            title: 'Reminders',
            icon: Icons.notifications_active_rounded,
            children: [
              SettingsItem(
                title: 'Expense Reminders',
                subtitle: 'Get reminded to log your expenses',
                icon: Icons.notifications_rounded,
                onTap: () => _toggleNotifications(!_notificationsEnabled),
                trailing: Switch(
                  value: _notificationsEnabled,
                  onChanged: _toggleNotifications,
                ),
              ),
              if (_notificationsEnabled) ...[
                SettingsItem(
                  title: 'Daily Check-Ins',
                  subtitle: 'At 12 PM, 4 PM, 7 PM and 9 PM when nothing is logged that day',
                  icon: Icons.access_time_filled_rounded,
                  onTap: () => _toggleTimelyReminders(!_timelyRemindersEnabled),
                  trailing: Switch(
                    value: _timelyRemindersEnabled,
                    onChanged: _toggleTimelyReminders,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Custom Reminders',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addCustomReminder,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                ),
                if (_customReminders.isEmpty)
                  _sectionNote('No custom reminders yet.')
                else
                  ..._customReminders.asMap().entries.map((entry) {
                    final index = entry.key;
                    final reminder = entry.value;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(60),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: DynamicIconBg(
                          padding: 10,
                          child: Icon(Icons.alarm_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                        ),
                        title: Text(
                          reminder.title,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Text(
                          'Daily at ${reminder.formatTime(context)}',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: reminder.isEnabled,
                              onChanged: (val) => _toggleCustomReminder(index, val),
                            ),
                            IconButton(
                              tooltip: 'Delete reminder',
                              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                              onPressed: () => _deleteCustomReminder(index),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ],
          ),

          // ------------------------------------------------------------ Backup & Sync
          SettingsGroup(
            title: 'Backup & Sync',
            icon: Icons.cloud_sync_rounded,
            children: [
              if (!syncService.isSignedIn)
                SettingsItem(
                  title: 'Google Drive',
                  subtitle: 'Sign in to back up and sync your data',
                  icon: Icons.login_rounded,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final success = await syncService.signIn();
                    if (success && mounted) {
                      setState(() {});
                      _fetchDriveUsage();
                      await _performRestore(silent: true);
                    }
                  },
                )
              else ...[
                SettingsItem(
                  title: syncService.currentUser?.displayName ?? 'Google Account',
                  subtitle: syncService.currentUser?.email ?? 'Signed in',
                  icon: Icons.account_circle_rounded,
                  trailing: OutlinedButton(
                    onPressed: () async {
                      await syncService.signOut();
                      setState(() {});
                    },
                    child: const Text('Sign Out'),
                  ),
                ),
                SettingsItem(
                  title: 'Automatic Backup',
                  subtitle: 'Back up when the app opens and closes',
                  icon: Icons.autorenew_rounded,
                  onTap: () => _toggleAutoSync(!_isAutoSyncEnabled),
                  trailing: Switch(
                    value: _isAutoSyncEnabled,
                    onChanged: _toggleAutoSync,
                  ),
                ),
                SettingsItem(
                  title: 'Include Receipt Images',
                  subtitle: 'Back up and restore images attached to expenses',
                  icon: Icons.image_rounded,
                  onTap: () => _toggleSyncImages(!_isSyncImagesEnabled),
                  trailing: Switch(
                    value: _isSyncImagesEnabled,
                    onChanged: _toggleSyncImages,
                  ),
                ),
                if (_lastSyncTime != null)
                  _sectionNote(
                    'Last backup: ${DateFormat('MMM d, yyyy • h:mm a').format(DateTime.parse(_lastSyncTime!).toLocal())}\n'
                    'Drive storage used: $_driveUsage',
                  ),
                if (_isSyncing)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(_syncStatus, style: const TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: _syncProgress > 0 ? _syncProgress : null, borderRadius: BorderRadius.circular(8)),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _handleRestore,
                            icon: const Icon(Icons.cloud_download_rounded),
                            label: const Text('Restore'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _handleBackup,
                            icon: const Icon(Icons.cloud_upload_rounded),
                            label: const Text('Back Up Now'),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Divider(),
              ),
              SettingsItem(
                title: 'Export Backup File',
                subtitle: 'Save a copy of your data to Downloads',
                icon: Icons.download_rounded,
                onTap: _exportLocalBackup,
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
              SettingsItem(
                title: 'Import Backup File',
                subtitle: 'Restore your data from a .sqlite backup file',
                icon: Icons.upload_rounded,
                onTap: _restoreLocalBackup,
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),

          // ------------------------------------------------------------ Appearance
          SettingsGroup(
            title: 'Appearance',
            icon: Icons.palette_rounded,
            children: [
              SettingsItem(
                title: 'Theme',
                subtitle: 'System, light, dark or AMOLED black',
                icon: Icons.brightness_medium_rounded,
                onTap: _showThemePickerSheet,
                trailing: _valueChevron(_themeLabel),
              ),
              SettingsItem(
                title: 'Accent Color',
                subtitle: 'Sets the color palette across the app',
                icon: Icons.color_lens_rounded,
                onTap: _showColorPickerSheet,
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ref.watch(appColorProvider),
                  ),
                ),
              ),
              SettingsItem(
                title: 'Fonts',
                subtitle: 'Title: ${ref.watch(titleFontProvider)} • Body: ${ref.watch(bodyFontProvider)}',
                icon: Icons.text_format_rounded,
                onTap: _showTypographySubCategorySheet,
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
              SettingsItem(
                title: 'Icon Shape',
                subtitle: 'Background shape behind icons',
                icon: Icons.format_shapes_rounded,
                onTap: _showShapePickerSheet,
                trailing: DynamicIconBg(
                  padding: 12,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: ShapeDecoration(
                      shape: DynamicIconBg.getShapeBorder(ref.watch(iconShapeProvider)).copyWith(
                        side: BorderSide(color: Theme.of(context).colorScheme.onSurface, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ------------------------------------------------------------ Haptics
          SettingsGroup(
            title: 'Haptics',
            icon: Icons.vibration_rounded,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        DynamicIconBg(
                          padding: 12,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Icon(Icons.touch_app_rounded, size: 20, color: Theme.of(context).colorScheme.onSurface),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Vibration Strength', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
                              Text('Feedback for taps and gestures', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(150), fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: Theme.of(context).colorScheme.primary,
                        inactiveTrackColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        thumbColor: Theme.of(context).colorScheme.onPrimaryContainer,
                        overlayColor: Colors.transparent,
                        trackHeight: 24,
                        activeTickMarkColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
                        inactiveTickMarkColor: Theme.of(context).colorScheme.primary.withAlpha(150),
                        tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 4),
                        trackShape: CustomLineTrackShape(),
                        thumbShape: const CustomStarThumbShape(thumbRadius: 16),
                      ),
                      child: Slider(
                        value: Haptics.intensity.index.toDouble(),
                        min: 0,
                        max: 3,
                        divisions: 3,
                        onChanged: (val) {
                          _toggleHaptics(val);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Off', style: TextStyle(fontSize: 11, color: Haptics.intensity == HapticIntensity.off ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant)),
                          Text('Light', style: TextStyle(fontSize: 11, color: Haptics.intensity == HapticIntensity.light ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant)),
                          Text('Medium', style: TextStyle(fontSize: 11, color: Haptics.intensity == HapticIntensity.medium ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant)),
                          Text('Strong', style: TextStyle(fontSize: 11, color: Haptics.intensity == HapticIntensity.heavy ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ------------------------------------------------------------ About
          SettingsGroup(
            title: 'About',
            icon: Icons.info_outline_rounded,
            children: [
              SettingsItem(
                title: 'Check for Updates',
                subtitle: _appVersion.isNotEmpty ? 'Version $_appVersion' : 'Check GitHub for a newer release',
                icon: Icons.system_update_rounded,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  Haptics.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Checking for updates...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  await UpdateService.checkForUpdates(
                    context,
                    force: true,
                    showNoUpdateFeedback: true,
                  );
                },
              ),
              SettingsItem(
                title: 'Source Code',
                subtitle: 'github.com/AR0305/AR-Expense-Tracker',
                icon: Icons.code_rounded,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Haptics.selectionClick();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('https://github.com/AR0305/AR-Expense-Tracker')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CustomLineTrackShape extends SliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 24;
    final double trackLeft = offset.dx + 16.0;
    final double trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width - 32.0;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    if (sliderTheme.trackHeight == null || sliderTheme.trackHeight! <= 0) return;

    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final Paint activePaint = Paint()..color = sliderTheme.activeTrackColor!;
    final Paint inactivePaint = Paint()..color = sliderTheme.inactiveTrackColor!;
    final Paint linePaint = Paint()
      ..color = sliderTheme.thumbColor!.withAlpha(80)
      ..strokeWidth = 1.5;

    final Rect visualTrackRect = Rect.fromLTRB(
      trackRect.left - trackRect.height / 2, 
      trackRect.top, 
      trackRect.right + trackRect.height / 2, 
      trackRect.bottom
    );

    final RRect inactiveTrackRRect = RRect.fromRectAndRadius(visualTrackRect, Radius.circular(trackRect.height / 2));
    context.canvas.drawRRect(inactiveTrackRRect, inactivePaint);

    if (thumbCenter.dx > trackRect.left) {
      final Rect activeRect = Rect.fromLTRB(visualTrackRect.left, visualTrackRect.top, thumbCenter.dx, visualTrackRect.bottom);
      final RRect activeTrackRRect = RRect.fromRectAndRadius(activeRect, Radius.circular(trackRect.height / 2));
      context.canvas.drawRRect(activeTrackRRect, activePaint);

      context.canvas.drawLine(
        Offset(trackRect.left, trackRect.center.dy),
        Offset(thumbCenter.dx, trackRect.center.dy),
        linePaint,
      );
    }
  }
}

class CustomStarThumbShape extends SliderComponentShape {
  final double thumbRadius;
  const CustomStarThumbShape({this.thumbRadius = 16.0});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    final paint = Paint()
      ..color = sliderTheme.thumbColor ?? Colors.black
      ..style = PaintingStyle.fill;
      
    final path = Path();
    final points = 24; 
    final innerRadius = thumbRadius * 0.85;
    final outerRadius = thumbRadius;
    final angle = math.pi * 2 / points;
    
    for (int i = 0; i < points; i++) {
      final r = i % 2 == 0 ? outerRadius : innerRadius;
      final a = i * angle;
      final point = Offset(center.dx + r * math.cos(a), center.dy + r * math.sin(a));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    
    canvas.drawPath(path, paint);
  }
}

class SettingsGroup extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool initiallyExpanded;

  const SettingsGroup({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  State<SettingsGroup> createState() => _SettingsGroupState();
}

class _SettingsGroupState extends State<SettingsGroup> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(_isExpanded ? 150 : 80),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withAlpha(50),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
              Haptics.selectionClick();
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  DynamicIconBg(
                    padding: 12,
                    child: Icon(widget.icon, size: 20, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
                    child: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(children: widget.children),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeInOutCubic,
          ),
        ],
      ),
    );
  }
}

class SettingsItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingsItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            DynamicIconBg(
              padding: 12,
              color: Theme.of(context).colorScheme.primaryContainer.withAlpha(150),
              child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
