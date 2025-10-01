import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class Medication extends Equatable {
  final String id;
  final String name;
  final String dosage;
  final String frequency;
  final int totalQuantity;
  final int currentQuantity;
  final DateTime? refillDate;

  // NEW: Reminder fields
  final bool remindersEnabled;
  final List<MedicationReminder> reminders;
  final int refillThreshold; // Alert when <= this many left
  final String? notes;
  final DateTime createdAt;
  final bool isEssential;

  const Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    this.totalQuantity = 30,
    required this.currentQuantity,
    this.refillDate,
    this.remindersEnabled = false,
    this.reminders = const [],
    this.refillThreshold = 7,
    this.notes,
    required this.createdAt,
    this.isEssential = false,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        dosage,
        frequency,
        totalQuantity,
        currentQuantity,
        refillDate,
        remindersEnabled,
        reminders,
        refillThreshold,
        notes,
        createdAt,
        isEssential
      ];

  @override
  String toString() => '$name $dosage';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'totalQuantity': totalQuantity,
      'currentQuantity': currentQuantity,
      'refillDate': refillDate?.toIso8601String(),
      'remindersEnabled': remindersEnabled,
      'reminders': reminders.map((r) => r.toMap()).toList(),
      'refillThreshold': refillThreshold,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'isEssential': isEssential,
    };
  }

  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      frequency: map['frequency'] ?? '',
      totalQuantity: map['totalQuantity'] ?? 30,
      currentQuantity: map['currentQuantity'] ?? 30,
      refillDate: map['refillDate'] != null
          ? DateTime.tryParse(map['refillDate'])
          : null,
      remindersEnabled: map['remindersEnabled'] ?? false,
      reminders: (map['reminders'] as List<dynamic>? ?? [])
          .map((r) => MedicationReminder.fromMap(r))
          .toList(),
      refillThreshold: map['refillThreshold'] ?? 7,
      notes: map['notes'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      isEssential: map['isEssential'] ?? false,
    );
  }

  // Legacy constructor for backward compatibility with your existing medications
  factory Medication.fromLegacy(String name, String dosage, String frequency) {
    return Medication(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      dosage: dosage,
      frequency: frequency,
      currentQuantity: 30,
      createdAt: DateTime.now(),
    );
  }

  // Helper methods
  String get displayString => '$name $dosage ($frequency)';

  bool get needsRefill => currentQuantity <= refillThreshold;

  bool get isRunningLow => currentQuantity <= (refillThreshold * 1.5);

  double get adherencePercentage {
    // Calculate based on reminders taken vs missed
    if (reminders.isEmpty) return 100.0;
    // Implementation depends on tracking taken/missed doses
    return 85.0; // Placeholder
  }

  int get daysUntilEmpty {
    if (currentQuantity <= 0) return 0;
    final dailyDoses = _getDailyDoseCount();
    return (currentQuantity / dailyDoses).ceil();
  }

  int _getDailyDoseCount() {
    switch (frequency.toLowerCase()) {
      case 'once daily':
      case 'daily':
        return 1;
      case 'twice daily':
      case 'bid':
        return 2;
      case 'three times daily':
      case 'tid':
        return 3;
      case 'four times daily':
      case 'qid':
        return 4;
      default:
        return 1;
    }
  }

  Medication copyWith({
    String? name,
    String? dosage,
    String? frequency,
    int? totalQuantity,
    int? currentQuantity,
    DateTime? refillDate,
    bool? remindersEnabled,
    List<MedicationReminder>? reminders,
    int? refillThreshold,
    String? notes,
    bool? isEssential,
  }) {
    return Medication(
      id: id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      currentQuantity: currentQuantity ?? this.currentQuantity,
      refillDate: refillDate ?? this.refillDate,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      reminders: reminders ?? this.reminders,
      refillThreshold: refillThreshold ?? this.refillThreshold,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      isEssential: isEssential ?? this.isEssential,
    );
  }
}

class MedicationReminder extends Equatable {
  final String id;
  final TimeOfDay time;
  final bool enabled;
  final List<int> daysOfWeek; // 1-7 (Monday-Sunday)
  final String? customMessage;
  final DateTime createdAt;
  final int dosesCount; // How many doses at this time

  const MedicationReminder({
    required this.id,
    required this.time,
    this.enabled = true,
    this.daysOfWeek = const [1, 2, 3, 4, 5, 6, 7], // All days by default
    this.customMessage,
    required this.createdAt,
    this.dosesCount = 1,
  });

  @override
  List<Object?> get props =>
      [id, time, enabled, daysOfWeek, customMessage, createdAt, dosesCount];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hour': time.hour,
      'minute': time.minute,
      'enabled': enabled,
      'daysOfWeek': daysOfWeek,
      'customMessage': customMessage,
      'createdAt': createdAt.toIso8601String(),
      'dosesCount': dosesCount,
    };
  }

  factory MedicationReminder.fromMap(Map<String, dynamic> map) {
    return MedicationReminder(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      time: TimeOfDay(hour: map['hour'] ?? 8, minute: map['minute'] ?? 0),
      enabled: map['enabled'] ?? true,
      daysOfWeek: List<int>.from(map['daysOfWeek'] ?? [1, 2, 3, 4, 5, 6, 7]),
      customMessage: map['customMessage'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      dosesCount: map['dosesCount'] ?? 1,
    );
  }

  String get formattedTime {
    final hour = time.hour == 0
        ? 12
        : time.hour > 12
            ? time.hour - 12
            : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String get daysSummary {
    if (daysOfWeek.length == 7) return 'Daily';
    if (daysOfWeek.length == 5 && daysOfWeek.every((day) => day <= 5)) {
      return 'Weekdays';
    }
    if (daysOfWeek.length == 2 &&
        daysOfWeek.contains(6) &&
        daysOfWeek.contains(7)) {
      return 'Weekends';
    }

    const dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return daysOfWeek.map((day) => dayNames[day]).join(', ');
  }

  MedicationReminder copyWith({
    TimeOfDay? time,
    bool? enabled,
    List<int>? daysOfWeek,
    String? customMessage,
    int? dosesCount,
  }) {
    return MedicationReminder(
      id: id,
      time: time ?? this.time,
      enabled: enabled ?? this.enabled,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      customMessage: customMessage ?? this.customMessage,
      createdAt: createdAt,
      dosesCount: dosesCount ?? this.dosesCount,
    );
  }
}
