import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import '../models/symptom_checker_models.dart';
import '../services/symptom_checker_service.dart';
import '../services/deepseek_service.dart';
import '../widgets/emergency_button.dart';

class SymptomCheckerScreen extends StatefulWidget {
  const SymptomCheckerScreen({super.key});

  @override
  State<SymptomCheckerScreen> createState() => _SymptomCheckerScreenState();
}

class _SymptomCheckerScreenState extends State<SymptomCheckerScreen> {
  final TextEditingController _symptomController = TextEditingController();
  final PageController _pageController = PageController();

  List<SymptomQuestion> _questions = [];
  Map<String, dynamic> _answers = {};
  int _currentQuestionIndex = 0;
  bool _isLoading = false;
  String? _assessment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Symptom Checker'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Column(
        children: [
          const EmergencyButton(),
          Expanded(
            child: _questions.isEmpty
                ? _buildInitialSymptomInput()
                : _buildQuestionFlow(),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialSymptomInput() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What symptom are you experiencing?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _symptomController,
            decoration: const InputDecoration(
              hintText: 'Describe your main symptom...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startSymptomAssessment,
              child: const Text('Start Assessment'),
            ),
          ),
          const SizedBox(height: 24),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Important',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This tool is for informational purposes only and is not a substitute for professional medical advice. If you are experiencing a medical emergency, call 911 immediately.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionFlow() {
    if (_assessment != null) {
      return _buildAssessmentResult();
    }

    if (_currentQuestionIndex >= _questions.length) {
      return _buildLoadingAssessment();
    }

    final question = _questions[_currentQuestionIndex];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / _questions.length,
          ),
          const SizedBox(height: 24),
          Text(
            'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            question.question,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: question.options.length,
              itemBuilder: (context, index) {
                final option = question.options[index];
                final isSelected = _answers[question.id] == option;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(option),
                    leading: Radio<String>(
                      value: option,
                      groupValue: _answers[question.id],
                      onChanged: (value) =>
                          _answerQuestion(question.id, value!),
                    ),
                    onTap: () => _answerQuestion(question.id, option),
                    selected: isSelected,
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentQuestionIndex > 0)
                TextButton(
                  onPressed: _previousQuestion,
                  child: const Text('Previous'),
                ),
              const Spacer(),
              ElevatedButton(
                onPressed: _answers[question.id] != null ? _nextQuestion : null,
                child: Text(_currentQuestionIndex == _questions.length - 1
                    ? 'Get Assessment'
                    : 'Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingAssessment() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Progress indicator with animation
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 60,
                  width: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'PersonalMedAI is analyzing your symptoms...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                Text(
                  'This may take 10-30 seconds',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
                ),

                const SizedBox(height: 20),

                // Progress steps
                _buildProgressSteps(),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Important note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Please wait while we process your information. The analysis will appear shortly.',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for progress steps
  Widget _buildProgressSteps() {
    return Column(
      children: [
        _buildProgressStep('Processing symptoms...', true),
        _buildProgressStep('Analyzing patterns...', true),
        _buildProgressStep('Consulting medical database...', false),
        _buildProgressStep('Generating recommendations...', false),
      ],
    );
  }

  Widget _buildProgressStep(String text, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            height: 16,
            width: 16,
            decoration: BoxDecoration(
              color: isCompleted
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: isCompleted
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 12,
                  )
                : const SizedBox(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isCompleted
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentResult() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.assessment, color: Colors.green),
              SizedBox(width: 8),
              Text(
                'Assessment Complete',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectionArea(
                child: TexMarkdown(
                  _assessment!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Save & Close'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _startNewAssessment,
                  child: const Text('New Assessment'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Medical disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Important: This analysis is for informational purposes only. Please consult a qualified healthcare professional for proper diagnosis and treatment.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _startSymptomAssessment() {
    final symptom = _symptomController.text.trim();
    if (symptom.isEmpty) return;

    setState(() {
      _questions = SymptomCheckerService.getInitialQuestions(symptom);
      _answers['primary_symptom'] = symptom;
      _currentQuestionIndex = 0;
    });
  }

  void _answerQuestion(String questionId, String answer) {
    setState(() {
      _answers[questionId] = answer;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      _generateAssessment();
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  void _generateAssessment() async {
    print('🔄 Starting assessment generation...'); // Debug log

    setState(() {
      _isLoading = true;
    });

    // Add a small delay to ensure the UI updates
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      print('📝 Creating assessment object...'); // Debug log

      final assessment = SymptomAssessment(
        answers: _answers,
        timestamp: DateTime.now(),
        sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      print('🤖 Calling DeepSeek API...'); // Debug log

      final deepSeekService = DeepSeekService();
      final result = await deepSeekService.analyzeSymptoms(
        [_answers['primary_symptom']],
        _answers['severity'] ?? '5',
        _answers,
      );

      print(
          '✅ Assessment received: ${result.substring(0, 50)}...'); // Debug log

      setState(() {
        _assessment = result;
        _isLoading = false;
      });

      print('✅ Assessment generation complete!'); // Debug log
    } catch (e) {
      print('❌ Assessment generation error: $e'); // Debug log

      setState(() {
        _assessment =
            'Unable to generate assessment at this time. Please consult with a healthcare professional.';
        _isLoading = false;
      });
    }
  }

  void _startNewAssessment() {
    setState(() {
      _questions.clear();
      _answers.clear();
      _currentQuestionIndex = 0;
      _assessment = null;
      _symptomController.clear();
    });
  }
}
