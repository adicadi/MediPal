import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medipal/models/medication.dart';
import 'package:medipal/screens/medication_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'dart:convert';
import '../utils/app_state.dart';
import '../utils/blur_dialog.dart';
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
        if (kDebugMode) {
          print(
              '📂 Loaded ${_analysisHistory.length} analysis records from cache');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading analysis history: $e');
      }
    }
  }

  // ENHANCED: Save analysis history to SharedPreferences
  Future<void> _saveAnalysisHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson =
          jsonEncode(_analysisHistory.map((item) => item.toJson()).toList());
      await prefs.setString('medication_analysis_history', historyJson);
      if (kDebugMode) {
        print('💾 Saved analysis history to cache');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving analysis history: $e');
      }
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
    if (kDebugMode) {
      print('🔍 Generated medication hash: $hash');
    }
    if (kDebugMode) {
      print('📋 For medications: ${medicationStrings.join(' + ')}');
    }
    return hash;
  }

  // FIXED: Enhanced cache finding with better matching
  MedicationAnalysisHistory? _findExistingAnalysis(List medications) {
    if (medications.length < 2) return null;

    final targetHash = _generateMedicationHash(medications);
    if (kDebugMode) {
      print('🔍 Looking for cached analysis with hash: $targetHash');
    }
    if (kDebugMode) {
      print('📚 Available cached analyses: ${_analysisHistory.length}');
    }

    for (int i = 0; i < _analysisHistory.length; i++) {
      final analysis = _analysisHistory[i];
      if (kDebugMode) {
        print(
            ' - Cache $i: hash=${analysis.medicationHash}, meds=${analysis.medications.map((m) => m.name).join(", ")}');
      }
      if (analysis.medicationHash == targetHash) {
        if (kDebugMode) {
          print('✅ Found matching cache at index $i');
        }
        return analysis;
      }
    }

    if (kDebugMode) {
      print('❌ No matching cache found');
    }
    return null;
  }

  // FIXED: More reliable cache checking
  Future<void> _checkInteractionsWithSmartCache() async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (kDebugMode) {
      print('🔄 Checking interactions with smart cache...');
    }
    if (kDebugMode) {
      print(
          '💊 Current medications: ${appState.medications.map((m) => m.name).join(', ')}');
    }

    if (appState.medications.length < 2) {
      if (kDebugMode) {
        print('⚠️ Less than 2 medications, clearing results');
      }
      appState.setMedicationInteractionResult('');
      _lastAnalysisHash = null;
      _isResultFromCache = false;
      _currentMedicationHash = '';
      setState(() {});
      return;
    }

    final newHash = _generateMedicationHash(appState.medications);
    if (kDebugMode) {
      print('🆔 New hash: $newHash');
    }
    if (kDebugMode) {
      print('🆔 Last hash: $_lastAnalysisHash');
    }
    if (kDebugMode) {
      print('🆔 Current hash: $_currentMedicationHash');
    }

    // If we already have the result for these exact medications displayed
    if (_lastAnalysisHash == newHash &&
        appState.medicationInteractionResult.isNotEmpty &&
        _isResultFromCache) {
      if (kDebugMode) {
        print('✅ Result already displayed and cached for current medications');
      }
      return;
    }

    // Update current hash
    _currentMedicationHash = newHash;

    // Check if we have this combination in cache
    final existingAnalysis = _findExistingAnalysis(appState.medications);
    if (existingAnalysis != null) {
      if (kDebugMode) {
        print('⚡ Found cached analysis, displaying instantly');
      }

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

    if (kDebugMode) {
      print('❌ No cache found, will need to perform analysis');
    }
    // Reset cache flags since we don't have cached result
    _isResultFromCache = false;
    _lastAnalysisHash = null;

    // Don't automatically start analysis - wait for user to click button
    setState(() {});
  }

  // UPDATED: Show cache success notification - NOW USES THEME COLORS
  void _showCacheSuccessNotification(DateTime cacheTime) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.flash_on, color: colorScheme.onTertiary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Instant Cache Result ⚡',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onTertiary,
                        ),
                      ),
                      Text(
                        'Loaded from ${_formatCacheAge(cacheTime)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onTertiary.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: colorScheme.tertiary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Refresh',
              textColor: colorScheme.onTertiary,
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
    if (kDebugMode) {
      print('🔄 Force refresh requested');
    }
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

    // Show loading state
    appState.setLoading(true);
    _isResultFromCache = false;
    setState(() {});

    try {
      final medicationNames =
          appState.medications.map((med) => med.toString()).toList();
      if (kDebugMode) {
        print('🔄 Starting new analysis for: ${medicationNames.join(', ')}');
      }

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
      if (kDebugMode) {
        print('✅ New analysis completed and cached');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error during analysis: $e');
      }
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Consumer<AppState>(
          builder: (context, appState, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => Navigator.maybePop(context),
                        style: IconButton.styleFrom(
                          shape: const CircleBorder(),
                          backgroundColor: colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.9),
                          foregroundColor: colorScheme.onSurface,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Medication Warnings',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MedicationsScreen(),
                            ),
                          );
                        },
                        style: IconButton.styleFrom(
                          shape: const CircleBorder(),
                          backgroundColor: colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.9),
                          foregroundColor: colorScheme.onSurface,
                        ),
                        icon: const Icon(Icons.alarm_rounded),
                        tooltip: 'Set Reminders',
                      ),
                      Badge(
                        isLabelVisible: _analysisHistory.isNotEmpty,
                        label: Text('${_analysisHistory.length}'),
                        child: IconButton.filledTonal(
                          onPressed: () => _showAnalysisHistory(context),
                          style: IconButton.styleFrom(
                            shape: const CircleBorder(),
                            backgroundColor:
                                colorScheme.surfaceContainerHighest.withValues(
                              alpha: 0.9,
                            ),
                            foregroundColor: colorScheme.onSurface,
                          ),
                          icon: const Icon(Icons.history_rounded),
                          tooltip:
                              'Analysis History (${_analysisHistory.length})',
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => _showHelpDialog(context),
                        style: IconButton.styleFrom(
                          shape: const CircleBorder(),
                          backgroundColor: colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.9),
                          foregroundColor: colorScheme.onSurface,
                        ),
                        icon: const Icon(Icons.help_outline_rounded),
                        tooltip: 'Help',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                // UPDATED: Enhanced Safety Notice - NOW USES THEME COLORS
                _buildSafetyNotice(theme, colorScheme),
                const SizedBox(height: 16),

                // Enhanced Add Medication Section
                _buildAddMedicationSection(colorScheme, theme),
                const SizedBox(height: 14),

                // Enhanced Current Medications Section
                _buildCurrentMedicationsSection(appState, theme, colorScheme),
                const SizedBox(height: 14),

                // ENHANCED: Drug Interaction Analysis with smart caching
                if (appState.medications.length >= 2) ...[
                  _buildInteractionAnalysisSection(
                      appState, colorScheme, theme, context),
                ],
                const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // UPDATED: Safety notice now uses theme colors instead of hardcoded orange
  Widget _buildSafetyNotice(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.errorContainer
                .withValues(alpha: 0.7), // Theme-based warning color
            colorScheme.errorContainer.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.error.withValues(alpha: 0.1),
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
              color: colorScheme.error.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.security,
              color: colorScheme.error,
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
                    color: colorScheme.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Always consult your healthcare provider or pharmacist before starting, stopping, or changing medications.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onErrorContainer,
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
    );
  }

  // ENHANCED: Interaction Analysis Section with cache indicators
  Widget _buildInteractionAnalysisSection(AppState appState,
      ColorScheme colorScheme, ThemeData theme, BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: colorScheme.surfaceContainer.withValues(alpha: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with cache status
              _buildAnalysisHeader(colorScheme, theme),
              const SizedBox(height: 14),

              // Content area with smart loading/results
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildAnalysisContent(
                    appState, colorScheme, theme, context),
              ),
              const SizedBox(height: 14),

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
                color: colorScheme.primary.withValues(alpha: 0.2),
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
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),

        // UPDATED: Cache indicator now uses theme colors
        if (_isResultFromCache) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.tertiary.withValues(alpha: 0.3),
                  colorScheme.tertiary.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.tertiary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.flash_on, color: colorScheme.tertiary, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Instant Cache Result ⚡',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.tertiary,
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
            colorScheme.primaryContainer.withValues(alpha: 0.2),
            colorScheme.primaryContainer.withValues(alpha: 0.1),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
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
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // UPDATED: Loading state now uses theme colors instead of hardcoded blue
  Widget _buildLoadingState(ColorScheme colorScheme, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.7),
            colorScheme.primaryContainer.withValues(alpha: 0.3),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.1),
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
                    valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                  ),
                ),
                Icon(
                  Icons.psychology,
                  color: colorScheme.primary,
                  size: 24,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'MediPal is Analyzing...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimaryContainer,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Checking for potential drug interactions',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'This may take 10-30 seconds',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _buildAnalysisSteps(colorScheme),
        ],
      ),
    );
  }

  Widget _buildAnalysisSteps(ColorScheme colorScheme) {
    return Column(
      children: [
        _buildProgressStep('Processing medications...', true, colorScheme),
        const SizedBox(height: 8),
        _buildProgressStep('Checking database...', true, colorScheme),
        const SizedBox(height: 8),
        _buildProgressStep('Analyzing interactions...', false, colorScheme),
        const SizedBox(height: 8),
        _buildProgressStep('Generating report...', false, colorScheme),
      ],
    );
  }

  Widget _buildProgressStep(
      String text, bool isActive, ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isActive ? colorScheme.primary : colorScheme.outline,
            shape: BoxShape.circle,
          ),
          child: isActive
              ? const SizedBox(
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
              color: isActive
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
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
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.hourglass_empty,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            'Analysis Pending',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            'Click the start button to check for interactions.',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // UPDATED: Result display now uses theme colors
  Widget _buildInteractionResultWithMarkdown(
    BuildContext context,
    String result,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final isNoInteraction = _isNoInteractionResult(result);
    final resultColor =
        isNoInteraction ? colorScheme.tertiary : colorScheme.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (isNoInteraction
                    ? colorScheme.tertiaryContainer
                    : colorScheme.errorContainer)
                .withValues(alpha: 0.7),
            (isNoInteraction
                    ? colorScheme.tertiaryContainer
                    : colorScheme.errorContainer)
                .withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: resultColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: resultColor.withValues(alpha: 0.1),
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
                  color: resultColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isNoInteraction ? Icons.check_circle : Icons.warning,
                  color: resultColor,
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
                    color: isNoInteraction
                        ? colorScheme.onTertiaryContainer
                        : colorScheme.onErrorContainer,
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
              color: colorScheme.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: resultColor.withValues(alpha: 0.2),
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

  Widget _buildAddMedicationSection(ColorScheme colorScheme, ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.outlineVariant),
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
                                      const EdgeInsets.symmetric(vertical: 12),
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
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
            const SizedBox(height: 12),
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
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
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
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
                          horizontal: 20, vertical: 12),
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
                const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
            leading: Hero(
              tag: 'medication_$index',
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant),
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
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
                color: colorScheme.onSurface.withValues(alpha: 0.7),
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
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16, color: Colors.red.shade600),
                      const SizedBox(width: 8),
                      Text('Remove',
                          style: TextStyle(color: Colors.red.shade600)),
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

    if (kDebugMode) {
      print('➕ Adding medication: ${medication.name}');
    }
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
            Icon(Icons.check_circle,
                color: Theme.of(context).colorScheme.onTertiary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${medication.name} added successfully',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Theme.of(context).colorScheme.onTertiary,
          onPressed: () {
            appState.removeMedication(appState.medications.length - 1);
            _checkInteractionsWithSmartCache();
          },
        ),
      ),
    );
  }

  void _copyResult(String result) async {
    final colorScheme = Theme.of(context).colorScheme;
    await Clipboard.setData(ClipboardData(text: result));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.copy, color: colorScheme.onPrimary),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Analysis copied to clipboard',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _editMedication(BuildContext context, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.construction, color: colorScheme.onSecondary),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Edit feature coming soon!',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.secondary,
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

    showBlurDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.warning, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            const Expanded(
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
                      Icon(Icons.delete,
                          color: Theme.of(context).colorScheme.onError),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${medication.name} removed',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Theme.of(context).colorScheme.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  // FIXED: Enhanced analysis history with current medication highlighting
  void _showAnalysisHistory(BuildContext context) {
    showBlurDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 760,
              maxHeight: MediaQuery.of(context).size.height * 0.86,
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                          Icons.history,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Analysis History',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${_analysisHistory.length} cached analyses',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.7),
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
                              SnackBar(
                                content:
                                    const Text('Cache cleared for testing'),
                                backgroundColor: colorScheme.secondary,
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
                          backgroundColor: colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_analysisHistory.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history,
                              size: 64,
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No analysis history yet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Analyze medication interactions to build your cache history',
                              style: TextStyle(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.5),
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
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.62,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _analysisHistory.length,
                        itemBuilder: (context, index) {
                          final analysis = _analysisHistory[index];
                          final isCurrentMedications =
                              analysis.medicationHash == _currentMedicationHash;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            color: isCurrentMedications
                                ? colorScheme.primaryContainer
                                    .withValues(alpha: 0.3)
                                : colorScheme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: isCurrentMedications
                                  ? BorderSide(
                                      color: colorScheme.primary,
                                      width: 1.5,
                                    )
                                  : BorderSide(
                                      color: colorScheme.outlineVariant),
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isCurrentMedications
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.2)
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
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
                                        color: colorScheme.primary,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        'CURRENT',
                                        style: TextStyle(
                                          color: colorScheme.onPrimary,
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
                                    _formatCacheAge(analysis.timestamp),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.6),
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
      },
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
        content: Row(
          children: [
            Icon(Icons.restore, color: Theme.of(context).colorScheme.onPrimary),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Analysis result loaded from history ⚡',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showBlurDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.help_outline,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Expanded(
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
    showBlurDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.local_pharmacy,
                color: Theme.of(context).colorScheme.tertiary),
            const SizedBox(width: 8),
            const Expanded(
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
