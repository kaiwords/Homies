import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
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
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  Intl.defaultLocale = 'en_AU';
  await initializeDateFormatting('en_AU', null);
  final state = HomiesState();
  await state.load();
  runApp(HomiesApp(state: state));

  // NotificationService.init() triggers the native "Allow Notifications?"
  // permission prompt and awaits its result — that await can hang forever on
  // a real device if it's requested before the app's UI exists, permanently
  // blocking the first frame. Run it after runApp() instead, so a stalled
  // permission prompt can never stop the app from rendering.
  unawaited(NotificationService.init().then((_) => NotificationService.scheduleFromState(state)));
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
