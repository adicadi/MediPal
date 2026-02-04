import 'dart:convert';

class WearableSummary {
  final DateTime updatedAt;
  final int? stepsToday;
  final double? avgHeartRate;
  final double? restingHeartRate;
  final double? sleepHours;
  final double? stressScore;

  const WearableSummary({
    required this.updatedAt,
    this.stepsToday,
    this.avgHeartRate,
    this.restingHeartRate,
    this.sleepHours,
    this.stressScore,
  });

  bool get isEmpty =>
      stepsToday == null &&
      avgHeartRate == null &&
      restingHeartRate == null &&
      sleepHours == null &&
      stressScore == null;

  Map<String, dynamic> toMap() => {
        'updatedAt': updatedAt.toIso8601String(),
        'stepsToday': stepsToday,
        'avgHeartRate': avgHeartRate,
        'restingHeartRate': restingHeartRate,
        'sleepHours': sleepHours,
        'stressScore': stressScore,
      };

  String toJson() => jsonEncode(toMap());

  factory WearableSummary.fromMap(Map<String, dynamic> map) => WearableSummary(
        updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
        stepsToday: map['stepsToday'] as int?,
        avgHeartRate: (map['avgHeartRate'] as num?)?.toDouble(),
        restingHeartRate: (map['restingHeartRate'] as num?)?.toDouble(),
        sleepHours: (map['sleepHours'] as num?)?.toDouble(),
        stressScore: (map['stressScore'] as num?)?.toDouble(),
      );

  factory WearableSummary.fromJson(String source) {
    return WearableSummary.fromMap(jsonDecode(source));
  }
}
