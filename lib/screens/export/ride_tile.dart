import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../features/illustration/illustration_storage.dart';
import '../../features/illustration/illustration_viewer_screen.dart';

/// One saved ride: stats, illustration thumbnail and actions.
class RideTile extends StatefulWidget {
  const RideTile({
    super.key,
    required this.ride,
    required this.isStravaConnected,
    required this.onShareFit,
    required this.onShareTcx,
    required this.onUploadStrava,
    required this.onDelete,
    required this.onEditName,
    required this.onIllustrate,
  });

  final RideSummary ride;
  final bool isStravaConnected;
  final VoidCallback onShareFit;
  final VoidCallback onShareTcx;
  final VoidCallback onUploadStrava;
  final VoidCallback onDelete;
  final VoidCallback onEditName;
  final VoidCallback onIllustrate;

  @override
  State<RideTile> createState() => _RideTileState();
}

class _RideTileState extends State<RideTile> {
  Uint8List? _illustrationBytes;

  @override
  void initState() {
    super.initState();
    _loadIllustration();
  }

  @override
  void didUpdateWidget(RideTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The history is reloaded after a (re)generation: new ride objects.
    // Other rebuilds (Strava state…) keep the same ones and the same image.
    if (!identical(oldWidget.ride, widget.ride)) _loadIllustration();
  }

  Future<void> _loadIllustration() async {
    Uint8List? bytes;
    try {
      bytes = await IllustrationStorage.load(widget.ride.id);
    } catch (e) {
      // No thumbnail rather than an error if the storage is unavailable.
      if (kDebugMode) debugPrint('[Export] illustration not loaded: $e');
    }
    if (mounted) {
      setState(() {
        _illustrationBytes = bytes;
      });
    }
  }

  void _openIllustrationViewer() {
    if (_illustrationBytes != null) {
      showIllustrationViewer(
        context,
        imageBytes: _illustrationBytes!,
        sessionName: widget.ride.displayName,
        onRegenerate: widget.onIllustrate,
      );
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('dd MMM yyyy - HH:mm').format(widget.ride.startTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Miniature illustration ou icone velo
              GestureDetector(
                onTap:
                    _illustrationBytes != null ? _openIllustrationViewer : null,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    image: _illustrationBytes != null
                        ? DecorationImage(
                            // 48 dp thumbnail: no need to decode the full image.
                            image: ResizeImage(
                              MemoryImage(_illustrationBytes!),
                              width: 160,
                            ),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _illustrationBytes == null
                      ? Icon(Icons.directions_bike, color: AppColors.primary)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: widget.onEditName,
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.ride.displayName,
                              style: Theme.of(context).textTheme.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.edit,
                              size: 14, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                    Text(
                      dateStr,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: widget.onDelete,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats row
          Row(
            children: [
              _StatChip(
                icon: Icons.timer,
                value: _formatDuration(widget.ride.duration),
              ),
              const SizedBox(width: 8),
              if (widget.ride.averagePower != null)
                _StatChip(
                  icon: Icons.flash_on,
                  value: '${widget.ride.averagePower}W',
                ),
              if (widget.ride.averagePower != null) const SizedBox(width: 8),
              if (widget.ride.averageCadence != null)
                _StatChip(
                  icon: Icons.rotate_right,
                  value: '${widget.ride.averageCadence} rpm',
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Action buttons
          if (widget.isStravaConnected)
            Column(
              children: [
                // Strava upload button (prominent)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.onUploadStrava,
                    icon: const Icon(Icons.upload, size: 18),
                    label: const Text('Envoyer vers Strava'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Share buttons (secondary)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onShareFit,
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('.FIT'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onShareTcx,
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('.TCX'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Illustration button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.onIllustrate,
                    icon: Icon(Icons.auto_awesome,
                        size: 16, color: AppColors.primary),
                    label: const Text('Illustrer'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onShareFit,
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('.FIT'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onShareTcx,
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('.TCX'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Illustration button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.onIllustrate,
                    icon: Icon(Icons.auto_awesome,
                        size: 16, color: AppColors.primary),
                    label: const Text('Illustrer'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.value,
  });

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
