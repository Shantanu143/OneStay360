import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:business/presentation/design/components/biz_button.dart';
import 'package:business/presentation/design/components/biz_chips.dart';
import 'package:business/presentation/design/components/biz_dialogs.dart';
import 'package:business/presentation/design/components/biz_header.dart';
import 'package:business/presentation/design/components/biz_scaffold.dart';
import 'package:business/presentation/design/components/biz_search_field.dart';
import 'package:business/presentation/design/components/biz_section_label.dart';
import 'package:business/presentation/design/components/biz_states.dart';
import 'package:business/presentation/design/components/biz_step_pills.dart';
import 'package:business/presentation/design/components/biz_text_field.dart';
import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/design/tokens.dart';

Widget _host(Widget child) => MaterialApp(
  theme: BizTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  group('BizButton', () {
    testWidgets('fires onPressed when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(BizButton(label: 'Save', onPressed: () => taps++)),
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('is inert when onPressed is null', (tester) async {
      await tester.pumpWidget(
        _host(const BizButton(label: 'Save', onPressed: null)),
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('shows a spinner and ignores taps while loading', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(BizButton(label: 'Save', loading: true, onPressed: () => taps++)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(BizButton));
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('renders leading and trailing icons', (tester) async {
      await tester.pumpWidget(
        _host(
          BizButton(
            label: 'Continue',
            icon: Icons.add_rounded,
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    });

    testWidgets('every kind and size builds', (tester) async {
      for (final kind in BizButtonKind.values) {
        for (final size in BizButtonSize.values) {
          await tester.pumpWidget(
            _host(
              Center(
                child: BizButton(
                  label: 'x',
                  kind: kind,
                  size: size,
                  expand: false,
                  onPressed: () {},
                ),
              ),
            ),
          );
          expect(find.text('x'), findsOneWidget, reason: '$kind $size');
        }
      }
    });
  });

  group('BizFilterChips', () {
    testWidgets('shows labels with counts and reports the tapped index', (
      tester,
    ) async {
      int? picked;
      await tester.pumpWidget(
        _host(
          BizFilterChips(
            selectedIndex: 0,
            onSelected: (i) => picked = i,
            chips: const [
              BizChipData('All', count: 4),
              BizChipData('Active'),
              BizChipData('Vacant'),
            ],
          ),
        ),
      );

      expect(find.text('All'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);

      await tester.tap(find.text('Vacant'));
      await tester.pumpAndSettle();
      expect(picked, 2);
    });

    testWidgets('marks only the selected chip as selected for accessibility', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          BizFilterChips(
            selectedIndex: 1,
            onSelected: (_) {},
            chips: const [BizChipData('All'), BizChipData('Active')],
          ),
        ),
      );

      final selected = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.selected == true);
      expect(selected.length, 1);
    });

    final many = [for (var i = 0; i < 8; i++) BizChipData('Chip number $i')];

    testWidgets('opens with a late selected chip scrolled into view', (tester) async {
      await tester.pumpWidget(
        _host(BizFilterChips(selectedIndex: 7, onSelected: (_) {}, chips: many)),
      );
      await tester.pumpAndSettle();

      final right = tester.getTopRight(find.text('Chip number 7')).dx;
      expect(right, lessThanOrEqualTo(800.0), reason: 'inside the 800px test window');
      expect(tester.getTopLeft(find.text('Chip number 0')).dx, lessThan(0));
    });

    testWidgets('scrolls to a chip that becomes selected off-screen', (tester) async {
      var selected = 0;
      late StateSetter set;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return BizFilterChips(selectedIndex: selected, onSelected: (_) {}, chips: many);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Chip number 0')).dx, greaterThan(0));

      set(() => selected = 6);
      await tester.pumpAndSettle();

      expect(tester.getTopRight(find.text('Chip number 6')).dx, lessThanOrEqualTo(800.0));
      expect(tester.getTopLeft(find.text('Chip number 0')).dx, lessThan(0));
    });

    testWidgets('a short row starts at the left even inside a centered column', (tester) async {
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              BizFilterChips(
                selectedIndex: 0,
                onSelected: (_) {},
                chips: const [BizChipData('One'), BizChipData('Two')],
              ),
            ],
          ),
        ),
      );

      expect(tester.getTopLeft(find.text('One')).dx, lessThan(60));
    });

    testWidgets('chips in a choice wrap keep their natural width', (tester) async {
      await tester.pumpWidget(
        _host(
          Padding(
            padding: const EdgeInsets.all(16),
            child: BizChoiceWrap<String>(
              options: const ['Cash', 'UPI', 'Cheque'],
              selected: 'Cash',
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final cash = tester.getSize(find.ancestor(of: find.text('Cash'), matching: find.byType(AnimatedContainer)).first);
      expect(cash.width, lessThan(200), reason: 'not stretched across the 800px window');
      expect(
        tester.getTopLeft(find.text('UPI')).dy,
        tester.getTopLeft(find.text('Cash')).dy,
        reason: 'on the same row',
      );
    });

    testWidgets('leaves the row alone when the chip is already visible', (tester) async {
      await tester.pumpWidget(
        _host(BizFilterChips(selectedIndex: 1, onSelected: (_) {}, chips: many)),
      );
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.text('Chip number 0')).dx, greaterThan(0));
    });
  });

  group('BizChip fill', () {
    Color? fillOf(WidgetTester tester, String label) {
      final box = tester.widget<AnimatedContainer>(
        find.ancestor(of: find.text(label), matching: find.byType(AnimatedContainer)).first,
      );
      return (box.decoration as BoxDecoration).color;
    }

    testWidgets('is white on the page and grey on a card, so it stays visible there', (tester) async {
      await tester.pumpWidget(_host(Column(children: [
        BizChip(data: const BizChipData('On page'), selected: false, onTap: () {}),
        BizChip(data: const BizChipData('On card'), selected: false, onTap: () {}, onCard: true),
        BizChip(data: const BizChipData('Picked'), selected: true, onTap: () {}, onCard: true),
      ])));

      expect(fillOf(tester, 'On page'), Colors.white);
      expect(fillOf(tester, 'On card'), BizColors.page);
      expect(fillOf(tester, 'Picked'), BizColors.card, reason: 'selected looks the same everywhere');
    });
  });

  group('BizStatusPill', () {
    testWidgets('renders its label for every tone', (tester) async {
      for (final tone in BizTone.values) {
        await tester.pumpWidget(_host(BizStatusPill('State', tone: tone)));
        expect(find.text('State'), findsOneWidget, reason: '$tone');
      }
    });
  });

  group('BizStepPills', () {
    const steps = ['Property', 'Tenant info', 'Lease', 'Bill'];

    testWidgets('marks earlier steps done and later steps upcoming', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const BizStepPills(steps: steps, current: 2)),
      );

      expect(
        find.byIcon(Icons.check_rounded),
        findsNWidgets(2),
      ); // steps 1 and 2
      expect(find.text('3'), findsOneWidget); // current step number
      expect(find.text('4'), findsOneWidget); // upcoming step number
    });

    testWidgets('progress bar reflects the current step', (tester) async {
      await tester.pumpWidget(
        _host(const BizStepPills(steps: steps, current: 1)),
      );
      await tester.pumpAndSettle();

      final bar = tester.widget<FractionallySizedBox>(
        find.byKey(const ValueKey('step-progress-fill')),
      );
      expect(bar.widthFactor, closeTo(2 / 4, 1e-9));
    });

    testWidgets('only completed steps are tappable', (tester) async {
      final tapped = <int>[];
      await tester.pumpWidget(
        _host(BizStepPills(steps: steps, current: 2, onStepTap: tapped.add)),
      );

      await tester.tap(find.text('Property'));
      await tester.tap(find.text('Bill')); // upcoming: ignored
      await tester.pumpAndSettle();

      expect(tapped, [0]);
    });
  });

  group('BizSearchField', () {
    testWidgets('debounces typing before reporting the query', (tester) async {
      final queries = <String>[];
      await tester.pumpWidget(
        _host(
          BizSearchField(hint: 'Name, address or city', onChanged: queries.add),
        ),
      );

      await tester.enterText(find.byType(TextField), 'gre');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'green');
      await tester.pump(const Duration(milliseconds: 100));
      expect(queries, isEmpty);

      await tester.pump(const Duration(milliseconds: 300));
      expect(queries, ['green']);
    });

    testWidgets('clear button empties the field and reports an empty query', (
      tester,
    ) async {
      final queries = <String>[];
      await tester.pumpWidget(
        _host(
          BizSearchField(
            hint: 'Search',
            debounce: Duration.zero,
            onChanged: queries.add,
          ),
        ),
      );

      expect(find.byIcon(Icons.close_rounded), findsNothing);
      await tester.enterText(find.byType(TextField), 'pune');
      await tester.pump();
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
      expect(queries.last, '');
    });
  });

  group('BizTextField', () {
    testWidgets('shows its label and validates through a Form', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _host(
          Form(
            key: formKey,
            child: BizTextField(
              label: 'Full name',
              validator: (v) => (v ?? '').isEmpty ? 'Enter a name' : null,
            ),
          ),
        ),
      );

      expect(find.text('Full name'), findsOneWidget);
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Enter a name'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'Amit Patel');
      expect(formKey.currentState!.validate(), isTrue);
    });
  });

  group('BizSectionLabel', () {
    testWidgets('upper-cases the label and shows the trailing text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const BizSectionLabel('Floor', trailing: '6 of 19 beds free')),
      );

      expect(find.text('FLOOR'), findsOneWidget);
      expect(find.text('6 of 19 beds free'), findsOneWidget);
    });
  });

  group('BizHeader', () {
    testWidgets('shows eyebrow, title and actions', (tester) async {
      await tester.pumpWidget(
        _host(
          BizHeader(
            eyebrow: '4 properties · Pune',
            title: 'Properties',
            actions: const [Icon(Icons.swap_vert_rounded)],
          ),
        ),
      );

      expect(find.text('4 properties · Pune'), findsOneWidget);
      expect(find.text('Properties'), findsOneWidget);
      expect(find.byIcon(Icons.swap_vert_rounded), findsOneWidget);
    });

    testWidgets('back button pops the route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BizTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const Scaffold(
                        body: BizHeader(title: 'Detail', showBack: true),
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsNothing);
    });
  });

  group('BizScaffold', () {
    testWidgets('lays out header, body and a sticky bottom bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BizTheme.light(),
          home: const BizScaffold(
            title: 'Add Tenant',
            eyebrow: 'Tenants',
            body: Text('body content'),
            bottomBar: Text('sticky cta'),
          ),
        ),
      );

      expect(find.text('Add Tenant'), findsOneWidget);
      expect(find.text('body content'), findsOneWidget);
      expect(find.text('sticky cta'), findsOneWidget);
    });
  });

  group('states', () {
    testWidgets('error state offers a retry', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        _host(
          BizErrorState(
            message: 'Could not load properties',
            onRetry: () => retries++,
          ),
        ),
      );

      expect(find.text('Could not load properties'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(retries, 1);
    });

    testWidgets('empty state shows title, message and optional action', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          BizEmptyState(
            icon: Icons.apartment_outlined,
            title: 'No properties yet',
            message: 'Add your first property to get started.',
            actionLabel: 'Add property',
            onAction: () => taps++,
          ),
        ),
      );

      expect(find.text('No properties yet'), findsOneWidget);
      await tester.tap(find.text('Add property'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });

  group('dialogs', () {
    testWidgets('showBizConfirm resolves true on confirm and false on cancel', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: BizTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => result = await showBizConfirm(
                  context,
                  title: 'Delete property?',
                  message: 'This cannot be undone.',
                  confirmLabel: 'Delete',
                  destructive: true,
                ),
                child: const Text('ask'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
      expect(find.text('Delete property?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(result, isTrue);

      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('showBizToast shows the message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BizTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showBizToast(context, 'Saved'),
                child: const Text('toast'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('toast'));
      await tester.pump();
      expect(find.text('Saved'), findsOneWidget);
    });
  });
}

// Silences the unused import when a test above is removed.
// ignore: unused_element
Future<void> _unused() async => Completer<void>().future;
