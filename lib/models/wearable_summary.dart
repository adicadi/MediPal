import 'dart:convert';

class WearableSummary {
  final DateTime updatedAt;
  final int? stepsToday;
  final int? activeMinutesToday;
  final double? avgHeartRate;
  final double? restingHeartRate;
  final double? sleepHours;
  final double? sleepEfficiency;
  final double? stressScore;

  const WearableSummary({
    required this.updatedAt,
    this.stepsToday,
    this.activeMinutesToday,
    this.avgHeartRate,
    this.restingHeartRate,
    this.sleepHours,
    this.sleepEfficiency,
    this.stressScore,
  });

  bool get isEmpty =>
      stepsToday == null &&
      activeMinutesToday == null &&
      avgHeartRate == null &&
      restingHeartRate == null &&
      sleepHours == null &&
      sleepEfficiency == null &&
      stressScore == null;

  Map<String, dynamic> toMap() => {
        'updatedAt': updatedAt.toIso8601String(),
        'stepsToday': stepsToday,
        'activeMinutesToday': activeMinutesToday,
        'avgHeartRate': avgHeartRate,
        'restingHeartRate': restingHeartRate,
        'sleepHours': sleepHours,
        'sleepEfficiency': sleepEfficiency,
        'stressScore': stressScore,
      };

  String toJson() => jsonEncode(toMap());

  factory WearableSummary.fromMap(Map<String, dynamic> map) => WearableSummary(
        updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
        stepsToday: map['stepsToday'] as int?,
        activeMinutesToday: map['activeMinutesToday'] as int?,
        avgHeartRate: (map['avgHeartRate'] as num?)?.toDouble(),
        restingHeartRate: (map['restingHeartRate'] as num?)?.toDouble(),
        sleepHours: (map['sleepHours'] as num?)?.toDouble(),
        sleepEfficiency: (map['sleepEfficiency'] as num?)?.toDouble(),
        stressScore: (map['stressScore'] as num?)?.toDouble(),
      );

  factory WearableSummary.fromJson(String source) {
    return WearableSummary.fromMap(jsonDecode(source));
  }
}
