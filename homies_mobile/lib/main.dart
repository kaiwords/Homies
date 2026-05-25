import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'firebase_options.dart';
import 'router.dart';
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
}

class HomiesApp extends StatefulWidget {
  final HomiesState state;
  const HomiesApp({super.key, required this.state});

  @override
  State<HomiesApp> createState() => _HomiesAppState();
}

class _HomiesAppState extends State<HomiesApp> {
  late final _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    return HomiesScope(
      state: widget.state,
      child: MaterialApp.router(
        title: 'homies',
        debugShowCheckedModeBanner: false,
        theme: buildHomiesTheme(),
        routerConfig: _router,
      ),
    );
  }
}
