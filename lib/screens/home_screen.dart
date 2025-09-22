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
        title: Text(
          'PersonalMedAI',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              _showProfileDialog(context);
            },
            icon: const Icon(Icons.account_circle),
            tooltip: 'Profile',
          ),
          IconButton(
            onPressed: () {
              _showSettingsDialog(context);
            },
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh health data
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Health data refreshed'),
                behavior: SnackBarBehavior.floating,
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
              // Welcome Card
              Consumer<AppState>(
                builder: (context, appState, child) {
                  return Card(
                    elevation: 3,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primaryContainer.withOpacity(0.5),
                            colorScheme.secondaryContainer.withOpacity(0.3),
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
                                  '${_getGreeting()}, ${appState.userName}!',
                                  style:
                                      theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
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
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.favorite,
                              color: colorScheme.primary,
                              size: 32,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Quick Actions Section
              Text(
                'Quick Actions',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 60,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    PillButton(
                      text: 'Symptom Checker',
                      icon: Icons.search,
                      onPressed: () {
                        Navigator.pushNamed(context, '/symptoms');
                      },
                    ),
                    PillButton(
                      text: 'Medication Info',
                      icon: Icons.medication,
                      onPressed: () {
                        Navigator.pushNamed(context, '/medications');
                      },
                    ),
                    PillButton(
                      text: 'Emergency Guide',
                      icon: Icons.emergency,
                      onPressed: () {
                        _showComingSoonDialog(context, 'Emergency Guide');
                      },
                    ),
                    PillButton(
                      text: 'My Records',
                      icon: Icons.folder,
                      onPressed: () {
                        _showComingSoonDialog(context, 'My Records');
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Health Summary Section
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
                    onPressed: () {
                      _showHealthTips(context);
                    },
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
                        title: "Today's Insights",
                        content: "Good sleep last night - 8.5 hours",
                        subtitle: "Activity goal met: 10,000 steps",
                        icon: Icons.insights,
                        isLoading: _isGettingInsights,
                        onTap: () => _getHealthInsights(context),
                      ),
                      HealthSummaryCard(
                        title: "Upcoming Medications",
                        content: appState.medications.isNotEmpty
                            ? "${appState.medications.first.name} - Next dose in 2 hours"
                            : "No medications scheduled",
                        subtitle: appState.medications.length > 1
                            ? "${appState.medications.length} medications total"
                            : appState.medications.isEmpty
                                ? "Tap to add medications"
                                : null,
                        icon: Icons.schedule,
                        onTap: () {
                          Navigator.pushNamed(context, '/medications');
                        },
                      ),
                      HealthSummaryCard(
                        title: "Recent Consultations",
                        content: appState.symptomAnalysis.isNotEmpty
                            ? "Last AI consultation: Today"
                            : "No recent consultations",
                        subtitle: appState.symptomAnalysis.isNotEmpty
                            ? "Tap to view analysis"
                            : "Start your first consultation",
                        icon: Icons.chat,
                        onTap: () {
                          if (appState.symptomAnalysis.isNotEmpty) {
                            _showLastConsultation(
                                context, appState.symptomAnalysis);
                          } else {
                            Navigator.pushNamed(context, '/symptoms');
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
      /*floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startAIConsultation(context),
        icon: const Icon(Icons.psychology),
        label: const Text('Ask PersonalMedAI'),
        elevation: 4,
      ),*/

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            Navigator.pushNamed(context, '/chat'), // Change this line
        icon: const Icon(Icons.chat),
        label: const Text('AI Chat'),
        elevation: 4,
      ),
    );
  }

  void _showProfileDialog(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Your Name',
                prefixIcon: Icon(Icons.person),
              ),
              controller: TextEditingController(text: appState.userName),
              onChanged: (value) {
                appState.setUserName(value);
              },
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
        title: const Text('Settings'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.notifications),
              title: Text('Notifications'),
              subtitle: Text('Coming soon'),
            ),
            ListTile(
              leading: Icon(Icons.security),
              title: Text('Privacy'),
              subtitle: Text('Coming soon'),
            ),
            ListTile(
              leading: Icon(Icons.info),
              title: Text('About'),
              subtitle: Text('PersonalMedAI v1.0.0'),
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
        title: Text(feature),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.construction,
              size: 48,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text('$feature feature is coming soon!'),
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

  void _showLastConsultation(BuildContext context, String analysis) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Last Consultation'),
        content: SingleChildScrollView(
          child: Text(analysis),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/symptoms');
            },
            child: const Text('New Consultation'),
          ),
        ],
      ),
    );
  }

  void _showHealthTips(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Health Tips'),
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

  Future<void> _getHealthInsights(BuildContext context) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final deepSeekService =
        Provider.of<DeepSeekService>(context, listen: false);

    setState(() {
      _isGettingInsights = true;
    });

    try {
      final insights =
          await deepSeekService.getHealthInsights(appState.getHealthData());

      if (mounted) {
        setState(() {
          _isGettingInsights = false;
        });

        _showInsightsDialog(context, insights);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGettingInsights = false;
        });
        _showErrorDialog(
            context, 'Unable to get health insights at this time.');
      }
    }
  }

  void _showInsightsDialog(BuildContext context, String insights) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.insights, color: Colors.blue),
            SizedBox(width: 8),
            Text('AI Health Insights'),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(insights),
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

  Future<void> _startAIConsultation(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI Consultation'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.psychology,
              size: 48,
              color: Colors.teal,
            ),
            SizedBox(height: 16),
            Text('What would you like to discuss with PersonalMedAI today?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/symptoms');
            },
            child: const Text('Check Symptoms'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/medications');
            },
            child: const Text('Medication Help'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
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
