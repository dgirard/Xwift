import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../core/database/database_provider.dart';
import '../core/theme/app_colors.dart';
import '../features/bluetooth/ble_provider.dart';
import '../features/ftms/ftms_provider.dart';
import '../features/heart_rate/hr_monitor_provider.dart';
import '../models/bike_telemetry.dart';
import '../models/ride_session.dart';
import '../widgets/power_display.dart';
import '../widgets/metric_tile.dart';
import '../widgets/grade_selector.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  RideMode _currentMode = RideMode.sim;
  double _currentGrade = 0.0; // Pente en pourcentage (-10% à +10%)
  double _resistanceLevel = 50;
  bool _isRiding = false;      // En train de pédaler (timer actif)
  bool _rideStarted = false;   // Sortie démarrée (même si en pause)

  // Timer for elapsed time
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;

  // Ride session tracking
  String? _rideId;
  DateTime? _rideStartTime;
  final List<TelemetrySample> _rideSamples = [];
  Timer? _sampleTimer;

  @override
  void initState() {
    super.initState();
    // Request control when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(ftmsControlProvider.notifier).requestControl();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sampleTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _startTimer() {
    _stopwatch.reset();
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsedTime = _stopwatch.elapsed;
      });
    });
  }

  void _stopTimer() {
    _stopwatch.stop();
    _timer?.cancel();
    _timer = null;
  }

  void _resetTimer() {
    _stopwatch.reset();
    setState(() {
      _elapsedTime = Duration.zero;
    });
  }

  String _formatElapsedTime(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(bleConnectionProvider);
    final ftmsState = ref.watch(ftmsControlProvider);
    final telemetry = ref.watch(currentTelemetryProvider);
    final hrConnection = ref.watch(hrConnectionProvider);

    // Get power zone based on default FTP (should come from settings)
    const ftp = 200;
    final powerZone = telemetry.getPowerZone(ftp);

    // Use external HR monitor if connected, otherwise fall back to FTMS telemetry
    final heartRate = hrConnection.isConnected
        ? hrConnection.currentHeartRate
        : telemetry.heartRate;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.bluetooth_connected),
          color: connectionState.isConnected ? AppColors.success : AppColors.error,
          onPressed: () => context.go('/connect'),
        ),
        title: Text(connectionState.connectedDevice?.name ?? 'Non connecte'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Reconnect
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Mode toggle + Timer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Mode toggle
                  Expanded(
                    child: _ModeToggle(
                      currentMode: _currentMode,
                      onModeChanged: (mode) {
                        setState(() => _currentMode = mode);
                        if (mode == RideMode.erg) {
                          context.push('/ride/erg');
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Elapsed time display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _isRiding ? AppColors.primary.withOpacity(0.2) : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isRiding ? AppColors.primary : AppColors.surfaceBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isRiding ? Icons.timer : Icons.timer_outlined,
                          size: 20,
                          color: _isRiding ? AppColors.primary : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatElapsedTime(_elapsedTime),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                color: _isRiding ? AppColors.primary : AppColors.textPrimary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Power display
            Expanded(
              flex: 3,
              child: PowerDisplay(
                watts: telemetry.instantPower ?? 0,
                zone: powerZone,
                ftp: ftp,
              ),
            ),

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
                      value: '${telemetry.instantSpeed?.toStringAsFixed(1) ?? '0.0'}',
                      unit: 'km/h',
                      icon: Icons.speed,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.push('/hr-monitor'),
                      child: MetricTile(
                        value: heartRate != null ? '$heartRate' : '--',
                        unit: 'BPM',
                        icon: hrConnection.isConnected ? Icons.watch : Icons.favorite,
                        valueColor: heartRate != null ? AppColors.error : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Grade control section
            if (_currentMode == RideMode.sim) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.terrain, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Pente simulee',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              GradeSelector(
                currentGrade: _currentGrade,
                onGradeChanged: _onGradeChanged,
              ),
              const SizedBox(height: 24),

              // Resistance slider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.trending_up, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Resistance',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const Spacer(),
                    Text(
                      '${_resistanceLevel.round()}%',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.primary,
                          ),
                    ),
                  ],
                ),
              ),
              Slider(
                value: _resistanceLevel,
                min: 0,
                max: 100,
                onChanged: (value) {
                  setState(() => _resistanceLevel = value);
                },
                onChangeEnd: (value) {
                  ref.read(ftmsControlProvider.notifier).setResistance(value);
                },
              ),
            ],

            const Spacer(),

            // Control buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isRiding
                          ? () {
                              // Pause - UI d'abord, FTMS en arrière-plan
                              _stopTimer();
                              setState(() => _isRiding = false);
                              ref.read(ftmsControlProvider.notifier).pause();
                            }
                          : (_elapsedTime > Duration.zero && !_isRiding)
                              ? () {
                                  // Reprendre - UI d'abord, FTMS en arrière-plan
                                  _stopwatch.start();
                                  _timer = Timer.periodic(const Duration(seconds: 1), (_) {
                                    setState(() {
                                      _elapsedTime = _stopwatch.elapsed;
                                    });
                                  });
                                  setState(() => _isRiding = true);
                                  ref.read(ftmsControlProvider.notifier).start();
                                }
                              : null,
                      icon: Icon(_isRiding ? Icons.pause : Icons.play_arrow),
                      label: Text(_isRiding ? 'Pause' : 'Reprendre'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (_rideStarted) {
                          await _endRide();
                        } else {
                          await _startRide();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _rideStarted ? AppColors.error : AppColors.primary,
                      ),
                      icon: Icon(_rideStarted ? Icons.stop : Icons.play_arrow),
                      label: Text(_rideStarted ? 'Arreter' : 'Demarrer'),
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

  Future<void> _startRide() async {
    // Initialize ride tracking
    _rideId = const Uuid().v4();
    _rideStartTime = DateTime.now();
    _rideSamples.clear();

    // Toujours démarrer le timer et l'UI, même sans vélo connecté
    setState(() {
      _isRiding = true;
      _rideStarted = true;
    });
    _startTimer();

    // Start collecting telemetry samples every second
    _sampleTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _collectSample();
    });

    // Tenter d'envoyer la commande FTMS (peut échouer si pas de vélo)
    await ref.read(ftmsControlProvider.notifier).start();

    // Appliquer les paramètres initiaux si en mode SIM
    if (_currentMode == RideMode.sim) {
      await ref.read(ftmsControlProvider.notifier).setGrade(_currentGrade);
    }
  }

  void _collectSample() {
    if (!_isRiding) return;

    final telemetry = ref.read(currentTelemetryProvider);
    final hrConnection = ref.read(hrConnectionProvider);

    // Use external HR monitor if connected, otherwise fall back to FTMS telemetry
    final heartRate = hrConnection.isConnected
        ? hrConnection.currentHeartRate
        : telemetry.heartRate;

    final sample = TelemetrySample(
      timestamp: DateTime.now(),
      power: telemetry.instantPower,
      cadence: telemetry.instantCadence?.round(),
      speed: telemetry.instantSpeed,
      heartRate: heartRate,
      distance: telemetry.totalDistance,
      calories: telemetry.totalEnergy,
    );

    _rideSamples.add(sample);
  }

  Future<void> _endRide() async {
    // UI d'abord, FTMS en arrière-plan
    _stopTimer();
    _sampleTimer?.cancel();
    _sampleTimer = null;
    setState(() => _isRiding = false);
    ref.read(ftmsControlProvider.notifier).stop();

    final duration = _elapsedTime;
    final endTime = DateTime.now();

    // Create ride session
    final session = RideSession(
      id: _rideId ?? const Uuid().v4(),
      startTime: _rideStartTime ?? DateTime.now().subtract(duration),
      endTime: endTime,
      mode: _currentMode,
      samples: List.from(_rideSamples),
      state: RideState.completed,
      targetGrade: _currentMode == RideMode.sim ? _currentGrade : null,
      resistanceLevel: _resistanceLevel,
    );

    // Show end ride dialog
    if (mounted) {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Sortie terminee'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.timer, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Duree: ${_formatElapsedTime(duration)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (session.averagePower != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.flash_on, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Puissance moy: ${session.averagePower} W',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              const Text('Voulez-vous sauvegarder cette session ?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Supprimer'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sauvegarder'),
            ),
          ],
        ),
      );

      if (result == true && mounted) {
        // Save ride to database
        await ref.read(rideRepositoryProvider).saveRide(session);
        // Invalidate ride history to refresh
        ref.invalidate(rideHistoryProvider);
        ref.invalidate(rideStatsProvider);

        if (mounted) {
          context.push('/settings/export');
        }
      }

      // Reset pour la prochaine sortie
      _resetTimer();
      _rideSamples.clear();
      _rideId = null;
      _rideStartTime = null;
      setState(() => _rideStarted = false);
    }
  }

  void _onGradeChanged(double grade) {
    setState(() => _currentGrade = grade);
    ref.read(ftmsControlProvider.notifier).setGrade(grade);
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.currentMode,
    required this.onModeChanged,
  });

  final RideMode currentMode;
  final ValueChanged<RideMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              label: 'SIM Mode',
              isSelected: currentMode == RideMode.sim,
              onTap: () => onModeChanged(RideMode.sim),
            ),
          ),
          Expanded(
            child: _ModeButton(
              label: 'ERG Mode',
              isSelected: currentMode == RideMode.erg,
              onTap: () => onModeChanged(RideMode.erg),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
          ),
        ),
      ),
    );
  }
}
