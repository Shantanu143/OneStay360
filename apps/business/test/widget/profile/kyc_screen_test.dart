import 'dart:typed_data';

import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/profile/kyc_screen.dart';
import 'package:business/presentation/profile/kyc_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSource implements KycSource {
  Kyc stored = const Kyc();
  Object? saveFailure;
  final saved = <Kyc>[];
  final uploads = <String>[];

  @override
  Future<Kyc> load(String businessId) async => stored;

  @override
  Future<void> save(String businessId, Kyc kyc) async {
    if (saveFailure != null) throw saveFailure!;
    saved.add(kyc);
  }

  @override
  Future<String> uploadDocument(String businessId, String kind, String fileName, Uint8List bytes) async {
    uploads.add(kind);
    return 'https://files.test/$kind';
  }
}

class FakePicker implements DocumentPicker {
  @override
  Future<PickedDocument?> pick() async => PickedDocument('c.jpg', Uint8List.fromList([1]));
}

void main() {
  late FakeSource source;

  setUp(() => source = FakeSource());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: BizTheme.light(),
        home: KycScreen(businessId: 'BUS1', source: source, picker: FakePicker()),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('shows what is saved', (tester) async {
    source.stored = const Kyc(gstin: '22AAAAA0000A1Z5', pan: 'AAAAA0000A', address: 'Baner, Pune');
    await open(tester);

    expect(tester.widget<TextFormField>(find.byKey(const Key('gstin'))).controller!.text, '22AAAAA0000A1Z5');
    expect(tester.widget<TextFormField>(find.byKey(const Key('pan'))).controller!.text, 'AAAAA0000A');
    expect(tester.widget<TextFormField>(find.byKey(const Key('address'))).controller!.text, 'Baner, Pune');
  });

  testWidgets('saves what was typed', (tester) async {
    await open(tester);

    await tester.enterText(find.byKey(const Key('gstin')), '22aaaaa0000a1z5');
    await tester.enterText(find.byKey(const Key('pan')), 'aaaaa0000a');
    await tester.enterText(find.byKey(const Key('address')), 'Baner, Pune');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(source.saved.single.gstin, '22AAAAA0000A1Z5');
    expect(source.saved.single.pan, 'AAAAA0000A');
    expect(find.text('KYC details saved.'), findsOneWidget);
  });

  testWidgets('says what is wrong with a number', (tester) async {
    await open(tester);

    await tester.enterText(find.byKey(const Key('pan')), 'ABC');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a PAN like ABCDE1234F.'), findsOneWidget);
    expect(source.saved, isEmpty);
  });

  testWidgets('a failed save is reported', (tester) async {
    source.saveFailure = Exception('denied');
    await open(tester);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't save. Try again."), findsOneWidget);
  });

  testWidgets('documents can be uploaded and show as uploaded', (tester) async {
    await open(tester);

    expect(find.text('Uploaded'), findsNothing);
    await tester.tap(find.text('Upload').first);
    await tester.pumpAndSettle();

    expect(source.uploads, ['incorporation']);
    expect(find.text('Uploaded'), findsOneWidget);
    expect(find.text('Replace'), findsOneWidget);
  });
}
