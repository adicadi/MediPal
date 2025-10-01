import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../models/medication.dart'; // Import the external Medication model
import 'dart:convert';

class AppState extends ChangeNotifier {
  // User profile data (enhanced for onboarding)
  String _userName = '';
  String _userEmail = '';
  int _userAge = 0;
  String _userGender = '';

  // Existing symptom and medication data
  final List<String> _selectedSymptoms = [];
  String _selectedSeverity = '';
  final List<Medication> _medications = [
    Medication.fromLegacy('Aspirin', '81mg', 'Daily'),
    Medication.fromLegacy('Lisinopril', '10mg', 'Daily'),
  ];
  String _symptomAnalysis = '';
  String _medicationInteractionResult = '';
  bool _isLoading = false;
  final Map<String, dynamic> _additionalSymptomInfo = {};

  // Chat history support
  final List<ChatMessage> _chatMessages = [];

  // Getters - existing
  String get userName => _userName;
  List<String> get selectedSymptoms => List.unmodifiable(_selectedSymptoms);
  String get selectedSeverity => _selectedSeverity;
  List<Medication> get medications => List.unmodifiable(_medications);
  String get symptomAnalysis => _symptomAnalysis;
  String get medicationInteractionResult => _medicationInteractionResult;
  bool get isLoading => _isLoading;
  Map<String, dynamic> get additionalSymptomInfo =>
      Map.from(_additionalSymptomInfo);

  // Getters - new user profile
  String get userEmail => _userEmail;
  int get userAge => _userAge;
  String get userGender => _userGender;

