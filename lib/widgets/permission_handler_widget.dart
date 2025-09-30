import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/emergency_service.dart';

class PermissionHandlerWidget extends StatefulWidget {
  final Widget child;

  const PermissionHandlerWidget({super.key, required this.child});

  @override
  State<PermissionHandlerWidget> createState() =>
      _PermissionHandlerWidgetState();
}

class _PermissionHandlerWidgetState extends State<PermissionHandlerWidget>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionsOnStartup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsOnResume();
    }
  }

  Future<void> _checkPermissionsOnStartup() async {
    // Don't show permission dialog immediately on startup
    // Just check and cache the status
    await EmergencyService.checkAllPermissions();
  }

  Future<void> _checkPermissionsOnResume() async {
    // Check permissions when app resumes (user might have changed settings)
    await EmergencyService.checkAllPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
