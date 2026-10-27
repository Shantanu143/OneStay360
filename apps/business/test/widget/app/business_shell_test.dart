import 'package:business/app/business_shell.dart';
import 'package:business/app/deep_links.dart';
import 'package:business/data/providers/business_state_provider.dart';
import 'package:business/models/business_membership_model.dart';
import 'package:business/presentation/design/theme.dart';
import 'package:business/services/business_membership_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Membership implements BusinessMembershipService {
  _Membership(this.role);
  final String role;

  @override
  Future<BusinessMembership?> getActiveMembership(
    String uid,
    String businessId,
  ) async => BusinessMembership(
    id: uid,
    uid: uid,
    businessId: 'BUS1',
    role: role,
    status: 'active',
    name: 'R',
    email: '',
    phone: '',
  );

  @override
  Future<bool> isActiveMember(String uid, String businessId) async => true;

  @override
  Stream<BusinessMembership?> streamActiveMembership(
    String uid,
    String businessId,
  ) => const Stream.empty();
}

/// A tab page with state we can observe being preserved.
class _CounterPage extends StatefulWidget {
  const _CounterPage(this.name);
  final String name;
  @override
  State<_CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<_CounterPage> {
  int taps = 0;
  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () => setState(() => taps++),
      child: Text('${widget.name}:$taps'),
    ),
  );
}

class _SpyCoordinator extends DeepLinkCoordinator {
  _SpyCoordinator()
    : super(navigatorKey: GlobalKey<NavigatorState>(), routeFor: (_) => null);
  int ready = 0;
  int ended = 0;
  @override
  void sessionReady() => ready++;
  @override
  void sessionEnded() => ended++;
}

void main() {
  late List<ShellTab> built;
  late _SpyCoordinator coordinator;
  late int homeFab;
  late int propertiesFab;

  Future<BusinessStateProvider> providerFor(String role) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('u1').set({
      'fullName': 'Rajesh Sharma',
      'businessName': 'Apex',
      'businessId': 'BUS1',
    });
    final p = BusinessStateProvider(
      membershipService: _Membership(role),
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1')),
      firestore: firestore,
      membershipRetryDelay: Duration.zero,
    );
    await p.loadUserData();
    return p;
  }

  Future<void> pumpShell(WidgetTester tester, {String role = 'owner'}) async {
    final provider = await providerFor(role);
    built = [];
    homeFab = 0;
    propertiesFab = 0;
    coordinator = _SpyCoordinator();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BusinessStateProvider>.value(value: provider),
          Provider<DeepLinkCoordinator>.value(value: coordinator),
        ],
        child: MaterialApp(
          theme: BizTheme.light(),
          home: BusinessShell(
            pageBuilder: (context, tab) {
              built.add(tab);
              return _CounterPage(tab.name);
            },
            onHomeFab: (_, __) async => homeFab++,
            onPropertiesFab: (_, __) async => propertiesFab++,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('opens on Home and only builds tabs when first visited', (
    tester,
  ) async {
    await pumpShell(tester);

    expect(find.text('home:0'), findsOneWidget);
    expect(built, [ShellTab.home]);
  });

  testWidgets('owners get five tabs, managers three', (tester) async {
    await pumpShell(tester, role: 'owner');
    for (final label in ['Home', 'Properties', 'Tenants', 'Team', 'Reports']) {
      expect(find.text(label), findsOneWidget);
    }

    await pumpShell(tester, role: 'manager');
    expect(find.text('Reports'), findsNothing);
    expect(find.text('Team'), findsNothing);
    expect(find.text('Tenants'), findsOneWidget);
  });

  testWidgets('switching tabs keeps each tab\'s state', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.text('home:0'));
    await tester.pump();
    expect(find.text('home:1'), findsOneWidget);

    await tester.tap(find.text('Properties'));
    await tester.pumpAndSettle();
    expect(find.text('properties:0'), findsOneWidget);
    await tester.tap(find.text('properties:0'));
    await tester.pump();
    await tester.tap(find.text('properties:1'));
    await tester.pump();

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('home:1'), findsOneWidget, reason: 'home kept its state');

    await tester.tap(find.text('Properties'));
    await tester.pumpAndSettle();
    expect(
      find.text('properties:2'),
      findsOneWidget,
      reason: 'properties kept its state',
    );
    expect(
      built.where((t) => t == ShellTab.properties).length,
      1,
      reason: 'built once, not per visit',
    );
  });

  testWidgets('system back from another tab returns to Home first', (
    tester,
  ) async {
    await pumpShell(tester);
    await tester.tap(find.text('Tenants'));
    await tester.pumpAndSettle();
    expect(find.text('tenants:0'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('home:0'), findsOneWidget);
  });

  testWidgets('a tab can ask the shell to switch tabs', (tester) async {
    final provider = await providerFor('owner');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BusinessStateProvider>.value(value: provider),
          Provider<DeepLinkCoordinator>.value(value: _SpyCoordinator()),
        ],
        child: MaterialApp(
          theme: BizTheme.light(),
          home: BusinessShell(
            pageBuilder: (context, tab) => Center(
              child: TextButton(
                onPressed: () =>
                    context.read<ShellController>().goTo(ShellTab.reports),
                child: Text('go from ${tab.name}'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('go from home'));
    await tester.pumpAndSettle();

    expect(find.text('go from reports'), findsOneWidget);
  });

  testWidgets('the + button belongs to Home and Properties only', (
    tester,
  ) async {
    await pumpShell(tester);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(homeFab, 1);

    await tester.tap(find.text('Properties'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(propertiesFab, 1);

    await tester.tap(find.text('Tenants'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add_rounded), findsNothing);

    await tester.tap(find.text('Team'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add_rounded), findsNothing);

    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add_rounded), findsNothing);
  });

  testWidgets('onQuickAdd shows + button across all tabs', (tester) async {
    final provider = await providerFor('owner');
    int quickAddTaps = 0;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BusinessStateProvider>.value(value: provider),
          Provider<DeepLinkCoordinator>.value(value: _SpyCoordinator()),
        ],
        child: MaterialApp(
          theme: BizTheme.light(),
          home: BusinessShell(
            pageBuilder: (context, tab) => _CounterPage(tab.name),
            onQuickAdd: (_, __) async => quickAddTaps++,
          ),
        ),
      ),
    );
    await tester.pump();

    for (final tab in ['Home', 'Properties', 'Tenants', 'Team', 'Reports']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.add_rounded), findsOneWidget, reason: 'FAB present on $tab');
    }

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(quickAddTaps, 1);
  });

  testWidgets('only owners can add a property, so only they get a + on Properties', (tester) async {
    await pumpShell(tester, role: 'manager');

    expect(find.byIcon(Icons.add_rounded), findsOneWidget, reason: 'Home keeps its quick add');
    await tester.tap(find.text('Properties'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add_rounded), findsNothing);
    expect(propertiesFab, 0);
  });

  testWidgets('hides the nav while the keyboard is open', (tester) async {
    await pumpShell(tester);
    expect(find.text('Properties'), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();

    expect(find.text('Properties'), findsNothing);
  });

  testWidgets('tells the deep-link coordinator when the session is on screen', (
    tester,
  ) async {
    await pumpShell(tester);
    await tester.pump();
    expect(coordinator.ready, 1);
    expect(coordinator.ended, 0);

    await tester.pumpWidget(const SizedBox());
    expect(coordinator.ended, 1);
  });
}
