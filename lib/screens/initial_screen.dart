import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utils/app_state.dart';
import '../services/onboarding_service.dart';

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  bool _isLoading = true;
  String _status = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() {
        _status = 'Loading user data...';
      });

      final appState = Provider.of<AppState>(context, listen: false);
      await appState.loadUserProfile();

      setState(() {
        _status = 'Setting up notifications...';
      });

      try {
        await appState.initializeNotifications();
        if (kDebugMode) {
          print('✅ Medication reminders initialized');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Could not initialize medication reminders: $e');
        }
      }

      setState(() {
        _status = 'Checking onboarding status...';
      });

      final isOnboardingCompleted =
          await OnboardingService.isOnboardingCompleted();

      setState(() {
        _status = 'Launching app...';
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) {
        return;
      }

      if (isOnboardingCompleted) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during app initialization: $e');
      }

      if (mounted) {
        setState(() {
          _status = 'Error during initialization';
          _isLoading = false;
        });

        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _showErrorDialog();
          }
        });
      }
    }
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Initialization Issue'),
          ],
        ),
        content: const Text(
          'There was an issue during app initialization. You can continue to use the app, but some features may not work properly.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacementNamed('/home');
            },
            child: const Text('Continue Anyway'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacementNamed('/onboarding');
            },
            child: const Text('Setup Account'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primaryContainer,
                    colorScheme.secondaryContainer,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                Icons.psychology,
                size: 80,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'MediPal',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Your Personal Health Assistant',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            if (_isLoading) ...[
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(colorScheme.primary),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _status,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              const Icon(
                Icons.error_outline,
                color: Colors.orange,
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                _status,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.orange,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/home');
                    },
                    child: const Text('Go to Home'),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/onboarding');
                    },
                    child: const Text('Setup Account'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
