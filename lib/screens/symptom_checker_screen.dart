import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_state.dart';
import '../services/deepseek_service.dart';

class SymptomCheckerScreen extends StatefulWidget {
  const SymptomCheckerScreen({super.key});

  @override
  State<SymptomCheckerScreen> createState() => _SymptomCheckerScreenState();
}

class _SymptomCheckerScreenState extends State<SymptomCheckerScreen> {
  final TextEditingController _symptomController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _triggersController = TextEditingController();
  final TextEditingController _otherSymptomsController =
      TextEditingController();

  final List<String> _suggestedSymptoms = [
    'Headache',
    'Fever',
    'Cough',
    'Nausea',
    'Fatigue',
    'Sore throat',
    'Chest pain',
    'Shortness of breath',
    'Dizziness',
    'Stomach pain',
    'Back pain',
    'Joint pain',
    'Muscle aches',
    'Runny nose',
    'Congestion',
    'Skin rash',
    'Eye irritation',
    'Difficulty sleeping'
  ];

  final List<String> _severityLevels = ['Mild', 'Moderate', 'Severe'];
  List<String> _filteredSymptoms = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _symptomController.addListener(() {
      _filterSymptoms(_symptomController.text);
    });
  }

  @override
  void dispose() {
    _symptomController.dispose();
    _durationController.dispose();
    _triggersController.dispose();
    _otherSymptomsController.dispose();
    super.dispose();
  }

  void _filterSymptoms(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredSymptoms.clear();
        _showSuggestions = false;
      } else {
        _filteredSymptoms = _suggestedSymptoms
            .where((symptom) =>
                symptom.toLowerCase().contains(query.toLowerCase()))
            .take(5)
            .toList();
        _showSuggestions = _filteredSymptoms.isNotEmpty;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Symptom Checker'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _clearAll(context),
            tooltip: 'Clear all',
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Medical Disclaimer
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This tool provides general information only. Consult a healthcare professional for proper diagnosis.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Symptom Input Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Describe Your Symptoms',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _symptomController,
                          decoration: const InputDecoration(
                            hintText:
                                'Type your symptoms or tap suggestions below...',
                            prefixIcon: Icon(Icons.search),
                          ),
                          maxLines: 2,
                        ),

                        // Quick symptom suggestions
                        const SizedBox(height: 16),
                        Text(
                          'Common Symptoms:',
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _suggestedSymptoms.take(8).map((symptom) {
                            return ActionChip(
                              label: Text(symptom),
                              onPressed: () {
                                appState.toggleSymptom(symptom);
                              },
                            );
                          }).toList(),
                        ),

                        // Filtered suggestions
                        if (_showSuggestions) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Matching symptoms:',
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: _filteredSymptoms.map((symptom) {
                              return ActionChip(
                                label: Text(symptom),
                                onPressed: () {
                                  appState.toggleSymptom(symptom);
                                  _symptomController.clear();
                                  setState(() => _showSuggestions = false);
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Selected Symptoms
                if (appState.selectedSymptoms.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Selected Symptoms (${appState.selectedSymptoms.length})',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => appState.clearSymptoms(),
                                icon: const Icon(Icons.clear_all, size: 16),
                                label: const Text('Clear'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: appState.selectedSymptoms.map((symptom) {
                              return Chip(
                                label: Text(symptom),
                                deleteIcon: const Icon(Icons.close, size: 18),
                                onDeleted: () =>
                                    appState.toggleSymptom(symptom),
                                backgroundColor: colorScheme.primaryContainer,
                                side: BorderSide(color: colorScheme.primary),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Severity Selection
                if (appState.selectedSymptoms.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How severe are your symptoms?',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: _severityLevels.map((severity) {
                              final isSelected =
                                  appState.selectedSeverity == severity;
                              return Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: ChoiceChip(
                                    label: Text(severity),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      if (selected) {
                                        appState.setSeverity(severity);
                                      }
                                    },
                                    selectedColor: _getSeverityColor(
                                        severity, colorScheme),
                                    backgroundColor:
                                        colorScheme.surfaceContainerHighest,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          if (appState.selectedSeverity.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              _getSeverityDescription(
                                  appState.selectedSeverity),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Additional Information
                if (appState.selectedSymptoms.isNotEmpty &&
                    appState.selectedSeverity.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Additional Information',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _durationController,
                            decoration: const InputDecoration(
                              labelText: 'Duration',
                              hintText:
                                  'e.g., 2 days, 1 week, started yesterday',
                              prefixIcon: Icon(Icons.schedule),
                            ),
                            onChanged: (value) {
                              appState.addAdditionalSymptomInfo(
                                  'duration', value);
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _triggersController,
                            decoration: const InputDecoration(
                              labelText: 'Triggers or worsening factors',
                              hintText: 'e.g., movement, food, stress, weather',
                              prefixIcon: Icon(Icons.warning_amber),
                            ),
                            onChanged: (value) {
                              appState.addAdditionalSymptomInfo(
                                  'triggers', value);
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _otherSymptomsController,
                            decoration: const InputDecoration(
                              labelText: 'Other symptoms',
                              hintText:
                                  'Any additional symptoms not mentioned above',
                              prefixIcon: Icon(Icons.add),
                            ),
                            onChanged: (value) {
                              appState.addAdditionalSymptomInfo(
                                  'other_symptoms', value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Analysis Result
                if (appState.symptomAnalysis.isNotEmpty) ...[
                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.medical_information,
                                  color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'AI Analysis Result',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              appState.symptomAnalysis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning,
                                    color: Colors.red[700], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Important: This analysis is for informational purposes only. Please consult a qualified healthcare professional for proper diagnosis and treatment.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.w500,
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
                  const SizedBox(height: 16),
                ],

                // Analyze Button
                if (appState.selectedSymptoms.isNotEmpty &&
                    appState.selectedSeverity.isNotEmpty) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: appState.isLoading
                          ? null
                          : () => _analyzeSymptoms(context),
                      icon: appState.isLoading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.analytics),
                      label: Text(appState.isLoading
                          ? 'Analyzing...'
                          : 'Analyze Symptoms'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getSeverityColor(String severity, ColorScheme colorScheme) {
    switch (severity) {
      case 'Mild':
        return Colors.green.withOpacity(0.3);
      case 'Moderate':
        return Colors.orange.withOpacity(0.3);
      case 'Severe':
        return Colors.red.withOpacity(0.3);
      default:
        return colorScheme.primaryContainer;
    }
  }

  String _getSeverityDescription(String severity) {
    switch (severity) {
      case 'Mild':
        return 'Symptoms are noticeable but do not significantly interfere with daily activities.';
      case 'Moderate':
        return 'Symptoms are bothersome and may interfere with some daily activities.';
      case 'Severe':
        return 'Symptoms significantly interfere with daily activities and may require immediate attention.';
      default:
        return '';
    }
  }

  Future<void> _analyzeSymptoms(BuildContext context) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final deepSeekService =
        Provider.of<DeepSeekService>(context, listen: false);

    appState.setLoading(true);

    try {
      final analysis = await deepSeekService.analyzeSymptoms(
        appState.selectedSymptoms,
        appState.selectedSeverity,
        appState.additionalSymptomInfo,
      );

      appState.setSymptomAnalysis(analysis);

      // Scroll to show results
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(context,
            'Unable to analyze symptoms at this time. Please check your internet connection and try again.');
      }
    } finally {
      appState.setLoading(false);
    }
  }

  void _clearAll(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.clearSymptoms();
    _symptomController.clear();
    _durationController.clear();
    _triggersController.clear();
    _otherSymptomsController.clear();
    setState(() => _showSuggestions = false);
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
