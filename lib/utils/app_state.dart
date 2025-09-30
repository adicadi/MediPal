import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  // User profile data (enhanced for onboarding)
  String _userName = 'Aditya';
  String _userEmail = '';
  int _userAge = 0;
  String _userGender = '';

  // Existing symptom and medication data
  final List<String> _selectedSymptoms = [];
  String _selectedSeverity = '';
  final List<Medication> _medications = [
    const Medication(name: 'Aspirin', dosage: '81mg', frequency: 'Daily'),
    const Medication(name: 'Lisinopril', dosage: '10mg', frequency: 'Daily'),
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

  // User profile setters (enhanced for onboarding)
  void setUserName(String name) {
    if (_userName != name) {
      _userName = name;
      _saveUserProfile();
      notifyListeners();
    }
  }

  void setUserEmail(String email) {
    if (_userEmail != email) {
      _userEmail = email;
      _saveUserProfile();
      notifyListeners();
    }
  }

  void setUserAge(int age) {
    if (_userAge != age) {
      _userAge = age;
      _saveUserProfile();
      notifyListeners();
    }
  }

  void setUserGender(String gender) {
    if (_userGender != gender) {
      _userGender = gender;
      _saveUserProfile();
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

  // Medication management (existing)
  void addMedication(Medication medication) {
    _medications.add(medication);
    _saveMedications();
    notifyListeners();
  }

  void removeMedication(int index) {
    if (index >= 0 && index < _medications.length) {
      _medications.removeAt(index);
      _saveMedications();
      notifyListeners();
    }
  }

  void setMedicationInteractionResult(String result) {
    if (_medicationInteractionResult != result) {
      _medicationInteractionResult = result;
      notifyListeners();
    }
  }

  // Chat management
  void addChatMessage(ChatMessage message) {
    _chatMessages.add(message);
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

  // Enhanced health data with user profile
  Map<String, dynamic> getHealthData() {
    return {
      // User profile data
      'user_name': _userName,
      'user_email': _userEmail,
      'user_age': _userAge,
      'user_gender': _userGender,

      // Health metrics
      'sleep_hours': '8.5',
      'steps': '10,000',
      'heart_rate': '72 bpm',
      'activity_level': 'Moderate',

      // Medication data
      'medications_count': _medications.length,
      'medications': _medications.map((m) => m.name).toList(),
      'medication_details': _medications.map((m) => m.toMap()).toList(),

      // Symptom data
      'last_symptom_check': _symptomAnalysis.isNotEmpty ? 'Recent' : 'Never',
      'recent_symptoms': _selectedSymptoms,
      'symptom_severity': _selectedSeverity,

      // Health score calculation based on user data
      'health_score': _calculateHealthScore(),
      'last_update': DateTime.now().toIso8601String(),
    };
  }

  // Calculate health score based on available data
  String _calculateHealthScore() {
    int score = 70; // Base score

    // Age factor
    if (_userAge > 0) {
      if (_userAge < 30)
        score += 10;
      else if (_userAge < 50)
        score += 5;
      else if (_userAge < 70)
        score += 0;
      else
        score -= 5;
    }

    // Medication factor
    if (_medications.isEmpty)
      score += 10;
    else if (_medications.length <= 2)
      score += 5;
    else
      score -= 2;

    // Recent symptoms factor
    if (_symptomAnalysis.isEmpty)
      score += 5;
    else
      score -= 3;

    return '${score.clamp(50, 100)}/100';
  }

  // Persistence methods
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
      await _loadChatHistory(); // FIXED: Now properly defined below

      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error loading user profile: $e');
    }
  }

  Future<void> _saveMedications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final medicationsJson = _medications.map((m) => m.toMap()).toList();
      await prefs.setString('medications', medicationsJson.toString());
    } catch (e) {
      if (kDebugMode) print('Error saving medications: $e');
    }
  }

  Future<void> _loadMedications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final medicationsString = prefs.getString('medications');
      if (medicationsString != null && medicationsString.isNotEmpty) {
        // Parse medications if needed
        // For now, keep the default medications
      }
    } catch (e) {
      if (kDebugMode) print('Error loading medications: $e');
    }
  }

  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chatJson = _chatMessages.map((m) => m.toMap()).toList();
      await prefs.setString('chat_history', chatJson.toString());
    } catch (e) {
      if (kDebugMode) print('Error saving chat history: $e');
    }
  }

  // FIXED: Added the missing _loadChatHistory method
  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chatString = prefs.getString('chat_history');
      if (chatString != null && chatString.isNotEmpty) {
        // Parse chat history if needed
        // Implementation can be added based on your ChatMessage structure
        // For now, start with empty chat history
        _chatMessages.clear();
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

  // Get personalized greeting based on time and user data
  String getPersonalizedGreeting() {
    final hour = DateTime.now().hour;
    String greeting;

    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    if (_userName.isNotEmpty && _userName != 'User') {
      return '$greeting, $_userName!';
    } else {
      return '$greeting!';
    }
  }

  // Get age-appropriate health tips
  List<String> getPersonalizedHealthTips() {
    List<String> tips = [
      '💧 Stay hydrated - drink 8 glasses of water daily',
      '🚶‍♀️ Take 10,000 steps per day for optimal health',
      '😴 Get 7-9 hours of quality sleep each night',
      '🥗 Eat a balanced diet with fruits and vegetables',
    ];

    // Age-specific tips
    if (_userAge > 0) {
      if (_userAge < 30) {
        tips.add('🏃‍♂️ Build healthy habits early for lifelong wellness');
        tips.add('🧘‍♀️ Practice stress management techniques');
      } else if (_userAge < 50) {
        tips.add('🩺 Get regular health screenings');
        tips.add('💪 Maintain muscle mass with strength training');
      } else {
        tips.add('🦴 Focus on bone health with calcium and vitamin D');
        tips.add('👩‍⚕️ Regular check-ups become more important');
      }
    }

    // Gender-specific tips
    if (_userGender == 'Female') {
      tips.add('🩸 Monitor iron levels, especially if menstruating');
    } else if (_userGender == 'Male') {
      tips.add('❤️ Pay attention to heart health');
    }

    return tips;
  }

  // Reset all data (existing, enhanced)
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

    // Clear SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    notifyListeners();
  }
}

// Existing Medication class (unchanged)
class Medication extends Equatable {
  final String name;
  final String dosage;
  final String frequency;

  const Medication({
    required this.name,
    required this.dosage,
    required this.frequency,
  });

  @override
  List<Object?> get props => [name, dosage, frequency];

  @override
  String toString() => '$name $dosage';

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
    };
  }

  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      frequency: map['frequency'] ?? '',
    );
  }
}

// FIXED: Chat message class with proper constructor
class ChatMessage extends Equatable {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ??
            DateTime
                .now(); // FIXED: Removed const and used proper initialization

  @override
  List<Object?> get props => [text, isUser, timestamp];

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      text: map['text'] ?? '',
      isUser: map['isUser'] ?? false,
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}
