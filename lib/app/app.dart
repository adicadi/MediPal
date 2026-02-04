import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utils/app_state.dart';
import '../services/deepseek_service.dart';
import '../screens/initial_screen.dart';
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
        ChangeNotifierProvider(create: (context) => AppState()),
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
      child: MaterialApp(
        title: 'MediPal',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: home ?? const InitialScreen(),
        routes: routes ?? appRoutes,
        scrollBehavior: const AppScrollBehavior(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
