import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/wearable_summary.dart';
import '../utils/app_state.dart';

class WearableScreen extends StatefulWidget {
  const WearableScreen({super.key});

  @override
  State<WearableScreen> createState() => _WearableScreenState();
}

class _WearableScreenState extends State<WearableScreen> {
  bool _isRefreshing = false;

  Future<void> _refresh(AppState appState) async {
    setState(() => _isRefreshing = true);
    await appState.refreshWearableSummary();
    if (mounted) {
      setState(() => _isRefreshing = false);
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
          final history = appState.wearableHistory;
          final weekly = _buildWeeklySummary(history);
          final weeklyTitle = weekly.isEmpty
              ? 'No weekly data yet'
              : 'Last 7 days summary';

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
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Summary',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      if (weekly.isEmpty)
                        Text(
                          weeklyTitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        Column(
                          children: [
                            _metricRow(
                                'Avg steps', weekly['steps'] ?? '-'),
                            _metricRow('Avg sleep', weekly['sleep'] ?? '-'),
                            _metricRow('Avg resting HR',
                                weekly['restingHr'] ?? '-'),
                          ],
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

  Map<String, String> _buildWeeklySummary(List<WearableSummary> history) {
    if (history.isEmpty) return {};
    final last7 = history.length > 7
        ? history.sublist(history.length - 7)
        : history;

    double? stepsAvg;
    double? sleepAvg;
    double? restingHrAvg;

    final steps = last7.where((e) => e.stepsToday != null).toList();
    if (steps.isNotEmpty) {
      stepsAvg = steps.map((e) => e.stepsToday as int).reduce((a, b) => a + b) /
          steps.length;
    }

    final sleep = last7.where((e) => e.sleepHours != null).toList();
    if (sleep.isNotEmpty) {
      sleepAvg =
          sleep.map((e) => e.sleepHours as double).reduce((a, b) => a + b) /
              sleep.length;
    }

    final resting = last7.where((e) => e.restingHeartRate != null).toList();
    if (resting.isNotEmpty) {
      restingHrAvg = resting
              .map((e) => e.restingHeartRate as double)
              .reduce((a, b) => a + b) /
          resting.length;
    }

    return {
      if (stepsAvg != null) 'steps': stepsAvg.toStringAsFixed(0),
      if (sleepAvg != null) 'sleep': '${sleepAvg.toStringAsFixed(1)} hrs',
      if (restingHrAvg != null)
        'restingHr': '${restingHrAvg.toStringAsFixed(0)} bpm',
    };
  }

}
