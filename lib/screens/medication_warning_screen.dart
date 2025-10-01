import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:personalmedai/models/medication.dart';
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

  // ENHANCED: Smart caching system
  List<MedicationAnalysisHistory> _analysisHistory = [];
  String? _lastAnalysisHash;
  bool _isResultFromCache = false;
  String _currentMedicationHash = '';

  // Animation controllers
  AnimationController? _addFormAnimationController;
  AnimationController? _resultAnimationController;
  Animation<double>? _addFormAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadAnalysisHistory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInteractionsWithSmartCache();
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

  // ENHANCED: Load analysis history from SharedPreferences
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
        print(
            '📂 Loaded ${_analysisHistory.length} analysis records from cache');
      }
    } catch (e) {
      print('❌ Error loading analysis history: $e');
    }
  }

  // ENHANCED: Save analysis history to SharedPreferences
  Future<void> _saveAnalysisHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson =
          jsonEncode(_analysisHistory.map((item) => item.toJson()).toList());
      await prefs.setString('medication_analysis_history', historyJson);
      print('💾 Saved analysis history to cache');
    } catch (e) {
      print('❌ Error saving analysis history: $e');
    }
  }

  // ENHANCED: More robust medication hash generation
  String _generateMedicationHash(List medications) {
    if (medications.length < 2) return '';

    // Create a sorted list of medication strings for consistent hashing
    final medicationStrings = medications.map((med) {
      // Normalize the medication data
      final name = med.name.toLowerCase().trim();
      final dosage = med.dosage.toLowerCase().trim();
      final frequency = med.frequency.toLowerCase().trim();
      return '$name|$dosage|$frequency';
    }).toList()
      ..sort();

    final combinedString = medicationStrings.join('::');
    final hash = combinedString.hashCode.toString();
    print('🔍 Generated medication hash: $hash');
    print('📋 For medications: ${medicationStrings.join(' + ')}');
    return hash;
  }

  // FIXED: Enhanced cache finding with better matching
  MedicationAnalysisHistory? _findExistingAnalysis(List medications) {
    if (medications.length < 2) return null;

    final targetHash = _generateMedicationHash(medications);
    print('🔍 Looking for cached analysis with hash: $targetHash');
    print('📚 Available cached analyses: ${_analysisHistory.length}');

    for (int i = 0; i < _analysisHistory.length; i++) {
      final analysis = _analysisHistory[i];
      print(
          ' - Cache $i: hash=${analysis.medicationHash}, meds=${analysis.medications.map((m) => m.name).join(", ")}');
      if (analysis.medicationHash == targetHash) {
        print('✅ Found matching cache at index $i');
        return analysis;
      }
    }

    print('❌ No matching cache found');
    return null;
  }

  // FIXED: More reliable cache checking
  Future<void> _checkInteractionsWithSmartCache() async {
    final appState = Provider.of<AppState>(context, listen: false);
    print('🔄 Checking interactions with smart cache...');
    print(
        '💊 Current medications: ${appState.medications.map((m) => m.name).join(', ')}');

    if (appState.medications.length < 2) {
      print('⚠️ Less than 2 medications, clearing results');
      appState.setMedicationInteractionResult('');
      _lastAnalysisHash = null;
      _isResultFromCache = false;
      _currentMedicationHash = '';
      setState(() {});
      return;
    }

    final newHash = _generateMedicationHash(appState.medications);
    print('🆔 New hash: $newHash');
    print('🆔 Last hash: $_lastAnalysisHash');
    print('🆔 Current hash: $_currentMedicationHash');

    // If we already have the result for these exact medications displayed
    if (_lastAnalysisHash == newHash &&
        appState.medicationInteractionResult.isNotEmpty &&
        _isResultFromCache) {
      print('✅ Result already displayed and cached for current medications');
      return;
    }

    // Update current hash
    _currentMedicationHash = newHash;

    // Check if we have this combination in cache
    final existingAnalysis = _findExistingAnalysis(appState.medications);
    if (existingAnalysis != null) {
      print('⚡ Found cached analysis, displaying instantly');

      // Set the result immediately
      appState.setMedicationInteractionResult(existingAnalysis.result);
      _lastAnalysisHash = newHash;
      _isResultFromCache = true;

      // Update UI immediately
      setState(() {});

      // Show success notification
      _showCacheSuccessNotification(existingAnalysis.timestamp);
      return;
    }

    print('❌ No cache found, will need to perform analysis');
    // Reset cache flags since we don't have cached result
    _isResultFromCache = false;
    _lastAnalysisHash = null;

    // Don't automatically start analysis - wait for user to click button
    setState(() {});
  }

  // NEW: Show cache success notification
  void _showCacheSuccessNotification(DateTime cacheTime) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.flash_on, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Instant Cache Result ⚡',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Loaded from ${_formatCacheAge(cacheTime)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Refresh',
              textColor: Colors.white,
              onPressed: () => _forceCheckInteractions(),
            ),
          ),
        );
      }
    });
  }

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

  // FIXED: Force refresh clears cache flags properly
  Future<void> _forceCheckInteractions() async {
    print('🔄 Force refresh requested');
    _isResultFromCache = false;
    _lastAnalysisHash = null;
    setState(() {}); // Update UI to remove cache indicator
    await _performNewAnalysis();
  }

  // ENHANCED: Perform new analysis with improved caching
  Future<void> _performNewAnalysis() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final deepSeekService =
        Provider.of<DeepSeekService>(context, listen: false);

    if (appState.medications.length < 2) {
      appState.setMedicationInteractionResult('');
      return;
    }

    if (deepSeekService == null) {
      appState.setMedicationInteractionResult(
          'AI service not available. Please check your connection and try again.');
      return;
    }

    // Show loading state
    appState.setLoading(true);
    _isResultFromCache = false;
    setState(() {});

    try {
      final medicationNames =
          appState.medications.map((med) => med.toString()).toList();
      print('🔄 Starting new analysis for: ${medicationNames.join(', ')}');

      final result = await deepSeekService.checkMedicationInteractions(
          medicationNames, appState);

      appState.setMedicationInteractionResult(result);

      // Save to history with enhanced metadata
      final newAnalysis = MedicationAnalysisHistory(
        medications: List.from(appState.medications),
        result: result,
        timestamp: DateTime.now(),
        medicationHash: _currentMedicationHash,
      );

      setState(() {
        // Remove old analysis for same medications if exists
        _analysisHistory.removeWhere(
            (analysis) => analysis.medicationHash == _currentMedicationHash);

        // Add new analysis at the beginning
        _analysisHistory.insert(0, newAnalysis);
        _lastAnalysisHash = _currentMedicationHash;

        // Keep only last 20 analyses to manage storage
        if (_analysisHistory.length > 20) {
          _analysisHistory = _analysisHistory.take(20).toList();
        }
      });

      await _saveAnalysisHistory();
      print('✅ New analysis completed and cached');
    } catch (e) {
      print('❌ Error during analysis: $e');
      appState.setMedicationInteractionResult(
          'Unable to analyze medication interactions at this time. Please check your internet connection and try again later.');
    } finally {
      appState.setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication Warnings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Enhanced history button with count
          Badge(
            isLabelVisible: _analysisHistory.isNotEmpty,
            label: Text('${_analysisHistory.length}'),
            child: IconButton(
              icon: const Icon(Icons.history),
              onPressed: () => _showAnalysisHistory(context),
              tooltip: 'Analysis History (${_analysisHistory.length})',
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
                // Enhanced Safety Notice
                _buildSafetyNotice(theme, colorScheme),
                const SizedBox(height: 24),

                // Enhanced Add Medication Section
                _buildAddMedicationSection(colorScheme, theme),
                const SizedBox(height: 20),

                // Enhanced Current Medications Section
                _buildCurrentMedicationsSection(appState, theme, colorScheme),
                const SizedBox(height: 20),

                // ENHANCED: Drug Interaction Analysis with smart caching
                if (appState.medications.length >= 2) ...[
                  _buildInteractionAnalysisSection(
                      appState, colorScheme, theme, context),
                ],
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  // ENHANCED: Interaction Analysis Section with cache indicators
  Widget _buildInteractionAnalysisSection(AppState appState,
      ColorScheme colorScheme, ThemeData theme, BuildContext context) {
    return Card(
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
              // Header with cache status
              _buildAnalysisHeader(colorScheme, theme),
              const SizedBox(height: 20),

              // Content area with smart loading/results
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildAnalysisContent(
                    appState, colorScheme, theme, context),
              ),
              const SizedBox(height: 20),

              // Action buttons with cache options
              _buildAnalysisActionButtons(appState, colorScheme, context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisHeader(ColorScheme colorScheme, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.2),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Drug Interaction Analysis',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'AI-powered medication safety check',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),

        // Cache indicator
        if (_isResultFromCache) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                Icon(Icons.flash_on, color: Colors.green.shade700, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Instant Cache Result ⚡',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // FIXED: Enhanced analysis content builder
  Widget _buildAnalysisContent(AppState appState, ColorScheme colorScheme,
      ThemeData theme, BuildContext context) {
    // If we're loading, show loading state
    if (appState.isLoading) {
      return _buildLoadingState(colorScheme, theme);
    }

    // If we have results, show them
    if (appState.medicationInteractionResult.isNotEmpty) {
      return _buildInteractionResultWithMarkdown(
        context,
        appState.medicationInteractionResult,
        colorScheme,
        theme,
      );
    }

    // If we have medications but no results and not loading, show start button
    if (appState.medications.length >= 2) {
      return _buildStartAnalysisState(colorScheme, theme);
    }

    // Default pending state
    return _buildPendingState(colorScheme);
  }

  // NEW: Start analysis state (when we have meds but no results)
  Widget _buildStartAnalysisState(ColorScheme colorScheme, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withOpacity(0.2),
            colorScheme.primaryContainer.withOpacity(0.1),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.play_circle_outline,
              size: 48,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Ready to Analyze',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Click "Start Analysis" below to check for drug interactions',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // FIXED: Enhanced action buttons with better logic
  Widget _buildAnalysisActionButtons(
      AppState appState, ColorScheme colorScheme, BuildContext context) {
    final hasResults = appState.medicationInteractionResult.isNotEmpty;

    return Column(
      children: [
        // Main action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: appState.isLoading
                    ? null
                    : () {
                        if (hasResults || _isResultFromCache) {
                          _forceCheckInteractions();
                        } else {
                          _performNewAnalysis();
                        }
                      },
                icon: appState.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(hasResults || _isResultFromCache
                        ? Icons.refresh
                        : Icons.play_arrow),
                label: Text(appState.isLoading
                    ? 'Analyzing...'
                    : hasResults || _isResultFromCache
                        ? 'Refresh Analysis'
                        : 'Start Analysis'),
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
                onPressed: () => _showAnalysisHistory(context),
                icon: Badge(
                  isLabelVisible: _analysisHistory.isNotEmpty,
                  label: Text('${_analysisHistory.length}'),
                  child: const Icon(Icons.history),
                ),
                label: const Text('History'),
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
        const SizedBox(height: 8),

        // Secondary actions
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: hasResults
                    ? () => _copyResult(appState.medicationInteractionResult)
                    : null,
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy Result'),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: () => _showPharmacistAdvice(context),
                icon: const Icon(Icons.local_pharmacy, size: 16),
                label: const Text('Safety Tips'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSafetyNotice(ThemeData theme, ColorScheme colorScheme) {
    return TweenAnimationBuilder<double>(
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
    );
  }

  Widget _buildAddMedicationSection(ColorScheme colorScheme, ThemeData theme) {
    return Card(
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
                    style: theme.textTheme.titleMedium?.copyWith(
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
                          _addFormAnimationController?.forward();
                        } else {
                          _addFormAnimationController?.reverse();
                          _clearForm();
                        }
                      });
                    },
                    icon: Icon(_showAddForm ? Icons.expand_less : Icons.add),
                    tooltip: _showAddForm ? 'Cancel' : 'Add medication',
                  ),
                ),
              ],
            ),
            if (_showAddForm) ...[
              SizeTransition(
                sizeFactor: _addFormAnimation!,
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant.withOpacity(0.3),
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
                                hintText: 'e.g., Aspirin, Ibuprofen, Metformin',
                                prefixIcon: const Icon(Icons.medication),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: colorScheme.surface,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a medication name';
                                }
                                return null;
                              },
                              textCapitalization: TextCapitalization.words,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _dosageController,
                                    decoration: InputDecoration(
                                      labelText: 'Dosage',
                                      hintText: 'e.g., 81mg, 10mg',
                                      prefixIcon:
                                          const Icon(Icons.medical_services),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: colorScheme.surface,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _frequencyController,
                                    decoration: InputDecoration(
                                      labelText: 'Frequency',
                                      hintText: 'e.g., Daily, Twice daily',
                                      prefixIcon: const Icon(Icons.schedule),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: colorScheme.surface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _addMedication,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Medication'),
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
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
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentMedicationsSection(
      AppState appState, ThemeData theme, ColorScheme colorScheme) {
    return Card(
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${appState.medications.length} medication${appState.medications.length != 1 ? 's' : ''} added',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
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
              _buildEmptyMedicationState(context, colorScheme, theme),
            ] else ...[
              _buildMedicationList(context, appState, theme, colorScheme),
            ],
          ],
        ),
      ),
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showAddForm = true;
                        _addFormAnimationController?.forward();
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Your First Medication'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  Widget _buildLoadingState(ColorScheme colorScheme, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade50,
            Colors.blue.shade50,
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
                    valueColor: AlwaysStoppedAnimation(Colors.blue.shade600),
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
          const SizedBox(height: 20),
          _buildAnalysisSteps(),
        ],
      ),
    );
  }

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
                    valueColor: AlwaysStoppedAnimation(Colors.white),
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
            'Click the start button to check for interactions.',
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

  void _clearForm() {
    _medicationController.clear();
    _dosageController.clear();
    _frequencyController.clear();
  }

  // FIXED: Enhanced medication addition with proper constructor
  void _addMedication() {
    if (!_formKey.currentState!.validate()) return;

    final appState = Provider.of<AppState>(context, listen: false);

    // FIXED: Use the enhanced Medication constructor with required parameters
    final medication = Medication(
      id: DateTime.now()
          .millisecondsSinceEpoch
          .toString(), // Generate unique ID
      name: _medicationController.text.trim(),
      dosage: _dosageController.text.trim().isEmpty
          ? 'Not specified'
          : _dosageController.text.trim(),
      frequency: _frequencyController.text.trim().isEmpty
          ? 'As needed'
          : _frequencyController.text.trim(),
      currentQuantity: 30, // Default starting quantity
      createdAt: DateTime.now(), // Current timestamp
    );

    print('➕ Adding medication: ${medication.name}');
    appState.addMedication(medication);
    _clearForm();

    setState(() {
      _showAddForm = false;
      _addFormAnimationController?.reverse();
    });

    // Check cache after adding
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInteractionsWithSmartCache();
    });

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
            _checkInteractionsWithSmartCache();
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
              _checkInteractionsWithSmartCache();
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

  // FIXED: Enhanced analysis history with current medication highlighting
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Analysis History',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${_analysisHistory.length} cached analyses',
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
                  // Debug button to clear cache
                  if (_analysisHistory.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _analysisHistory.clear();
                        });
                        _saveAnalysisHistory();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cache cleared for testing'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      },
                      icon: const Icon(Icons.delete_sweep),
                      tooltip: 'Clear Cache (Debug)',
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
                          'Analyze medication interactions to build your cache history',
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
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: _analysisHistory.length,
                    itemBuilder: (context, index) {
                      final analysis = _analysisHistory[index];
                      final isCurrentMedications =
                          analysis.medicationHash == _currentMedicationHash;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: isCurrentMedications ? 4 : 2,
                        color: isCurrentMedications
                            ? Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withOpacity(0.3)
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isCurrentMedications
                              ? BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                )
                              : BorderSide.none,
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isCurrentMedications
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.2)
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isCurrentMedications
                                  ? Icons.star
                                  : Icons.medication,
                              color: isCurrentMedications
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                              size: 20,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  analysis.medications
                                      .map((m) => m.name)
                                      .join(', '),
                                  style: TextStyle(
                                    fontWeight: isCurrentMedications
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCurrentMedications) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'CURRENT',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hash: ${analysis.medicationHash}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.5),
                                ),
                              ),
                              Text(
                                _formatCacheAge(analysis.timestamp),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _loadAnalysisResult(analysis),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            child: Text(
                              isCurrentMedications ? 'Current' : 'Use',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
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
    _isResultFromCache = true;

    setState(() {
      // Update UI to show cache indicator
    });

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.restore, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Analysis result loaded from history ⚡',
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

## ⚡ Smart Cache System

Analysis results are **automatically cached**:
- Same medication combinations load **instantly**
- Cache shows age of analysis
- **"Refresh Analysis"** button for new analysis
- **History view** shows all past analyses

## 🎯 Cache Benefits

- **Instant results** for repeated checks
- **Reduced API usage** saves costs
- **Offline access** to past analyses
- **Smart detection** of medication changes

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

**Smart Cache Benefits:**
- **Instant results** when rechecking same medications
- **Track changes** over time with history
- **Share results** easily with healthcare providers

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

// History model class with enhanced functionality
class MedicationAnalysisHistory {
  final List medications;
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
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: m['name'],
                  dosage: m['dosage'],
                  frequency: m['frequency'],
                  currentQuantity: 30,
                  createdAt: DateTime.now(),
                ))
            .toList(),
        result: json['result'],
        timestamp: DateTime.parse(json['timestamp']),
        medicationHash: json['medicationHash'],
      );
}
