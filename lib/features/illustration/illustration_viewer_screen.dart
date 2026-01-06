import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import 'illustration_storage.dart';

/// Full screen illustration viewer with zoom, save, share and regenerate
class IllustrationViewerScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final String sessionName;
  final VoidCallback? onRegenerate;

  const IllustrationViewerScreen({
    super.key,
    required this.imageBytes,
    required this.sessionName,
    this.onRegenerate,
  });

  @override
  State<IllustrationViewerScreen> createState() => _IllustrationViewerScreenState();
}

class _IllustrationViewerScreenState extends State<IllustrationViewerScreen> {
  final TransformationController _transformationController = TransformationController();
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    // Allow all orientations for this screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // Reset to portrait only when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _transformationController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  Future<void> _saveImage() async {
    try {
      // Sauvegarder dans le dossier Download du telephone
      final downloadPath = await IllustrationStorage.saveToDownloads(
        '', // rideId pas necessaire car le nom est base sur sessionName
        widget.imageBytes,
        widget.sessionName,
      );

      if (mounted) {
        if (downloadPath != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Image sauvegardee dans Download'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          // Fallback vers documents si Download non accessible
          final directory = await getApplicationDocumentsDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final file = File('${directory.path}/illustration_$timestamp.png');
          await file.writeAsBytes(widget.imageBytes);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image sauvegardee: ${file.path}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _shareImage() async {
    try {
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/illustration_$timestamp.png');
      await file.writeAsBytes(widget.imageBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Illustration - ${widget.sessionName}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _regenerate() {
    Navigator.pop(context);
    widget.onRegenerate?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _showControls
          ? AppBar(
              backgroundColor: Colors.black54,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                widget.sessionName,
                style: const TextStyle(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                IconButton(
                  onPressed: _resetZoom,
                  icon: const Icon(Icons.fit_screen),
                  tooltip: 'Reinitialiser le zoom',
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image with zoom
            InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.5,
              maxScale: 5.0,
              child: Center(
                child: Image.memory(
                  widget.imageBytes,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white54,
                          size: 64,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Impossible de charger l\'image',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // Bottom action bar
            if (_showControls)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black87,
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Regenerate button
                      if (widget.onRegenerate != null)
                        _ActionButton(
                          icon: Icons.refresh,
                          label: 'Regenerer',
                          onTap: _regenerate,
                        ),
                      // Save button
                      _ActionButton(
                        icon: Icons.save_alt,
                        label: 'Sauvegarder',
                        onTap: _saveImage,
                      ),
                      // Share button
                      _ActionButton(
                        icon: Icons.share,
                        label: 'Partager',
                        onTap: _shareImage,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Navigate to illustration viewer screen
Future<void> showIllustrationViewer(
  BuildContext context, {
  required Uint8List imageBytes,
  required String sessionName,
  VoidCallback? onRegenerate,
}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (ctx) => IllustrationViewerScreen(
        imageBytes: imageBytes,
        sessionName: sessionName,
        onRegenerate: onRegenerate,
      ),
    ),
  );
}
