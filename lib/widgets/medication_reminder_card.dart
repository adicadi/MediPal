import 'package:flutter/material.dart';
import '../models/medication.dart';

class MedicationReminderCard extends StatelessWidget {
  final Medication medication;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Function(bool)? onToggleReminders;
  final VoidCallback? onTakeDose;

  const MedicationReminderCard({
    Key? key,
    required this.medication,
    this.onEdit,
    this.onDelete,
    this.onToggleReminders,
    this.onTakeDose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          // Header Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: medication.isEssential
                  ? Colors.red.shade50
                  : Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Medication Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
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
                // Medication Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medication.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                // Reminder Toggle
                Switch(
                  value: medication.remindersEnabled,
                  onChanged: onToggleReminders,
                  activeColor: Colors.green,
                ),
              ],
            ),
          ),

          // Body Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quantity Status
                _buildQuantityStatus(),

                if (medication.reminders.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildRemindersList(),
                ],

                if (medication.needsRefill) ...[
                  const SizedBox(height: 12),
                  _buildRefillAlert(),
                ],

                if (medication.notes != null &&
                    medication.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildNotes(),
                ],

                const SizedBox(height: 16),
                _buildActionButtons(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityStatus() {
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
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '${medication.currentQuantity}/${medication.totalQuantity}',
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
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

  Widget _buildRemindersList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '⏰ Reminders',
          style: TextStyle(fontWeight: FontWeight.w600),
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
              deleteIcon: const Icon(Icons.close, size: 18),
              onDeleted: reminder.enabled ? () {} : null,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRefillAlert() {
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

  Widget _buildNotes() {
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

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: onTakeDose,
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
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
          color: Colors.red,
          tooltip: 'Delete',
        ),
      ],
    );
  }
}
