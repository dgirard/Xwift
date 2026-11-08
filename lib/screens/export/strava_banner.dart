import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../features/strava/strava_provider.dart';

/// Strava connection banner widget
class StravaBanner extends ConsumerWidget {
  final StravaConnectionState stravaState;

  const StravaBanner({super.key, required this.stravaState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = stravaState.status == StravaConnectionStatus.connected;
    final isConnecting =
        stravaState.status == StravaConnectionStatus.connecting;
    final needsConfig =
        stravaState.status == StravaConnectionStatus.notConfigured;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isConnected
              ? [Colors.green.shade700, Colors.green.shade500]
              : [Colors.orange.shade700, Colors.orange.shade500],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: isConnected
                ? const Icon(Icons.check, color: Colors.white, size: 28)
                : const Icon(Icons.directions_bike, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? 'Strava Connecte' : 'Strava Sync',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                      ),
                ),
                Text(
                  isConnected
                      ? stravaState.athlete?.fullName ?? 'Connecte'
                      : needsConfig
                          ? 'Configurez vos identifiants'
                          : 'Connectez pour sync automatique',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
              ],
            ),
          ),
          if (isConnecting)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else if (isConnected)
            TextButton(
              onPressed: () => _showDisconnectDialog(context, ref),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Deconnecter'),
            )
          else
            ElevatedButton(
              onPressed: () {
                if (needsConfig) {
                  _showConfigDialog(context, ref);
                } else {
                  ref.read(stravaConnectionProvider.notifier).connect();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange,
              ),
              child: Text(needsConfig ? 'Configurer' : 'Connecter'),
            ),
        ],
      ),
    );
  }

  void _showDisconnectDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deconnecter Strava ?'),
        content: const Text(
            'Vous devrez vous reconnecter pour envoyer des activites.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              ref.read(stravaConnectionProvider.notifier).disconnect();
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Deconnecter'),
          ),
        ],
      ),
    );
  }

  void _showConfigDialog(BuildContext context, WidgetRef ref) {
    final clientIdController = TextEditingController();
    final clientSecretController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configuration Strava'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '1. Allez sur strava.com/settings/api\n'
                '2. Creez une application\n'
                '3. Copiez Client ID et Secret',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: clientIdController,
                decoration: const InputDecoration(
                  labelText: 'Client ID',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: clientSecretController,
                decoration: const InputDecoration(
                  labelText: 'Client Secret',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final clientId = clientIdController.text.trim();
              final clientSecret = clientSecretController.text.trim();

              if (clientId.isNotEmpty && clientSecret.isNotEmpty) {
                await ref
                    .read(stravaConnectionProvider.notifier)
                    .saveCredentials(
                      clientId,
                      clientSecret,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
