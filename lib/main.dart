import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart'; // Use flutter_timezone instead of flutter_native_timezone
import 'utils/app_state.dart';
import 'services/deepseek_service.dart';
import 'services/onboarding_service.dart';
import 'services/notification_service.dart'; // Import your notification service
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/symptom_checker_screen.dart';
import 'screens/medication_warning_screen.dart';

void main() async {
  // CRITICAL: Ensure Flutter is initialized before any async operations
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load environment variables
    await dotenv.load(fileName: ".env");
    if (kDebugMode) {
      print('✅ .env loaded successfully');
    }
  } catch (e) {
    if (kDebugMode) {
      print('⚠️ Warning: .env file not found: $e');
    }
  }

  try {
    // Initialize timezone database
    if (kDebugMode) {
      print('🌍 Initializing timezone database...');
    }
    tz.initializeTimeZones();

    // Get device's local timezone
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    if (kDebugMode) {
      print('📍 Device timezone: $timeZoneName');
    }

    // Handle special cases (e.g., Kiev -> Kyiv)
    final String normalizedTimeZone =
        timeZoneName == "Europe/Kiev" ? "Europe/Kyiv" : timeZoneName;

    // Set local location for timezone-aware notifications
    tz.setLocalLocation(tz.getLocation(normalizedTimeZone));
    if (kDebugMode) {
      print('✅ Timezone set to: ${tz.local}');
    }
  } catch (e) {
    if (kDebugMode) {
      print('⚠️ Timezone initialization failed, falling back to UTC: $e');
    }
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  }

  try {
    // Initialize notification service
    if (kDebugMode) {
      print('🔔 Initializing notification service...');
    }
    await NotificationService.initialize();
    if (kDebugMode) {
      print('✅ Notification service initialized');
    }

    // Request notification permissions
    final hasPermission = await NotificationService.requestPermissions();
    if (hasPermission) {
      if (kDebugMode) {
        print('✅ Notification permissions granted');
      }
    } else {
      if (kDebugMode) {
        print('⚠️ Notification permissions denied');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('⚠️ Notification service initialization failed: $e');
    }
    // App will continue without notifications
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AppState()),
        Provider(create: (context) {
          try {
            return DeepSeekService();
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ DeepSeekService initialization failed: $e');
            }
            return null;
          }
        }),
      ],
      child: MaterialApp(
        title: 'MediPal',
        theme: _buildLightTheme(),
        darkTheme: _buildDarkTheme(),
        themeMode: ThemeMode.system,
        home: const InitialScreen(),
        routes: {
          '/home': (context) => const HomeScreen(),
          '/onboarding': (context) => const OnboardingScreen(),
          '/chat': (context) => const ChatScreen(),
          '/symptoms': (context) => const SymptomCheckerScreen(),
          '/medications': (context) => const MedicationWarningScreen(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

ThemeData _buildLightTheme() {
  const seedColor = Colors.blue;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    brightness: Brightness.light,

    // AppBar Theme
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),

    // Card Theme
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: colorScheme.surface,
    ),

    // Elevated Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
    ),

    // Floating Action Button Theme
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 4,
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
    ),

    // Divider Theme
    dividerTheme: DividerThemeData(
      color: colorScheme.outline.withValues(alpha: 150),
      thickness: 1,
    ),
  );
}

// Dark Theme Configuration
ThemeData _buildDarkTheme() {
  const seedColor = Colors.blue;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.dark,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    brightness: Brightness.dark,

    // AppBar Theme
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),

    // Card Theme
    cardTheme: CardThemeData(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 230),
    ),

    // Elevated Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 3,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 230),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: colorScheme.outline.withValues(alpha: 150)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
    ),

    // Floating Action Button Theme
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 6,
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
    ),

    // Divider Theme
    dividerTheme: DividerThemeData(
      color: colorScheme.outline.withOpacity(0.3),
      thickness: 1,
    ),

    // Bottom Navigation Bar Theme
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: colorScheme.surface,
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: colorScheme.onSurface.withOpacity(0.6),
      elevation: 8,
    ),
  );
}

// Initial screen that decides whether to show onboarding
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

      // Load user profile first
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.loadUserProfile();

      setState(() {
        _status = 'Setting up notifications...';
      });

      // Initialize medication reminders after loading profile
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

      // Check onboarding status
      final isOnboardingCompleted =
          await OnboardingService.isOnboardingCompleted();

      setState(() {
        _status = 'Launching app...';
      });

      // Small delay for smooth transition
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        if (isOnboardingCompleted) {
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          Navigator.of(context).pushReplacementNamed('/onboarding');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during app initialization: $e');
      }

      // Fallback: show error and allow manual navigation
      if (mounted) {
        setState(() {
          _status = 'Error during initialization';
          _isLoading = false;
        });

        // Show error dialog after a short delay
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
            // App Logo
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
