class SymptomQuestion {
  final String id;
  final String question;
  final List<String> options;
  final QuestionType type;
  final bool required;

  SymptomQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.type,
    this.required = false,
  });
}

enum QuestionType {
  multipleChoice,
  scale,
  duration,
  location,
  severity,
}

class SymptomAssessment {
  final Map<String, dynamic> answers;
  final DateTime timestamp;
  final String sessionId;

  SymptomAssessment({
    required this.answers,
    required this.timestamp,
    required this.sessionId,
  });

  String generatePrompt() {
    final buffer = StringBuffer();
    buffer.writeln('Patient Assessment:');

    answers.forEach((key, value) {
      buffer.writeln('$key: $value');
    });

    buffer.writeln('\nProvide a comprehensive assessment including:');
    buffer.writeln('1. Most likely conditions (with probabilities)');
    buffer.writeln('2. Recommended immediate actions');
    buffer.writeln('3. When to seek medical attention');
    buffer.writeln('4. Follow-up recommendations');
    buffer.writeln('5. Important medical disclaimers');

    return buffer.toString();
  }
}
