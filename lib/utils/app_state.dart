import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';

class AppState extends ChangeNotifier {
  String _userName = 'John';
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

  // Getters
  String get userName => _userName;
  List<String> get selectedSymptoms => List.unmodifiable(_selectedSymptoms);
  String get selectedSeverity => _selectedSeverity;
  List<Medication> get medications => List.unmodifiable(_medications);
  String get symptomAnalysis => _symptomAnalysis;
  String get medicationInteractionResult => _medicationInteractionResult;
  bool get isLoading => _isLoading;
  Map<String, dynamic> get additionalSymptomInfo =>
      Map.from(_additionalSymptomInfo);

  // User name
  void setUserName(String name) {
    if (_userName != name) {
      _userName = name;
      notifyListeners();
    }
  }

  // Symptom management
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

  // Medication management
  void addMedication(Medication medication) {
    _medications.add(medication);
    notifyListeners();
  }

  void removeMedication(int index) {
    if (index >= 0 && index < _medications.length) {
      _medications.removeAt(index);
      notifyListeners();
    }
  }

  void setMedicationInteractionResult(String result) {
    if (_medicationInteractionResult != result) {
      _medicationInteractionResult = result;
      notifyListeners();
    }
  }

  // Loading state
  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  // Health data
  Map<String, dynamic> getHealthData() {
    return {
      'sleep_hours': '8.5',
      'steps': '10,000',
      'heart_rate': '72 bpm',
      'activity_level': 'Moderate',
      'medications_count': _medications.length.toString(),
      'last_symptom_check':
          _symptomAnalysis.isNotEmpty ? '2 days ago' : 'Never',
      'health_score': '85/100',
    };
  }

  // Reset all data
  void resetData() {
    _selectedSymptoms.clear();
    _selectedSeverity = '';
    _additionalSymptomInfo.clear();
    _symptomAnalysis = '';
    _medicationInteractionResult = '';
    _isLoading = false;
    notifyListeners();
  }
}

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
