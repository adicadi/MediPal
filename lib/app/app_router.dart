import 'package:flutter/material.dart';

import '../screens/onboarding_screen.dart';
import '../screens/home_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/symptom_checker_screen.dart';
import '../screens/medication_warning_screen.dart';
import '../screens/wearable_settings_screen.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/home': (context) => const HomeScreen(),
  '/onboarding': (context) => const OnboardingScreen(),
  '/chat': (context) => const ChatScreen(),
  '/symptoms': (context) => const SymptomCheckerScreen(),
  '/medications': (context) => const MedicationWarningScreen(),
  '/wearables': (context) => const WearableSettingsScreen(),
};
