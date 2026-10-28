import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tenant/app/tenant_shell.dart';

void main() {
  late Map<ShellTab, int> builds;

  setUp(() => builds = {});

  Widget app({ShellController? controller}) => MaterialApp(
        home: TenantShell(
          controller: controller,
          pageBuilder: (context, tab) {
            builds[tab] = (builds[tab] ?? 0) + 1;
            return Center(
              child: TextButton(
                onPressed: () => context.read<ShellController>().goTo(ShellTab.explore),
                child: Text('PAGE ${tab.name}'),
              ),
            );
          },
        ),
      );

  testWidgets('opens on Home with all four tabs in the nav', (tester) async {
    await tester.pumpWidget(app());
    expect(find.text('PAGE home'), findsOneWidget);
    for (final label in ['Home', 'Explore', 'My stay', 'Profile']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('tapping a tab shows it, building each page once', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('PAGE profile'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(builds[ShellTab.profile], 1);
    expect(builds[ShellTab.home], 1);
  });

  testWidgets('pages can switch tabs through the controller', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('PAGE home'));
    await tester.pumpAndSettle();
    expect(find.text('PAGE explore'), findsOneWidget);
  });

  testWidgets('an outside controller drives it (push notifications)', (tester) async {
    final controller = ShellController();
    await tester.pumpWidget(app(controller: controller));
    controller.goTo(ShellTab.stay);
    await tester.pumpAndSettle();
    expect(find.text('PAGE stay'), findsOneWidget);
  });

  testWidgets('back goes Home before leaving the app', (tester) async {
    final controller = ShellController();
    await tester.pumpWidget(app(controller: controller));
    controller.goTo(ShellTab.profile);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(controller.current, ShellTab.home);
  });
}
