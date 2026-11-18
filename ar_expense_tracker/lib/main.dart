import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/theme_provider.dart';
import 'utils/font_utils.dart';

import 'screens/splash_screen.dart';
import 'services/drive_sync_service.dart';
import 'utils/haptics.dart';
import 'package:home_widget/home_widget.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'providers/shared_intent_provider.dart';
import 'services/update_service.dart';
import 'providers/expense_provider.dart';
import 'database/expense_database.dart';
import 'screens/home_screen.dart';
import 'screens/group_selection_screen.dart';
import 'services/notification_service.dart';
import 'services/upi_tracking_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();
  Haptics.init(sharedPreferences);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});

  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _performAutoSync(isStartup: true);
    _initHomeWidget();
    _initSharingIntent();
    _initNotifications();

    // Check for updates shortly after the app opens
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && navigatorKey.currentContext != null) {
        UpdateService.checkForUpdates(navigatorKey.currentContext!);
      }
    });

    // Process recurring expenses, check reminder notifications, and ingest approved UPI expenses on startup
    Future.delayed(const Duration(seconds: 1), () async {
      final db = ref.read(expenseDatabaseProvider);
      UpiTrackingService.initialize(db);
      await db.processRecurringExpenses();
      await NotificationService.checkAndScheduleReminders(db);
      await UpiTrackingService.processPendingApprovedExpenses(db);
    });
  }

  void _initNotifications() {
    NotificationService.initialize(
      onDeepLink: (uri) {
        ref.read(pendingWidgetUriProvider.notifier).setUri(uri);
        _processWidgetUri(uri);
      },
    );
  }

  void _initSharingIntent() {
    // For sharing images coming from outside the app while the app is in the memory
    ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          ref.read(sharedImagePathProvider.notifier).setPath(value.first.path);
        }
      },
      onError: (_) {},
    );

    // For sharing images coming from outside the app while the app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<SharedMediaFile> value,
    ) {
      if (value.isNotEmpty) {
        ref.read(sharedImagePathProvider.notifier).setPath(value.first.path);
      }
      ReceiveSharingIntent.instance.reset();
    });
  }

  void _initHomeWidget() {
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_launchedFromWidget);
    HomeWidget.widgetClicked.listen(_launchedFromWidget);
  }

  void _launchedFromWidget(Uri? uri) {
    if (uri != null) {
      ref.read(pendingWidgetUriProvider.notifier).setUri(uri);
      _processWidgetUri(uri);
    }
  }

  void _processWidgetUri(Uri uri) async {
    final uriString = uri.toString();
    final match = RegExp(r'groupId=([^&]+)').firstMatch(uriString);
    final groupIdString = uri.queryParameters['groupId'] ?? match?.group(1);

    final host = uri.host.toLowerCase();
    final isUpiEdit = host == 'upiedit' ||
        uri.path.toLowerCase().contains('upiedit') ||
        uriString.toLowerCase().contains('upiedit');
    final isAddExpense = isUpiEdit ||
        host == 'addexpense' ||
        uri.path.toLowerCase().contains('addexpense') ||
        uriString.toLowerCase().contains('addexpense');
    final isInsights = host == 'insights' ||
        uri.path.toLowerCase().contains('insights') ||
        uriString.toLowerCase().contains('insights');

    final double? upiAmount = isUpiEdit ? double.tryParse(uri.queryParameters['amount'] ?? '') : null;
    final String? upiTitle = isUpiEdit ? uri.queryParameters['title'] : null;
    final String? upiCategory = isUpiEdit ? uri.queryParameters['category'] : null;
    final String? upiNote = isUpiEdit ? uri.queryParameters['note'] : null;
    // Set natively when the auto-confirm timeout logged the payment just before ✏️ Edit was tapped
    final upiAlreadyAdded = isUpiEdit && uri.queryParameters['alreadyAdded'] == '1';

    // Wait until navigator is mounted and context is ready
    int attempts = 0;
    while ((!mounted || navigatorKey.currentContext == null) && attempts < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    if (navigatorKey.currentContext == null) return;

    final db = ref.read(expenseDatabaseProvider);
    final groups = await db.fetchGroups();
    if (groups.isEmpty) return;

    ExpenseGroup targetGroup = groups.first;
    if (groupIdString != null && groupIdString.isNotEmpty) {
      targetGroup = groups.firstWhere(
        (g) => g.id.toString() == groupIdString,
        orElse: () => groups.first,
      );
    }

    // Clear the provider so Splash doesn't hold it
    ref.read(pendingWidgetUriProvider.notifier).clear();

    // Reset navigation stack with GroupSelectionScreen at root, and push HomeScreen on top
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const GroupSelectionScreen()),
      (route) => false,
    );
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          group: targetGroup,
          // Already logged: don't open an editor that would save it a second time
          autoOpenAddExpense: isAddExpense && !upiAlreadyAdded,
          autoOpenInsights: isInsights,
          initialAddExpenseAmount: upiAmount,
          initialAddExpenseTitle: upiTitle,
          initialAddExpenseCategory: upiCategory,
          initialAddExpenseNote: upiNote,
          fromPaymentPrompt: isUpiEdit,
        ),
      ),
    );

    if (upiAlreadyAdded) {
      final amount = upiAmount ?? 0;
      final amountText = amount % 1 == 0 ? amount.toInt().toString() : amount.toStringAsFixed(2);
      final payee = upiTitle != null && upiTitle.isNotEmpty ? ' to $upiTitle' : '';
      final ctx = navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
        SnackBar(
          content: Text('₹$amountText$payee was already auto-added. Edit it from the book it was saved to.'),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _performAutoSync(isStartup: false);
    } else if (state == AppLifecycleState.resumed) {
      final db = ref.read(expenseDatabaseProvider);
      db.processRecurringExpenses();
      NotificationService.checkAndScheduleReminders(db);
      UpiTrackingService.processPendingApprovedExpenses(db);
    }
  }

  Future<void> _performAutoSync({required bool isStartup}) async {
    final prefs = await SharedPreferences.getInstance();
    final isAutoSyncEnabled = prefs.getBool('auto_sync') ?? false;
    if (!isAutoSyncEnabled) return;

    final syncService = ref.read(driveSyncServiceProvider);
    if (!syncService.isSignedIn) {
      final success = await syncService.signInSilently();
      if (!success) return;
    }

    try {
      // Always backup on auto-sync to avoid accidental local data loss
      await syncService.backupDatabase();
    } catch (_) {
    } finally {
      syncService.clearStatusWithDelay();
    }
  }

  TextTheme _buildTextTheme(TextTheme base, String titleFont, String bodyFont) {
    return FontUtils.buildCombinedTextTheme(base, titleFont, bodyFont);
  }

  AppBarTheme _buildAppBarTheme(ColorScheme colorScheme, String titleFont) {
    return AppBarTheme(
      centerTitle: true,
      titleTextStyle: FontUtils.getFontTextStyle(
        titleFont,
        TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final appSeedColor = ref.watch(appColorProvider);
    final isAmoled = ref.watch(isAmoledProvider);
    final titleFont = ref.watch(titleFontProvider);
    final bodyFont = ref.watch(bodyFontProvider);

    return MaterialApp(
      title: 'AR Expense Tracker',
      navigatorKey: navigatorKey,
      themeMode: themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: appSeedColor,
          brightness: Brightness.light,
        ),
        textTheme: _buildTextTheme(ThemeData.light().textTheme, titleFont, bodyFont),
        appBarTheme: _buildAppBarTheme(ColorScheme.fromSeed(seedColor: appSeedColor, brightness: Brightness.light), titleFont),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: appSeedColor,
          brightness: Brightness.dark,
        ).copyWith(surface: isAmoled ? Colors.black : null),
        scaffoldBackgroundColor: isAmoled ? Colors.black : null,
        textTheme: _buildTextTheme(ThemeData.dark().textTheme, titleFont, bodyFont),
        appBarTheme: _buildAppBarTheme(ColorScheme.fromSeed(seedColor: appSeedColor, brightness: Brightness.dark).copyWith(surface: isAmoled ? Colors.black : null), titleFont),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
