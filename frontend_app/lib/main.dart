import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'firebase_options.dart';
import 'router.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'en_AU';
  await initializeDateFormatting('en_AU', null);

  // iOS kills the app if it takes too long between launch and the first
  // rendered frame (the launch watchdog) — a real-device-only limit that a
  // debug/emulator run never hits. Firebase.initializeApp() and state.load()
  // can each stall for many seconds on a slow/absent connection, and awaiting
  // them here before runApp() risks tripping that watchdog: the app never
  // gets a chance to draw anything and iOS just kills it, indistinguishable
  // from a permanent black screen with no crash log. Every HomiesState field
  // has a safe default (seed data / empty lists), so call runApp()
  // immediately and let Firebase/state loading finish in the background;
  // state.load() and the Firebase auth listener both call notifyListeners()
  // when data arrives, so the UI updates itself once ready.
  final state = HomiesState();
  runApp(HomiesApp(state: state));

  unawaited(_initFirebaseAndLoadState(state));

  // NotificationService.init() triggers the native "Allow Notifications?"
  // permission prompt and awaits its result — that await can hang forever on
  // a real device if it's requested before the app's UI exists, permanently
  // blocking the first frame. Run it after runApp() instead, so a stalled
  // permission prompt can never stop the app from rendering.
  unawaited(NotificationService.init().then((_) => NotificationService.scheduleFromState(state)));
}

Future<void> _initFirebaseAndLoadState(HomiesState state) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 15));
  } catch (e) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('Firebase.initializeApp failed or timed out: $e');
    }
  }

  try {
    await state.load().timeout(const Duration(seconds: 10));
  } catch (e) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('state.load() failed or timed out: $e');
    }
  }
}

class HomiesApp extends StatefulWidget {
  final HomiesState state;
  const HomiesApp({super.key, required this.state});

  @override
  State<HomiesApp> createState() => _HomiesAppState();
}

class _HomiesAppState extends State<HomiesApp> {
  late final _router = buildRouter(widget.state);
  late bool _isDark = widget.state.notifPrefs.darkMode;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    super.dispose();
  }

  // HomiesState.notifyListeners() fires on every mutation app-wide (chat,
  // chores, bills, etc.), not just theme changes. Only rebuild MaterialApp
  // (which HomiesScope's own InheritedNotifier doesn't cover) when the
  // dark-mode flag actually flips, instead of on every unrelated mutation.
  void _onStateChanged() {
    final isDark = widget.state.notifPrefs.darkMode;
    if (isDark != _isDark) setState(() => _isDark = isDark);
  }

  @override
  Widget build(BuildContext context) {
    return HomiesScope(
      state: widget.state,
      child: MaterialApp.router(
        title: 'homies',
        debugShowCheckedModeBanner: false,
        theme: buildHomiesTheme(),
        darkTheme: buildHomiesDarkTheme(),
        themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
        routerConfig: _router,
      ),
    );
  }
}
