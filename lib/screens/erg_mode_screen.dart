import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../features/ftms/ftms_provider.dart';
import '../models/workout_plan.dart';
import '../widgets/metric_tile.dart';

class ErgModeScreen extends ConsumerStatefulWidget {
  const ErgModeScreen({super.key});

  @override
  ConsumerState<ErgModeScreen> createState() => _ErgModeScreenState();
}

class _ErgModeScreenState extends ConsumerState<ErgModeScreen> {
  WorkoutPlan? _selectedWorkout;
  WorkoutState? _workoutState;
  Timer? _timer;
  int _targetPower = 150;
  int _biasPercent = 100;
  bool _isRunning = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = ref.watch(currentTelemetryProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Mode ERG'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth),
            color: AppColors.success,
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Workout selector
            if (_selectedWorkout != null) ...[
              _WorkoutHeader(
                workout: _selectedWorkout!,
                onChangeTap: _selectWorkout,
              ),
              const SizedBox(height: 16),
              // Interval progress bar
              _IntervalProgressBar(
                workout: _selectedWorkout!,
                currentIndex: _workoutState?.currentIntervalIndex ?? 0,
                progress: _workoutState?.intervalProgress ?? 0,
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _selectWorkout,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Choisir un entrainement'),
                ),
              ),
            ],

            const Spacer(),

            // Target power display
            Column(
              children: [
                Text(
                  '${_selectedWorkout != null ? _workoutState?.adjustedTargetPower ?? _targetPower : _targetPower}',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 80,
                      ),
                ),
                Text(
                  'W',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'CIBLE DE PUISSANCE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.success,
                          letterSpacing: 1.2,
                        ),
                  ),
                ),
                if (_selectedWorkout == null) ...[
                  const SizedBox(height: 16),
                  // Manual power adjustment
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() => _targetPower = (_targetPower - 10).clamp(50, 500));
                          _updateTargetPower();
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                        iconSize: 32,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        onPressed: () {
                          setState(() => _targetPower = (_targetPower + 10).clamp(50, 500));
                          _updateTargetPower();
                        },
                        icon: const Icon(Icons.add_circle_outline),
                        iconSize: 32,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ],
            ),

            const Spacer(),

            // Metrics row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      value: '${telemetry.instantCadence?.round() ?? 0}',
                      unit: 'RPM',
                      icon: Icons.rotate_right,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricTile(
                      value: '${telemetry.heartRate ?? '--'}',
                      unit: 'BPM',
                      icon: Icons.favorite,
                      valueColor:
                          telemetry.heartRate != null ? AppColors.error : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricTile(
                      value: _formatDuration(_workoutState?.remainingTotal ??
                          Duration.zero),
                      unit: 'RESTANT',
                      icon: Icons.timer,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Bias control
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() => _biasPercent = (_biasPercent - 5).clamp(80, 120));
                      _updateBias();
                    },
                    icon: const Icon(Icons.remove),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'BIAS $_biasPercent%',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => _biasPercent = (_biasPercent + 5).clamp(80, 120));
                      _updateBias();
                    },
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Control buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isRunning ? _stopWorkout : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Arreter'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isRunning ? null : _startWorkout,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Demarrer'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _selectWorkout() async {
    // Show workout selection dialog with sample workouts
    final workout = await showDialog<WorkoutPlan>(
      context: context,
      builder: (context) => _WorkoutSelectionDialog(),
    );

    if (workout != null) {
      setState(() {
        _selectedWorkout = workout;
        _workoutState = WorkoutState(
          plan: workout,
          currentIntervalIndex: 0,
          elapsed: Duration.zero,
          isRunning: false,
        );
      });
    }
  }

  void _startWorkout() async {
    await ref.read(ftmsControlProvider.notifier).start();
    _updateTargetPower();

    setState(() => _isRunning = true);

    // Start timer for workout progression
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_workoutState != null) {
        final newElapsed = _workoutState!.elapsed + const Duration(seconds: 1);
        final newIndex = _selectedWorkout!.getIntervalIndexAt(newElapsed);

        setState(() {
          _workoutState = _workoutState!.copyWith(
            elapsed: newElapsed,
            currentIntervalIndex: newIndex,
            isRunning: true,
          );
        });

        // Update target power if interval changed
        if (newIndex != _workoutState!.currentIntervalIndex) {
          _updateTargetPower();
        }

        // Check if workout complete
        if (_workoutState!.isComplete) {
          _stopWorkout();
        }
      }
    });
  }

  void _stopWorkout() async {
    _timer?.cancel();
    await ref.read(ftmsControlProvider.notifier).stop();
    setState(() => _isRunning = false);
  }

  void _updateTargetPower() {
    final power = _workoutState?.adjustedTargetPower ?? _targetPower;
    ref.read(ftmsControlProvider.notifier).setTargetPower(power);
  }

  void _updateBias() {
    if (_workoutState != null) {
      setState(() {
        _workoutState = _workoutState!.copyWith(biasPercent: _biasPercent);
      });
      _updateTargetPower();
    }
  }
}

