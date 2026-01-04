import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../screens/welcome_screen.dart';
import '../../screens/device_connection_screen.dart';
import '../../screens/dashboard_screen.dart';
import '../../screens/erg_mode_screen.dart';
import '../../screens/profile_screen.dart';
import '../../screens/export_screen.dart';
import '../../screens/workouts_screen.dart';
import '../../screens/hr_monitor_screen.dart';

/// App router configuration
final appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: '/',
      name: 'welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/connect',
      name: 'connect',
      builder: (context, state) => const DeviceConnectionScreen(),
    ),
    GoRoute(
      path: '/ride',
      name: 'ride',
      builder: (context, state) => const DashboardScreen(),
      routes: [
        GoRoute(
          path: 'erg',
          name: 'erg',
          builder: (context, state) => const ErgModeScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/profile',
      name: 'profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/workouts',
      name: 'workouts',
      builder: (context, state) => const WorkoutsScreen(),
    ),
    GoRoute(
      path: '/settings/export',
      name: 'export',
      builder: (context, state) => const ExportScreen(),
    ),
    GoRoute(
      path: '/hr-monitor',
      name: 'hr-monitor',
      builder: (context, state) => const HrMonitorScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.uri}'),
    ),
  ),
);
