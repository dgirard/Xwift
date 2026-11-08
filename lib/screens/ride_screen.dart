import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../features/bluetooth/ble_provider.dart';
import '../features/control/trainer_control_provider.dart';
import '../features/ride/ride_session_provider.dart';
import '../widgets/ride/control_panel.dart';
import '../widgets/ride/live_data_panel.dart';
import '../widgets/ride/ride_action_bar.dart';
import '../widgets/ride/ride_format.dart';
import '../widgets/ride/trainer_status.dart';

/// The single riding screen: live data, effort setting and recording.
/// Works without a trainer; the trainer status at the top connects it.
class RideScreen extends ConsumerStatefulWidget {
  const RideScreen({super.key});

  @override
  ConsumerState<RideScreen> createState() => _RideScreenState();
}

class _RideScreenState extends ConsumerState<RideScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Settings are delivered as soon as a trainer is ready.
      ref.read(trainerControlProvider);
      ref.read(bleConnectionProvider.notifier).autoConnect();
    });
  }

  void _goHome() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideActive = ref.watch(rideSessionProvider.select((s) => s.isActive));
    final router = GoRouter.of(context);

    return PopScope(
      // Leaving is fine (the ride keeps recording), closing the app is not.
      canPop: !rideActive || router.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sortie en cours : touchez Pause puis Terminer pour l\'enregistrer.',
            ),
          ),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Accueil',
            icon: const Icon(Icons.home_outlined),
            onPressed: _goHome,
          ),
          titleSpacing: 0,
          centerTitle: false,
          title: const Align(
            alignment: Alignment.centerLeft,
            child: TrainerStatusPill(),
          ),
          actions: [
            IconButton(
              tooltip: 'Mes sorties',
              icon: const Icon(Icons.history),
              onPressed: () => context.push('/settings/export'),
            ),
            IconButton(
              tooltip: 'Profil et réglages',
              icon: const Icon(Icons.person_outline),
              onPressed: () => context.push('/profile'),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 660;
              return Column(
                children: [
                  const _RideClock(),
                  const Expanded(child: LiveDataPanel()),
                  ControlPanel(compact: compact),
                  const RideActionBar(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RideClock extends ConsumerWidget {
  const _RideClock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ride = ref.watch(rideSessionProvider);
    final (String label, Color color) = switch (ride.status) {
      RideStatus.idle => ('PRÊT', AppColors.textTertiary),
      RideStatus.recording => ('ENREGISTREMENT', AppColors.error),
      RideStatus.paused => ('EN PAUSE', AppColors.warning),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatClock(ride.elapsed),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: ride.isPaused ? AppColors.warning : AppColors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Expanded(
            child: Text(
              ride.isActive ? formatDistance(ride.distance) : '',
              textAlign: TextAlign.end,
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