  // Getters - chat
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);

  // NEW: Age-based content restrictions
  bool get isMinor => _userAge > 0 && _userAge < 18;
  bool get isYoungAdult => _userAge >= 18 && _userAge < 25;
  bool get isAdult => _userAge >= 25;

  // NEW: Medication reminder getters
  List<Medication> get medicationsNeedingRefill {
    return _medications.where((med) => med.needsRefill).toList();
  }

  List<Medication> get medicationsWithReminders {
    return _medications
        .where((med) => med.remindersEnabled && med.reminders.isNotEmpty)
        .toList();
  }

  int get totalActiveReminders {
    return _medications.where((med) => med.remindersEnabled).fold(
        0, (sum, med) => sum + med.reminders.where((r) => r.enabled).length);
  }

  // NEW: Get personalized greeting with time awareness
  String get personalizedGreeting {
    final timeOfDay = DateTime.now().hour;
    String greeting;
    String emoji;

    if (timeOfDay < 6) {
      greeting = 'Good night';
      emoji = '🌙';
    } else if (timeOfDay < 12) {
      greeting = 'Good morning';
      emoji = '🌅';
    } else if (timeOfDay < 17) {
      greeting = 'Good afternoon';
      emoji = '☀️';
    } else if (timeOfDay < 21) {
      greeting = 'Good evening';
      emoji = '🌆';
    } else {
      greeting = 'Good night';
      emoji = '🌙';
    }

    if (_userName.isNotEmpty && _userName != 'User') {
      return '$greeting, $_userName! $emoji';
    } else {
      return '$greeting! $emoji';
    }
  }

  // NEW: Get age-appropriate disclaimer
  String get ageAppropriateDisclaimer {
    if (isMinor) {
      return '''
⚠️ **Important for Young Users:**
- Always talk to a parent, guardian, or trusted adult about health concerns
- Never make medical decisions without adult supervision  
- If you feel unwell, tell a trusted adult immediately
- This app provides general information only - not medical advice
- Ask questions! Adults are here to help you stay healthy 🌟
      ''';
    } else if (isYoungAdult) {
      return '''
⚠️ **Important Health Information:**
- This tool provides educational information only
- Always consult healthcare professionals for medical advice
- Build relationships with trusted healthcare providers
- Take charge of your health with professional guidance
- Call emergency services for urgent symptoms 🏥
      ''';
    } else {
      return '''
⚠️ **Important Medical Disclaimer:**
- This tool provides general information only
- Always consult healthcare professionals for medical advice
- Never ignore professional medical guidance
- Call emergency services for urgent symptoms
- Your health decisions should be made with qualified medical professionals 👩‍⚕️
      ''';
    }
  }

  // NEW: Age-appropriate health tips
  List<String> get personalizedHealthTips {
    List<String> baseTips = [
      '💧 Stay hydrated - drink 8 glasses of water daily',
      '🚶‍♀️ Take regular walks to stay active',
      '😴 Get quality sleep every night',
      '🥗 Eat a balanced diet with fruits and vegetables',
    ];

    if (isMinor) {
      return [
        '🏃‍♀️ Stay active with fun activities and sports',
        '📱 Limit screen time and take regular breaks',
        '🧠 Talk about your feelings with trusted adults',
        '🥕 Try new healthy foods - make it fun!',
        '😴 Kids need 9-11 hours of sleep each night',
        '🌟 Always tell an adult if you don\'t feel well',
      ];
    } else if (isYoungAdult) {
      return [
        ...baseTips,
        '🏃‍♂️ Build healthy habits early for lifelong wellness',
        '🧘‍♀️ Practice stress management techniques',
        '🩺 Start building relationships with healthcare providers',
        '💪 Include strength training in your routine',
        '🧠 Prioritize mental health and seek support when needed',
      ];
    } else {
      return [
        ...baseTips,
        '🩺 Schedule regular health screenings',
        '💪 Maintain muscle mass with strength training',
        '🦴 Focus on bone health with calcium and vitamin D',
        '👩‍⚕️ Keep up with recommended medical check-ups',
        '❤️ Monitor cardiovascular health',
      ];
    }
  }

  // NEW: Content filtering for AI responses
  bool shouldFilterContent(String content) {
    if (!isMinor) return false;

    final sensitiveKeywords = [
      'sexual',
      'pregnancy',
      'contraception',
      'reproductive',
      'std',
      'sti',
      'adult',
      'mature',
      'intimate',
      'private parts',
      'drug abuse',
      'alcohol',
      'addiction',
      'overdose',
      'suicide',
      'self-harm',
      'depression',
      'anxiety disorders'
    ];

    final lowerContent = content.toLowerCase();
    return sensitiveKeywords.any((keyword) => lowerContent.contains(keyword));
  }

  // NEW: Get filtered, age-appropriate error message
  String getAgeAppropriateErrorMessage() {
    if (isMinor) {
      return '''
Oops! $_userName, I'm having trouble connecting right now. 😅

**What you can do:**
- Try asking your question again in a few minutes
- Talk to a parent or guardian about your health question  
- Ask a trusted adult to help you
- If you're not feeling well, always tell a trusted adult! 🌟

Remember: Adults are there to help keep you healthy and safe! 💙
      ''';
    } else {
      return '''
I'm experiencing technical difficulties right now, $_userName. 

**Please try:**
- Asking your question again in a few minutes
- Consulting with a healthcare professional
- Calling emergency services if this is urgent

Your health and safety are the top priority. 🏥
      ''';
    }
  }

  // User profile setters (enhanced for onboarding)
  Future<void> setUserName(String name) async {
    if (_userName != name) {
      _userName = name;
      await _saveUserProfile();
      notifyListeners();
    }
  }

  Future<void> setUserEmail(String email) async {
    if (_userEmail != email) {
      _userEmail = email;
      await _saveUserProfile();
      notifyListeners();
    }
  }

  Future<void> setUserAge(int age) async {
    if (_userAge != age) {
      _userAge = age;
      await _saveUserProfile();
      notifyListeners();
    }
  }

  Future<void> setUserGender(String gender) async {
    if (_userGender != gender) {
      _userGender = gender;
      await _saveUserProfile();
      notifyListeners();
    }
  }

  // Symptom management (existing)
  void toggleSymptom(String symptom) {
    if (_selectedSymptoms.contains(symptom)) {
      _selectedSymptoms.remove(symptom);
    } else {
      _selectedSymptoms.add(symptom);
    }
    notifyListeners();
  }

  void clearSymptoms() {
    _selectedSymptoms.clear();
    _selectedSeverity = '';
    _additionalSymptomInfo.clear();
    _symptomAnalysis = '';
    notifyListeners();
  }

  void setSeverity(String severity) {
    if (_selectedSeverity != severity) {
      _selectedSeverity = severity;
      notifyListeners();
    }
  }

  void addAdditionalSymptomInfo(String key, dynamic value) {
    _additionalSymptomInfo[key] = value;
    notifyListeners();
  }

  void setSymptomAnalysis(String analysis) {
    if (_symptomAnalysis != analysis) {
      _symptomAnalysis = analysis;
      notifyListeners();
    }
  }

  // ENHANCED: Medication management with smart reminders
  void addMedication(Medication medication) {
    _medications.add(medication);
    _saveMedications();
    notifyListeners();
  }

  void removeMedication(int index) async {
    if (index >= 0 && index < _medications.length) {
      final medication = _medications[index];

      // Cancel all notifications for this medication
      await NotificationService.cancelMedicationReminders(medication.id);

      _medications.removeAt(index);
      _saveMedications();
      notifyListeners();
    }
  }

  // NEW: Update medication with reminders
  Future<void> updateMedicationWithReminders(
      int index, Medication updatedMedication) async {
    if (index >= 0 && index < _medications.length) {
      _medications[index] = updatedMedication;

      // Schedule notifications if enabled
      if (updatedMedication.remindersEnabled) {
        await NotificationService.scheduleMedicationReminders(
            updatedMedication);
      } else {
        await NotificationService.cancelMedicationReminders(
            updatedMedication.id);
      }

      await _saveMedications();
      notifyListeners();
    }
  }

  // NEW: Take medication dose (reduce quantity)
  Future<void> takeMedicationDose(String medicationId) async {
    final index = _medications.indexWhere((med) => med.id == medicationId);
    if (index != -1) {
      final medication = _medications[index];
      final updatedMedication = medication.copyWith(
        currentQuantity:
            (medication.currentQuantity - 1).clamp(0, medication.totalQuantity),
      );

      _medications[index] = updatedMedication;

      // Check if refill reminder is needed
      if (updatedMedication.needsRefill) {
        await NotificationService.scheduleRefillReminder(updatedMedication);
      }

      await _saveMedications();
      notifyListeners();
    }
  }

  // NEW: Initialize notification system
  Future<void> initializeNotifications() async {
    await NotificationService.initialize();
    await NotificationService.requestPermissions();

    // Schedule all active medication reminders
    for (final medication in medicationsWithReminders) {
      await NotificationService.scheduleMedicationReminders(medication);
    }
  }

  // NEW: Toggle all reminders for a medication
  Future<void> toggleMedicationReminders(
      String medicationId, bool enabled) async {
    final index = _medications.indexWhere((med) => med.id == medicationId);
    if (index != -1) {
      final medication = _medications[index];
      final updatedMedication = medication.copyWith(remindersEnabled: enabled);
      await updateMedicationWithReminders(index, updatedMedication);
    }
  }

  // NEW: Add reminder to medication
  Future<void> addReminderToMedication(
      String medicationId, MedicationReminder reminder) async {
    final index = _medications.indexWhere((med) => med.id == medicationId);
    if (index != -1) {
      final medication = _medications[index];
      final updatedReminders =
          List<MedicationReminder>.from(medication.reminders)..add(reminder);
      final updatedMedication = medication.copyWith(
        reminders: updatedReminders,
        remindersEnabled: true, // Auto-enable when adding reminder
      );
      await updateMedicationWithReminders(index, updatedMedication);
    }
  }

  // NEW: Remove reminder from medication
  Future<void> removeReminderFromMedication(
      String medicationId, String reminderId) async {
    final index = _medications.indexWhere((med) => med.id == medicationId);
    if (index != -1) {
      final medication = _medications[index];
      final updatedReminders =
          medication.reminders.where((r) => r.id != reminderId).toList();
      final updatedMedication = medication.copyWith(
        reminders: updatedReminders,
        remindersEnabled: updatedReminders.isNotEmpty,
      );
      await updateMedicationWithReminders(index, updatedMedication);
    }
  }

  void setMedicationInteractionResult(String result) {
    if (_medicationInteractionResult != result) {
      _medicationInteractionResult = result;
      notifyListeners();
    }
  }

  // Chat management (enhanced with age restrictions)
  void addChatMessage(ChatMessage message) {
    // Filter content for minors
    if (isMinor && !message.isUser && shouldFilterContent(message.text)) {
      final filteredMessage = ChatMessage(
        text: '''
I notice you're asking about something that might be better discussed with a trusted adult like a parent, guardian, or doctor.

**What you can do:**
- Talk to a parent or guardian about your question  
- Ask a school nurse or counselor
- Visit a doctor with a trusted adult

Remember: I'm here to help with general health information, but for anything serious or personal, it's always best to talk to a real person who can help you properly! 😊

Is there something else I can help you with today?
        ''',
        isUser: false,
      );
      _chatMessages.add(filteredMessage);
    } else {
      _chatMessages.add(message);
    }

    _saveChatHistory();
    notifyListeners();
  }

  void clearChatMessages() {
    _chatMessages.clear();
    _saveChatHistory();
    notifyListeners();
  }

  // Loading state (existing)
  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  // Enhanced health data with user profile and age considerations
  Map<String, dynamic> getHealthData() {
    return {
      // User profile data
      'user_name': _userName,
      'user_email': _userEmail,
      'user_age': _userAge,
      'user_gender': _userGender,
      'age_group': isMinor
          ? 'minor'
          : isYoungAdult
              ? 'young_adult'
              : 'adult',
      'content_restrictions': isMinor,

      // Health metrics (age-adjusted)
      'sleep_hours': isMinor ? '9-11' : '7-9',
      'recommended_steps': isMinor ? '12,000' : '10,000',
      'activity_level': 'Moderate',

      // Medication data with reminders
      'medications_count': _medications.length,
      'medications': _medications.map((m) => m.name).toList(),
      'medication_details': _medications.map((m) => m.toMap()).toList(),
      'medications_with_reminders': medicationsWithReminders.length,
      'total_active_reminders': totalActiveReminders,
      'medications_needing_refill': medicationsNeedingRefill.length,

      // Symptom data
      'last_symptom_check': _symptomAnalysis.isNotEmpty ? 'Recent' : 'Never',
      'recent_symptoms': _selectedSymptoms,
      'symptom_severity': _selectedSeverity,

      // Health score calculation based on user data
      'health_score': _calculateHealthScore(),
      'personalized_tips': personalizedHealthTips,
      'last_update': DateTime.now().toIso8601String(),
    };
  }

  // Enhanced health score calculation with age factors
  String _calculateHealthScore() {
    int score = 70; // Base score

    // Age factor (more nuanced)
    if (_userAge > 0) {
      if (_userAge < 18) {
        score += 15; // Young people generally healthier
      } else if (_userAge < 30) {
        score += 10;
      } else if (_userAge < 50) {
        score += 5;
      } else if (_userAge < 70) {
        score += 0;
      } else {
        score -= 5;
      }
    }

    // Medication factor with reminder bonus
    if (_medications.isEmpty) {
      score += 10;
    } else if (_medications.length <= 2) {
      score += 5;
      // Bonus for having reminders set up
      if (medicationsWithReminders.length == _medications.length) {
        score += 3;
      }
    } else if (_medications.length <= 5) {
      score += 0;
      if (medicationsWithReminders.length >= _medications.length * 0.8) {
        score += 2;
      }
    } else {
      score -= 5;
    }

    // Recent symptoms factor
    if (_symptomAnalysis.isEmpty) {
      score += 5;
    } else {
      score -= 3;
    }

    // Chat activity (positive engagement)
    if (_chatMessages.length > 5) {
      score += 2; // Engaged in health monitoring
    }

    // Medication adherence factor
    if (totalActiveReminders > 0) {
      score += 3; // Proactive health management
    }

    return '${score.clamp(40, 100)}/100';
  }

  // Persistence methods (enhanced)
  Future<void> _saveUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', _userName);
      await prefs.setString('user_email', _userEmail);
      await prefs.setInt('user_age', _userAge);
      await prefs.setString('user_gender', _userGender);
    } catch (e) {
      if (kDebugMode) print('Error saving user profile: $e');
    }
  }

  Future<void> loadUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userName = prefs.getString('user_name') ?? 'User';
      _userEmail = prefs.getString('user_email') ?? '';
      _userAge = prefs.getInt('user_age') ?? 0;
      _userGender = prefs.getString('user_gender') ?? '';

      await _loadMedications();
      await _loadChatHistory();

      // Initialize notifications after loading profile
      await initializeNotifications();

      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error loading user profile: $e');
    }
  }

  Future<void> _saveMedications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final medicationsJson =
          jsonEncode(_medications.map((m) => m.toMap()).toList());
      await prefs.setString('medications', medicationsJson);
    } catch (e) {
      if (kDebugMode) print('Error saving medications: $e');
    }
  }

  Future<void> _loadMedications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final medicationsString = prefs.getString('medications');
      if (medicationsString != null && medicationsString.isNotEmpty) {
        final List<dynamic> medicationsList = jsonDecode(medicationsString);
        _medications.clear();
        _medications.addAll(
            medicationsList.map((json) => Medication.fromMap(json)).toList());
      }
    } catch (e) {
      if (kDebugMode) print('Error loading medications: $e');
      // Keep default medications if loading fails
    }
  }

  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chatJson = jsonEncode(_chatMessages.map((m) => m.toMap()).toList());
      await prefs.setString('chat_history', chatJson);
    } catch (e) {
      if (kDebugMode) print('Error saving chat history: $e');
    }
  }

  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chatString = prefs.getString('chat_history');
      if (chatString != null && chatString.isNotEmpty) {
        final List<dynamic> chatList = jsonDecode(chatString);
        _chatMessages.clear();
        _chatMessages
            .addAll(chatList.map((json) => ChatMessage.fromMap(json)).toList());
      }
    } catch (e) {
      if (kDebugMode) print('Error loading chat history: $e');
    }
  }

  Future<void> loadChatHistory() async {
    await _loadChatHistory();
  }

  Future<void> saveChatHistory() async {
    await _saveChatHistory();
  }

  // DEPRECATED: Use personalizedGreeting getter instead
  String getPersonalizedGreeting() {
    return personalizedGreeting;
  }

  // DEPRECATED: Use personalizedHealthTips getter instead
  List<String> getPersonalizedHealthTips() {
    return personalizedHealthTips;
  }

  // Reset methods (existing, enhanced)
  void resetData() {
    _selectedSymptoms.clear();
    _selectedSeverity = '';
    _additionalSymptomInfo.clear();
    _symptomAnalysis = '';
    _medicationInteractionResult = '';
    _isLoading = false;
    _chatMessages.clear();
    notifyListeners();
  }

  // Complete reset (including user profile) - useful for testing
  Future<void> resetAllData() async {
    resetData();
    _userName = 'User';
    _userEmail = '';
    _userAge = 0;
    _userGender = '';
    _medications.clear();

    // Cancel all notifications
    await NotificationService.cancelAllMedicationNotifications();

    // Add back default medications
    _medications.addAll([
      Medication.fromLegacy('Aspirin', '81mg', 'Daily'),
      Medication.fromLegacy('Lisinopril', '10mg', 'Daily'),
    ]);

    // Clear SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    notifyListeners();
  }

  // NEW: Check if user profile is complete
  bool get isUserProfileComplete {
    return _userName.isNotEmpty &&
        _userName != 'User' &&
        _userAge > 0 &&
        _userGender.isNotEmpty;
  }

  // NEW: Get age-appropriate max response length for AI
  int get maxAIResponseLength {
    if (isMinor) return 200; // Shorter, simpler responses
    if (isYoungAdult) return 400; // Medium length
    return 600; // Full detailed responses for adults
  }

  // NEW: Get content safety level for AI requests
  String get contentSafetyLevel {
    if (isMinor) return 'strict';
    if (isYoungAdult) return 'moderate';
    return 'standard';
  }
}

// Enhanced Chat message class with better serialization
class ChatMessage extends Equatable {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? messageId;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.messageId,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  List<Object?> get props => [text, isUser, timestamp, messageId];

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'messageId':
          messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      text: map['text'] ?? '',
      isUser: map['isUser'] ?? false,
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      messageId: map['messageId'],
    );
  }

  // NEW: Get formatted timestamp for display
  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  // NEW: Check if message contains health concern keywords
  bool get containsHealthConcern {
    final concernKeywords = [
      'pain',
      'hurt',
      'sick',
      'fever',
      'emergency',
      'urgent',
      'bleeding',
      'chest pain',
      'difficulty breathing',
      'severe'
    ];
    return concernKeywords
        .any((keyword) => text.toLowerCase().contains(keyword));
  }
}
