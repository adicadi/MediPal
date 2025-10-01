import 'package:flutter/material.dart';
import '../models/medication.dart';

class AddReminderDialog extends StatefulWidget {
  const AddReminderDialog({Key? key}) : super(key: key);

  @override
  State<AddReminderDialog> createState() => _AddReminderDialogState();
}

class _AddReminderDialogState extends State<AddReminderDialog> {
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  final Set<int> _selectedDays = {1, 2, 3, 4, 5, 6, 7}; // All days selected
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
              // Header
              Row(
                children: [
                  const Icon(Icons.alarm_add, color: Colors.blue, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Add Reminder',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Time Picker
              const Text(
                'Reminder Time',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
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

              // Days Selection
              const Text(
                'Repeat On',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
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

              // Doses Count
              const Text(
                'Number of Doses',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (_dosesCount > 1) {
                        setState(() => _dosesCount--);
                      }
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    '$_dosesCount',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (_dosesCount < 10) {
                        setState(() => _dosesCount++);
                      }
                    },
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _dosesCount == 1 ? 'dose' : 'doses',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Custom Message
              const Text(
                'Custom Message (Optional)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'e.g., Take with food',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.message_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
