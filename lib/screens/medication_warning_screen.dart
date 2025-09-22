import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'dart:convert';
import '../utils/app_state.dart';
import '../services/deepseek_service.dart';

class MedicationWarningScreen extends StatefulWidget {
  const MedicationWarningScreen({super.key});

  @override
  State<MedicationWarningScreen> createState() =>
      _MedicationWarningScreenState();
}

class _MedicationWarningScreenState extends State<MedicationWarningScreen>
    with TickerProviderStateMixin {
  final TextEditingController _medicationController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _frequencyController = TextEditingController();

  bool _showAddForm = false;
  final _formKey = GlobalKey<FormState>();

  // History management
  List<MedicationAnalysisHistory> _analysisHistory = [];
  String? _lastAnalysisHash;

  // Animation controllers for enhanced UX - FIXED: Made nullable with proper initialization
  AnimationController? _addFormAnimationController;
  AnimationController? _resultAnimationController;
  Animation<double>? _addFormAnimation;
  Animation<double>? _resultAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadAnalysisHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInteractionsWithHistory();
    });
  }

  void _initializeAnimations() {
    _addFormAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _resultAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _addFormAnimation = CurvedAnimation(
      parent: _addFormAnimationController!,
      curve: Curves.easeInOut,
    );
    _resultAnimation = CurvedAnimation(
      parent: _resultAnimationController!,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _medicationController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    _addFormAnimationController?.dispose();
    _resultAnimationController?.dispose();
    super.dispose();
  }

  // Load analysis history from SharedPreferences
  Future<void> _loadAnalysisHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('medication_analysis_history');

      if (historyJson != null) {
        final List<dynamic> historyList = jsonDecode(historyJson);
        setState(() {
          _analysisHistory = historyList
              .map((item) => MedicationAnalysisHistory.fromJson(item))
              .toList();
        });
      }
    } catch (e) {
      print('Error loading analysis history: $e');
    }
  }

  // Save analysis history to SharedPreferences
  Future<void> _saveAnalysisHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson =
          jsonEncode(_analysisHistory.map((item) => item.toJson()).toList());
      await prefs.setString('medication_analysis_history', historyJson);
    } catch (e) {
      print('Error saving analysis history: $e');
    }
  }

  // Generate hash for current medication list
  String _generateMedicationHash(List<Medication> medications) {
    final medicationString = medications
        .map((med) => '${med.name}_${med.dosage}_${med.frequency}')
        .join('|');
    return medicationString.hashCode.toString();
  }

  // Check if analysis exists for current medications
  MedicationAnalysisHistory? _findExistingAnalysis(
      List<Medication> medications) {
    if (medications.length < 2) return null;

    final hash = _generateMedicationHash(medications);
    return _analysisHistory
        .where((analysis) => analysis.medicationHash == hash)
        .cast<MedicationAnalysisHistory?>()
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Early return with loading if animations not initialized yet
    if (_addFormAnimation == null || _resultAnimation == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Medication Warnings'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication Warnings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Badge(
            isLabelVisible: _analysisHistory.isNotEmpty,
            label: Text('${_analysisHistory.length}'),
            child: IconButton(
              icon: const Icon(Icons.history),
              onPressed: () => _showAnalysisHistory(context),
              tooltip: 'Analysis History',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
            tooltip: 'Help',
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
                // Enhanced Safety Notice with animation
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.shade50,
                              Colors.orange.shade100.withOpacity(0.5),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.security,
                                color: Colors.orange.shade700,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Safety First!',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Always consult your healthcare provider or pharmacist before starting, stopping, or changing medications.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Enhanced Add Medication Section
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row - Better responsive layout
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.add_circle_outline,
                                    color: colorScheme.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Add Medication',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                AnimatedRotation(
                                  turns: _showAddForm ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 300),
                                  child: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _showAddForm = !_showAddForm;
                                        if (_showAddForm) {
                                          _addFormAnimationController
                                              ?.forward();
                                        } else {
                                          _addFormAnimationController
                                              ?.reverse();
                                          _clearForm();
                                        }
                                      });
                                    },
                                    icon: Icon(_showAddForm
                                        ? Icons.expand_less
                                        : Icons.add),
                                    tooltip: _showAddForm
                                        ? 'Cancel'
                                        : 'Add medication',
                                  ),
                                ),
                              ],
                            ),
                            // Action buttons moved to separate row
                            if (appState.medications.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: TextButton.icon(
                                  onPressed: () => _showClearAllDialog(context),
                                  icon: const Icon(Icons.clear_all, size: 16),
                                  label: const Text('Clear All'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red.shade600,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        // Animated Add Form
                        SizeTransition(
                          sizeFactor: _addFormAnimation!,
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceVariant
                                      .withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    children: [
                                      TextFormField(
                                        controller: _medicationController,
                                        decoration: InputDecoration(
                                          labelText: 'Medication Name *',
                                          hintText:
                                              'e.g., Aspirin, Ibuprofen, Metformin',
                                          prefixIcon:
                                              const Icon(Icons.medication),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          filled: true,
                                          fillColor: colorScheme.surface,
                                        ),
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Please enter a medication name';
                                          }
                                          return null;
                                        },
                                        textCapitalization:
                                            TextCapitalization.words,
                                      ),
                                      const SizedBox(height: 16),
                                      // Responsive row for smaller screens
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          if (constraints.maxWidth < 400) {
                                            // Stack vertically on small screens
                                            return Column(
                                              children: [
                                                TextFormField(
                                                  controller: _dosageController,
                                                  decoration: InputDecoration(
                                                    labelText: 'Dosage',
                                                    hintText:
                                                        'e.g., 81mg, 10mg',
                                                    prefixIcon: const Icon(
                                                        Icons.medical_services),
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    filled: true,
                                                    fillColor:
                                                        colorScheme.surface,
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                TextFormField(
                                                  controller:
                                                      _frequencyController,
                                                  decoration: InputDecoration(
                                                    labelText: 'Frequency',
                                                    hintText:
                                                        'e.g., Daily, Twice daily',
                                                    prefixIcon: const Icon(
                                                        Icons.schedule),
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    filled: true,
                                                    fillColor:
                                                        colorScheme.surface,
                                                  ),
                                                ),
                                              ],
                                            );
                                          } else {
                                            // Side by side on larger screens
                                            return Row(
                                              children: [
                                                Expanded(
                                                  child: TextFormField(
                                                    controller:
                                                        _dosageController,
                                                    decoration: InputDecoration(
                                                      labelText: 'Dosage',
                                                      hintText:
                                                          'e.g., 81mg, 10mg',
                                                      prefixIcon: const Icon(
                                                          Icons
                                                              .medical_services),
                                                      border:
                                                          OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      filled: true,
                                                      fillColor:
                                                          colorScheme.surface,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: TextFormField(
                                                    controller:
                                                        _frequencyController,
                                                    decoration: InputDecoration(
                                                      labelText: 'Frequency',
                                                      hintText:
                                                          'e.g., Daily, Twice daily',
                                                      prefixIcon: const Icon(
                                                          Icons.schedule),
                                                      border:
                                                          OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      filled: true,
                                                      fillColor:
                                                          colorScheme.surface,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 20),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: _addMedication,
                                          icon: const Icon(Icons.add),
                                          label: const Text('Add Medication'),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
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

                const SizedBox(height: 20),

                // Enhanced Current Medications Section
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.medication_liquid,
                                color: colorScheme.secondary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Current Medications',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${appState.medications.length} medication${appState.medications.length != 1 ? 's' : ''} added',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurface
                                          .withOpacity(0.7),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (appState.medications.isNotEmpty)
                              IconButton(
                                onPressed: () => _forceCheckInteractions(),
                                icon: const Icon(Icons.refresh),
                                tooltip: 'Force refresh interactions',
                                style: IconButton.styleFrom(
                                  backgroundColor: colorScheme.primaryContainer,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (appState.medications.isEmpty) ...[
                          _buildEmptyMedicationState(
                              context, colorScheme, theme),
                        ] else ...[
                          _buildMedicationList(
                              context, appState, theme, colorScheme),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // FIXED: Enhanced Interaction Results Section - Always visible with instant cache
                if (appState.medications.length >= 2) ...[
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primaryContainer.withOpacity(0.1),
                            colorScheme.secondaryContainer.withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with responsive layout
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary
                                            .withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.security,
                                        color: colorScheme.primary,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Drug Interaction Analysis',
                                            style: theme.textTheme.titleLarge
                                                ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'AI-powered medication safety check',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: colorScheme.onSurface
                                                  .withOpacity(0.7),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                // Cache indicator moved to separate row
                                if (_isResultFromCache()) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.green.shade100,
                                          Colors.green.shade50,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.green.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.flash_on,
                                            color: Colors.green.shade700,
                                            size: 14),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Instant Cache Result',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 20),

                            // FIXED: Content that responds to loading states
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _buildAnalysisContent(
                                  appState, colorScheme, theme, context),
                            ),

                            const SizedBox(height: 20),

                            // Action buttons
                            _buildActionButtons(appState, colorScheme, context),
                          ],
                        ),
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

  // FIXED: New method to handle analysis content switching
  Widget _buildAnalysisContent(AppState appState, ColorScheme colorScheme,
      ThemeData theme, BuildContext context) {
    if (appState.isLoading) {
      return _buildLoadingState();
    } else if (appState.medicationInteractionResult.isEmpty) {
      return _buildPendingState(colorScheme);
    } else {
      return _buildInteractionResultWithMarkdown(
        context,
        appState.medicationInteractionResult,
        colorScheme,
        theme,
      );
    }
  }

  // FIXED: New method for action buttons with loading states
  Widget _buildActionButtons(
      AppState appState, ColorScheme colorScheme, BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 500) {
          // Stack vertically on small screens
          return Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      appState.isLoading ? null : _forceCheckInteractions,
                  icon: appState.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(appState.isLoading
                      ? 'Analyzing...'
                      : 'Recheck Interactions'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: appState.medicationInteractionResult.isNotEmpty
                          ? () =>
                              _copyResult(appState.medicationInteractionResult)
                          : null,
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showPharmacistAdvice(context),
                      icon: const Icon(Icons.local_pharmacy),
                      label: const Text('Tips'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.secondaryContainer,
                        foregroundColor: colorScheme.onSecondaryContainer,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        } else {
          // Side by side on larger screens
          return Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      appState.isLoading ? null : _forceCheckInteractions,
                  icon: appState.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(appState.isLoading ? 'Analyzing...' : 'Recheck'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: appState.medicationInteractionResult.isNotEmpty
                      ? () => _copyResult(appState.medicationInteractionResult)
                      : null,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showPharmacistAdvice(context),
                  icon: const Icon(Icons.local_pharmacy),
                  label: const Text('Tips'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.secondaryContainer,
                    foregroundColor: colorScheme.onSecondaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildEmptyMedicationState(
      BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.surfaceVariant.withOpacity(0.3),
                  colorScheme.surfaceVariant.withOpacity(0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.medication_outlined,
                    size: 48,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'No medications added yet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add your medications to check for potential interactions and get personalized safety insights',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                // Responsive button
                LayoutBuilder(
                  builder: (context, constraints) {
                    return SizedBox(
                      width: constraints.maxWidth > 300 ? 300 : double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showAddForm = true;
                            _addFormAnimationController?.forward();
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: Text(
                          constraints.maxWidth > 250
                              ? 'Add Your First Medication'
                              : 'Add Medication',
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMedicationList(BuildContext context, AppState appState,
      ThemeData theme, ColorScheme colorScheme) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: appState.medications.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final medication = appState.medications[index];
        return AnimatedContainer(
          duration: Duration(milliseconds: 200 + (index * 50)),
          curve: Curves.easeOutBack,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            leading: Hero(
              tag: 'medication_$index',
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primaryContainer,
                      colorScheme.primaryContainer.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.medication,
                  color: colorScheme.primary,
                  size: 24,
                ),
              ),
            ),
            title: Text(
              medication.name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${medication.dosage} • ${medication.frequency}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing: PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) {
                if (value == 'delete') {
                  _confirmRemoveMedication(context, index);
                } else if (value == 'edit') {
                  _editMedication(context, index);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 16),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Remove', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // FIXED: Enhanced loading state with better progress indication
  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade50,
            Colors.blue.shade50 ?? Colors.blue.shade50,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Larger, more prominent loading indicator
          SizedBox(
            height: 60,
            width: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 60,
                  width: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                  ),
                ),
                Icon(
                  Icons.psychology,
                  color: Colors.blue.shade600,
                  size: 24,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'PersonalMedAI is Analyzing...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Checking for potential drug interactions',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'This may take 10-30 seconds',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade500,
            ),
            textAlign: TextAlign.center,
          ),

          // Added progress steps indicator
          const SizedBox(height: 20),
          _buildAnalysisSteps(),
        ],
      ),
    );
  }

  // FIXED: Add animated progress steps
  Widget _buildAnalysisSteps() {
    return Column(
      children: [
        _buildProgressStep('Processing medications...', true),
        const SizedBox(height: 8),
        _buildProgressStep('Checking database...', true),
        const SizedBox(height: 8),
        _buildProgressStep('Analyzing interactions...', false),
        const SizedBox(height: 8),
        _buildProgressStep('Generating report...', false),
      ],
    );
  }

  Widget _buildProgressStep(String text, bool isActive) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isActive ? Colors.blue.shade600 : Colors.blue.shade200,
            shape: BoxShape.circle,
          ),
          child: isActive
              ? SizedBox(
                  width: 8,
                  height: 8,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? Colors.blue.shade700 : Colors.blue.shade400,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingState(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.hourglass_empty,
            color: Colors.grey.shade600,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            'Analysis Pending',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the refresh button to check for interactions.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionResultWithMarkdown(
    BuildContext context,
    String result,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final isNoInteraction = _isNoInteractionResult(result);
    final resultColor = isNoInteraction ? Colors.green : Colors.orange;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            resultColor.shade50,
            resultColor.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: resultColor.shade200),
        boxShadow: [
          BoxShadow(
            color: resultColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: resultColor.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isNoInteraction ? Icons.check_circle : Icons.warning,
                  color: resultColor.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isNoInteraction
                      ? 'No Significant Interactions Found'
                      : 'Potential Drug Interaction Detected',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: resultColor.shade800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: resultColor.withOpacity(0.2),
              ),
            ),
            child: SelectionArea(
              child: SingleChildScrollView(
                child: TexMarkdown(
                  result,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isNoInteractionResult(String result) {
    final lowerResult = result.toLowerCase();
    return lowerResult.contains('no significant') ||
        lowerResult.contains('no interactions') ||
        lowerResult.contains('safe') ||
        lowerResult.contains('no major') ||
        lowerResult.contains('no concerning');
  }

  bool _isResultFromCache() {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.medications.length < 2) return false;

    final hash = _generateMedicationHash(appState.medications);
    return hash == _lastAnalysisHash &&
        _findExistingAnalysis(appState.medications) != null;
  }

  void _clearForm() {
    _medicationController.clear();
    _dosageController.clear();
    _frequencyController.clear();
  }

  // FIXED: Updated _addMedication to handle immediate cache checking
  void _addMedication() {
    if (!_formKey.currentState!.validate()) return;

    final appState = Provider.of<AppState>(context, listen: false);

    final medication = Medication(
      name: _medicationController.text.trim(),
      dosage: _dosageController.text.trim().isEmpty
          ? 'Not specified'
          : _dosageController.text.trim(),
      frequency: _frequencyController.text.trim().isEmpty
          ? 'As needed'
          : _frequencyController.text.trim(),
    );

    appState.addMedication(medication);

    _clearForm();
    setState(() {
      _showAddForm = false;
      _addFormAnimationController?.reverse();
    });

    // FIXED: Check interactions immediately for instant cache response
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInteractionsWithHistory();
    });

    // Enhanced success feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${medication.name} added successfully',
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
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {
            appState.removeMedication(appState.medications.length - 1);
            _checkInteractionsWithHistory();
          },
        ),
      ),
    );
  }

  void _copyResult(String result) async {
    await Clipboard.setData(ClipboardData(text: result));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.copy, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Analysis copied to clipboard',
                overflow: TextOverflow.ellipsis,
              ),
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

  void _editMedication(BuildContext context, int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.construction, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Edit feature coming soon!',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _confirmRemoveMedication(BuildContext context, int index) {
    final appState = Provider.of<AppState>(context, listen: false);
    final medication = appState.medications[index];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Remove Medication',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: [
              const TextSpan(text: 'Are you sure you want to remove '),
              TextSpan(
                text: medication.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' from your medication list?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              appState.removeMedication(index);
              _checkInteractionsWithHistory();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.delete, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${medication.name} removed',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.clear_all, color: Colors.red),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Clear All Medications',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: const Text(
            'Are you sure you want to remove all medications from your list? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final appState = Provider.of<AppState>(context, listen: false);
              final count = appState.medications.length;
              while (appState.medications.isNotEmpty) {
                appState.removeMedication(0);
              }
              appState.setMedicationInteractionResult('');
              _lastAnalysisHash = null;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Cleared $count medications',
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
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  // FIXED: Updated _checkInteractionsWithHistory method for instant cached results
  Future<void> _checkInteractionsWithHistory() async {
    final appState = Provider.of<AppState>(context, listen: false);

    if (appState.medications.length < 2) {
      appState.setMedicationInteractionResult('');
      _lastAnalysisHash = null;
      return;
    }

    // Check if we have cached result for current medication combination
    final existingAnalysis = _findExistingAnalysis(appState.medications);
    if (existingAnalysis != null) {
      // FIXED: Set cached result IMMEDIATELY without delay
      appState.setMedicationInteractionResult(existingAnalysis.result);
      _lastAnalysisHash = existingAnalysis.medicationHash;

      // Show cache notification without delay
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.cached, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Analysis loaded instantly from cache',
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
              duration: const Duration(seconds: 1), // Shorter duration
            ),
          );
        }
      });
      return;
    }

    // No cached result, make API call
    await _performNewAnalysis();
  }

  Future<void> _forceCheckInteractions() async {
    await _performNewAnalysis();
  }

  // FIXED: Updated _performNewAnalysis with proper progress indication
  Future<void> _performNewAnalysis() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final deepSeekService =
        Provider.of<DeepSeekService>(context, listen: false);

    if (appState.medications.length < 2) {
      appState.setMedicationInteractionResult('');
      return;
    }

    // FIXED: Show loading state immediately
    appState.setLoading(true);

    // FIXED: Ensure the result section appears with loading indicator
    if (appState.medicationInteractionResult.isEmpty) {
      // Trigger rebuild to show the loading state
      setState(() {});
    }

    try {
      final medicationNames =
          appState.medications.map((med) => med.toString()).toList();
      final result =
          await deepSeekService.checkMedicationInteractions(medicationNames);

      appState.setMedicationInteractionResult(result);

      // Save to history
      final newAnalysis = MedicationAnalysisHistory(
        medications: List.from(appState.medications),
        result: result,
        timestamp: DateTime.now(),
        medicationHash: _generateMedicationHash(appState.medications),
      );

      setState(() {
        _analysisHistory.add(newAnalysis);
        _lastAnalysisHash = newAnalysis.medicationHash;

        if (_analysisHistory.length > 10) {
          _analysisHistory =
              _analysisHistory.sublist(_analysisHistory.length - 10);
        }
      });

      await _saveAnalysisHistory();
    } catch (e) {
      appState.setMedicationInteractionResult(
          'Unable to check medication interactions at this time. Please consult your pharmacist or healthcare provider.');
    } finally {
      appState.setLoading(false);
    }
  }

  void _showAnalysisHistory(BuildContext context) {
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
                    child: Text(
                      'Analysis History',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      overflow: TextOverflow.ellipsis,
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
              if (_analysisHistory.isEmpty) ...[
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No analysis history yet',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your medication interaction analyses will appear here',
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
                    itemCount: _analysisHistory.length,
                    itemBuilder: (context, index) {
                      final analysis =
                          _analysisHistory.reversed.toList()[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          title: Text(
                            analysis.medications.map((m) => m.name).join(', '),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Container(
                            margin: const EdgeInsets.only(top: 4),
                            child: Text(
                              _formatDateTime(analysis.timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.6),
                              ),
                              overflow: TextOverflow.ellipsis,
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
                                        Icons.analytics,
                                        size: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Analysis Result:',
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
                                          analysis.result,
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
                                          onPressed: () =>
                                              _copyResult(analysis.result),
                                          icon:
                                              const Icon(Icons.copy, size: 16),
                                          label: const Text('Copy'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: FittedBox(
                                          child: ElevatedButton.icon(
                                            onPressed: () =>
                                                _loadAnalysisResult(analysis),
                                            icon: const Icon(Icons.restore,
                                                size: 16),
                                            label: const Text('Use Result'),
                                          ),
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

  void _loadAnalysisResult(MedicationAnalysisHistory analysis) {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.setMedicationInteractionResult(analysis.result);
    _lastAnalysisHash = analysis.medicationHash;
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.restore, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Analysis result loaded from history',
                overflow: TextOverflow.ellipsis,
              ),
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

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

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
                'Medication Interaction Checker',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: SelectionArea(
            child: TexMarkdown(
              '''
## How to Use This Tool

**Add Your Medications:**
1. Add all your current medications
2. Include prescription and over-the-counter drugs
3. Review the interaction analysis
4. Consult your healthcare provider for questions

## ⚡ Instant Cache Feature

Analysis results are **saved automatically**. Returning to the same medication combination will show **instant cached results**, saving time and API calls.

## ⚠️ Important Disclaimer

This tool provides **general information only**. Always consult your healthcare provider or pharmacist before making medication changes.

**For emergencies:** Call your local emergency number immediately.
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

  void _showPharmacistAdvice(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.local_pharmacy, color: Colors.green),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pharmacist Tips',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: SelectionArea(
            child: TexMarkdown(
              '''
## 💊 Essential Medication Tips

**Taking Medications:**
- Take medications **as prescribed**
- Follow **timing instructions** carefully
- Note **food interactions** (with/without meals)

**Safety Guidelines:**
- Stay **hydrated** when taking medications
- Keep an **updated medication list**
- Inform **all healthcare providers** of your medications

**When in Doubt:**
- **Ask questions** if you're unsure about anything
- **Never stop** medications without consulting your doctor
- **Report side effects** to your healthcare provider

**Emergency:** If you experience severe side effects, seek immediate medical attention.
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
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.thumb_up),
            label: const Text('Thanks!'),
          ),
        ],
      ),
    );
  }
}

// History model class (unchanged)
class MedicationAnalysisHistory {
  final List<Medication> medications;
  final String result;
  final DateTime timestamp;
  final String medicationHash;

  MedicationAnalysisHistory({
    required this.medications,
    required this.result,
    required this.timestamp,
    required this.medicationHash,
  });

  Map<String, dynamic> toJson() => {
        'medications': medications
            .map((m) => {
                  'name': m.name,
                  'dosage': m.dosage,
                  'frequency': m.frequency,
                })
            .toList(),
        'result': result,
        'timestamp': timestamp.toIso8601String(),
        'medicationHash': medicationHash,
      };

  static MedicationAnalysisHistory fromJson(Map<String, dynamic> json) =>
      MedicationAnalysisHistory(
        medications: (json['medications'] as List)
            .map((m) => Medication(
                  name: m['name'],
                  dosage: m['dosage'],
                  frequency: m['frequency'],
                ))
            .toList(),
        result: json['result'],
        timestamp: DateTime.parse(json['timestamp']),
        medicationHash: json['medicationHash'],
      );
}
