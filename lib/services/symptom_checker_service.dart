import '../models/symptom_checker_models.dart';

class SymptomCheckerService {
  static List<SymptomQuestion> getInitialQuestions(String primarySymptom) {
    // This would typically come from a medical database
    final commonQuestions = [
      SymptomQuestion(
        id: 'duration',
        question: 'How long have you been experiencing this symptom?',
        options: [
          'Less than 1 hour',
          '1-24 hours',
          '1-7 days',
          'More than a week'
        ],
        type: QuestionType.duration,
        required: true,
      ),
      SymptomQuestion(
        id: 'severity',
        question: 'How severe is your $primarySymptom on a scale of 1-10?',
        options: List.generate(10, (i) => '${i + 1}'),
        type: QuestionType.scale,
        required: true,
      ),
    ];

    // Add symptom-specific questions
    if (primarySymptom.toLowerCase().contains('headache')) {
      commonQuestions.addAll([
        SymptomQuestion(
          id: 'headache_type',
          question: 'What type of pain is it?',
          options: ['Throbbing', 'Sharp', 'Dull ache', 'Pressure'],
          type: QuestionType.multipleChoice,
        ),
        SymptomQuestion(
          id: 'headache_location',
          question: 'Where is the pain located?',
          options: [
            'Forehead',
            'Temples',
            'Back of head',
            'One side',
            'All over'
          ],
          type: QuestionType.location,
        ),
        SymptomQuestion(
          id: 'associated_symptoms',
          question: 'Do you have any of these symptoms?',
          options: [
            'Nausea',
            'Light sensitivity',
            'Sound sensitivity',
            'Visual changes',
            'None'
          ],
          type: QuestionType.multipleChoice,
        ),
      ]);
    }

    return commonQuestions;
  }

  static List<SymptomQuestion> getFollowUpQuestions(
    String primarySymptom,
    Map<String, dynamic> previousAnswers,
  ) {
    final followUp = <SymptomQuestion>[];

    // Dynamic follow-up based on previous answers
    if (previousAnswers['severity'] != null) {
      final severity = int.tryParse(previousAnswers['severity']) ?? 0;
      if (severity >= 7) {
        followUp.add(SymptomQuestion(
          id: 'emergency_symptoms',
          question: 'Are you experiencing any of these emergency symptoms?',
          options: [
            'Difficulty breathing',
            'Chest pain',
            'Loss of consciousness',
            'Severe bleeding',
            'None of these'
          ],
          type: QuestionType.multipleChoice,
          required: true,
        ));
      }
    }

    return followUp;
  }
}
