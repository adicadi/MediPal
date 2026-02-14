import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/wearable_summary.dart';
import '../services/wearable_health_service.dart';
import '../utils/app_state.dart';

enum StepsRange { week, month, year }

class WearableScreen extends StatefulWidget {
  const WearableScreen({super.key});

  @override
  State<WearableScreen> createState() => _WearableScreenState();
}

class _WearableScreenState extends State<WearableScreen> {
  bool _isRefreshing = false;
  StepsRange _stepsRange = StepsRange.week;

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
    return DateTime.now().difference(updatedAt) > const Duration(minutes: 30);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Consumer<AppState>(
          builder: (context, appState, child) {
            final summary = appState.wearableSummary;
            final history = appState.wearableHistory;
            final weekly = _buildWeeklySummary(history);
            final weeklyTitle =
                weekly.isEmpty ? 'No weekly data yet' : 'Last 7 days summary';
            final stepPoints = _buildStepPoints(history, summary, _stepsRange);
            final stepsTotal =
                stepPoints.fold<int>(0, (sum, e) => sum + e.value);
            final stepsAverage = stepPoints.isEmpty
                ? 0
                : (stepsTotal / stepPoints.length).round();

            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              children: [
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => Navigator.maybePop(context),
                      style: IconButton.styleFrom(
                        shape: const CircleBorder(),
                        backgroundColor: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.9),
                        foregroundColor: colorScheme.onSurface,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Wearables',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
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
                            _metricRow(
                                'Steps', summary.stepsToday?.toString() ?? '-'),
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
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed:
                            _isRefreshing ? null : () => _refresh(appState),
                        icon: _isRefreshing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh),
                        label: Text(
                            _isRefreshing ? 'Refreshing...' : 'Refresh data'),
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
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Steps Trend',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          SegmentedButton<StepsRange>(
                            showSelectedIcon: false,
                            style: SegmentedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              textStyle: theme.textTheme.labelSmall,
                            ),
                            segments: const [
                              ButtonSegment(
                                value: StepsRange.week,
                                label: Text('Week'),
                              ),
                              ButtonSegment(
                                value: StepsRange.month,
                                label: Text('Month'),
                              ),
                              ButtonSegment(
                                value: StepsRange.year,
                                label: Text('Year'),
                              ),
                            ],
                            selected: {_stepsRange},
                            onSelectionChanged: (selection) {
                              if (selection.isNotEmpty) {
                                setState(() => _stepsRange = selection.first);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (stepPoints.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No step history available yet.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      else
                        _StepsBarChart(points: stepPoints),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _statChip(
                            context,
                            label: 'Total',
                            value: _formatSteps(stepsTotal),
                          ),
                          const SizedBox(width: 8),
                          _statChip(
                            context,
                            label: 'Avg',
                            value: _formatSteps(stepsAverage),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
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
                            _metricRow('Avg steps', weekly['steps'] ?? '-'),
                            _metricRow('Avg sleep', weekly['sleep'] ?? '-'),
                            _metricRow(
                                'Avg resting HR', weekly['restingHr'] ?? '-'),
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
    final last7 =
        history.length > 7 ? history.sublist(history.length - 7) : history;

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

  List<_StepPoint> _buildStepPoints(
    List<WearableSummary> history,
    WearableSummary? summary,
    StepsRange range,
  ) {
    final all = <WearableSummary>[...history];
    if (summary != null && summary.stepsToday != null) {
      all.add(summary);
    }

    if (all.isEmpty) return [];

    all.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    final uniqueByDay = <String, WearableSummary>{};
    for (final item in all) {
      if (item.stepsToday == null) continue;
      final key = _dayKey(item.updatedAt);
      uniqueByDay[key] = item;
    }
    final dayItems = uniqueByDay.values.toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));

    if (range == StepsRange.week) {
      final last = dayItems.length > 7
          ? dayItems.sublist(dayItems.length - 7)
          : dayItems;
      return last
          .map((e) => _StepPoint(
                label: _weekdayLabel(e.updatedAt.weekday),
                value: e.stepsToday ?? 0,
              ))
          .toList();
    }

    if (range == StepsRange.month) {
      final last = dayItems.length > 30
          ? dayItems.sublist(dayItems.length - 30)
          : dayItems;
      return last
          .map((e) => _StepPoint(
                label: '${e.updatedAt.day}',
                value: e.stepsToday ?? 0,
              ))
          .toList();
    }

    final byMonth = <String, List<int>>{};
    for (final item in dayItems) {
      final key = '${item.updatedAt.year}-${item.updatedAt.month}';
      byMonth.putIfAbsent(key, () => []).add(item.stepsToday ?? 0);
    }
    final monthEntries = byMonth.entries.toList()
      ..sort((a, b) {
        final pa = a.key.split('-');
        final pb = b.key.split('-');
        final ya = int.parse(pa[0]);
        final yb = int.parse(pb[0]);
        if (ya != yb) return ya.compareTo(yb);
        return int.parse(pa[1]).compareTo(int.parse(pb[1]));
      });
    final last12 = monthEntries.length > 12
        ? monthEntries.sublist(monthEntries.length - 12)
        : monthEntries;

    return last12.map((entry) {
      final month = int.parse(entry.key.split('-')[1]);
      final avg = entry.value.reduce((a, b) => a + b) /
          (entry.value.isEmpty ? 1 : entry.value.length);
      return _StepPoint(label: _monthShort(month), value: avg.round());
    }).toList();
  }

  String _weekdayLabel(int weekday) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[(weekday - 1).clamp(0, 6)];
  }

  String _monthShort(int month) {
    const labels = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return labels[(month - 1).clamp(0, 11)];
  }

  String _dayKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _statChip(BuildContext context,
      {required String label, required String value}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  String _formatSteps(int value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return '$value';
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
                        separatorBuilder: (_, __) => const Divider(height: 16),
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

class _StepPoint {
  final String label;
  final int value;
  const _StepPoint({required this.label, required this.value});
}

class _StepsBarChart extends StatelessWidget {
  final List<_StepPoint> points;
  const _StepsBarChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (points.isEmpty) return const SizedBox.shrink();
    final maxValue = points
        .map((e) => e.value)
        .fold<int>(1, (prev, val) => val > prev ? val : prev);
    final barWidth = points.length > 12 ? 8.0 : 12.0;

    return SizedBox(
      height: 190,
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: points.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final p = points[index];
                final factor = (p.value / maxValue).clamp(0.04, 1.0);
                return SizedBox(
                  width: barWidth + 8,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Tooltip(
                        message: '${p.value} steps',
                        child: Container(
                          height: 120 * factor,
                          width: barWidth,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                colorScheme.primary.withValues(alpha: 0.95),
                                colorScheme.primary.withValues(alpha: 0.55),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Divider(color: colorScheme.outlineVariant, height: 1),
        ],
      ),
    );
  }
}