class _WorkoutHeader extends StatelessWidget {
  const _WorkoutHeader({
    required this.workout,
    required this.onChangeTap,
  });

  final WorkoutPlan workout;
  final VoidCallback onChangeTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${workout.totalDuration.inMinutes} min',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onChangeTap,
            icon: const Icon(Icons.swap_horiz, size: 16),
            label: const Text('Changer'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntervalProgressBar extends StatelessWidget {
  const _IntervalProgressBar({
    required this.workout,
    required this.currentIndex,
    required this.progress,
  });

  final WorkoutPlan workout;
  final int currentIndex;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 60,
      child: Row(
        children: workout.intervals.asMap().entries.map((entry) {
          final index = entry.key;
          final interval = entry.value;
          final isActive = index == currentIndex;
          final isPast = index < currentIndex;

          return Expanded(
            flex: interval.duration.inSeconds,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: isPast
                    ? AppColors.primary
                    : isActive
                        ? AppColors.primary.withOpacity(0.5)
                        : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: isActive
                  ? FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    )
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _WorkoutSelectionDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Sample workouts
    final workouts = [
      WorkoutPlan(
        name: 'FTP Builder - Semaine 1',
        description: 'Entrainement FTP 45 min',
        intervals: [
          WorkoutInterval(
            duration: const Duration(minutes: 10),
            targetPower: 130,
            name: 'Warmup',
          ),
          WorkoutInterval(
            duration: const Duration(minutes: 5),
            targetPower: 200,
            name: 'Interval 1',
          ),
          WorkoutInterval(
            duration: const Duration(minutes: 3),
            targetPower: 120,
            name: 'Recovery',
          ),
          WorkoutInterval(
            duration: const Duration(minutes: 5),
            targetPower: 200,
            name: 'Interval 2',
          ),
          WorkoutInterval(
            duration: const Duration(minutes: 3),
            targetPower: 120,
            name: 'Recovery',
          ),
          WorkoutInterval(
            duration: const Duration(minutes: 5),
            targetPower: 200,
            name: 'Interval 3',
          ),
          WorkoutInterval(
            duration: const Duration(minutes: 10),
            targetPower: 100,
            name: 'Cooldown',
          ),
        ],
      ),
      WorkoutPlan(
        name: 'Endurance 1h',
        description: 'Zone 2 endurance ride',
        intervals: [
          WorkoutInterval(
            duration: const Duration(hours: 1),
            targetPower: 150,
            name: 'Endurance',
          ),
        ],
      ),
    ];

    return AlertDialog(
      title: const Text('Choisir un entrainement'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: workouts.length,
          itemBuilder: (context, index) {
            final workout = workouts[index];
            return ListTile(
              title: Text(workout.name),
              subtitle: Text('${workout.totalDuration.inMinutes} min'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, workout),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}
