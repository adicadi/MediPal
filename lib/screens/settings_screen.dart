import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wearable_health_service.dart';
import '../utils/app_state.dart';
import '../screens/home_screen.dart';
import '../utils/blur_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isAvailable = false;
  bool _hasPermissions = false;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _isChecking = true);
    final available = await WearableHealthService.isHealthConnectAvailable();
    final permissions =
        available ? await WearableHealthService.hasRequiredPermissions() : false;
    if (!mounted) return;
    setState(() {
      _isAvailable = available;
      _hasPermissions = permissions;
      _isChecking = false;
    });
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy & Data Use'),
        content: SingleChildScrollView(
          child: Text(_privacyText()),
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

  void _showProfileDialog(BuildContext context, AppState appState) {
    showBlurDialog(
      context: context,
      builder: (context) => ProfileEditDialog(appState: appState),
    );
  }

  String _privacyText() {
    return '''MediPal Privacy Notice (Summary)

Last updated: ${DateTime.now().year}

This notice explains how MediPal handles data. It is a plain‑language summary and does not replace formal legal advice.

1) Data We Process
• Account/profile data you enter (name, age, gender).
• Health data you add (symptoms, medications).
• Wearable aggregates (steps, sleep, heart rate averages) if you connect Health Connect.
• App usage and diagnostic data (crash logs, performance) stored locally.

2) Purpose & Legal Basis (GDPR)
• Provide the service you request (contract/consent).
• Safety features and reminders (legitimate interest/consent).
• Health data is treated as sensitive and processed only with your explicit consent and only on‑device by default.

3) Storage & Security
• Data is stored locally on your device.
• We minimize data collection and only use aggregates for AI assistance by default.
• You can revoke permissions at any time in Health Connect settings.

4) Sharing
• We do not sell your data.
• We do not share wearable data with third parties.
• AI responses may use on‑device aggregates; raw wearable time‑series is not used unless you explicitly enable it (not enabled by default).

5) Your Rights (EU/UK/Global)
• Access, correction, deletion, and portability where applicable.
• Withdraw consent at any time.
• Contact support to exercise rights.

6) Children’s Privacy
• The app is designed for minors with age‑appropriate safety guidance.
• We avoid sensitive content for minors and minimize data processing.

7) International Laws
• We follow GDPR principles (lawfulness, purpose limitation, data minimization, security, transparency).
• For other regions, we align with common privacy standards (e.g., CCPA/CPRA, LGPD, PIPEDA) focusing on consent, access, and deletion rights.

8) Contact
If you have privacy questions, contact: adicadi158+medipal@gmail.com

Note: This summary is informational and should be reviewed by legal counsel to ensure full compliance with applicable laws.''';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Edit Profile'),
                  subtitle: const Text('Update your personal information'),
                  onTap: () => _showProfileDialog(context, appState),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wearables',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      if (_isChecking)
                        const LinearProgressIndicator(minHeight: 2)
                      else
                        Row(
                          children: [
                            Icon(
                              _isAvailable
                                  ? Icons.check_circle
                                  : Icons.info_outline,
                              color: _isAvailable
                                  ? colorScheme.primary
                                  : colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_isAvailable
                                  ? 'Health Connect available'
                                  : 'Health Connect not available'),
                            ),
                            if (!_isAvailable)
                              const TextButton(
                                onPressed:
                                    WearableHealthService.installHealthConnect,
                                child: Text('Install'),
                              ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _hasPermissions
                                ? Icons.lock_open
                                : Icons.lock_outline,
                            color: _hasPermissions
                                ? colorScheme.primary
                                : colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_hasPermissions
                                ? 'Permissions granted'
                                : 'Permissions required'),
                          ),
                          if (!_hasPermissions)
                            TextButton(
                              onPressed: () async {
                                final granted = await WearableHealthService
                                    .requestRequiredPermissions();
                                if (!mounted) return;
                                setState(() {
                                  _hasPermissions = granted;
                                });
                              },
                              child: const Text('Grant'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => Navigator.pushNamed(context, '/wearables'),
                        icon: const Icon(Icons.watch),
                        label: const Text('Open Wearables'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Notifications'),
                  subtitle: const Text('Coming soon'),
                  onTap: () {},
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.security),
                  title: const Text('Privacy'),
                  subtitle: const Text('GDPR & global privacy summary'),
                  onTap: () => _showPrivacyDialog(context),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('About'),
                  subtitle: const Text('MediPal v1.0.0'),
                  onTap: () {},
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
