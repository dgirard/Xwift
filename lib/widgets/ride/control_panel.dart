import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../features/control/trainer_control_provider.dart';
import '../../features/ftms/ftms_provider.dart';
import '../../features/ride/ride_session_provider.dart';
import '../../features/settings/user_settings_provider.dart';
import 'big_stepper.dart';
import 'program_sheet.dart';
import 'ride_format.dart';
import 'trainer_status.dart';

/// Sets the effort: one mode at a time, one main control, quick presets and
/// an explicit confirmation of what the trainer applied.
class ControlPanel extends ConsumerWidget {
  const ControlPanel({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final control = ref.watch(trainerControlProvider);
    // One short line, kept on small screens: it says what the mode does.
    final hint = switch (control.mode) {
      ControlMode.grade => 'Simule une route : plus ça monte, plus c\'est dur.',
      ControlMode.power when control.program != null =>
        'Le programme règle la puissance pour vous.',
      ControlMode.power => 'Le home trainer impose cette puissance.',
      ControlMode.resistance => 'Frein fixe : l\'effort suit votre cadence.',
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: EdgeInsets.fromLTRB(12, 12, 12, compact ? 8 : 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeSelector(
            mode: control.mode,
            onChanged: (mode) => _changeMode(context, ref, mode),
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            hint,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          SizedBox(height: compact ? 6 : 12),
          switch (control.mode) {
            ControlMode.grade => _GradeControls(compact: compact),
            ControlMode.power => control.program != null
                ? _ProgramControls(compact: compact)
                : _PowerControls(compact: compact),
            ControlMode.resistance => _ResistanceControls(compact: compact),
          },
          SizedBox(height: compact ? 6 : 10),
          const _StatusLine(),
        ],
      ),
    );
  }

  Future<void> _changeMode(
    BuildContext context,
    WidgetRef ref,
    ControlMode mode,
  ) async {
    final control = ref.read(trainerControlProvider);
    if (control.program != null && mode != ControlMode.power) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Arrêter le programme ?'),
          content: Text(
            'Le programme « ${control.program!.plan.name} » ne s\'applique '
            'qu\'en mode Puissance.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continuer le programme'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Arrêter'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    ref.read(trainerControlProvider.notifier).setMode(mode);
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.mode, required this.onChanged});

  final ControlMode mode;
  final ValueChanged<ControlMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<ControlMode>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          backgroundColor: AppColors.surfaceLight,
          foregroundColor: AppColors.textSecondary,
          selectedBackgroundColor: AppColors.primary,
          selectedForegroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.surfaceBorder),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: Theme.of(context).textTheme.titleSmall,
        ),
        segments: [
          for (final (value, label) in const [
            (ControlMode.grade, 'Pente'),
            (ControlMode.power, 'Puissance'),
            (ControlMode.resistance, 'Résistance'),
          ])
            ButtonSegment(
              value: value,
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, maxLines: 1, softWrap: false),
              ),
            ),
        ],
        selected: {mode},
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}

bool _pending(ApplyStatus status) =>
    status == ApplyStatus.sending || status == ApplyStatus.waitingTrainer;

