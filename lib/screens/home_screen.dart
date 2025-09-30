import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:provider/provider.dart';
import '../utils/app_state.dart';
import '../widgets/health_summary_card.dart';
import '../services/emergency_service.dart';

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
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.psychology,
                color: colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'PersonalMedAI',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _showProfileDialog(context),
            icon: const Icon(Icons.account_circle),
            tooltip: 'Profile',
          ),
          IconButton(
            onPressed: () => _showSettingsDialog(context),
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _getHealthInsights(context, showDialog: false);
          if (mounted) {
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
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Consumer<AppState>(
                builder: (context, appState, child) {
                  return _buildPersonalizedWelcomeCard(
                      appState, colorScheme, theme);
                },
              ),
              const SizedBox(height: 24),
              Consumer<AppState>(
                builder: (context, appState, child) {
                  return _buildQuickActionsSection(appState, theme);
                },
              ),
              const SizedBox(height: 32),
              Consumer<AppState>(
                builder: (context, appState, child) {
                  return _buildHealthSummarySection(appState, theme);
                },
              ),
              const SizedBox(height: 32),
              Consumer<AppState>(
                builder: (context, appState, child) {
                  return _buildPersonalizedTipsSection(
                      appState, theme, colorScheme);
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      floatingActionButton: Consumer<AppState>(
        builder: (context, appState, child) {
          return FloatingActionButton.extended(
            onPressed: () => Navigator.pushNamed(context, '/chat'),
            icon: const Icon(Icons.psychology),
            label: Text(
              appState.isMinor ? 'Ask Questions' : 'Ask AI',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            elevation: 4,
            backgroundColor: appState.isMinor ? Colors.orange : null,
          );
        },
      ),
    );
  }

  Widget _buildPersonalizedWelcomeCard(
      AppState appState, ColorScheme colorScheme, ThemeData theme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer.withOpacity(0.8),
              colorScheme.secondaryContainer.withOpacity(0.6),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appState.personalizedGreeting,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getAgeAppropriateSubtitle(appState),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color:
                              colorScheme.onPrimaryContainer.withOpacity(0.8),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    appState.isMinor ? Icons.school : Icons.favorite,
                    color: colorScheme.primary,
                    size: 40,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Age-appropriate information bar
            if (appState.isMinor)
              _buildMinorSafetyBar(colorScheme, theme)
            else
              _buildHealthStatsRow(appState, colorScheme),
          ],
        ),
      ),
    );
  }

  String _getAgeAppropriateSubtitle(AppState appState) {
    if (appState.isMinor) {
      return 'Remember to talk to trusted adults about health questions! 🌟';
    } else if (appState.isYoungAdult) {
      return 'Building healthy habits for your future! 💪';
    } else {
      return 'How are you feeling today? 💙';
    }
  }

  Widget _buildMinorSafetyBar(ColorScheme colorScheme, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.family_restroom, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Young User Mode: Always consult with parents or guardians',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  // FIXED: Health stats row WITHOUT health score
  Widget _buildHealthStatsRow(AppState appState, ColorScheme colorScheme) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _buildQuickStat(
          '${appState.medications.length}',
          'Medications',
          Icons.medication,
          colorScheme,
        ),
        _buildQuickStat(
          appState.symptomAnalysis.isNotEmpty ? '1' : '0',
          'Consultations',
          Icons.chat,
          colorScheme,
        ),
      ],
    );
  }

  Widget _buildQuickActionsSection(AppState appState, ThemeData theme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                appState.isMinor ? 'Things You Can Do' : 'Quick Actions',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            if (!appState.isMinor)
              TextButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/chat'),
                icon: const Icon(Icons.chat, size: 18),
                label: const Text(
                  'AI Chat',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 70,
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
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                appState.isMinor ? 'Health Information' : 'Health Summary',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            TextButton.icon(
              onPressed: () => _showPersonalizedHealthTips(context, appState),
              icon: const Icon(Icons.tips_and_updates, size: 18),
              label: const Text(
                'Tips',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          children: _buildAgeAppropriateHealthCards(appState),
        ),
      ],
    );
  }

  List<Widget> _buildAgeAppropriateHealthCards(AppState appState) {
    List<Widget> cards = [];

    if (appState.isMinor) {
      cards.addAll([
        HealthSummaryCard(
          title: "Health Questions",
          content: "Ask me about health topics appropriate for your age",
          subtitle: "Always remember to talk to trusted adults too!",
          icon: Icons.help,
          onTap: () => _showMinorChatInfo(context),
        ),
        HealthSummaryCard(
          title: "Healthy Habits",
          content: "Learn about staying healthy and strong",
          subtitle: "Fun tips for young people",
          icon: Icons.fitness_center,
          onTap: () => _showPersonalizedHealthTips(context, appState),
        ),
        HealthSummaryCard(
          title: "When to Tell Adults",
          content: "Learn when it's important to talk to grown-ups",
          subtitle: "Your safety is most important",
          icon: Icons.family_restroom,
          onTap: () => _showMinorGuidance(context),
        ),
      ]);
    } else {
      cards.addAll([
        HealthSummaryCard(
          title: "AI Health Insights",
          content: "Get personalized health recommendations",
          subtitle: "Powered by PersonalMedAI",
          icon: Icons.insights,
          isLoading: _isGettingInsights,
          onTap: () => _getHealthInsights(context),
        ),
        HealthSummaryCard(
          title: "Medications",
          content: appState.medications.isNotEmpty
              ? "${appState.medications.length} medication${appState.medications.length != 1 ? 's' : ''} tracked"
              : "No medications added yet",
          subtitle: appState.medications.isNotEmpty
              ? "Latest: ${appState.medications.last.name}"
              : "Tap to add your first medication",
          icon: Icons.medication,
          onTap: () => Navigator.pushNamed(context, '/medications'),
        ),
        HealthSummaryCard(
          title: "AI Consultations",
          content: appState.symptomAnalysis.isNotEmpty
              ? "Recent consultation available"
              : "No recent consultations",
          subtitle: appState.symptomAnalysis.isNotEmpty
              ? "Tap to view last analysis"
              : "Start your first consultation",
          icon: Icons.psychology,
          onTap: () {
            if (appState.symptomAnalysis.isNotEmpty) {
              _showLastConsultation(context, appState.symptomAnalysis);
            } else {
              Navigator.pushNamed(context, '/chat');
            }
          },
        ),
      ]);
    }

    return cards;
  }

  Widget _buildPersonalizedTipsSection(
      AppState appState, ThemeData theme, ColorScheme colorScheme) {
    final tips = appState.personalizedHealthTips.take(3).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    appState.isMinor
                        ? 'Tips Just for You!'
                        : 'Personalized Health Tips',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      _showPersonalizedHealthTips(context, appState),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...tips.map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tip.split(' ')[0], // Get emoji
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tip.substring(
                              tip.indexOf(' ') + 1), // Get text after emoji
                          style: theme.textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedPillButton(
      String text, IconData icon, Color color, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: Colors.white),
        label: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 3,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStat(
      String value, String label, IconData icon, ColorScheme colorScheme) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: colorScheme.onPrimaryContainer.withOpacity(0.7),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '$value $label',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.onPrimaryContainer.withOpacity(0.8),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  // FIXED: Profile dialog using separate widget to avoid TextEditingController disposal issues
  void _showProfileDialog(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => ProfileEditDialog(appState: appState),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.settings, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Settings',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text(
                'Edit Profile',
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: const Text(
                'Update your personal information',
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.pop(context);
                _showProfileDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text(
                'Notifications',
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: const Text(
                'Coming soon',
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _showComingSoonDialog(context, 'Notifications'),
            ),
            ListTile(
              leading: const Icon(Icons.security),
              title: const Text(
                'Privacy',
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: const Text(
                'Coming soon',
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _showComingSoonDialog(context, 'Privacy Settings'),
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text(
                'About',
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: const Text(
                'PersonalMedAI v1.0.0',
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _showAboutDialog(context),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _getHealthInsights(BuildContext context,
      {bool showDialog = true}) async {
    final appState = Provider.of<AppState>(context, listen: false);

    setState(() {
      _isGettingInsights = true;
    });

    try {
      await Future.delayed(const Duration(seconds: 2));
      final insights = _generateAgeAppropriateInsights(appState);

      if (mounted) {
        setState(() {
          _isGettingInsights = false;
        });

        if (showDialog) {
          _showInsightsDialog(context, insights, appState);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGettingInsights = false;
        });

        if (showDialog) {
          _showErrorDialog(context, appState.getAgeAppropriateErrorMessage());
        }
      }
    }
  }

  String _generateAgeAppropriateInsights(AppState appState) {
    if (appState.isMinor) {
      return '''
Hi ${appState.userName}! 🌟

Here are some special health tips just for you:

🏃‍♀️ **Stay Active:** Try to play outside or do fun activities every day! Dancing, bike riding, or playing sports are great ways to stay strong.

😴 **Get Good Sleep:** Young people like you need 9-11 hours of sleep each night to grow big and strong!

🥕 **Eat Healthy Foods:** Try to eat colorful fruits and vegetables. They're like superpowers for your body!

💧 **Drink Water:** Water helps your body work its best. Try to drink water instead of sugary drinks.

🧠 **Talk to Adults:** Always remember to tell a trusted adult if you don't feel well or have questions about your health.

Remember: You're doing great by learning about staying healthy! Keep up the good work! 💪
      ''';
    } else {
      return '''
Hello ${appState.userName}! 

Based on your health profile, here are personalized insights:

💊 **Medications:** You're tracking ${appState.medications.length} medication${appState.medications.length != 1 ? 's' : ''}. Great job staying organized!

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

  void _showInsightsDialog(
      BuildContext context, String insights, AppState appState) {
    showDialog(
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
    showDialog(
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
    showDialog(
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
    showDialog(
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
    showDialog(
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
    showDialog(
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

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        showDialog(
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
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        // Show generic emergency info if location fails
        showDialog(
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
  }

  // ENHANCED: Emergency info with location-based emergency numbers
  void _showEmergencyInfo(BuildContext context) async {
    // Show loading dialog first
    showDialog(
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
      if (mounted) {
        Navigator.pop(context);

        // Show emergency info with local numbers
        _showEmergencyInfoDialog(context, emergencyNumbers);
      }
    } catch (e) {
      // Close loading dialog and show error
      if (mounted) {
        Navigator.pop(context);
        _showEmergencyInfoDialog(context, null);
      }
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

    showDialog(
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
      showDialog(
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

    showDialog(
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

  void _showLastConsultation(BuildContext context, String analysis) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.psychology, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Last Consultation',
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
            child: SelectionArea(child: Text(analysis)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/chat');
            },
            child: const Text('New Chat'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.psychology, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'About PersonalMedAI',
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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PersonalMedAI v1.0.0'),
                SizedBox(height: 8),
                Text(
                    'Your personal AI health assistant powered by advanced language models.'),
                SizedBox(height: 16),
                Text('Features:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('• Age-appropriate health guidance'),
                Text('• AI-powered symptom analysis'),
                Text('• Medication interaction checking'),
                Text('• Location-based emergency numbers'),
                Text('• Personalized health insights and tips'),
                Text('• 24/7 AI chat support'),
                Text('• Safe mode for young users'),
                SizedBox(height: 16),
                Text(
                  '⚠️ This app provides information only and does not replace professional medical advice.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
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
        ],
      ),
    );
  }

  void _showComingSoonDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          feature,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              '$feature is coming soon!',
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'We are working hard to bring you this feature.',
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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

// FIXED: Separate ProfileEditDialog widget to handle TextEditingController properly
class ProfileEditDialog extends StatefulWidget {
  final AppState appState;

  const ProfileEditDialog({super.key, required this.appState});

  @override
  State<ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<ProfileEditDialog> {
  late final TextEditingController nameController;
  late final TextEditingController emailController;
  late final TextEditingController ageController;
  late String selectedGender;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.appState.userName);
    emailController = TextEditingController(text: widget.appState.userEmail);
    ageController = TextEditingController(
        text: widget.appState.userAge > 0
            ? widget.appState.userAge.toString()
            : '');
    selectedGender = widget.appState.userGender;
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.person, color: Colors.blue),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Profile Settings',
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
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (Optional)',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ageController,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  prefixIcon: Icon(Icons.cake),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              const Text(
                'Gender',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildGenderOption('Male', Icons.male)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildGenderOption('Female', Icons.female)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildGenderOption('Other', Icons.person)),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.appState.isMinor
                      ? Colors.orange.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.appState.isMinor
                        ? Colors.orange.shade200
                        : Colors.blue.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.appState.isMinor ? Icons.school : Icons.person,
                      color: widget.appState.isMinor
                          ? Colors.orange.shade700
                          : Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.appState.isMinor
                            ? 'Young User Mode - Always consult with parents or guardians'
                            : widget.appState.isYoungAdult
                                ? 'Young Adult Mode - Building healthy habits for your future'
                                : 'Adult Mode - Full access to all health features',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: widget.appState.isMinor
                              ? Colors.orange.shade700
                              : Colors.blue.shade700,
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
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveProfile,
          child: const Text('Save Changes'),
        ),
      ],
    );
  }

  Widget _buildGenderOption(String gender, IconData icon) {
    final isSelected = selectedGender == gender;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedGender = gender;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurface.withOpacity(0.7),
            ),
            const SizedBox(height: 4),
            Text(
              gender,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    try {
      int? age;
      if (ageController.text.trim().isNotEmpty) {
        age = int.tryParse(ageController.text.trim());
        if (age == null || age < 1 || age > 150) {
          _showErrorSnackBar('Please enter a valid age between 1 and 150');
          return;
        }
      }

      await widget.appState.setUserName(nameController.text.trim());
      await widget.appState.setUserEmail(emailController.text.trim());

      if (age != null) {
        await widget.appState.setUserAge(age);
      }

      if (selectedGender.isNotEmpty) {
        await widget.appState.setUserGender(selectedGender);
      }

      if (mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Error saving profile: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
