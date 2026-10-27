import 'package:business/presentation/design/components/biz_chips.dart';
import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/views/properties/property_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: BizTheme.light(),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

PropertyCard _card({
  String? rent = '₹6.5K–12K',
  int? occupancy,
  List<String> images = const [],
  VoidCallback? onOpen,
  VoidCallback? onEdit,
  VoidCallback? onPrimary,
  String primaryLabel = 'Finish setup',
  String status = 'Draft',
  BizTone tone = BizTone.draft,
}) => PropertyCard(
  name: 'Green Valley Co-living',
  location: 'Baner-Pashan Link Rd, Baner, Pune',
  statusLabel: status,
  statusTone: tone,
  rentRange: rent,
  beds: 9,
  rooms: 3,
  occupancyPercent: occupancy,
  updatedAgo: '20m ago',
  imageUrls: images,
  imageBuilder: (context, url) =>
      Container(key: ValueKey('img:$url'), color: Colors.teal),
  primaryLabel: primaryLabel,
  onOpen: onOpen ?? () {},
  onEdit: onEdit,
  onPrimary: onPrimary ?? () {},
);

void main() {
  testWidgets('shows the property facts', (tester) async {
    await tester.pumpWidget(_host(_card()));

    expect(find.text('Green Valley Co-living'), findsOneWidget);
    expect(find.text('Baner-Pashan Link Rd, Baner, Pune'), findsOneWidget);
    expect(find.text('₹6.5K–12K'), findsOneWidget);
    expect(find.text('/ month'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('Beds'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Rooms'), findsOneWidget);
    expect(find.text('Updated 20m ago'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
  });

  testWidgets('hides the price when none is set', (tester) async {
    await tester.pumpWidget(_host(_card(rent: null)));

    expect(find.text('/ month'), findsNothing);
    expect(find.textContaining('₹'), findsNothing);
  });

  testWidgets('adds an occupancy cell when provided', (tester) async {
    await tester.pumpWidget(_host(_card(occupancy: 94)));

    expect(find.text('94%'), findsOneWidget);
    expect(find.text('Occupied'), findsOneWidget);
  });

  testWidgets('shows a placeholder, no counter, without photos', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_card()));

    expect(find.text('No photo yet'), findsOneWidget);
    expect(find.textContaining('/3'), findsNothing);
  });

  testWidgets('shows a photo counter that follows swiping', (tester) async {
    await tester.pumpWidget(_host(_card(images: const ['a', 'b', 'c'])));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('img:a')), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-560, 0));
    await tester.pumpAndSettle();

    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('a single photo has no counter', (tester) async {
    await tester.pumpWidget(_host(_card(images: const ['a'])));
    await tester.pumpAndSettle();

    expect(find.textContaining('1/1'), findsNothing);
  });

  testWidgets('buttons and the card route to their callbacks', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      _host(
        _card(
          onOpen: () => calls.add('open'),
          onEdit: () => calls.add('edit'),
          onPrimary: () => calls.add('primary'),
        ),
      ),
    );

    await tester.tap(find.text('Edit'));
    await tester.tap(find.text('Finish setup'));
    await tester.tap(find.text('Green Valley Co-living'));
    await tester.pumpAndSettle();

    expect(calls, ['edit', 'primary', 'open']);
  });

  testWidgets('no Edit button when editing is not allowed', (tester) async {
    await tester.pumpWidget(_host(_card(onEdit: null)));

    expect(find.text('Edit'), findsNothing);
    expect(find.text('Finish setup'), findsOneWidget);
  });
}
