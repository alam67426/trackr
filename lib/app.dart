import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/pending_transaction_model.dart';
import 'providers/pending_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/transaction_provider.dart';
import 'screens/analytics_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/home_screen.dart';
import 'screens/more_screen.dart';
import 'screens/pending_screen.dart';
import 'screens/transactions_screen.dart';
import 'services/sms_listener.dart';
import 'services/notification_service.dart';
import 'utils/constants.dart';

class TrackrApp extends ConsumerStatefulWidget {
  const TrackrApp({super.key});

  @override
  ConsumerState<TrackrApp> createState() => _TrackrAppState();
}

class _TrackrAppState extends ConsumerState<TrackrApp>
    with WidgetsBindingObserver {
  late final SMSListener _smsListener;
  bool _smsListenerStarted = false;
  bool _startingSmsListener = false;
  bool _syncingInbox = false;
  Timer? _businessNotificationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _smsListener = SMSListener();
    _businessNotificationTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) unawaited(_syncNewDetections());
    });
    ref.listenManual<TrackrSettings>(
      settingsProvider,
      (previous, next) {
        if (next.smsAutoDetection && !_smsListenerStarted) {
          unawaited(_startSmsListener());
        }
      },
      fireImmediately: true,
    );
  }

  Future<void> _startSmsListener() async {
    if (_smsListenerStarted || _startingSmsListener) return;
    _startingSmsListener = true;
    try {
      final started = await _smsListener.start((pending) async {
        await _savePending(pending);
      });
      if (mounted) {
        _smsListenerStarted = started;
        if (started) unawaited(_syncNewDetections());
      }
    } finally {
      if (mounted) _startingSmsListener = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    // Reload transactions captured by the background isolate while the app
    // was away, then register the foreground channel again.
    unawaited(ref.read(pendingProvider.notifier).load());
    unawaited(_syncNewDetections());
    if (ref.read(settingsProvider).smsAutoDetection) {
      _smsListenerStarted = false;
      unawaited(_startSmsListener());
    }
  }

  Future<void> _savePending(PendingTransaction pending) async {
    // A listener may remain registered until the next restart. Respect a
    // later user choice to turn auto-detection off before saving anything.
    if (!ref.read(settingsProvider).smsAutoDetection) return;
    final settings = ref.read(settingsProvider);
    final pendingNotifier = ref.read(pendingProvider.notifier);
    final added = await pendingNotifier.add(pending);
    if (added &&
        settings.trustedAutoDetection &&
        pending.transaction.confidence >= .97) {
      await pendingNotifier.confirm(pending.id);
      ref.read(currentMonthProvider.notifier).state = DateTime(
          pending.transaction.dateTime.year, pending.transaction.dateTime.month);
      return;
    }
    if (added) await NotificationService.instance.transactionDetected(pending);
  }

  Future<void> _syncNewDetections() async {
    if (_syncingInbox || !ref.read(settingsProvider).smsAutoDetection) return;
    _syncingInbox = true;
    try {
      // The inbox is only a reliability fallback. SMSListener filters it with
      // the activation timestamp, so messages from before permission was
      // granted can never be added here.
      await _smsListener.scanRecentInbox(_savePending);
      if (ref.read(settingsProvider).businessChatDetection) {
        await _smsListener.scanBusinessNotifications(_savePending);
      }
    } finally {
      if (mounted) _syncingInbox = false;
    }
  }

  @override
  void dispose() {
    _businessNotificationTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Trackr',
      themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      darkTheme: AppTheme.dark,
      theme: AppTheme.light,
      home: const TrackrShell(),
    );
  }
}

class TrackrShell extends StatefulWidget {
  const TrackrShell({super.key});

  @override
  State<TrackrShell> createState() => _TrackrShellState();
}

class _TrackrShellState extends State<TrackrShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.reviewRequest.addListener(_openPendingReview);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingReview());
  }

  @override
  void dispose() {
    NotificationService.instance.reviewRequest
        .removeListener(_openPendingReview);
    super.dispose();
  }

  void _openPendingReview() {
    if (!mounted || NotificationService.instance.reviewRequest.value == null) {
      return;
    }
    NotificationService.instance.reviewRequest.value = null;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const PendingScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
          onOpenPending: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const PendingScreen()))),
      const TransactionsScreen(),
      const BudgetScreen(),
      const AnalyticsScreen(),
      const MoreScreen(),
    ];
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: screens[_index],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Transactions'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Budgets'),
          NavigationDestination(
              icon: Icon(Icons.query_stats_outlined),
              selectedIcon: Icon(Icons.query_stats),
              label: 'Analytics'),
          NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              selectedIcon: Icon(Icons.grid_view),
              label: 'More'),
        ],
      ),
    );
  }
}
