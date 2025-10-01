import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_state.dart';
import '../models/medication.dart';
import '../services/notification_service.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({Key? key}) : super(key: key);

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Added WidgetsBindingObserver
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addObserver(this); // Register lifecycle observer
    print('🔄 MedicationsScreen initialized with lifecycle observer');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Unregister observer
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // AUTO-RELOAD: Listen for app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground - reload data
      print('🔄 App resumed, reloading medications from storage...');
      _reloadMedications();
    }
  }

  // Reload medications from SharedPreferences
  Future<void> _reloadMedications() async {
    final appState = Provider.of<AppState>(context, listen: false);
    await appState.loadUserProfile();
    print('✅ Medications reloaded: ${appState.medications.length} found');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Medications'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              // Search bar with manual refresh button
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search medications...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Manual refresh button
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () async {
                        await _reloadMedications();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.white, size: 20),
                                  SizedBox(width: 12),
                                  Text('✅ Medications refreshed'),
                                ],
                              ),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      tooltip: 'Refresh',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
              // Tabs
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'All', icon: Icon(Icons.medication, size: 20)),
                  Tab(text: 'Active', icon: Icon(Icons.alarm_on, size: 20)),
                  Tab(
                      text: 'Refill',
                      icon: Icon(Icons.warning_amber, size: 20)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddMedicationDialog(context),
            tooltip: 'Add Medication',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          // PULL-TO-REFRESH: Wrap TabBarView with RefreshIndicator
          return RefreshIndicator(
            onRefresh: () async {
              print('🔄 Pull-to-refresh triggered');
              await _reloadMedications();
            },
            color: Colors.blue,
            backgroundColor: Colors.white,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMedicationDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Medication'),
      ),
    );
  }

  // Tab 1: All Medications
  Widget _buildAllMedicationsTab(AppState appState) {
    final medications = _filterMedications(appState.medications);

    if (medications.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height - 300,
          child: _buildEmptyState(
            icon: Icons.medication_outlined,
            title: _searchQuery.isEmpty
                ? 'No medications added yet'
                : 'No medications found',
            subtitle: _searchQuery.isEmpty
                ? 'Add your first medication to get started'
                : 'Try a different search term',
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics:
          const AlwaysScrollableScrollPhysics(), // Required for pull-to-refresh
      itemCount: medications.length,
      itemBuilder: (context, index) {
        final medication = medications[index];
        return _buildMedicationCard(medication, appState);
      },
    );
  }

  // Tab 2: Active Reminders
  Widget _buildActiveMedicationsTab(AppState appState) {
    final activeMeds = _filterMedications(appState.medicationsWithReminders);

    if (activeMeds.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height - 300,
          child: _buildEmptyState(
            icon: Icons.alarm_off,
            title: 'No active reminders',
            subtitle: 'Enable reminders for your medications',
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics:
          const AlwaysScrollableScrollPhysics(), // Required for pull-to-refresh
      itemCount: activeMeds.length,
      itemBuilder: (context, index) {
        final medication = activeMeds[index];
        return _buildMedicationCard(medication, appState);
      },
    );
  }

  // Tab 3: Refill Needed
  Widget _buildRefillNeededTab(AppState appState) {
    final refillMeds = _filterMedications(appState.medicationsNeedingRefill);

    if (refillMeds.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height - 300,
          child: _buildEmptyState(
            icon: Icons.check_circle_outline,
            title: 'All stocked up!',
            subtitle: 'No medications need refilling',
          ),
        ),
      );
    }

    return CustomScrollView(
      physics:
          const AlwaysScrollableScrollPhysics(), // Required for pull-to-refresh
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange[700], size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${refillMeds.length} Medication${refillMeds.length > 1 ? 's' : ''} Need Refilling',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[900],
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Contact your pharmacy to refill',
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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

  // Medication Card Widget
  Widget _buildMedicationCard(Medication medication, AppState appState) {
    final index = appState.medications.indexOf(medication);

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: medication.needsRefill
              ? Colors.orange.withOpacity(0.5)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: medication.isEssential
                    ? [Colors.red[50]!, Colors.red[100]!]
                    : [Colors.blue[50]!, Colors.blue[100]!],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    medication.isEssential
                        ? Icons.local_hospital
                        : Icons.medication,
                    color: medication.isEssential ? Colors.red : Colors.blue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              medication.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (medication.isEssential)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'ESSENTIAL',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${medication.dosage} • ${medication.frequency}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: medication.remindersEnabled,
                  onChanged: (value) async {
                    // Check permission before enabling reminders
                    if (value) {
                      final hasPermission =
                          await _ensureExactAlarmPermission(context);
                      if (!hasPermission) {
                        return; // Don't enable if permission denied
                      }
                    }

                    await appState.toggleMedicationReminders(
                      medication.id,
                      value,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            value
                                ? '✅ Reminders enabled'
                                : '⏸️ Reminders paused',
                          ),
                          backgroundColor: value ? Colors.green : Colors.orange,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  activeColor: Colors.green,
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quantity Status
                _buildQuantityBar(medication),

                if (medication.reminders.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildRemindersList(medication),
                ],

                if (medication.needsRefill) ...[
                  const SizedBox(height: 12),
                  _buildRefillAlert(medication),
                ],

                if (medication.notes != null &&
                    medication.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildNotes(medication),
                ],

                const SizedBox(height: 16),
                _buildActionButtons(medication, appState, index),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityBar(Medication medication) {
    final percentage = (medication.currentQuantity / medication.totalQuantity);
    Color statusColor;

    if (medication.needsRefill) {
      statusColor = Colors.red;
    } else if (medication.isRunningLow) {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.green;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '💊 Quantity',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            Text(
              '${medication.currentQuantity}/${medication.totalQuantity}',
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey[200],
            color: statusColor,
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${medication.daysUntilEmpty} days remaining',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildRemindersList(Medication medication) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '⏰ Reminders',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: medication.reminders.map((reminder) {
            return Chip(
              avatar: Icon(
                reminder.enabled
                    ? Icons.notifications_active
                    : Icons.notifications_off,
                size: 18,
                color: reminder.enabled ? Colors.blue : Colors.grey,
              ),
              label: Text(
                '${reminder.formattedTime} (${reminder.daysSummary})',
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor:
                  reminder.enabled ? Colors.blue[50] : Colors.grey[200],
              deleteIcon: const Icon(Icons.edit, size: 18),
              onDeleted: () => _editReminder(medication, reminder),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRefillAlert(Medication medication) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Refill Needed!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                  ),
                ),
                Text(
                  'Only ${medication.currentQuantity} pills remaining',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotes(Medication medication) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.note_outlined, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              medication.notes!,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      Medication medication, AppState appState, int index) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: () => _takeDose(medication.id, appState),
            icon: const Icon(Icons.check_circle, size: 20),
            label: const Text('Take Dose'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => _showAddReminderDialog(medication),
          icon: const Icon(Icons.alarm_add),
          color: Colors.blue,
          tooltip: 'Add Reminder',
        ),
        IconButton(
          onPressed: () => _editMedication(medication, index, appState),
          icon: const Icon(Icons.edit),
          color: Colors.blue,
          tooltip: 'Edit',
        ),
        IconButton(
          onPressed: () => _confirmDelete(medication, index, appState),
          icon: const Icon(Icons.delete_outline),
          color: Colors.red,
          tooltip: 'Delete',
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddMedicationDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Medication'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper Methods
  List<Medication> _filterMedications(List<Medication> medications) {
    if (_searchQuery.isEmpty) return medications;
    return medications
        .where((med) =>
            med.name.toLowerCase().contains(_searchQuery) ||
            med.dosage.toLowerCase().contains(_searchQuery))
        .toList();
  }

  // NEW: Check and request exact alarm permission
  Future<bool> _ensureExactAlarmPermission(BuildContext context) async {
    // Check if permission is already granted
    final canSchedule = await NotificationService.canScheduleExactAlarms();

    if (canSchedule) {
      return true;
    }

    // Show dialog explaining why permission is needed
    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.alarm, color: Colors.blue),
            SizedBox(width: 12),
            Text('Permission Required'),
          ],
        ),
        content: const Text(
          'To schedule medication reminders at exact times, this app needs permission to set alarms.\n\n'
          'This ensures you never miss a dose!\n\n'
          'You will be redirected to settings to enable "Alarms & reminders".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );

    if (shouldRequest != true) {
      return false;
    }

    // Request the permission (opens system settings)
    final granted = await NotificationService.requestExactAlarmPermission();

    if (!granted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Permission denied. Reminders may not work at exact times.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
    }

    return granted;
  }

  Future<void> _takeDose(String medicationId, AppState appState) async {
    await appState.takeMedicationDose(medicationId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('✅ Dose taken! Quantity updated.')),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'UNDO',
            textColor: Colors.white,
            onPressed: () {
              // Implement undo if needed
            },
          ),
        ),
      );
    }
  }

  Future<void> _showAddReminderDialog(Medication medication) async {
    // First ensure we have permission
    final hasPermission = await _ensureExactAlarmPermission(context);

    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Cannot add reminder without alarm permission'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Continue with reminder dialog
    final result = await showDialog<MedicationReminder>(
      context: context,
      builder: (context) => _AddReminderDialog(),
    );

    if (result != null && mounted) {
      try {
        final appState = Provider.of<AppState>(context, listen: false);
        await appState.addReminderToMedication(medication.id, result);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Reminder added successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error adding reminder: ${e.toString()}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _editReminder(Medication medication, MedicationReminder reminder) {
    // Implement edit reminder functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit reminder feature coming soon!'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _editMedication(Medication medication, int index, AppState appState) {
    _showAddMedicationDialog(context,
        existingMedication: medication, index: index);
  }

  Future<void> _confirmDelete(
      Medication medication, int index, AppState appState) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medication?'),
        content: Text(
          'Are you sure you want to delete ${medication.name}? This will remove all reminders.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      appState.removeMedication(index);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${medication.name} deleted'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showAddMedicationDialog(
    BuildContext context, {
    Medication? existingMedication,
    int? index,
  }) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddMedicationDialog(
        existingMedication: existingMedication,
      ),
    );

    if (result != null && mounted) {
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existingMedication != null
                  ? '✅ ${medication.name} updated'
                  : '✅ ${medication.name} added',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Medication Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('30-Second Test'),
              subtitle: const Text('Schedule notification in 30 seconds'),
              onTap: () async {
                await NotificationService.scheduleTestNotificationIn30Seconds();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          '✅ Notification scheduled for 30 seconds from now. Close the app and wait!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.alarm),
              title: const Text('Check Alarm Permission'),
              subtitle: const Text('Verify exact alarm permission'),
              onTap: () async {
                final canSchedule =
                    await NotificationService.canScheduleExactAlarms();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        canSchedule
                            ? '✅ Exact alarm permission granted'
                            : '⚠️ Exact alarm permission not granted',
                      ),
                      backgroundColor:
                          canSchedule ? Colors.green : Colors.orange,
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('View History'),
              subtitle: const Text('Coming soon'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// Add Medication Dialog
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.existingMedication != null
                      ? 'Edit Medication'
                      : 'Add New Medication',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Medication Name *',
                    hintText: 'e.g., Aspirin',
                    prefixIcon: Icon(Icons.medication),
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
                          labelText: 'Dosage *',
                          hintText: 'e.g., 81mg',
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
                          labelText: 'Frequency *',
                          hintText: 'e.g., Daily',
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
                    labelText: 'Refill Alert Threshold',
                    hintText: 'Alert when pills <= this number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'e.g., Take with food',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Mark as Essential'),
                  subtitle: const Text('Higher priority notifications'),
                  value: _isEssential,
                  onChanged: (value) => setState(() => _isEssential = value),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _save,
                        child: Text(
                          widget.existingMedication != null ? 'Update' : 'Add',
                        ),
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

// Add Reminder Dialog
class _AddReminderDialog extends StatefulWidget {
  @override
  State<_AddReminderDialog> createState() => _AddReminderDialogState();
}

class _AddReminderDialogState extends State<_AddReminderDialog> {
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  final Set<int> _selectedDays = {1, 2, 3, 4, 5, 6, 7};
  final TextEditingController _messageController = TextEditingController();
  int _dosesCount = 1;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Reminder',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              const Text('Reminder Time',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _selectedTime,
                  );
                  if (time != null) {
                    setState(() => _selectedTime = time);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatTime(_selectedTime),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Icon(Icons.access_time),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Repeat On',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
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
                  hintText: 'e.g., Take with food',
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
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_selectedDays.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select at least one day'),
                            ),
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
                          dosesCount: _dosesCount,
                        );

                        Navigator.pop(context, reminder);
                      },
                      child: const Text('Add Reminder'),
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
      selectedColor: Colors.blue,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontWeight: FontWeight.w600,
      ),
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
