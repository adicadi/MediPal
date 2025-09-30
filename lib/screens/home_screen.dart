import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_state.dart';
import '../widgets/pill_button.dart';
import '../widgets/health_summary_card.dart';
import '../services/deepseek_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isGettingInsights = false;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

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
            Text(
              'PersonalMedAI',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
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
          // Refresh health data and get new insights
          await _getHealthInsights(context, showDialog: false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Health data refreshed'),
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
              // Enhanced Welcome Card
              Consumer<AppState>(
                builder: (context, appState, child) {
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
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_getGreeting()}, ${appState.userName.isNotEmpty ? appState.userName : 'there'}!',
                                  style:
                                      theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'How are you feeling today?',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.onPrimaryContainer
                                        .withOpacity(0.8),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Quick stats
                                Row(
                                  children: [
                                    _buildQuickStat(
                                      '${appState.medications.length}',
                                      'Medications',
                                      Icons.medication,
                                      colorScheme,
                                    ),
                                    const SizedBox(width: 16),
                                    _buildQuickStat(
                                      appState.symptomAnalysis.isNotEmpty
                                          ? '1'
                                          : '0',
                                      'Consultations',
                                      Icons.chat,
                                      colorScheme,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Icon(
                              Icons.favorite,
                              color: colorScheme.primary,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Enhanced Quick Actions Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quick Actions',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  /*TextButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/chat'),
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('AI Chat'),
                  ),*/
                ],
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 70,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
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
                    /*_buildEnhancedPillButton(
                      'AI Chat',
                      Icons.psychology,
                      Colors.purple,
                      () => Navigator.pushNamed(context, '/chat'),
                    ),*/
                    _buildEnhancedPillButton(
                      'Emergency',
                      Icons.emergency,
                      Colors.red,
                      () => _showEmergencyInfo(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Enhanced Health Summary Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Health Summary',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showHealthTips(context),
                    icon: const Icon(Icons.tips_and_updates, size: 18),
                    label: const Text('Tips'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Consumer<AppState>(
                builder: (context, appState, child) {
                  return Column(
                    children: [
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
                        onTap: () =>
                            Navigator.pushNamed(context, '/medications'),
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
                            _showLastConsultation(
                                context, appState.symptomAnalysis);
                          } else {
                            Navigator.pushNamed(context, '/chat');
                          }
                        },
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/chat'),
        icon: const Icon(Icons.psychology),
        label: const Text('Ask AI'),
        elevation: 4,
      ),
    );
  }

  // Enhanced pill button with colors
  Widget _buildEnhancedPillButton(
      String text, IconData icon, Color color, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: Colors.white),
        label: Text(
          text,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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

  // Quick stat widget
  Widget _buildQuickStat(
      String value, String label, IconData icon, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: colorScheme.onPrimaryContainer.withOpacity(0.7),
        ),
        const SizedBox(width: 4),
        Text(
          '$value $label',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colorScheme.onPrimaryContainer.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  void _showProfileDialog(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    final nameController = TextEditingController(text: appState.userName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.person, color: Colors.blue),
            SizedBox(width: 8),
            Text('Profile Settings'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Your Name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              controller: nameController,
              onChanged: (value) => appState.setUserName(value),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your name helps PersonalMedAI provide personalized responses.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
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

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.settings, color: Colors.blue),
            SizedBox(width: 8),
            Text('Settings'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notifications'),
              subtitle: const Text('Coming soon'),
              onTap: () => _showComingSoonDialog(context, 'Notifications'),
            ),
            ListTile(
              leading: const Icon(Icons.security),
              title: const Text('Privacy'),
              subtitle: const Text('Coming soon'),
              onTap: () => _showComingSoonDialog(context, 'Privacy Settings'),
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('About'),
              subtitle: const Text('PersonalMedAI v1.0.0'),
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

  void _showAboutDialog(BuildContext context) {
    Navigator.pop(context); // Close settings dialog first
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.psychology, color: Colors.blue),
            SizedBox(width: 8),
            Text('About PersonalMedAI'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PersonalMedAI v1.0.0'),
            SizedBox(height: 8),
            Text(
                'Your personal AI health assistant powered by advanced language models.'),
            SizedBox(height: 16),
            Text('Features:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• AI-powered symptom analysis'),
            Text('• Medication interaction checking'),
            Text('• Health insights and tips'),
            Text('• 24/7 AI chat support'),
            SizedBox(height: 16),
            Text(
              '⚠️ This app provides information only and does not replace professional medical advice.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
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

  void _showComingSoonDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(feature),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text('$feature is coming soon!'),
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

  void _showEmergencyInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.emergency, color: Colors.red),
            SizedBox(width: 8),
            Text('Emergency Information'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🚨 CALL 911 IMMEDIATELY FOR:',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              SizedBox(height: 8),
              Text('• Difficulty breathing or chest pain'),
              Text('• Severe bleeding or major injuries'),
              Text('• Loss of consciousness'),
              Text('• Severe allergic reactions'),
              Text('• Signs of stroke or heart attack'),
              SizedBox(height: 16),
              Text(
                'Other Important Numbers:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Poison Control: 1-800-222-1222'),
              Text('• Crisis Text Line: Text HOME to 741741'),
              Text('• National Suicide Prevention: 988'),
            ],
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

  void _showLastConsultation(BuildContext context, String analysis) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.psychology, color: Colors.blue),
            SizedBox(width: 8),
            Text('Last Consultation'),
          ],
        ),
        content: SingleChildScrollView(
          child: SelectionArea(child: Text(analysis)),
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

  void _showHealthTips(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.tips_and_updates, color: Colors.green),
            SizedBox(width: 8),
            Text('Health Tips'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('💧 Stay hydrated - drink 8 glasses of water daily'),
              SizedBox(height: 8),
              Text('🚶‍♀️ Take 10,000 steps per day for optimal health'),
              SizedBox(height: 8),
              Text('😴 Get 7-9 hours of quality sleep each night'),
              SizedBox(height: 8),
              Text('🥗 Eat a balanced diet with fruits and vegetables'),
              SizedBox(height: 8),
              Text('🧘‍♀️ Practice stress management and mindfulness'),
              SizedBox(height: 8),
              Text('👩‍⚕️ Regular check-ups with healthcare providers'),
              SizedBox(height: 8),
              Text('📱 Use PersonalMedAI for health questions anytime!'),
            ],
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

  // FIXED: Enhanced health insights method
  Future<void> _getHealthInsights(BuildContext context,
      {bool showDialog = true}) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final deepSeekService =
        Provider.of<DeepSeekService>(context, listen: false);

    setState(() {
      _isGettingInsights = true;
    });

    try {
      // Get health data from app state
      final healthData = appState.getHealthData();

      // Call the health insights method
      final insights = await deepSeekService.getHealthInsights(healthData);

      if (mounted) {
        setState(() {
          _isGettingInsights = false;
        });

        if (showDialog) {
          _showInsightsDialog(context, insights);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGettingInsights = false;
        });

        if (showDialog) {
          _showErrorDialog(context,
              'Unable to get health insights at this time. Please try again later.');
        }
      }
    }
  }

  void _showInsightsDialog(BuildContext context, String insights) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.psychology, color: Colors.blue),
            SizedBox(width: 8),
            Text('AI Health Insights'),
          ],
        ),
        content: SingleChildScrollView(
          child: SelectionArea(child: Text(insights)),
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
            label: const Text('Chat with AI'),
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
            Text('Error'),
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
}
