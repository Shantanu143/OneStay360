import 'package:business/app/session_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'deactivates the push token, then signs out, then returns to the root',
    (tester) async {
      final calls = <String>[];
      final actions = SessionActions(
        deactivatePushToken: () async => calls.add('deactivate'),
        signOut: () async => calls.add('signOut'),
      );

      late BuildContext pushedContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (root) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(root).push(
                  MaterialPageRoute(
                    builder: (c) {
                      pushedContext = c;
                      return const Scaffold(body: Text('deep page'));
                    },
                  ),
                ),
                child: const Text('root page'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('root page'));
      await tester.pumpAndSettle();
      expect(find.text('deep page'), findsOneWidget);

      await actions.signOutAndReturnToRoot(pushedContext);
      await tester.pumpAndSettle();

      expect(calls, [
        'deactivate',
        'signOut',
      ], reason: 'token first: rules need auth');
      expect(find.text('deep page'), findsNothing);
      expect(find.text('root page'), findsOneWidget);
    },
  );

  testWidgets('still signs out when deactivating the token fails', (
    tester,
  ) async {
    final calls = <String>[];
    final actions = SessionActions(
      deactivatePushToken: () async => throw Exception('offline'),
      signOut: () async => calls.add('signOut'),
    );

    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const Scaffold(body: Text('root'));
          },
        ),
      ),
    );

    await actions.signOutAndReturnToRoot(context);

    expect(calls, ['signOut']);
  });
}
