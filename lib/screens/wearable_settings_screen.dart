import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wearable_health_service.dart';
import '../utils/app_state.dart';

class WearableSettingsScreen extends StatefulWidget {
  const WearableSettingsScreen({super.key});

  @override
  State<WearableSettingsScreen> createState() => _WearableSettingsScreenState();
}

class _WearableSettingsScreenState extends State<WearableSettingsScreen> {
  bool _isRefreshing = false;
  bool _checkedAvailability = false;
  bool _isAvailable = false;
  bool _hasPermissions = false;
  bool _isChecking = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checkedAvailability) {
      _checkedAvailability = true;
      _loadStatus();
    }
  }

  Future<void> _loadStatus() async {
    setState(() => _isChecking = true);
    final available = await WearableHealthService.isHealthConnectAvailable();
    final permissions =
        available ? await WearableHealthService.hasRequiredPermissions() : false;
    if (!mounted) return;
    setState(() {
      _isAvailable = available;
      _hasPermissions = permissions;
      _isChecking = false;
    });
    if (!available) {
      _showInstallPrompt();
    }
  }

  void _showInstallPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Health Connect Required'),
        content: const Text(
          'To read data from your smartwatch, please install Health Connect and grant permissions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await WearableHealthService.installHealthConnect();
            },
            child: const Text('Install'),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh(AppState appState) async {
    if (!_isAvailable) {
      _showInstallPrompt();
      return;
    }

    setState(() => _isRefreshing = true);
    await appState.refreshWearableSummary();
    if (mounted) {
      setState(() => _isRefreshing = false);
      await _loadStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wearables'),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          final summary = appState.wearableSummary;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      if (_isChecking)
                        const LinearProgressIndicator(minHeight: 2)
                      else
                        Row(
                          children: [
                            Icon(
                              _isAvailable
                                  ? Icons.check_circle
                                  : Icons.info_outline,
                              color: _isAvailable
                                  ? colorScheme.primary
                                  : colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_isAvailable
                                  ? 'Health Connect available'
                                  : 'Health Connect not available'),
                            ),
                            if (!_isAvailable)
                              const TextButton(
                                onPressed:
                                    WearableHealthService.installHealthConnect,
                                child: Text('Install'),
                              ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _hasPermissions
                                ? Icons.lock_open
                                : Icons.lock_outline,
                            color: _hasPermissions
                                ? colorScheme.primary
                                : colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_hasPermissions
                                ? 'Permissions granted'
                                : 'Permissions required'),
                          ),
                          if (!_hasPermissions)
                            TextButton(
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final granted =
                                    await WearableHealthService
                                        .requestRequiredPermissions();
                                if (!mounted) return;
                                setState(() {
                                  _hasPermissions = granted;
                                });
                                await _loadStatus();
                                if (!granted) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Permissions not granted. Please allow access in Health Connect.'),
                                    ),
                                  );
                                  _showPermissionsHelp();
                                }
                              },
                              child: const Text('Grant'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      if (summary == null || summary.isEmpty)
                        Text(
                          'No wearable data available yet.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        Column(
                          children: [
                            _metricRow('Steps',
                                summary.stepsToday?.toString() ?? '-'),
                            _metricRow(
                                'Active minutes',
                                summary.activeMinutesToday?.toString() ?? '-'),
                            _metricRow(
                                'Avg heart rate',
                                summary.avgHeartRate != null
                                    ? '${summary.avgHeartRate!.toStringAsFixed(0)} bpm'
                                    : '-'),
                            _metricRow(
                                'Resting heart rate',
                                summary.restingHeartRate != null
                                    ? '${summary.restingHeartRate!.toStringAsFixed(0)} bpm'
                                    : '-'),
                            _metricRow(
                                'Sleep',
                                summary.sleepHours != null
                                    ? '${summary.sleepHours!.toStringAsFixed(1)} hrs'
                                    : '-'),
                            _metricRow(
                                'Sleep efficiency',
                                summary.sleepEfficiency != null
                                    ? '${summary.sleepEfficiency!.toStringAsFixed(0)}%'
                                    : '-'),
                          ],
                        ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _isRefreshing
                            ? null
                            : () => _refresh(appState),
                        icon: const Icon(Icons.refresh),
                        label: Text(_isRefreshing
                            ? 'Refreshing...'
                            : 'Refresh data'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showPermissionsHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Grant permissions'),
        content: const Text(
          'Open Health Connect → App permissions → MediPal, then enable the requested data types.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await WearableHealthService.installHealthConnect();
            },
            child: const Text('Open/Install'),
          ),
        ],
      ),
    );
  }
}
