import 'dart:typed_data';

import 'package:business/presentation/profile/kyc_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeKycSource implements KycSource {
  Kyc stored = const Kyc();
  Object? loadFailure;
  Object? saveFailure;
  Object? uploadFailure;
  final saved = <Kyc>[];
  final uploads = <({String kind, String name, int bytes})>[];

  @override
  Future<Kyc> load(String businessId) async {
    if (loadFailure != null) throw loadFailure!;
    return stored;
  }

  @override
  Future<void> save(String businessId, Kyc kyc) async {
    if (saveFailure != null) throw saveFailure!;
    saved.add(kyc);
  }

  @override
  Future<String> uploadDocument(
    String businessId,
    String kind,
    String fileName,
    Uint8List bytes,
  ) async {
    if (uploadFailure != null) throw uploadFailure!;
    uploads.add((kind: kind, name: fileName, bytes: bytes.length));
    return 'https://files.test/$kind.jpg';
  }
}

class FakePicker implements DocumentPicker {
  PickedDocument? next = PickedDocument('cert.jpg', Uint8List.fromList([1, 2, 3]));

  @override
  Future<PickedDocument?> pick() async => next;
}

void main() {
  late FakeKycSource source;
  late FakePicker picker;
  late KycViewModel vm;

  setUp(() {
    source = FakeKycSource();
    picker = FakePicker();
    vm = KycViewModel(businessId: 'BUS1', source: source, picker: picker);
  });

  tearDown(() => vm.dispose());

  group('loading', () {
    test('shows what is already saved', () async {
      source.stored = const Kyc(
        gstin: '22AAAAA0000A1Z5',
        pan: 'AAAAA0000A',
        address: 'Baner, Pune',
        documents: {'gst': 'https://files.test/gst.jpg'},
      );

      await vm.load();

      expect(vm.loading, isFalse);
      expect(vm.kyc.gstin, '22AAAAA0000A1Z5');
      expect(vm.kyc.pan, 'AAAAA0000A');
      expect(vm.kyc.address, 'Baner, Pune');
      expect(vm.hasDocument('gst'), isTrue);
      expect(vm.hasDocument('incorporation'), isFalse);
    });

    test('reports a failed load and can retry', () async {
      source.loadFailure = Exception('denied');
      await vm.load();
      expect(vm.error, "Couldn't load your KYC details.");

      source.loadFailure = null;
      await vm.load();
      expect(vm.error, isNull);
    });
  });

  group('saving', () {
    setUp(() async => vm.load());

    test('stores trimmed, upper-case numbers', () async {
      vm.setGstin(' 22aaaaa0000a1z5 ');
      vm.setPan('aaaaa0000a');
      vm.setAddress('  Baner, Pune ');

      expect(await vm.save(), isTrue);

      expect(source.saved.single.gstin, '22AAAAA0000A1Z5');
      expect(source.saved.single.pan, 'AAAAA0000A');
      expect(source.saved.single.address, 'Baner, Pune');
      expect(vm.saving, isFalse);
    });

    test('every field is optional', () async {
      expect(await vm.save(), isTrue);
    });

    test('refuses a malformed GSTIN', () async {
      vm.setGstin('12345');

      expect(await vm.save(), isFalse);
      expect(vm.gstinError, 'Enter the 15-character GSTIN, like 22ABCDE1234F1Z5.');
      expect(source.saved, isEmpty);
    });

    test('refuses a malformed PAN', () async {
      vm.setPan('ABC');

      expect(await vm.save(), isFalse);
      expect(vm.panError, 'Enter a PAN like ABCDE1234F.');
    });

    test('fixing the field clears its error', () async {
      vm.setPan('ABC');
      await vm.save();
      vm.setPan('ABCDE1234F');

      expect(vm.panError, isNull);
    });

    test('keeps working after a failed save', () async {
      source.saveFailure = Exception('denied');
      vm.setPan('ABCDE1234F');

      expect(await vm.save(), isFalse);
      expect(vm.error, "Couldn't save. Try again.");
      expect(vm.saving, isFalse);

      source.saveFailure = null;
      expect(await vm.save(), isTrue);
      expect(vm.error, isNull);
    });
  });

  group('documents', () {
    setUp(() async => vm.load());

    test('picks a file and uploads it', () async {
      expect(await vm.upload('incorporation'), isTrue);

      expect(source.uploads.single, (kind: 'incorporation', name: 'cert.jpg', bytes: 3));
      expect(vm.hasDocument('incorporation'), isTrue);
      expect(vm.uploading, isNull);
    });

    test('does nothing when nothing was picked', () async {
      picker.next = null;

      expect(await vm.upload('gst'), isFalse);
      expect(source.uploads, isEmpty);
      expect(vm.error, isNull);
    });

    test('says what went wrong when the upload fails', () async {
      source.uploadFailure = Exception('denied');

      expect(await vm.upload('gst'), isFalse);
      expect(vm.error, "Couldn't upload the document. Try again.");
      expect(vm.hasDocument('gst'), isFalse);
      expect(vm.uploading, isNull);
    });

    test('shows which document is being uploaded while it goes', () async {
      final seen = <String?>[];
      vm.addListener(() => seen.add(vm.uploading));

      await vm.upload('gst');

      expect(seen, contains('gst'));
      expect(seen.last, isNull);
    });
  });
}
