import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:provider/provider.dart';
import '../utils/app_state.dart';
import '../widgets/health_summary_card.dart';
import '../services/emergency_service.dart';
import '../utils/blur_dialog.dart';
import '../models/wearable_summary.dart';
import '../services/wearable_health_service.dart';
import '../services/deepseek_service.dart';
import '../services/ai_insights_cache_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isGettingInsights = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: theme.colorScheme.primary,
          backgroundColor: theme.colorScheme.surface,
          onRefresh: () async {
            await _getHealthInsights(context, showDialog: false);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Health data refreshed',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            );
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Consumer<AppState>(
              builder: (context, appState, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopBar(theme),
                    const SizedBox(height: 6),
                    _buildGreetingLine(theme, appState),
                    const SizedBox(height: 14),
                    _buildHealthStatsRow(appState),
                    const SizedBox(height: 18),
                    _buildQuickActionsSection(appState, theme),
                    const SizedBox(height: 22),
                    _buildHealthSummarySection(appState, theme),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      floatingActionButton: Consumer<AppState>(
        builder: (context, appState, child) {
          return GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/chat'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(38),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF262B35), Color(0xFF0E1118)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF07112A).withValues(alpha: 0.45),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    appState.isMinor ? 'Ask Questions' : 'Quick AI Session',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildTopBar(ThemeData theme) {
    final textColor = theme.colorScheme.onSurface;
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            _formatCurrentDateLabel().toUpperCase(),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w400,
              letterSpacing: 1.2,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filledTonal(
          onPressed: () => Navigator.pushNamed(context, '/settings'),
          style: IconButton.styleFrom(
            shape: const CircleBorder(),
            backgroundColor:
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
            foregroundColor: textColor,
          ),
          icon: const Icon(Icons.tune_rounded),
          tooltip: 'Settings',
        ),
      ],
    );
  }

  Widget _buildGreetingLine(ThemeData theme, AppState appState) {
    final colorScheme = theme.colorScheme;
    final baseStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w400,
      color: colorScheme.onSurface.withValues(alpha: 0.94),
      letterSpacing: -0.2,
    );
    final nameStyle = baseStyle?.copyWith(fontWeight: FontWeight.w700);
    final text = appState.personalizedGreeting;
    final match = RegExp(r'^([^,]+),\s([^!]+)(!?.*)$').firstMatch(text);

    if (match != null) {
      final prefix = '${match.group(1)!}, ';
      final name = match.group(2)!;
      final suffix = match.group(3) ?? '';
      return Text.rich(
        TextSpan(
          style: baseStyle,
          children: [
            TextSpan(text: prefix),
            TextSpan(text: name, style: nameStyle),
            TextSpan(text: suffix),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Text(
      text,
      style: baseStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  // FIXED: Health stats row WITHOUT health score
  Widget _buildHealthStatsRow(AppState appState) {
    return Row(
      children: [
        Expanded(
          child: _buildStatusMetricCard(
            label: 'Medications',
            value: '${appState.medications.length}',
            icon: Icons.medication_rounded,
            accent: const Color(0xFF32A275),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatusMetricCard(
            label: 'Consultations',
            value: '${appState.chatSessionsCount}',
            icon: Icons.chat_bubble_rounded,
            accent: const Color(0xFF4D80C9),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: Theme.of(context).brightness == Brightness.dark
                  ? [
                      Theme.of(context)
                          .colorScheme
                          .surfaceContainer
                          .withValues(alpha: 0.95),
                      Theme.of(context)
                          .colorScheme
                          .surfaceContainerLow
                          .withValues(alpha: 0.95),
                    ]
                  : [
                      Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.96),
                      Theme.of(context)
                          .colorScheme
                          .surfaceContainerLow
                          .withValues(alpha: 0.96),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 14, color: accent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 36,
                  height: 0.95,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActionsSection(AppState appState, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: appState.isMinor ? 'Things You Can Do' : 'Priority',
          actionLabel: null,
          onActionTap: null,
          theme: theme,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _buildAgeAppropriateActions(appState),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildAgeAppropriateActions(AppState appState) {
    List<Widget> actions = [];

    if (appState.isMinor) {
      actions.addAll([
        _buildEnhancedPillButton(
          'Ask Questions',
          Icons.help,
          Colors.blue,
          () => _showMinorChatInfo(context),
        ),
        _buildEnhancedPillButton(
          'Health Tips',
          Icons.tips_and_updates,
          Colors.green,
          () => _showPersonalizedHealthTips(context, appState),
        ),
        _buildEnhancedPillButton(
          'Tell an Adult',
          Icons.family_restroom,
          Colors.orange,
          () => _showMinorGuidance(context),
        ),
        _buildEnhancedPillButton(
          'Emergency Help',
          Icons.emergency,
          Colors.red,
          () => _showMinorEmergencyInfo(context),
        ),
      ]);
    } else {
      actions.addAll([
        _buildEnhancedPillButton(
          'Symptom Checker',
          Icons.search,
          Colors.blue,
          () => Navigator.pushNamed(context, '/symptoms'),
        ),
        _buildEnhancedPillButton(
          'Medications',
          Icons.medication,
          Colors.green,
          () => Navigator.pushNamed(context, '/medications'),
        ),
        _buildEnhancedPillButton(
          'Emergency',
          Icons.emergency,
          Colors.red,
          () => _showEmergencyInfo(context),
        ),
      ]);
    }

    return actions;
  }

  Widget _buildHealthSummarySection(AppState appState, ThemeData theme) {
    final cards = _buildAgeAppropriateHealthCards(appState);
    final split = cards.length > 1 ? (cards.length / 2).ceil() : cards.length;
    final priorityCards = cards.take(split).toList();
    final scheduledCards = cards.skip(split).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Summary',
          actionLabel: 'Tips',
          onActionTap: () => _showPersonalizedHealthTips(context, appState),
          theme: theme,
        ),
        const SizedBox(height: 6),
        _buildTimelineGroup('', priorityCards, theme),
        if (scheduledCards.isNotEmpty)
          _buildTimelineGroup('', scheduledCards, theme),
      ],
    );
  }

  List<Widget> _buildAgeAppropriateHealthCards(AppState appState) {
    List<Widget> cards = [];

    cards.add(_buildWearableSummaryCard(appState));

    if (appState.isMinor) {
      cards.addAll([
        HealthSummaryCard(
          title: "Health Questions",
          content: "Ask me about health topics appropriate for your age",
          subtitle: "Always remember to talk to trusted adults too!",
          icon: Icons.help,
          backgroundColor: const Color(0xFFEAF3FF),
          onTap: () => _showMinorChatInfo(context),
        ),
        HealthSummaryCard(
          title: "Healthy Habits",
          content: "Learn about staying healthy and strong",
          subtitle: "Fun tips for young people",
          icon: Icons.fitness_center,
          backgroundColor: const Color(0xFFEBF7EF),
          onTap: () => _showPersonalizedHealthTips(context, appState),
        ),
        HealthSummaryCard(
          title: "When to Tell Adults",
          content: "Learn when it's important to talk to grown-ups",
          subtitle: "Your safety is most important",
          icon: Icons.family_restroom,
          backgroundColor: const Color(0xFFF9EDDE),
          onTap: () => _showMinorGuidance(context),
        ),
      ]);
    } else {
      cards.addAll([
        _buildInsightsCard(appState),
        HealthSummaryCard(
          title: "Medications",
          content: appState.medications.isNotEmpty
              ? "${appState.medications.length} medication${appState.medications.length != 1 ? 's' : ''} tracked"
              : "No medications added yet",
          subtitle: appState.medications.isNotEmpty
              ? "Latest: ${appState.medications.last.name}"
              : "Tap to add your first medication",
          icon: Icons.medication,
          backgroundColor: const Color(0xFFEAF3FF),
          onTap: () => Navigator.pushNamed(context, '/medications'),
        ),
        HealthSummaryCard(
          title: "AI Consultations",
          content: appState.chatSessionsCount > 0
              ? "Recent consultation available"
              : "No recent consultations",
          subtitle: appState.chatSessionsCount > 0
              ? "Tap to view chat history"
              : "Start your first consultation",
          icon: Icons.psychology,
          backgroundColor: const Color(0xFFEEEAFB),
          onTap: () {
            if (appState.chatSessionsCount > 0) {
              Navigator.pushNamed(context, '/chat');
            } else {
              Navigator.pushNamed(context, '/chat');
            }
          },
        ),
      ]);
    }

    return cards;
  }

  Widget _buildInsightsCard(AppState appState) {
    final meds = appState.medications.length;
    final trend = appState.stepsTrendPercent;
    final refillCount = appState.medicationsNeedingRefill.length;
    final remindersEnabled = appState.totalActiveReminders;

    String content;
    if (meds == 0) {
      content = 'Add medications and connect wearables for smarter insights';
    } else {
      content = remindersEnabled > 0
          ? 'Medication routine looks set up'
          : 'Consider enabling reminders';
      if (refillCount > 0) {
        content = '$content • $refillCount refill alert(s)';
      }
    }

    String subtitle = meds > 0
        ? '$meds medication${meds == 1 ? '' : 's'} tracked'
        : 'No medications tracked';
    if (trend != null) {
      subtitle = '$subtitle • ${_formatTrend(trend)} steps vs 7d';
    }

    return HealthSummaryCard(
      title: "AI Health Insights",
      content: content,
      subtitle: subtitle,
      icon: Icons.insights,
      backgroundColor: const Color(0xFFE9F5F1),
      isLoading: _isGettingInsights,
      onTap: () => _getHealthInsights(context),
    );
  }

  Widget _buildWearableSummaryCard(AppState appState) {
    final summary = appState.wearableSummary;
    final trend = appState.stepsTrendPercent;
    final content = summary == null || summary.isEmpty
        ? 'No wearable data yet'
        : _formatWearableSummary(summary);
    final subtitle = summary == null
        ? 'Connect Health Connect to get data'
        : 'Last updated: ${_formatWearableTime(summary.updatedAt)}';

    return HealthSummaryCard(
      title: 'Wearable Insights',
      content: content,
      subtitle: trend == null
          ? subtitle
          : '$subtitle • ${_formatTrend(trend)} steps vs 7d',
      icon: Icons.watch,
      backgroundColor: const Color(0xFFEAF1F8),
      onTap: () => _handleWearableTap(appState),
    );
  }

  Future<void> _handleWearableTap(AppState appState) async {
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

    final granted = await WearableHealthService.ensurePermissions();
    if (!mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please allow permissions in Health Connect to view wearable data.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await appState.refreshWearableSummary();
    if (!mounted) return;
    Navigator.pushNamed(context, '/wearables');
  }

  String _formatWearableSummary(WearableSummary summary) {
    final parts = <String>[];
    if (summary.stepsToday != null) {
      parts.add('${summary.stepsToday} steps');
    }
    final sleepHours = summary.sleepHours;
    if (sleepHours != null) {
      parts.add('${sleepHours.toStringAsFixed(1)} hrs sleep');
    }
    final avgHeartRate = summary.avgHeartRate;
    if (avgHeartRate != null) {
      parts.add('${avgHeartRate.toStringAsFixed(0)} bpm');
    }
    if (parts.isEmpty) {
      return 'No wearable data yet';
    }
    return parts.join(' • ');
  }

  String _formatWearableTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '${time.month}/${time.day} $hour:$minute';
  }

  String _formatTrend(double value) {
    final sign = value >= 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(0)}%';
  }

  Widget _buildEnhancedPillButton(
      String text, IconData icon, Color color, VoidCallback onPressed) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = HSLColor.fromColor(color);
    final background = base
        .withSaturation(isDark ? 0.20 : 0.24)
        .withLightness(isDark ? 0.24 : 0.95)
        .toColor();
    final border = base
        .withSaturation(isDark ? 0.26 : 0.18)
        .withLightness(isDark ? 0.34 : 0.78)
        .toColor();
    final foreground = base
        .withSaturation(isDark ? 0.50 : 0.52)
        .withLightness(isDark ? 0.76 : 0.35)
        .toColor();

    return Container(
      margin: const EdgeInsets.only(right: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: border, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 6),
                Text(
                  text,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required ThemeData theme,
    String? actionLabel,
    VoidCallback? onActionTap,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (actionLabel != null && onActionTap != null)
          TextButton.icon(
            onPressed: onActionTap,
            icon: const Icon(Icons.chevron_right_rounded, size: 18),
            label: Text(actionLabel),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Widget _buildTimelineGroup(
      String label, List<Widget> cards, ThemeData theme) {
    if (cards.isEmpty) return const SizedBox.shrink();
    final showLabel = label.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel)
          Text(
            label,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (showLabel) const SizedBox(height: 6),
        ...cards,
      ],
    );
  }

  String _formatCurrentDateLabel() {
    const weekdays = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final now = DateTime.now();
    return '${weekdays[now.weekday % 7]}, ${months[now.month - 1]} ${now.day}';
  }

  Future<void> _getHealthInsights(BuildContext context,
      {bool showDialog = true}) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final deepSeekService =
        Provider.of<DeepSeekService>(context, listen: false);

    setState(() {
      _isGettingInsights = true;
    });

    try {
      final payload = _buildHealthInsightsPayload(appState);
      final payloadJson = jsonEncode(payload);
      final cached = await AiInsightsCacheService.load();
      String insights;
      if (cached != null && cached.payloadJson == payloadJson) {
        insights = cached.insights;
      } else {
        insights = await deepSeekService.getHealthInsights(payload, appState);
        await AiInsightsCacheService.save(payloadJson, insights);
      }

      if (!context.mounted) return;
      setState(() {
        _isGettingInsights = false;
      });

      if (showDialog) {
        _showInsightsDialog(context, insights, appState);
      }
    } catch (e) {
      if (!context.mounted) return;
      setState(() {
        _isGettingInsights = false;
      });

      if (showDialog) {
        _showErrorDialog(context, appState.getAgeAppropriateErrorMessage());
      }
    }
  }

  // ignore: unused_element
  String _generateAgeAppropriateInsights(AppState appState) {
    final wearable = appState.wearableSummary;
    final meds = appState.medications;
    final refillCount = appState.medicationsNeedingRefill.length;
    final remindersEnabled = appState.totalActiveReminders;

    if (appState.isMinor) {
      final steps = wearable?.stepsToday;
      final sleep = wearable?.sleepHours;
      return '''
Hi ${appState.userName}! 🌟

Here are some special health tips just for you:

🏃‍♀️ **Stay Active:** Try to play outside or do fun activities every day! Dancing, bike riding, or playing sports are great ways to stay strong.

😴 **Get Good Sleep:** Young people like you need 9-11 hours of sleep each night to grow big and strong!

🥕 **Eat Healthy Foods:** Try to eat colorful fruits and vegetables. They're like superpowers for your body!

💧 **Drink Water:** Water helps your body work its best. Try to drink water instead of sugary drinks.

🧠 **Talk to Adults:** Always remember to tell a trusted adult if you don't feel well or have questions about your health.

Remember: You're doing great by learning about staying healthy! Keep up the good work! 💪
${steps != null ? '\n👟 **Steps today:** $steps steps' : ''}
${sleep != null ? '\n😴 **Sleep last night:** ${sleep.toStringAsFixed(1)} hours' : ''}
      ''';
    } else {
      final lines = <String>[];
      if (wearable != null && !wearable.isEmpty) {
        if (wearable.stepsToday != null) {
          lines.add('• Steps today: ${wearable.stepsToday}');
        }
        if (wearable.avgHeartRate != null) {
          lines.add(
              '• Avg heart rate: ${wearable.avgHeartRate!.toStringAsFixed(0)} bpm');
        }
        if (wearable.restingHeartRate != null) {
          lines.add(
              '• Resting HR: ${wearable.restingHeartRate!.toStringAsFixed(0)} bpm');
        }
        if (wearable.sleepHours != null) {
          lines.add('• Sleep: ${wearable.sleepHours!.toStringAsFixed(1)} hrs');
        }
      }

      final medLine = meds.isNotEmpty
          ? '• Medications tracked: ${meds.length}'
          : '• No medications tracked yet';
      final refillLine =
          refillCount > 0 ? '• Refill alerts: $refillCount medication(s)' : '';
      final reminderLine = remindersEnabled > 0
          ? '• Active reminders: $remindersEnabled'
          : '• Reminders: not set';

      return '''
Hello ${appState.userName}! 

Based on your health profile, here are personalized insights:

**Today’s summary**
${lines.isEmpty ? '• Wearable data not available yet' : lines.join('\n')}

**Medications**
$medLine
$reminderLine
${refillLine.isNotEmpty ? refillLine : ''}

${appState.isYoungAdult ? '''
🎓 **Young Adult Focus:**
- Build healthy habits now for lifelong benefits
- Consider establishing relationships with healthcare providers
- Focus on stress management during this transitional period
''' : '''
👨‍⚕️ **Health Maintenance:**
- Keep up with regular health screenings
- Monitor any changes in your health status  
- Maintain an active lifestyle appropriate for your age
'''}

💡 **Recommendations:**
${appState.personalizedHealthTips.take(3).map((tip) => '• ${tip.substring(tip.indexOf(' ') + 1)}').join('\n')}

${appState.ageAppropriateDisclaimer}
      ''';
    }
  }

  Map<String, dynamic> _buildHealthInsightsPayload(AppState appState) {
    final wearable = appState.wearableSummary;
    final history = appState.wearableHistory;
    return {
      'wearable_summary': wearable == null || wearable.isEmpty
          ? null
          : {
              'steps_today': wearable.stepsToday,
              'sleep_hours': wearable.sleepHours,
              'avg_heart_rate': wearable.avgHeartRate,
              'resting_heart_rate': wearable.restingHeartRate,
              'stress_score': wearable.stressScore,
            },
      'wearable_history_days': history.isEmpty ? 0 : history.length,
      'steps_trend_percent': appState.stepsTrendPercent,
      'sleep_trend_percent': appState.sleepTrendPercent,
      'resting_hr_trend_percent': appState.restingHrTrendPercent,
      'medications_count': appState.medications.length,
      'active_reminders': appState.totalActiveReminders,
      'refill_alerts': appState.medicationsNeedingRefill.length,
      'user_age': appState.userAge,
      'user_gender': appState.userGender,
    };
  }

  void _showInsightsDialog(
      BuildContext context, String insights, AppState appState) {
    showBlurDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.psychology, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                appState.isMinor
                    ? 'Health Tips for You!'
                    : 'AI Health Insights',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: SelectionArea(child: TexMarkdown((insights))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/chat');
            },
            icon: const Icon(Icons.chat),
            label: Text(
              appState.isMinor ? 'Ask Questions' : 'Chat with AI',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showBlurDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Oops!',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPersonalizedHealthTips(BuildContext context, AppState appState) {
    showBlurDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.tips_and_updates, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                appState.isMinor
                    ? 'Health Tips for You!'
                    : 'Personalized Health Tips',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (appState.isMinor) ...[
                  Text(
                    '🌟 Special tips just for young people like you:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                ...appState.personalizedHealthTips.map((tip) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(tip),
                    )),
                if (appState.isMinor) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      '💡 Remember: Always talk to your parents or guardians about health and ask them to help you with these tips!',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  void _showMinorChatInfo(BuildContext context) {
    showBlurDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.help, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ask Health Questions',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '🌟 I can help you learn about:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• How to stay healthy and strong'),
                Text('• Why eating good food is important'),
                Text('• How much sleep you need'),
                Text('• Fun ways to exercise'),
                Text('• When to wash your hands'),
                SizedBox(height: 16),
                Text(
                  '⚠️ Important Reminder:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.orange),
                ),
                SizedBox(height: 8),
                Text(
                    'Always talk to a parent, guardian, or trusted adult about:'),
                Text('• If you feel sick or hurt'),
                Text('• Any health questions you have'),
                Text('• Before trying anything new'),
                SizedBox(height: 16),
                Text(
                  'Remember: Adults are there to help keep you safe and healthy! 💙',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/chat');
            },
            child: const Text('Ask Questions'),
          ),
        ],
      ),
    );
  }

  void _showMinorGuidance(BuildContext context) {
    showBlurDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.family_restroom, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'When to Tell Adults',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '🏠 Always tell a trusted adult if:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• You feel sick or hurt'),
                Text('• Something doesn\'t feel right'),
                Text('• You have questions about your body'),
                Text('• Someone makes you uncomfortable'),
                Text('• You need help with anything'),
                SizedBox(height: 16),
                Text(
                  '👨‍👩‍👧‍👦 Trusted adults include:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• Parents or guardians'),
                Text('• Teachers'),
                Text('• School nurses'),
                Text('• Doctors'),
                Text('• Family members you trust'),
                SizedBox(height: 16),
                Text(
                  'You are never bothering adults when you ask for help! 🌟',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I understand'),
          ),
        ],
      ),
    );
  }

  // ENHANCED: Minor emergency info with location-based emergency numbers
  void _showMinorEmergencyInfo(BuildContext context) async {
    // Show loading dialog
    showBlurDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Getting emergency numbers for your area...'),
          ],
        ),
      ),
    );

    try {
      final emergencyNumbers = await EmergencyService.getEmergencyNumbers();

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      showBlurDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.emergency, color: Colors.red),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Emergency Help',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '🚨 If there\'s an emergency in ${emergencyNumbers.countryName}:',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  const Text('1. Find a trusted adult RIGHT AWAY'),
                  const Text(
                      '2. If no adult is around, call the emergency number below'),
                  const Text('3. Stay calm and ask for help'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[300]!),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '📞 Emergency Number for ${emergencyNumbers.countryName}:',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          emergencyNumbers.emergency,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '🌟 You did the right thing by learning about safety!',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('I understand'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog
      // Show generic emergency info if location fails
      showBlurDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Emergency Help'),
          content: const Text(
              'If there\'s an emergency:\n\n1. Find a trusted adult RIGHT AWAY\n2. Call your local emergency number\n3. Stay calm and ask for help'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('I understand'),
            ),
          ],
        ),
      );
    }
  }

  // ENHANCED: Emergency info with location-based emergency numbers
  void _showEmergencyInfo(BuildContext context) async {
    // Show loading dialog first
    showBlurDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Getting your location for local emergency numbers...'),
          ],
        ),
      ),
    );

    try {
      // Get location-based emergency numbers
      final emergencyNumbers = await EmergencyService.getEmergencyNumbers();

      // Close loading dialog
      if (!context.mounted) return;
      Navigator.pop(context);

      // Show emergency info with local numbers
      _showEmergencyInfoDialog(context, emergencyNumbers);
    } catch (e) {
      // Close loading dialog and show error
      if (!context.mounted) return;
      Navigator.pop(context);
      _showEmergencyInfoDialog(context, null);
    }
  }

  void _showEmergencyInfoDialog(
      BuildContext context, EmergencyNumbers? numbers) {
    final emergencyNumbers = numbers ??
        const EmergencyNumbers(
          emergency: '112 (International)',
          police: '112',
          fire: '112',
          ambulance: '112',
          poisonControl: 'Contact local emergency services',
          mentalHealth: 'Contact local services',
          domesticViolence: 'Contact local services',
          countryName: 'International',
          countryCode: 'INTL',
        );

    showBlurDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.emergency, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Emergency Information',
                    style: TextStyle(fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    emergencyNumbers.countryName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Primary Emergency Number
                _buildEmergencyNumberCard(
                  '🚨 EMERGENCY',
                  emergencyNumbers.emergency,
                  'For immediate life-threatening situations',
                  Colors.red,
                  isUrgent: true,
                ),

                const SizedBox(height: 16),

                // Specific Services
                const Text(
                  'Specific Emergency Services:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),

                _buildEmergencyNumberCard(
                  '👮 Police',
                  emergencyNumbers.police,
                  'Crime, accidents, immediate danger',
                  Colors.blue[700]!,
                ),

                _buildEmergencyNumberCard(
                  '🚒 Fire Department',
                  emergencyNumbers.fire,
                  'Fires, explosions, gas leaks',
                  Colors.orange[700]!,
                ),

                _buildEmergencyNumberCard(
                  '🚑 Ambulance/Medical',
                  emergencyNumbers.ambulance,
                  'Medical emergencies, serious injuries',
                  Colors.green[700]!,
                ),

                const SizedBox(height: 16),

                // Support Services
                const Text(
                  'Support & Crisis Services:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),

                _buildEmergencyNumberCard(
                  '☠️ Poison Control',
                  emergencyNumbers.poisonControl,
                  'Poisoning, overdose, toxic exposure',
                  Colors.purple[700]!,
                ),

                _buildEmergencyNumberCard(
                  '🧠 Mental Health Crisis',
                  emergencyNumbers.mentalHealth,
                  'Suicide prevention, mental health crisis',
                  Colors.teal[700]!,
                ),

                _buildEmergencyNumberCard(
                  '🏠 Domestic Violence',
                  emergencyNumbers.domesticViolence,
                  'Domestic abuse, violence, safety',
                  Colors.pink[700]!,
                ),

                const SizedBox(height: 16),

                // Location info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on,
                          color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          numbers != null
                              ? 'Numbers updated for your location: ${emergencyNumbers.countryName}'
                              : 'Unable to get location. Showing international numbers.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () => _showManualCountrySelection(context),
            icon: const Icon(Icons.public, size: 18),
            label: const Text('Change Country'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyNumberCard(
    String title,
    String number,
    String description,
    Color color, {
    bool isUrgent = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: isUrgent ? 4 : 2,
        color: isUrgent ? Colors.red[50] : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isUrgent
              ? BorderSide(color: Colors.red[300]!, width: 2)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: isUrgent ? 16 : 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      number,
                      style: TextStyle(
                        fontSize: isUrgent ? 18 : 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _callEmergencyNumber(number),
                icon: Icon(
                  Icons.phone,
                  color: color,
                  size: isUrgent ? 28 : 24,
                ),
                tooltip: 'Call $number',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _callEmergencyNumber(String number) {
    // Remove any formatting and extract just the numbers
    final cleanNumber = number.replaceAll(RegExp(r'[^\d\+]'), '');

    if (cleanNumber.isNotEmpty) {
      // For now, show the number to dial
      showBlurDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Emergency Call'),
          content: Text(
              'Dial: $number\n\nFor immediate assistance, use your device\'s phone app to call this number.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showManualCountrySelection(BuildContext context) {
    Navigator.pop(context); // Close emergency dialog

    showBlurDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Country'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: EmergencyService.getAvailableCountries().map((code) {
                final numbers =
                    EmergencyService.getEmergencyNumbersForCountry(code);
                return ListTile(
                  title: Text(numbers.countryName),
                  subtitle: Text('Emergency: ${numbers.emergency}'),
                  trailing: Text(code),
                  onTap: () {
                    Navigator.pop(context);
                    _showEmergencyInfoDialog(context, numbers);
                  },
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
