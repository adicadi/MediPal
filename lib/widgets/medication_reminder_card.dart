import 'package:flutter/material.dart';
import '../models/medication.dart';

class MedicationReminderCard extends StatelessWidget {
  final Medication medication;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Function(bool)? onToggleReminders;
  final VoidCallback? onTakeDose;

  const MedicationReminderCard({
    super.key,
    required this.medication,
    this.onEdit,
    this.onDelete,
    this.onToggleReminders,
    this.onTakeDose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: medication.needsRefill
              ? colorScheme.error.withValues(alpha: 0.45)
              : colorScheme.outlineVariant,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: medication.isEssential
                  ? colorScheme.errorContainer.withValues(alpha: 0.5)
                  : colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Medication Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    medication.isEssential
                        ? Icons.local_hospital
                        : Icons.medication,
                    color: medication.isEssential
                        ? colorScheme.error
                        : colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // Medication Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medication.name,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${medication.dosage} • ${medication.frequency}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Reminder Toggle
                Switch(
                  value: medication.remindersEnabled,
                  onChanged: onToggleReminders,
                  activeThumbColor: colorScheme.primary,
                ),
              ],
            ),
          ),

          // Body Section
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quantity Status
                _buildQuantityStatus(context),

                if (medication.reminders.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildRemindersList(),
                ],

                if (medication.needsRefill) ...[
                  const SizedBox(height: 12),
                  _buildRefillAlert(context),
                ],

                if (medication.notes != null &&
                    medication.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildNotes(context),
                ],

                const SizedBox(height: 12),
                _buildActionButtons(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityStatus(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
            backgroundColor: colorScheme.surfaceContainerHighest,
            color: statusColor,
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${medication.daysUntilEmpty} days remaining',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
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

  Widget _buildRefillAlert(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Refill Needed!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.error,
                  ),
                ),
                Text(
                  'Only ${medication.currentQuantity} pills remaining',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotes(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.note_outlined,
              size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              medication.notes!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
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
