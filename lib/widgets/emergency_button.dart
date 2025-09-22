import 'package:flutter/material.dart';
import '../services/emergency_service.dart';

class EmergencyButton extends StatelessWidget {
  const EmergencyButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showEmergencyOptions(context),
              icon: const Icon(Icons.emergency, color: Colors.white),
              label: const Text('Medical Emergency'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => EmergencyService.openTelehealthService(),
            icon: const Icon(Icons.video_call),
            label: const Text('Talk to Doctor'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showEmergencyOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Emergency Services'),
          ],
        ),
        content: const Text(
          'Are you experiencing a medical emergency?\n\n'
          '• Call 911: Life-threatening situations\n'
          '• Telehealth: Non-emergency consultation\n'
          '• Find Hospital: Locate nearest facility',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              EmergencyService.callEmergency();
            },
            child: const Text('Call 911', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
