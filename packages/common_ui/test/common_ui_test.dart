import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:common_ui/common_ui.dart';

void main() {
  testWidgets('EmptyStateWidget renders title, message, and action', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyStateWidget(
            title: 'No properties',
            message: 'Add a property to get started.',
            icon: Icons.home_outlined,
            actionLabel: 'Add',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('No properties'), findsOneWidget);
    expect(find.text('Add a property to get started.'), findsOneWidget);

    await tester.tap(find.text('Add'));
    expect(tapped, isTrue);
  });
}
