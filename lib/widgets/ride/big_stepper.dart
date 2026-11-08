import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

/// The main control of the ride screen: a large value framed by two large
/// buttons, usable while pedaling. Holding a button repeats it.
class BigStepper extends StatelessWidget {
  const BigStepper({
    super.key,
    required this.value,
    required this.decreaseLabel,
    required this.increaseLabel,
    required this.onDecrease,
    required this.onIncrease,
    this.unit,
    this.caption,
    this.valueColor,
    this.dimmed = false,
    this.compact = false,
    this.semanticName,
    this.onCaptionTap,
  });

  final String value;
  final String? unit;
  final String? caption;
  final String decreaseLabel;
  final String increaseLabel;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final Color? valueColor;

  /// The value is not confirmed by the trainer yet.
  final bool dimmed;
  final bool compact;

  /// Name read by screen readers ("Pente", "Puissance cible"…).
  final String? semanticName;

  /// Makes the caption editable (shown with a pencil).
  final VoidCallback? onCaptionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = compact ? 64.0 : 76.0;
    return Row(
      children: [
        StepButton(
          icon: Icons.remove,
          label: decreaseLabel,
          size: size,
          onPressed: onDecrease,
          semanticLabel: '${semanticName ?? ''} $decreaseLabel'.trim(),
        ),
        Expanded(
          child: Semantics(
            liveRegion: true,
            label: [semanticName, value, unit, caption]
                .whereType<String>()
                .join(' '),
            excludeSemantics: true,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: dimmed ? 0.55 : 1,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          value,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontSize: compact ? 38 : 46,
                            color: valueColor ?? AppColors.textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (unit != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            unit!,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (caption != null && onCaptionTap == null)
                    Text(
                      caption!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  if (caption != null && onCaptionTap != null)
                    InkWell(
                      onTap: onCaptionTap,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                caption!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.edit,
                                size: 12, color: AppColors.primaryLight),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        StepButton(
          icon: Icons.add,
          label: increaseLabel,
          size: size,
          onPressed: onIncrease,
          semanticLabel: '${semanticName ?? ''} $increaseLabel'.trim(),
        ),
      ],
    );
  }
}

/// A large square button with an icon and a short label; repeats when held.
class StepButton extends StatefulWidget {
  const StepButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 76,
    this.semanticLabel,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final double size;
  final String? semanticLabel;

  @override
  State<StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<StepButton> {
  Timer? _repeat;

  void _press() {
    HapticFeedback.selectionClick();
    widget.onPressed?.call();
  }

  void _startRepeat() {
    _repeat?.cancel();
    _repeat = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (widget.onPressed == null) {
        _stopRepeat();
      } else {
        widget.onPressed!();
      }
    });
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final color = enabled ? AppColors.primary : AppColors.textTertiary;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel ?? widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onLongPressStart: enabled ? (_) => _startRepeat() : null,
        onLongPressEnd: (_) => _stopRepeat(),
        onLongPressCancel: _stopRepeat,
        child: Material(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: enabled ? _press : null,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: enabled
                      ? AppColors.primary.withValues(alpha: 0.6)
                      : AppColors.surfaceBorder,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, color: color, size: widget.size * 0.42),
                  Text(
                    widget.label,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of quick presets ("Plat 0 %", "Seuil 250 W"…).
class PresetRow extends StatelessWidget {
  const PresetRow({super.key, required this.presets});

  final List<Preset> presets;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < presets.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: _PresetChip(preset: presets[i])),
        ],
      ],
    );
  }
}

class Preset {
  const Preset({
    required this.title,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String value;
  final bool selected;
  final VoidCallback onTap;
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.preset});

  final Preset preset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = preset.selected;
    return Semantics(
      button: true,
      selected: selected,
      label: '${preset.title} ${preset.value}',
      excludeSemantics: true,
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.22)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            preset.onTap();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.surfaceBorder,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  preset.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected
                        ? AppColors.primaryLight
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    preset.value,
                    maxLines: 1,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
