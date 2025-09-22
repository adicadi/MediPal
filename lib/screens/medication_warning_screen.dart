import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_state.dart';
import '../services/deepseek_service.dart';

class MedicationWarningScreen extends StatefulWidget {
  const MedicationWarningScreen({super.key});

  @override
  State<MedicationWarningScreen> createState() =>
      _MedicationWarningScreenState();
}

class _MedicationWarningScreenState extends State<MedicationWarningScreen> {
  final TextEditingController _medicationController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _frequencyController = TextEditingController();

  bool _showAddForm = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInteractions();
    });
  }

  @override
  void dispose() {
    _medicationController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    super.dispose();
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
                // Safety Notice
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.security,
                          color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Always consult your healthcare provider or pharmacist before starting, stopping, or changing medications.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Add Medication Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Add Medication',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Row(
                              children: [
                                if (appState.medications.isNotEmpty)
                                  TextButton.icon(
                                    onPressed: () =>
                                        _showClearAllDialog(context),
                                    icon: const Icon(Icons.clear_all, size: 16),
                                    label: const Text('Clear All'),
                                  ),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _showAddForm = !_showAddForm;
                                      if (!_showAddForm) _clearForm();
                                    });
                                  },
                                  icon: Icon(_showAddForm
                                      ? Icons.expand_less
                                      : Icons.add),
                                  tooltip: _showAddForm
                                      ? 'Cancel'
                                      : 'Add medication',
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (_showAddForm) ...[
                          const SizedBox(height: 16),
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _medicationController,
                                  decoration: const InputDecoration(
                                    labelText: 'Medication Name *',
                                    hintText:
                                        'e.g., Aspirin, Ibuprofen, Metformin',
                                    prefixIcon: Icon(Icons.medication),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter a medication name';
                                    }
                                    return null;
                                  },
                                  textCapitalization: TextCapitalization.words,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _dosageController,
                                        decoration: const InputDecoration(
                                          labelText: 'Dosage',
                                          hintText: 'e.g., 81mg, 10mg',
                                          prefixIcon:
                                              Icon(Icons.medical_services),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _frequencyController,
                                        decoration: const InputDecoration(
                                          labelText: 'Frequency',
                                          hintText: 'e.g., Daily, Twice daily',
                                          prefixIcon: Icon(Icons.schedule),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _addMedication,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Medication'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Current Medications
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
                                'Current Medications (${appState.medications.length})',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (appState.medications.isNotEmpty)
                              IconButton(
                                onPressed: () => _checkInteractions(),
                                icon: const Icon(Icons.refresh),
                                tooltip: 'Refresh interactions',
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (appState.medications.isEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.medication_outlined,
                                  size: 64,
                                  color: colorScheme.onSurfaceVariant
                                      .withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No medications added yet',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add your medications to check for potential interactions',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _showAddForm = true;
                                    });
                                  },
                                  icon: const Icon(Icons.add),
                                  label:
                                      const Text('Add Your First Medication'),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: appState.medications.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final medication = appState.medications[index];
                              return ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer
                                        .withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.medication,
                                    color: colorScheme.primary,
                                    size: 24,
                                  ),
                                ),
                                title: Text(
                                  medication.name,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${medication.dosage} • ${medication.frequency}',
                                  style: theme.textTheme.bodySmall,
                                ),
                                trailing: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
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
                                          Icon(Icons.delete,
                                              size: 16, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Remove',
                                              style:
                                                  TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Interaction Results
                if (appState.medications.length >= 2) ...[
                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.security, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Drug Interaction Analysis',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (appState.isLoading) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              child: const Column(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 12),
                                  Text('Analyzing medication interactions...'),
                                ],
                              ),
                            ),
                          ] else if (appState
                              .medicationInteractionResult.isEmpty) ...[
                            _buildInteractionCard(
                              context,
                              'Analysis Pending',
                              'Tap the refresh button to check for interactions.',
                              Icons.hourglass_empty,
                              Colors.grey,
                            ),
                          ] else ...[
                            if (_isNoInteractionResult(
                                appState.medicationInteractionResult)) ...[
                              _buildInteractionCard(
                                context,
                                'No Significant Interactions Found',
                                appState.medicationInteractionResult,
                                Icons.check_circle,
                                Colors.green,
                              ),
                            ] else ...[
                              _buildInteractionCard(
                                context,
                                'Potential Drug Interaction Detected',
                                appState.medicationInteractionResult,
                                Icons.warning,
                                Colors.orange,
                              ),
                            ],
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: appState.isLoading
                                      ? null
                                      : _checkInteractions,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Recheck Interactions'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _showPharmacistAdvice(context),
                                  icon: const Icon(Icons.local_pharmacy),
                                  label: const Text('Pharmacist Tips'),
                                ),
                              ),
                            ],
                          ),
                        ],
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

  Widget _buildInteractionCard(
    BuildContext context,
    String title,
    String content,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color.withOpacity(0.9),
              height: 1.4,
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
    setState(() => _showAddForm = false);

    _checkInteractions();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('\${medication.name} added successfully'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {
            appState.removeMedication(appState.medications.length - 1);
            _checkInteractions();
          },
        ),
      ),
    );
  }

  void _editMedication(BuildContext context, int index) {
    // Implementation for editing medications
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit feature coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _confirmRemoveMedication(BuildContext context, int index) {
    final appState = Provider.of<AppState>(context, listen: false);
    final medication = appState.medications[index];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Medication'),
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
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              appState.removeMedication(index);
              _checkInteractions();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('\${medication.name} removed'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
        title: const Text('Clear All Medications'),
        content: const Text(
            'Are you sure you want to remove all medications from your list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final appState = Provider.of<AppState>(context, listen: false);
              final count = appState.medications.length;
              while (appState.medications.isNotEmpty) {
                appState.removeMedication(0);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Cleared $count medications'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkInteractions() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final deepSeekService =
        Provider.of<DeepSeekService>(context, listen: false);

    if (appState.medications.length < 2) {
      appState.setMedicationInteractionResult('');
      return;
    }

    appState.setLoading(true);

    try {
      final medicationNames =
          appState.medications.map((med) => med.toString()).toList();
      final result =
          await deepSeekService.checkMedicationInteractions(medicationNames);

      appState.setMedicationInteractionResult(result);
    } catch (e) {
      appState.setMedicationInteractionResult(
          'Unable to check medication interactions at this time. Please consult your pharmacist or healthcare provider.');
    } finally {
      appState.setLoading(false);
    }
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Medication Interaction Checker'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'This tool helps identify potential interactions between your medications.'),
              SizedBox(height: 12),
              Text('How to use:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('1. Add all your current medications'),
              Text('2. Include prescription and over-the-counter drugs'),
              Text('3. Review the interaction analysis'),
              Text('4. Consult your healthcare provider for questions'),
              SizedBox(height: 12),
              Text('Important:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.red)),
              Text(
                  'This tool provides general information only. Always consult your healthcare provider or pharmacist before making medication changes.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showPharmacistAdvice(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pharmacist Tips'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('💊 Take medications as prescribed'),
              SizedBox(height: 8),
              Text('🕐 Follow timing instructions carefully'),
              SizedBox(height: 8),
              Text('🍽️ Note food interactions (with/without meals)'),
              SizedBox(height: 8),
              Text('💧 Stay hydrated when taking medications'),
              SizedBox(height: 8),
              Text('📝 Keep an updated medication list'),
              SizedBox(height: 8),
              Text('🏥 Inform all healthcare providers of your medications'),
              SizedBox(height: 8),
              Text("❓ Ask questions if you're unsure about anything"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Thanks!'),
          ),
        ],
      ),
    );
  }
}
