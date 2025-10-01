import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../services/emergency_service.dart';
import '../utils/app_state.dart';

class EmergencyButton extends StatelessWidget {
  const EmergencyButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Container(
          margin: const EdgeInsets.all(16),
          child: Column(
            // Changed from Row to Column for better responsiveness
            children: [
              // Emergency button - full width
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showEmergencyOptions(context, appState),
                  icon: const Icon(Icons.emergency, color: Colors.white),
                  label: Text(
                    appState.isMinor ? 'Emergency Help' : 'Medical Emergency',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Telehealth button - full width
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showTelehealthOptions(context, appState),
                  icon: const Icon(Icons.video_call),
                  label: Text(
                    appState.isMinor ? 'Ask a Trusted Adult' : 'Talk to Doctor',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              // DEBUG: Add test button for phone dialer (remove in production)
            ],
          ),
        );
      },
    );
  }

  void _showEmergencyOptions(BuildContext context, AppState appState) async {
    // Use Geolocator directly instead of permission_handler for now
    try {
      // Check location permission using Geolocator
      LocationPermission permission = await Geolocator.checkPermission();
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (permission == LocationPermission.denied || !serviceEnabled) {
        _showPermissionDialog(context, appState);
        return;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking permissions: $e');
      }
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min, // FIX: Prevent overflow
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                appState.isMinor
                    ? 'Getting emergency help for your area...'
                    : 'Getting emergency numbers for your location...',
                overflow: TextOverflow.ellipsis, // FIX: Prevent text overflow
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final emergencyNumbers = await EmergencyService.getEmergencyNumbers();

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        _showEmergencyDialog(context, appState, emergencyNumbers);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        _showEmergencyDialog(context, appState, null);
      }
    }
  }

  void _showEmergencyDialog(
      BuildContext context, AppState appState, EmergencyNumbers? numbers) {
    final emergencyNumbers = numbers ??
        const EmergencyNumbers(
          emergency: '911',
          police: '911',
          fire: '911',
          ambulance: '911',
          poisonControl: '1-800-222-1222',
          mentalHealth: '988',
          domesticViolence: '1-800-799-7233',
          countryName: 'Emergency Services',
          countryCode: 'EMERGENCY',
        );

    if (appState.isMinor) {
      _showMinorEmergencyDialog(context, emergencyNumbers);
    } else {
      _showAdultEmergencyDialog(context, emergencyNumbers);
    }
  }

  void _showMinorEmergencyDialog(
      BuildContext context, EmergencyNumbers emergencyNumbers) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Emergency Help',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          // FIX: Prevent content overflow
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🚨 If this is an emergency:',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 8),
              const Text('1. Find a trusted adult RIGHT NOW'),
              const Text('2. If no adult is around, call:'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[300]!),
                ),
                width: double.infinity,
                child: Column(
                  children: [
                    Text(
                      '📞 ${emergencyNumbers.countryName}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis, // FIX: Prevent overflow
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      emergencyNumbers.emergency,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                      overflow: TextOverflow.ellipsis, // FIX: Prevent overflow
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '3. Stay calm and tell them what happened',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I understand'),
          ),
          ElevatedButton(
            onPressed: () =>
                _callEmergency(context, emergencyNumbers.emergency),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Call Emergency',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAdultEmergencyDialog(
      BuildContext context, EmergencyNumbers emergencyNumbers) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Emergency - ${emergencyNumbers.countryName}',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          // FIX: Constrain dialog height
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you experiencing a medical emergency?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildEmergencyOption(
                  context,
                  '🚨 Call Emergency',
                  emergencyNumbers.emergency,
                  'Life-threatening situations',
                  Colors.red,
                ),
                _buildEmergencyOption(
                  context,
                  '🚑 Ambulance/Medical',
                  emergencyNumbers.ambulance,
                  'Medical emergencies',
                  Colors.green[700]!,
                ),
                _buildEmergencyOption(
                  context,
                  '☠️ Poison Control',
                  emergencyNumbers.poisonControl,
                  'Poisoning or overdose',
                  Colors.purple[700]!,
                ),
                _buildEmergencyOption(
                  context,
                  '🧠 Mental Health Crisis',
                  emergencyNumbers.mentalHealth,
                  'Suicide prevention, crisis support',
                  Colors.teal[700]!,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                _callEmergency(context, emergencyNumbers.emergency),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Call Emergency',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyOption(BuildContext context, String title,
      String number, String description, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _callEmergency(context, number),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: color.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                        overflow:
                            TextOverflow.ellipsis, // FIX: Prevent overflow
                        maxLines: 1,
                      ),
                      Text(
                        number,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow:
                            TextOverflow.ellipsis, // FIX: Prevent overflow
                        maxLines: 1,
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        overflow:
                            TextOverflow.ellipsis, // FIX: Prevent overflow
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8), // Add spacing
                Icon(Icons.phone, color: color, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTelehealthOptions(BuildContext context, AppState appState) {
    if (appState.isMinor) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ask a Trusted Adult'),
          content: const Text(
            'For health questions, it\'s always best to:\n\n'
            '• Talk to your parents or guardians\n'
            '• Ask a school nurse\n'
            '• Visit a doctor with a trusted adult\n\n'
            'Adults can help you get the right medical care!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('I understand'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Telehealth Options'),
          content: const Text(
            'Connect with healthcare professionals remotely:\n\n'
            '• Video consultations\n'
            '• Non-emergency medical advice\n'
            '• Prescription renewals\n'
            '• Health guidance',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final success = await EmergencyService.openTelehealthService();
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not open telehealth service'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              child: const Text('Open Telehealth'),
            ),
          ],
        ),
      );
    }
  }

  void _showPermissionDialog(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Location Access Needed',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: const Text(
          'To provide accurate emergency numbers for your area, we need:\n\n'
          '• Location permission\n'
          '• Location services enabled\n\n'
          'This helps us show the correct emergency numbers for your country.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _requestPermissions(context);
            },
            child: const Text('Enable Location'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestPermissions(BuildContext context) async {
    try {
      // Request location permission using Geolocator
      LocationPermission permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Location permission is required for emergency services'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Check if location services are enabled
      final locationEnabled = await Geolocator.isLocationServiceEnabled();

      if (!locationEnabled && context.mounted) {
        _showLocationServicesDialog(context);
      } else if (context.mounted) {
        // Try emergency options again
        final appState = Provider.of<AppState>(context, listen: false);
        _showEmergencyOptions(context, appState);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting permissions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showLocationServicesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Location Services'),
        content: const Text(
          'Location services are disabled. Please enable them in your device settings to get accurate emergency numbers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // ENHANCED: Complete phone dialer implementation with fallbacks
  void _callEmergency(BuildContext context, String number) {
    // Show confirmation before calling
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Call'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Call emergency services?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _attemptEmergencyCall(context, number);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                const Text('Call Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ENHANCED: Attempt emergency call with comprehensive fallbacks
  Future<void> _attemptEmergencyCall(
      BuildContext context, String number) async {
    // Show calling dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Opening phone dialer...')),
          ],
        ),
      ),
    );

    try {
      // Try to call using the emergency service
      final success = await EmergencyService.callSpecificNumber(number);

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);

        if (!success) {
          // Show fallback dialog with manual instruction
          _showManualDialDialog(context, number);
        } else {
          // Show success confirmation
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening dialer for: $number'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        _showManualDialDialog(context, number);
      }
    }
  }

  // ENHANCED: Manual dial dialog with copy-to-clipboard functionality
  void _showManualDialDialog(BuildContext context, String number) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.phone_in_talk, color: Colors.blue),
            SizedBox(width: 8),
            Text('Manual Dial Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please manually dial this emergency number:'),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _copyToClipboard(context, number),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Text(
                      number,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.content_copy,
                            size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Tap to copy number',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '1. Copy the number above\n2. Open your phone app\n3. Dial the number\n4. Press call',
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.left,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _copyToClipboard(context, number),
            child: const Text('Copy Number'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  // Copy number to clipboard
  Future<void> _copyToClipboard(BuildContext context, String number) async {
    try {
      await Clipboard.setData(ClipboardData(text: number));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Emergency number $number copied!')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error copying to clipboard: $e');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not copy number'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // DEBUG: Test phone dialer functionality

  // DEBUG: Test specific number
}
