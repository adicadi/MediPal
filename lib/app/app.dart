import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_state.dart';
import '../services/auth/auth_service.dart';
import '../services/auth/backend_api_service.dart';
import '../services/auth/session_storage_service.dart';
import '../utils/app_state.dart';
import '../services/deepseek_service.dart';
import '../screens/auth_gate_screen.dart';
import '../theme/app_theme.dart';
import 'app_router.dart';
import 'app_scroll_behavior.dart';

class MediPalApp extends StatelessWidget {
  const MediPalApp({super.key, this.home, this.routes});

  final Widget? home;
  final Map<String, WidgetBuilder>? routes;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => AppState()..loadThemePreference(),
        ),
        Provider(create: (_) => SessionStorageService()),
        Provider(create: (_) => BackendApiService()),
        Provider(
          create: (context) => AuthService(
            api: context.read<BackendApiService>(),
            sessionStore: context.read<SessionStorageService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => AuthState(
            authService: context.read<AuthService>(),
          )..bootstrap(),
        ),
        Provider(create: (context) {
          try {
            return DeepSeekService();
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ DeepSeekService initialization failed: $e');
            }
            return null;
          }
        }),
      ],
      child: Consumer<AppState>(
        builder: (context, appState, _) => MaterialApp(
          title: 'MediPal',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: appState.themeMode,
          home: home ?? const AuthGateScreen(),
          routes: routes ?? appRoutes,
          scrollBehavior: const AppScrollBehavior(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
