import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medipal/app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MediPalApp boots without bootstrap', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MediPalApp(
        home: SizedBox.shrink(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
