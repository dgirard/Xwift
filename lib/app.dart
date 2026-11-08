import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/ride/ride_session_provider.dart';

class XwiftApp extends ConsumerStatefulWidget {
  const XwiftApp({super.key});

  @override
  ConsumerState<XwiftApp> createState() => _XwiftAppState();
}

class _XwiftAppState extends ConsumerState<XwiftApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The system may kill the app once in the background: save the ride now.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(rideSessionProvider.notifier).checkpointNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Xwift',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
