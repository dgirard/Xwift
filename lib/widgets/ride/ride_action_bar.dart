import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../features/ride/ride_session_provider.dart';
import 'ride_format.dart';

/// Recording controls. One obvious action at a time: start, then pause; once
/// paused, resume or finish (finishing needs a pause first, so a stray tap
/// while riding cannot end the ride).
class RideActionBar extends ConsumerWidget {
  const RideActionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(rideSessionProvider.select((s) => s.status));
    final notifier = ref.read(rideSessionProvider.notifier);
    const height = 56.0;

    final Widget child = switch (status) {
      RideStatus.idle => ElevatedButton.icon(
          onPressed: notifier.start,
          style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(height)),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Démarrer la sortie'),
        ),
      RideStatus.recording => OutlinedButton.icon(
          onPressed: notifier.pause,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(height),
            side: const BorderSide(color: AppColors.textSecondary),
          ),
          icon: const Icon(Icons.pause),
          label: const Text('Pause'),
        ),
      RideStatus.paused => Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => finishRide(context, ref),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(height),
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
                icon: const Icon(Icons.stop),
                label: const Text('Terminer'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: notifier.resume,
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(height)),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Reprendre'),
              ),
            ),
          ],
        ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: child,
    );
  }
}

/// Ends the ride: name it and save it, or delete it.
Future<void> finishRide(BuildContext context, WidgetRef ref) async {
  final notifier = ref.read(rideSessionProvider.notifier);
  final ride = ref.read(rideSessionProvider);
  final session = notifier.buildSession();
  final defaultName = session.workout?.name ??
      'Sortie du ${DateFormat('dd/MM').format(ride.startTime ?? DateTime.now())}';

  final result = await showDialog<_EndChoice>(
    context: context,
    builder: (_) => _EndRideDialog(
      defaultName: defaultName,
      elapsed: ride.elapsed,
      distance: ride.distance,
      averagePower: session.averagePower,
    ),
  );
  if (result == null || !context.mounted) return;

  if (result.delete) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la sortie ?'),
        content: const Text(
            'Elle ne sera pas enregistrée. Cette action est définitive.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) await notifier.discard();
    return;
  }

  await notifier
      .save(result.name.trim().isEmpty ? defaultName : result.name.trim());
  if (context.mounted) context.push('/settings/export');
}

class _EndChoice {
  const _EndChoice.save(this.name) : delete = false;
  const _EndChoice.delete()
      : name = '',
        delete = true;

  final String name;
  final bool delete;
}

class _EndRideDialog extends StatefulWidget {
  const _EndRideDialog({
    required this.defaultName,
    required this.elapsed,
    required this.distance,
    required this.averagePower,
  });

  final String defaultName;
  final Duration elapsed;
  final int distance;
  final int? averagePower;

  @override
  State<_EndRideDialog> createState() => _EndRideDialogState();
}

class _EndRideDialogState extends State<_EndRideDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.defaultName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget stat(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(text, style: theme.textTheme.bodyMedium),
            ],
          ),
        );

    return AlertDialog(
      title: const Text('Terminer la sortie'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nom de la sortie'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            stat(
                Icons.timer_outlined, 'Durée : ${formatClock(widget.elapsed)}'),
            if (widget.distance > 0)
              stat(Icons.straighten,
                  'Distance : ${formatDistance(widget.distance)}'),
            if (widget.averagePower != null)
              stat(Icons.bolt, 'Puissance moyenne : ${widget.averagePower} W'),
          ],
        ),
      ),
      actionsOverflowButtonSpacing: 4,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, const _EndChoice.delete()),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Supprimer'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _EndChoice.save(_name.text)),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
