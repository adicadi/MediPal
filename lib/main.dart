import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/symptom_checker_screen.dart';
import 'screens/medication_warning_screen.dart';
import 'theme/app_theme.dart';
import 'services/deepseek_service.dart';
import 'utils/app_state.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
    print('✅ Environment variables loaded successfully');
  } catch (e) {
    print('⚠️ Warning: Could not load .env file: $e');
    print(
        'Make sure you have a .env file in your project root with DEEPSEEK_API_KEY');
  }

  runApp(const PersonalMedAIApp());
}

class PersonalMedAIApp extends StatelessWidget {
  const PersonalMedAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        Provider(create: (_) => DeepSeekService()),
      ],
      child: MaterialApp(
        title: 'PersonalMedAI',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
        routes: {
          '/home': (context) => const HomeScreen(),
          '/symptoms': (context) => const SymptomCheckerScreen(),
          '/medications': (context) => const MedicationWarningScreen(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
