import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_state.dart';
import '../models/medication.dart';
import '../services/notification_service.dart';
import '../utils/blur_dialog.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    if (kDebugMode) {
      print('🔄 MedicationsScreen initialized with lifecycle observer');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (kDebugMode) {
        print('🔄 App resumed, reloading medications from storage...');
      }
      _reloadMedications();
    }
  }

  Future<void> _reloadMedications() async {
    final appState = Provider.of<AppState>(context, listen: false);
    await appState.loadUserProfile();
    if (kDebugMode) {
      print('✅ Medications reloaded: ${appState.medications.length} found');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.maybePop(context),
                    style: IconButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor:
                          colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.9,
                      ),
                      foregroundColor: colorScheme.onSurface,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Medications',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => _showAddMedicationDialog(context),
                    style: IconButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor:
                          colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.9,
                      ),
                      foregroundColor: colorScheme.onSurface,
                    ),
                    icon: const Icon(Icons.add_rounded),
                    tooltip: 'Add medication',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search medications...',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor:
                      colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
            TabBar(
              controller: _tabController,
              indicatorColor: colorScheme.primary,
              indicatorWeight: 2,
              labelColor: colorScheme.primary,
              unselectedLabelColor: colorScheme.onSurfaceVariant,
              labelStyle: theme.textTheme.labelLarge,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Active'),
                Tab(text: 'Refill'),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Consumer<AppState>(
                builder: (context, appState, child) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      await _reloadMedications();
                    },
                    color: colorScheme.primary,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildAllMedicationsTab(appState),
                        _buildActiveMedicationsTab(appState),
                        _buildRefillNeededTab(appState),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMedicationDialog(context),
        child: const Icon(Icons.add, size: 24),
      ),
    );
  }

  Widget _buildAllMedicationsTab(AppState appState) {
    final medications = _filterMedications(appState.medications);

    if (medications.isEmpty) {
      return _buildEmptyState(
        icon: Icons.medication_outlined,
        title: _searchQuery.isEmpty
            ? 'No medications yet'
            : 'No medications found',
        subtitle: _searchQuery.isEmpty
            ? 'Add your first medication'
            : 'Try a different search term',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: medications.length,
      itemBuilder: (context, index) {
        final medication = medications[index];
        return _buildMedicationCard(medication, appState);
      },
    );
  }

  Widget _buildActiveMedicationsTab(AppState appState) {
    final activeMeds = _filterMedications(appState.medicationsWithReminders);

    if (activeMeds.isEmpty) {
      return _buildEmptyState(
        icon: Icons.notifications_none,
        title: 'No active reminders',
        subtitle: 'Enable reminders for medications',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: activeMeds.length,
      itemBuilder: (context, index) {
        final medication = activeMeds[index];
        return _buildMedicationCard(medication, appState);
      },
    );
  }

  Widget _buildRefillNeededTab(AppState appState) {
    final refillMeds = _filterMedications(appState.medicationsNeedingRefill);

    if (refillMeds.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline,
        title: 'All stocked up',
        subtitle: 'No refills needed',
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (refillMeds.isNotEmpty)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .tertiaryContainer
                    .withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .tertiary
                      .withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${refillMeds.length} medication${refillMeds.length > 1 ? 's' : ''} need refilling',
                      style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final medication = refillMeds[index];
                return _buildMedicationCard(medication, appState);
              },
              childCount: refillMeds.length,
            ),
          ),
        ),
      ],
    );
  }

  // Minimal medication card
  Widget _buildMedicationCard(Medication medication, AppState appState) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final index = appState.medications.indexOf(medication);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: medication.needsRefill
              ? colorScheme.tertiary.withValues(alpha: isDark ? 0.8 : 1)
              : colorScheme.outlineVariant.withValues(alpha: isDark ? 0.9 : 1),
          width: isDark ? 1.4 : 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: medication.isEssential
                        ? colorScheme.errorContainer
                        : colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    medication.isEssential
                        ? Icons.local_hospital
                        : Icons.medication,
                    color: medication.isEssential
                        ? colorScheme.onErrorContainer
                        : colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              medication.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (medication.isEssential)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Essential',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onErrorContainer,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${medication.dosage} • ${medication.frequency}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: medication.remindersEnabled,
                  onChanged: (value) async {
                    if (value) {
                      final hasPermission =
                          await _ensureExactAlarmPermission(context);
                      if (!hasPermission) return;
                    }

                    await appState.toggleMedicationReminders(
                        medication.id, value);
                  },
                  activeThumbColor: colorScheme.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Quantity indicator
            _buildQuantityIndicator(medication, colorScheme),

            if (medication.reminders.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildRemindersInfo(medication, colorScheme),
            ],

            if (medication.needsRefill) ...[
              const SizedBox(height: 12),
              _buildRefillNotice(medication),
            ],

            if (medication.notes?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              _buildNotes(medication, colorScheme),
            ],

            const SizedBox(height: 16),
            _buildActionButtons(medication, appState, index, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityIndicator(
      Medication medication, ColorScheme colorScheme) {
    final percentage = medication.currentQuantity / medication.totalQuantity;
    Color indicatorColor;

    if (medication.needsRefill) {
      indicatorColor = Colors.red;
    } else if (medication.isRunningLow) {
      indicatorColor = Colors.amber;
    } else {
      indicatorColor = Colors.green;
    }

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: colorScheme.surfaceContainerHighest,
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: indicatorColor,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${medication.currentQuantity}/${medication.totalQuantity}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: indicatorColor,
          ),
        ),
      ],
    );
  }

  Widget _buildRemindersInfo(Medication medication, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(
          Icons.schedule,
          size: 14,
          color: colorScheme.primary,
        ),
        const SizedBox(width: 6),
        Text(
          '${medication.reminders.length} reminder${medication.reminders.length > 1 ? 's' : ''} set',
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRefillNotice(Medication medication) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: colorScheme.onTertiaryContainer, size: 16),
          const SizedBox(width: 8),
          Text(
            'Refill needed',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onTertiaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotes(Medication medication, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.note,
            size: 14,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              medication.notes!,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Medication medication, AppState appState,
      int index, ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: () => _takeDose(medication.id, appState),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Take Dose'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => _showAddReminderDialog(medication),
          icon: const Icon(Icons.alarm_add, size: 18),
          color: colorScheme.onSurfaceVariant,
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          onPressed: () => _editMedication(medication, index, appState),
          icon: const Icon(Icons.edit, size: 18),
          color: colorScheme.onSurfaceVariant,
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          onPressed: () => _confirmDelete(medication, index, appState),
          icon: const Icon(Icons.delete_outline, size: 18),
          color: colorScheme.error,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _showAddMedicationDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Medication'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods remain the same...
  List<Medication> _filterMedications(List<Medication> medications) {
    if (_searchQuery.isEmpty) return medications;
    return medications
        .where((med) =>
            med.name.toLowerCase().contains(_searchQuery) ||
            med.dosage.toLowerCase().contains(_searchQuery))
        .toList();
  }

  Future<bool> _ensureExactAlarmPermission(BuildContext context) async {
    final canSchedule = await NotificationService.canScheduleExactAlarms();
    if (canSchedule) return true;

    if (!context.mounted) return false;
    final shouldRequest = await showBlurDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'To schedule medication reminders at exact times, this app needs permission to set alarms.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );

    if (shouldRequest != true) return false;

    final granted = await NotificationService.requestExactAlarmPermission();
    return granted;
  }

  Future<void> _takeDose(String medicationId, AppState appState) async {
    await appState.takeMedicationDose(medicationId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dose taken successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showAddReminderDialog(Medication medication) async {
    final hasPermission = await _ensureExactAlarmPermission(context);
    if (!hasPermission) return;

    if (!mounted) return;
    final result = await showBlurDialog<MedicationReminder>(
      context: context,
      builder: (context) => _AddReminderDialog(),
    );

    if (!mounted || result == null) return;

    final appState = Provider.of<AppState>(context, listen: false);
    await appState.addReminderToMedication(medication.id, result);
  }

  void _editMedication(Medication medication, int index, AppState appState) {
    _showAddMedicationDialog(context,
        existingMedication: medication, index: index);
  }

  Future<void> _confirmDelete(
      Medication medication, int index, AppState appState) async {
    final confirmed = await showBlurDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medication?'),
        content: Text('Are you sure you want to delete ${medication.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    appState.removeMedication(index);
  }

  Future<void> _showAddMedicationDialog(BuildContext context,
      {Medication? existingMedication, int? index}) async {
    final result = await showBlurDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          _AddMedicationDialog(existingMedication: existingMedication),
    );

    if (!context.mounted || result == null) return;

    final appState = Provider.of<AppState>(context, listen: false);
    final medication = Medication(
      id: existingMedication?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: result['name'],
      dosage: result['dosage'],
      frequency: result['frequency'],
      totalQuantity: result['totalQuantity'],
      currentQuantity: result['currentQuantity'],
      refillThreshold: result['refillThreshold'],
      notes: result['notes'],
      isEssential: result['isEssential'],
      createdAt: existingMedication?.createdAt ?? DateTime.now(),
      remindersEnabled: existingMedication?.remindersEnabled ?? false,
      reminders: existingMedication?.reminders ?? [],
    );

    if (existingMedication != null && index != null) {
      await appState.updateMedicationWithReminders(index, medication);
    } else {
      appState.addMedication(medication);
    }
  }
}

// Simplified Add Medication Dialog
class _AddMedicationDialog extends StatefulWidget {
  final Medication? existingMedication;

  const _AddMedicationDialog({this.existingMedication});

  @override
  State<_AddMedicationDialog> createState() => _AddMedicationDialogState();
}

class _AddMedicationDialogState extends State<_AddMedicationDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TextEditingController _frequencyController;
  late TextEditingController _totalQuantityController;
  late TextEditingController _currentQuantityController;
  late TextEditingController _refillThresholdController;
  late TextEditingController _notesController;
  bool _isEssential = false;

  @override
  void initState() {
    super.initState();
    final med = widget.existingMedication;
    _nameController = TextEditingController(text: med?.name ?? '');
    _dosageController = TextEditingController(text: med?.dosage ?? '');
    _frequencyController = TextEditingController(text: med?.frequency ?? '');
    _totalQuantityController =
        TextEditingController(text: med?.totalQuantity.toString() ?? '30');
    _currentQuantityController =
        TextEditingController(text: med?.currentQuantity.toString() ?? '30');
    _refillThresholdController =
        TextEditingController(text: med?.refillThreshold.toString() ?? '7');
    _notesController = TextEditingController(text: med?.notes ?? '');
    _isEssential = med?.isEssential ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    _totalQuantityController.dispose();
    _currentQuantityController.dispose();
    _refillThresholdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: colorScheme.surface,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.existingMedication != null
                      ? 'Edit Medication'
                      : 'Add Medication',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g., Aspirin',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dosageController,
                        decoration: const InputDecoration(
                          labelText: 'Dosage',
                          hintText: '81mg',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _frequencyController,
                        decoration: const InputDecoration(
                          labelText: 'Frequency',
                          hintText: 'Daily',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _totalQuantityController,
                        decoration: const InputDecoration(
                          labelText: 'Total Pills',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _currentQuantityController,
                        decoration: const InputDecoration(
                          labelText: 'Current Pills',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _refillThresholdController,
                  decoration: const InputDecoration(
                    labelText: 'Refill Threshold',
                    hintText: 'Alert when pills reach this number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'Take with food',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Essential Medication'),
                  subtitle: const Text('Higher priority'),
                  value: _isEssential,
                  onChanged: (value) => setState(() => _isEssential = value),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child:
                            const Text('Cancel', maxLines: 1, softWrap: false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _save,
                        child: Text(widget.existingMedication != null
                            ? 'Update'
                            : 'Add'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, {
        'name': _nameController.text.trim(),
        'dosage': _dosageController.text.trim(),
        'frequency': _frequencyController.text.trim(),
        'totalQuantity': int.tryParse(_totalQuantityController.text) ?? 30,
        'currentQuantity': int.tryParse(_currentQuantityController.text) ?? 30,
        'refillThreshold': int.tryParse(_refillThresholdController.text) ?? 7,
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'isEssential': _isEssential,
      });
    }
  }
}

// Simplified Add Reminder Dialog
class _AddReminderDialog extends StatefulWidget {
  @override
  State<_AddReminderDialog> createState() => _AddReminderDialogState();
}

class _AddReminderDialogState extends State<_AddReminderDialog> {
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  final Set<int> _selectedDays = {1, 2, 3, 4, 5, 6, 7};
  final TextEditingController _messageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: colorScheme.surface,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Reminder',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              const Text('Time', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final time = await showTimePicker(
                      context: context, initialTime: _selectedTime);
                  if (time != null) {
                    setState(() => _selectedTime = time);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatTime(_selectedTime),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const Icon(Icons.access_time),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Days', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _buildDayChip('Mon', 1),
                  _buildDayChip('Tue', 2),
                  _buildDayChip('Wed', 3),
                  _buildDayChip('Thu', 4),
                  _buildDayChip('Fri', 5),
                  _buildDayChip('Sat', 6),
                  _buildDayChip('Sun', 7),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Custom Message (Optional)',
                  hintText: 'Take with food',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Cancel',
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () {
                        if (_selectedDays.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Please select at least one day')),
                          );
                          return;
                        }

                        final reminder = MedicationReminder(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          time: _selectedTime,
                          enabled: true,
                          daysOfWeek: _selectedDays.toList()..sort(),
                          customMessage: _messageController.text.trim().isEmpty
                              ? null
                              : _messageController.text.trim(),
                          createdAt: DateTime.now(),
                          dosesCount: 1,
                        );

                        Navigator.pop(context, reminder);
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Add Reminder',
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayChip(String label, int dayNumber) {
    final isSelected = _selectedDays.contains(dayNumber);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedDays.add(dayNumber);
          } else {
            _selectedDays.remove(dayNumber);
          }
        });
      },
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour == 0
        ? 12
        : time.hour > 12
            ? time.hour - 12
            : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