class _GradeControls extends ConsumerWidget {
  const _GradeControls({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final control = ref.watch(trainerControlProvider);
    final notifier = ref.read(trainerControlProvider.notifier);
    final grade = control.grade;
    Preset preset(String title, double value) => Preset(
          title: title,
          value: '${formatGrade(value)} %',
          selected: grade == value,
          onTap: () => notifier.setGrade(value),
        );
    return Column(
      children: [
        BigStepper(
          semanticName: 'Pente',
          value: formatGrade(grade),
          unit: '%',
          caption: gradeLabel(grade),
          decreaseLabel: '−0,5 %',
          increaseLabel: '+0,5 %',
          dimmed: _pending(control.status),
          compact: compact,
          onDecrease: grade > TrainerControlNotifier.minGrade
              ? () => notifier.changeGrade(-1)
              : null,
          onIncrease: grade < TrainerControlNotifier.maxGrade
              ? () => notifier.changeGrade(1)
              : null,
        ),
        SizedBox(height: compact ? 8 : 10),
        PresetRow(presets: [
          preset('Plat', 0),
          preset('Faux-plat', 2),
          preset('Côte', 5),
          preset('Col', 8),
        ]),
      ],
    );
  }
}

class _PowerControls extends ConsumerWidget {
  const _PowerControls({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final control = ref.watch(trainerControlProvider);
    final notifier = ref.read(trainerControlProvider.notifier);
    final ftp = ref.watch(userSettingsProvider).valueOrNull?.ftp ?? 200;
    final target = control.targetPower;
    final limits = notifier.powerLimits;
    int watts(double ratio) => (ftp * ratio / 5).round() * 5;
    Preset preset(String title, double ratio) {
      final value = watts(ratio);
      return Preset(
        title: title,
        value: '$value W',
        selected: target == value,
        onTap: () => notifier.setPower(value),
      );
    }

    return Column(
      children: [
        BigStepper(
          semanticName: 'Puissance cible',
          value: '$target',
          unit: 'W',
          caption: '${(target / ftp * 100).round()} % · FTP $ftp W',
          onCaptionTap: () => editFtp(context, ref),
          decreaseLabel: '−10 W',
          increaseLabel: '+10 W',
          dimmed: _pending(control.status),
          compact: compact,
          onDecrease:
              target > limits.min ? () => notifier.changePower(-1) : null,
          onIncrease:
              target < limits.max ? () => notifier.changePower(1) : null,
        ),
        SizedBox(height: compact ? 8 : 10),
        PresetRow(presets: [
          preset('Récup', 0.55),
          preset('Endurance', 0.70),
          preset('Tempo', 0.85),
          preset('Seuil', 1.00),
        ]),
        const SizedBox(height: 4),
        SizedBox(
          height: 36,
          child: TextButton.icon(
            onPressed: () => showProgramSheet(context),
            icon: const Icon(Icons.list_alt, size: 18),
            label: const Text('Suivre un programme'),
          ),
        ),
      ],
    );
  }
}

class _ProgramControls extends ConsumerWidget {
  const _ProgramControls({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final control = ref.watch(trainerControlProvider);
    final notifier = ref.read(trainerControlProvider.notifier);
    final program = control.program!;
    final next = program.nextInterval;
    final intervals = program.plan.intervals;

    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.list_alt, size: 18, color: AppColors.primaryLight),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${program.plan.name} · ${program.index + 1}/${intervals.length} '
                '${program.interval.name ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
            ),
            SizedBox(
              height: 32,
              child: TextButton.icon(
                onPressed: () => _confirmQuit(context, ref),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Quitter'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _IntervalBar(program: program),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              'Reste ${formatClock(program.remainingInInterval)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                next == null
                    ? 'Dernier intervalle'
                    : 'Ensuite ${program.targetFor(next) > 0 ? '${program.targetFor(next)} W' : 'roue libre'} '
                        '· ${formatMinutes(next.duration)}',
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (next != null)
              SizedBox(
                height: 32,
                child: TextButton.icon(
                  onPressed: notifier.skipInterval,
                  icon: const Icon(Icons.skip_next, size: 18),
                  label: const Text('Passer'),
                ),
              ),
          ],
        ),
        SizedBox(height: compact ? 6 : 10),
        BigStepper(
          semanticName: 'Intensité du programme',
          value: '${program.intensity}',
          unit: '%',
          caption: program.target > 0
              ? 'Intensité · cible ${program.target} W'
              : 'Intensité · roue libre',
          decreaseLabel: '−5 %',
          increaseLabel: '+5 %',
          dimmed: _pending(control.status),
          compact: compact,
          onDecrease: program.intensity > 50
              ? () => notifier.changeIntensity(-1)
              : null,
          onIncrease: program.intensity < 150
              ? () => notifier.changeIntensity(1)
              : null,
        ),
        if (!ref.watch(rideSessionProvider.select((s) => s.isRecording))) ...[
          const SizedBox(height: 6),
          Text(
            'Le programme avance pendant l\'enregistrement de la sortie.',
            style:
                theme.textTheme.bodySmall?.copyWith(color: AppColors.warning),
          ),
        ],
      ],
    );
  }
}

Future<void> _confirmQuit(BuildContext context, WidgetRef ref) async {
  final program = ref.read(trainerControlProvider).program;
  if (program == null) return;
  final keep =
      program.target > 0 ? '${program.target} W' : 'la puissance actuelle';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Quitter le programme ?'),
      content: Text(
        '« ${program.plan.name} » s\'arrête. La sortie continue en mode '
        'Puissance à $keep.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Continuer le programme'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Quitter'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    ref.read(trainerControlProvider.notifier).stopProgram();
  }
}

/// Lets the rider fix the FTP used for zones and presets, without leaving.
Future<void> editFtp(BuildContext context, WidgetRef ref) async {
  final current = ref.read(userSettingsProvider).valueOrNull?.ftp ?? 200;
  final controller = TextEditingController(text: '$current');
  final value = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Votre FTP'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(suffixText: 'W'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(ctx, int.tryParse(controller.text.trim())),
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (value != null && value >= 50 && value <= 600) {
    await ref.read(userSettingsProvider.notifier).updateFtp(value);
  }
}

class _IntervalBar extends StatelessWidget {
  const _IntervalBar({required this.program});

  final WorkoutProgram program;

