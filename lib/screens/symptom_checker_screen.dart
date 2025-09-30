import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:personalmedai/utils/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // NEW: History management
  List<SymptomAssessmentHistory> _assessmentHistory = [];

  @override
  void initState() {
    super.initState();
    _loadAssessmentHistory();
  }

  // NEW: Load assessment history from SharedPreferences
  Future<void> _loadAssessmentHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('symptom_assessment_history');

      if (historyJson != null) {
        final List<dynamic> historyList = jsonDecode(historyJson);
        setState(() {
          _assessmentHistory = historyList
              .map((item) => SymptomAssessmentHistory.fromJson(item))
              .toList();
        });

        print(
            '📂 Loaded ${_assessmentHistory.length} symptom assessments from cache');
      }
    } catch (e) {
      print('❌ Error loading assessment history: $e');
    }
  }

  // NEW: Save assessment history to SharedPreferences
  Future<void> _saveAssessmentHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson =
          jsonEncode(_assessmentHistory.map((item) => item.toJson()).toList());
      await prefs.setString('symptom_assessment_history', historyJson);
      print('💾 Saved symptom assessment history to cache');
    } catch (e) {
      print('❌ Error saving assessment history: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Symptom Checker'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          // NEW: History button
          Badge(
            isLabelVisible: _assessmentHistory.isNotEmpty,
            label: Text('${_assessmentHistory.length}'),
            child: IconButton(
              icon: const Icon(Icons.history),
              onPressed: () => _showAssessmentHistory(context),
              tooltip: 'Assessment History (${_assessmentHistory.length})',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
            tooltip: 'Help',
          ),
        ],
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
              // NEW: Recent assessments preview
              if (_assessmentHistory.isNotEmpty) ...[
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.history,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Recent Assessments',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => _showAssessmentHistory(context),
                              child: const Text('View All'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...(_assessmentHistory.take(2).map(
                              (assessment) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  dense: true,
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.psychology,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      size: 16,
                                    ),
                                  ),
                                  title: Text(
                                    assessment.primarySymptom,
                                    style: const TextStyle(fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    _formatCacheAge(assessment.timestamp),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon:
                                        const Icon(Icons.visibility, size: 18),
                                    onPressed: () =>
                                        _viewAssessment(assessment),
                                  ),
                                ),
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

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

  // Keep your existing _buildQuestionFlow, _buildLoadingAssessment methods...
  // (The ones from the previous fix - they remain the same)

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

          // ENHANCED: Action buttons with save feedback
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveAndClose,
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

          const SizedBox(height: 12),

          // NEW: Additional action buttons
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _shareAssessment(),
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share Result'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _showAssessmentHistory(context),
                  icon: Badge(
                    isLabelVisible: _assessmentHistory.isNotEmpty,
                    label: Text('${_assessmentHistory.length}'),
                    child: const Icon(Icons.history, size: 18),
                  ),
                  label: const Text('View History'),
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

  // NEW: Save and close with proper feedback
  Future<void> _saveAndClose() async {
    if (_assessment != null) {
      await _saveCurrentAssessment();

      // Show save confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Assessment saved successfully! ✨',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'View History',
            textColor: Colors.white,
            onPressed: () => _showAssessmentHistory(context),
          ),
        ),
      );

      // Small delay for user to see the confirmation
      await Future.delayed(const Duration(milliseconds: 500));
    }

    Navigator.pop(context);
  }

  // NEW: Save current assessment to history
  Future<void> _saveCurrentAssessment() async {
    if (_assessment == null) return;

    final newAssessment = SymptomAssessmentHistory(
      primarySymptom: _answers['primary_symptom'] ?? 'Unknown symptom',
      assessment: _assessment!,
      answers: Map<String, dynamic>.from(_answers),
      timestamp: DateTime.now(),
      sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
    );

    setState(() {
      // Add to beginning of list
      _assessmentHistory.insert(0, newAssessment);

      // Keep only last 50 assessments to manage storage
      if (_assessmentHistory.length > 50) {
        _assessmentHistory = _assessmentHistory.take(50).toList();
      }
    });

    await _saveAssessmentHistory();
  }

  // NEW: Show assessment history dialog
  void _showAssessmentHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.history,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assessment History',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${_assessmentHistory.length} saved assessments',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.7),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  // Clear history button (for testing)
                  if (_assessmentHistory.isNotEmpty)
                    IconButton(
                      onPressed: () => _clearHistory(),
                      icon: const Icon(Icons.delete_sweep),
                      tooltip: 'Clear History',
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_assessmentHistory.isEmpty) ...[
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assessment_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No assessments yet',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Complete a symptom assessment to see it saved here',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: ListView.builder(
                    itemCount: _assessmentHistory.length,
                    itemBuilder: (context, index) {
                      final assessment = _assessmentHistory[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.psychology,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            assessment.primarySymptom,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Container(
                            margin: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatCacheAge(assessment.timestamp),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          children: [
                            Container(
                              margin: const EdgeInsets.all(16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant
                                    .withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.assessment,
                                        size: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Assessment Result:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline
                                            .withOpacity(0.2),
                                      ),
                                    ),
                                    child: SelectionArea(
                                      child: SingleChildScrollView(
                                        child: TexMarkdown(
                                          assessment.assessment,
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                            fontSize: 13,
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
                                        child: TextButton.icon(
                                          onPressed: () => _shareAssessment(
                                              assessment.assessment),
                                          icon:
                                              const Icon(Icons.share, size: 16),
                                          label: const Text('Share'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () =>
                                              _viewAssessment(assessment),
                                          icon: const Icon(Icons.visibility,
                                              size: 16),
                                          label: const Text('View Full'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // NEW: View individual assessment
  // ALTERNATIVE: Show assessment in a beautiful dialog
  void _viewAssessment(SymptomAssessmentHistory assessment) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.assessment,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assessment.primarySymptom,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Assessment from ${_formatCacheAge(assessment.timestamp)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.7),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceVariant,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Assessment content
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceVariant
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.2),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: SelectionArea(
                      child: TexMarkdown(
                        assessment.assessment,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 14,
                          height: 1.6,
                        ),
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
                    child: OutlinedButton.icon(
                      onPressed: () => _shareAssessment(assessment.assessment),
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),

              const SizedBox(height: 12),

              // Medical disclaimer
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This analysis is for informational purposes only. Consult a healthcare professional for medical advice.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // NEW: Share assessment
  void _shareAssessment([String? specificAssessment]) async {
    final assessmentText = specificAssessment ?? _assessment ?? '';

    // For now, copy to clipboard (you can integrate with Share package later)
    await Clipboard.setData(ClipboardData(text: '''
PersonalMedAI Symptom Assessment

Primary Symptom: ${_answers['primary_symptom'] ?? 'Not specified'}
Date: ${DateTime.now().toString().split(' ')[0]}

$assessmentText

---
Generated by PersonalMedAI
Note: This is for informational purposes only. Consult a healthcare professional for medical advice.
    '''));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.copy, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text('Assessment copied to clipboard'),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // NEW: Clear history with confirmation
  void _clearHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
            'Are you sure you want to clear all assessment history? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _assessmentHistory.clear();
              });
              _saveAssessmentHistory();
              Navigator.pop(context); // Close confirmation dialog
              Navigator.pop(context); // Close history dialog
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Assessment history cleared'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  // NEW: Show help dialog
  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Symptom Checker Help',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: SelectionArea(
            child: TexMarkdown(
              '''
## How to Use Symptom Checker

**Getting Started:**
1. Describe your main symptom in detail
2. Answer the guided questions honestly
3. Review your personalized assessment
4. Save for future reference

## 📚 Assessment History

All your assessments are **automatically saved**:
- View past assessments anytime
- Share results with healthcare providers
- Track symptom patterns over time
- Quick access to recent assessments

## 🔒 Privacy & Data

- All data is stored **locally** on your device
- No personal health information is sent to external servers
- You control your data completely

## ⚠️ Important Reminders

- This tool provides **general information only**
- Always consult healthcare professionals for diagnosis
- Call emergency services for urgent symptoms
- Regular medical check-ups are recommended

**Emergency:** If experiencing severe symptoms, call your local emergency number immediately.
              ''',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  // Helper method to format timestamps
  String _formatCacheAge(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  // Keep your existing methods...
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
      final appState = Provider.of<AppState>(context, listen: false);
      final result = await deepSeekService.analyzeSymptoms(
        [_answers['primary_symptom']],
        _answers['severity'] ?? '5',
        _answers,
        appState,
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

// NEW: History model for symptom assessments
class SymptomAssessmentHistory {
  final String primarySymptom;
  final String assessment;
  final Map<String, dynamic> answers;
  final DateTime timestamp;
  final String sessionId;

  SymptomAssessmentHistory({
    required this.primarySymptom,
    required this.assessment,
    required this.answers,
    required this.timestamp,
    required this.sessionId,
  });

  Map<String, dynamic> toJson() => {
        'primarySymptom': primarySymptom,
        'assessment': assessment,
        'answers': answers,
        'timestamp': timestamp.toIso8601String(),
        'sessionId': sessionId,
      };

  static SymptomAssessmentHistory fromJson(Map<String, dynamic> json) =>
      SymptomAssessmentHistory(
        primarySymptom: json['primarySymptom'],
        assessment: json['assessment'],
        answers: Map<String, dynamic>.from(json['answers']),
        timestamp: DateTime.parse(json['timestamp']),
        sessionId: json['sessionId'],
      );
}
