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
        child: SingleChildScrollView(
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
        ));
  }

  // FIXED: Proper flow control with loading state check
  Widget _buildQuestionFlow() {
    // FIXED: Check loading state FIRST
    if (_isLoading) {
      return _buildLoadingAssessment();
    }

    // Then check if assessment is complete
    if (_assessment != null) {
      return _buildAssessmentResult();
    }

    // Then check if we've finished all questions (this shouldn't happen now)
    if (_currentQuestionIndex >= _questions.length) {
      return _buildLoadingAssessment();
    }

    // Finally, show the current question
    final question = _questions[_currentQuestionIndex];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / _questions.length,
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            question.question,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 24),

          // Options list
          Expanded(
            child: ListView.builder(
              itemCount: question.options.length,
              itemBuilder: (context, index) {
                final option = question.options[index];
                final isSelected = _answers[question.id] == option;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    elevation: isSelected ? 4 : 1,
                    color: isSelected
                        ? Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withOpacity(0.3)
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isSelected
                          ? BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            )
                          : BorderSide.none,
                    ),
                    child: ListTile(
                      title: Text(
                        option,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      leading: Radio<String>(
                        value: option,
                        groupValue: _answers[question.id],
                        onChanged: (value) =>
                            _answerQuestion(question.id, value!),
                        activeColor: Theme.of(context).colorScheme.primary,
                      ),
                      onTap: () => _answerQuestion(question.id, option),
                      selected: isSelected,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Navigation buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Previous button
              if (_currentQuestionIndex > 0)
                OutlinedButton.icon(
                  onPressed: _previousQuestion,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Previous'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                )
              else
                const SizedBox(),

              const Spacer(),

              // Next/Get Assessment button
              ElevatedButton.icon(
                onPressed: _answers[question.id] != null ? _nextQuestion : null,
                icon: Icon(
                  _currentQuestionIndex == _questions.length - 1
                      ? Icons.assessment
                      : Icons.arrow_forward,
                  size: 18,
                ),
                label: Text(_currentQuestionIndex == _questions.length - 1
                    ? 'Get Assessment'
                    : 'Next'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
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
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Main loading indicator
                SizedBox(
                  height: 80,
                  width: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 80,
                        width: 80,
                        child: CircularProgressIndicator(
                          strokeWidth: 6,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.psychology,
                          color: Theme.of(context).colorScheme.primary,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                Text(
                  'PersonalMedAI is analyzing your symptoms...',
                  style: TextStyle(
                    fontSize: 18,
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
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Progress steps with animation
                _buildAnimatedProgressSteps(),
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

  // ENHANCED: Animated progress steps
  Widget _buildAnimatedProgressSteps() {
    return Column(
      children: [
        _buildAnimatedProgressStep('Processing symptoms...', 0, true),
        _buildAnimatedProgressStep('Analyzing patterns...', 1, true),
        _buildAnimatedProgressStep('Consulting medical database...', 2, false),
        _buildAnimatedProgressStep('Generating recommendations...', 3, false),
      ],
    );
  }

  Widget _buildAnimatedProgressStep(String text, int index, bool isActive) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 500 + (index * 200)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 300 + (index * 100)),
                  height: 20,
                  width: 20,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceVariant,
                    shape: BoxShape.circle,
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: isActive
                      ? SizedBox(
                          height: 12,
                          width: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : const SizedBox(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                      color: isActive
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method for progress steps (keep for backwards compatibility)
  Widget _buildProgressSteps() {
    return _buildAnimatedProgressSteps();
  }

  Widget _buildProgressStep(String text, bool isCompleted) {
    return _buildAnimatedProgressStep(text, 0, isCompleted);
  }

  Widget _buildAssessmentResult() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Success header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.shade50,
                  Colors.green.shade100.withOpacity(0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.assessment,
                    color: Colors.green.shade700,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assessment Complete',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Based on your symptoms and responses',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Assessment result card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SelectionArea(
                child: TexMarkdown(
                  _assessment!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.save),
                  label: const Text('Save & Close'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _startNewAssessment,
                  icon: const Icon(Icons.refresh),
                  label: const Text('New Assessment'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Medical disclaimer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning, color: Colors.red.shade700, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Important Medical Disclaimer',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This analysis is for informational purposes only and should not replace professional medical advice. Please consult a qualified healthcare professional for proper diagnosis and treatment.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red.shade600,
                          height: 1.4,
                        ),
                      ),
                    ],
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
      _assessment = null; // Reset assessment
      _isLoading = false; // Reset loading state
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
      // This is the last question, start assessment generation
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

  // FIXED: Better state management for assessment generation
  Future<void> _generateAssessment() async {
    print('🔄 Starting assessment generation...'); // Debug log

    // FIXED: Set loading state immediately and trigger UI rebuild
    setState(() {
      _isLoading = true;
      _assessment = null; // Clear any previous assessment
    });

    // Small delay to ensure UI updates
    await Future.delayed(const Duration(milliseconds: 300));

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

      // FIXED: Update state properly
      if (mounted) {
        setState(() {
          _assessment = result;
          _isLoading = false;
        });
      }

      print('✅ Assessment generation complete!'); // Debug log
    } catch (e) {
      print('❌ Assessment generation error: $e'); // Debug log

      if (mounted) {
        setState(() {
          _assessment = '''
## Assessment Unavailable

We're experiencing technical difficulties generating your assessment right now.

**What you can do:**
- Try again in a few minutes
- Consult with a healthcare professional about your symptoms
- Call emergency services if this is urgent

**Your symptoms:** ${_answers['primary_symptom']}

⚠️ **Important:** If you're experiencing severe symptoms or this is a medical emergency, please contact emergency services immediately.
          ''';
          _isLoading = false;
        });
      }
    }
  }

  void _startNewAssessment() {
    setState(() {
      _questions.clear();
      _answers.clear();
      _currentQuestionIndex = 0;
      _assessment = null;
      _isLoading = false;
      _symptomController.clear();
    });
  }

  @override
  void dispose() {
    _symptomController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}