  @override
  Widget build(BuildContext context) {
    final intervals = program.plan.intervals;
    final maxPower = intervals
        .map((i) => i.targetPower)
        .fold<int>(1, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < intervals.length; i++)
            Expanded(
              flex: intervals[i].duration.inSeconds.clamp(1, 1 << 30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0.5),
                child: _IntervalBlock(
                  heightFactor: (intervals[i].targetPower / maxPower)
                      .clamp(0.15, 1.0)
                      .toDouble(),
                  state: i < program.index
                      ? _BlockState.done
                      : i == program.index
                          ? _BlockState.current
                          : _BlockState.next,
                  progress: i == program.index ? program.intervalProgress : 0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _BlockState { done, current, next }

class _IntervalBlock extends StatelessWidget {
  const _IntervalBlock({
    required this.heightFactor,
    required this.state,
    required this.progress,
  });

  final double heightFactor;
  final _BlockState state;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final base = switch (state) {
      _BlockState.done => AppColors.primary.withValues(alpha: 0.45),
      _BlockState.current => AppColors.primary.withValues(alpha: 0.35),
      _BlockState.next => AppColors.surfaceLight,
    };
    return FractionallySizedBox(
      heightFactor: heightFactor,
      alignment: Alignment.bottomCenter,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: base),
            if (state == _BlockState.current)
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: const ColoredBox(color: AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResistanceControls extends ConsumerWidget {
  const _ResistanceControls({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final control = ref.watch(trainerControlProvider);
    // Rebuild when the trainer publishes its range.
    ref.watch(ftmsControlProvider.select((s) => s.resistanceRange));
    final notifier = ref.read(trainerControlProvider.notifier);
    final scale = notifier.resistanceScale;
    final level = notifier.resistanceLevel;

    return Column(
      children: [
        BigStepper(
          semanticName: 'Résistance',
          value: formatDecimal(level),
          caption:
              'Niveau, de ${formatDecimal(scale.min)} à ${formatDecimal(scale.max)}',
          decreaseLabel: '−${formatDecimal(scale.step)}',
          increaseLabel: '+${formatDecimal(scale.step)}',
          dimmed: _pending(control.status),
          compact: compact,
          onDecrease:
              level > scale.min ? () => notifier.changeResistance(-1) : null,
          onIncrease:
              level < scale.max ? () => notifier.changeResistance(1) : null,
        ),
        SizedBox(height: compact ? 10 : 14),
        Row(
          children: [
            Text('Facile', style: theme.textTheme.labelSmall),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: scale.fraction(level),
                  minHeight: 10,
                  backgroundColor: AppColors.surfaceLight,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('Dur', style: theme.textTheme.labelSmall),
          ],
        ),
        SizedBox(height: compact ? 10 : 14),
      ],
    );
  }
}

/// Plain-language confirmation of the last command, with a fix when needed.
class _StatusLine extends ConsumerWidget {
  const _StatusLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final control = ref.watch(trainerControlProvider);
    final link = ref.watch(trainerLinkProvider).link;
    final notifier = ref.read(trainerControlProvider.notifier);

    final (
      IconData icon,
      Color color,
      String text,
      String? action,
      VoidCallback? onAction
    ) = switch (control.status) {
      _ when link != TrainerLink.connected => (
          Icons.bluetooth_disabled,
          AppColors.textSecondary,
          link == TrainerLink.offline ||
                  link == TrainerLink.none ||
                  link == TrainerLink.failed
              ? 'Réglage prêt : il sera envoyé à la connexion du home trainer.'
              : 'Réglage prêt : envoi dès que le home trainer est connecté.',
          link == TrainerLink.offline ||
                  link == TrainerLink.none ||
                  link == TrainerLink.failed
              ? 'Connecter'
              : null,
          () => onTrainerTap(context, ref),
        ),
      ApplyStatus.idle || ApplyStatus.waitingTrainer => (
          Icons.hourglass_empty,
          AppColors.textSecondary,
          'En attente du home trainer…',
          null,
          null,
        ),
      ApplyStatus.sending => (
          Icons.sync,
          AppColors.textSecondary,
          'Envoi au home trainer…',
          null,
          null,
        ),
      ApplyStatus.applied => (
          Icons.check_circle,
          AppColors.success,
          control.programFinished && control.mode == ControlMode.power
              ? 'Programme terminé · puissance maintenue'
              : 'Appliqué par le home trainer',
          null,
          null,
        ),
      ApplyStatus.noControl => (
          Icons.warning_amber,
          AppColors.warning,
          'Le home trainer refuse le contrôle (Zwift ou une autre app est-elle connectée ?)',
          'Réessayer',
          notifier.retry,
        ),
      ApplyStatus.notSupported => (
          Icons.block,
          AppColors.warning,
          'Ce home trainer ne gère pas ce mode.',
          null,
          null,
        ),
      ApplyStatus.rejected => (
          Icons.warning_amber,
          AppColors.warning,
          'Valeur refusée par le home trainer.',
          'Réessayer',
          notifier.retry,
        ),
      ApplyStatus.noResponse => (
          Icons.warning_amber,
          AppColors.warning,
          'Pas de réponse du home trainer.',
          'Réessayer',
          notifier.retry,
        ),
    };

    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
          if (action != null)
            SizedBox(
              height: 32,
              child: TextButton(onPressed: onAction, child: Text(action)),
            ),
        ],
      ),
    );
  }
}

/// Opens the program picker (built-in and imported workouts).
void showProgramSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (_) => const ProgramSheet(),
  );
}
