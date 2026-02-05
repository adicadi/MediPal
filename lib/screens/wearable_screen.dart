import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/wearable_summary.dart';
import '../services/wearable_health_service.dart';
import '../utils/app_state.dart';

class WearableScreen extends StatefulWidget {
  const WearableScreen({super.key});

  @override
  State<WearableScreen> createState() => _WearableScreenState();
}

class _WearableScreenState extends State<WearableScreen> {
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshIfPermitted();
    });
  }

  Future<void> _refreshIfPermitted() async {
    final appState = context.read<AppState>();
    final available = await WearableHealthService.isHealthConnectAvailable();
    if (!mounted) return;
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Health Connect not available. Install it to use Wearable Insights.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final granted = await WearableHealthService.hasRequiredPermissions();
    if (!mounted || !granted) return;

    final summary = appState.wearableSummary;
    if (summary == null || _isStale(summary.updatedAt)) {
      _refresh(appState);
    }
  }

  Future<void> _refresh(AppState appState) async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final granted = await WearableHealthService.ensurePermissions();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please allow permissions in Health Connect to refresh data.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      await appState.refreshWearableSummary();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  bool _isStale(DateTime updatedAt) {
    return DateTime.now().difference(updatedAt) >
        const Duration(minutes: 30);
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
                      if (_isRefreshing) ...[
                        const LinearProgressIndicator(minHeight: 2),
                        const SizedBox(height: 12),
                      ],
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
                          ],
                        ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _isRefreshing
                            ? null
                            : () => _refresh(appState),
                        icon: _isRefreshing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh),
                        label: Text(_isRefreshing
                            ? 'Refreshing...'
                            : 'Refresh data'),
                      ),
                      if (kDebugMode) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _showSleepDebug(context),
                          icon: const Icon(Icons.bug_report_outlined),
                          label: const Text('Show sleep segments'),
                        ),
                      ],
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

  Future<void> _showSleepDebug(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      transitionAnimationController: AnimationController(
        vsync: Navigator.of(context),
        duration: const Duration(milliseconds: 220),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<List<SleepSegmentDebug>>(
              future: WearableHealthService.fetchSleepSegmentsLast24h(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Text(
                    'Failed to load sleep segments.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                }
                final segments = snapshot.data ?? [];
                if (segments.isEmpty) {
                  return Text(
                    'No sleep segments found in the last 24 hours.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sleep segments (today)',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: segments.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 16),
                        itemBuilder: (context, index) {
                          final segment = segments[index];
                          final range =
                              '${_formatTime(context, segment.start)} - ${_formatTime(context, segment.end)}';
                          final source =
                              '${segment.sourceName} (${segment.sourceId})';
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                range,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${segment.minutes} min • ${segment.type}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                source,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _formatTime(BuildContext context, DateTime time) {
    return TimeOfDay.fromDateTime(time).format(context);
  }

}
