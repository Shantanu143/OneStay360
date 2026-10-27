import 'package:business/models/payment_method_model.dart';
import 'package:business/presentation/payment_methods/method_form_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeRazorpay implements RazorpayGateway {
  final saved = <({String businessId, String keyId, String secret, String webhook})>[];
  Object? failure;

  @override
  Future<void> saveCredentials(String businessId, {required String keyId, required String keySecret, required String webhookSecret}) async {
    if (failure != null) throw failure!;
    saved.add((businessId: businessId, keyId: keyId, secret: keySecret, webhook: webhookSecret));
  }

  @override
  Future<RazorpayStatus> status(String businessId) async => const RazorpayStatus.notSet();

  @override
  Future<void> verify(String businessId) async {}
}

void main() {
  late FakeRazorpay razorpay;
  final now = DateTime(2026, 10, 26);

  MethodFormViewModel form(MethodType type, {PaymentMethod? existing}) => MethodFormViewModel(
        businessId: 'BUS1',
        type: type,
        existing: existing,
        razorpay: razorpay,
        now: () => now,
      );

  setUp(() => razorpay = FakeRazorpay());

  group('UPI', () {
    test('builds the method from a valid id', () {
      final f = form(MethodType.upi)
        ..setField(MethodField.upiId, ' sunrise@okhdfcbank ')
        ..setField(MethodField.upiPhone, '98765 43210');

      final m = f.build();

      expect(f.validate(), isTrue);
      expect(m.type, 'upi');
      expect(m.upiId, 'sunrise@okhdfcbank');
      expect(m.phoneNumber, '98765 43210');
      expect(m.isActive, isTrue);
      expect(m.businessId, 'BUS1');
    });

    test('needs an id in the form name@bank', () {
      final f = form(MethodType.upi)..setField(MethodField.upiId, 'nobank');

      expect(f.validate(), isFalse);
      expect(f.errorOf(MethodField.upiId), 'Enter a valid UPI ID, like name@bank.');

      f.setField(MethodField.upiId, '');
      f.validate();
      expect(f.errorOf(MethodField.upiId), 'Enter your UPI ID.');
    });

    test('the phone is optional but must be 10 digits when given', () {
      final f = form(MethodType.upi)
        ..setField(MethodField.upiId, 'a.b@upi')
        ..setField(MethodField.upiPhone, '12345');

      expect(f.validate(), isFalse);
      expect(f.errorOf(MethodField.upiPhone), 'Enter a 10-digit phone number.');

      f.setField(MethodField.upiPhone, '');
      expect(f.validate(), isTrue);
    });
  });

  group('bank', () {
    MethodFormViewModel valid() => form(MethodType.bank)
      ..setField(MethodField.bankName, 'HDFC Bank')
      ..setField(MethodField.holder, 'Rajesh Sharma')
      ..setField(MethodField.accountNumber, '1234567890')
      ..setField(MethodField.confirmAccount, '1234567890')
      ..setField(MethodField.ifsc, 'hdfc0001234');

    test('builds a bank method with an upper-case IFSC', () {
      final f = valid();

      expect(f.validate(), isTrue);
      final m = f.build();
      expect(m.type, 'bank');
      expect(m.bankName, 'HDFC Bank');
      expect(m.accountHolderName, 'Rajesh Sharma');
      expect(m.accountNumber, '1234567890');
      expect(m.ifscCode, 'HDFC0001234');
      expect(m.accountType, 'Savings');
    });

    test('accepts a bank that is not on the suggestion list', () {
      final f = valid()..setField(MethodField.bankName, 'Bandhan Bank');

      expect(f.validate(), isTrue);
    });

    test('checks each field', () {
      final f = form(MethodType.bank);

      expect(f.validate(), isFalse);
      expect(f.errorOf(MethodField.bankName), 'Enter the bank name.');
      expect(f.errorOf(MethodField.holder), 'Enter the account holder name.');
      expect(f.errorOf(MethodField.accountNumber), 'Enter the account number.');
      expect(f.errorOf(MethodField.ifsc), 'Enter the IFSC code.');
    });

    test('rejects a wrong account number, IFSC or confirmation', () {
      final f = valid()
        ..setField(MethodField.accountNumber, '12ab')
        ..setField(MethodField.ifsc, 'XXXX')
        ..setField(MethodField.confirmAccount, '999');

      expect(f.validate(), isFalse);
      expect(f.errorOf(MethodField.accountNumber), 'Enter 8 to 18 digits.');
      expect(f.errorOf(MethodField.ifsc), 'Enter a valid IFSC, like HDFC0001234.');

      f.setField(MethodField.accountNumber, '1234567890');
      f.validate();
      expect(f.errorOf(MethodField.confirmAccount), 'The account numbers do not match.');
    });

    test('suggests banks as the owner types', () {
      final f = form(MethodType.bank);

      expect(f.bankSuggestions('hdf'), ['HDFC Bank']);
      expect(f.bankSuggestions(''), isEmpty);
      expect(f.bankSuggestions('zzz'), isEmpty);
    });

    test('can be a current account', () {
      final f = valid()..setAccountType('Current');

      expect(f.build().accountType, 'Current');
    });
  });

  group('cash', () {
    test('has nothing to fill in', () {
      final f = form(MethodType.cash);

      expect(f.validate(), isTrue);
      expect(f.build().type, 'cash');
    });
  });

  group('razorpay', () {
    MethodFormViewModel valid() => form(MethodType.razorpay)
      ..setField(MethodField.rzKeyId, 'rzp_test_AbC123xyz')
      ..setField(MethodField.rzSecret, 'secret-value')
      ..setField(MethodField.rzWebhook, 'hook-secret');

    test('needs a key id and a secret', () {
      final f = form(MethodType.razorpay);

      expect(f.validate(), isFalse);
      expect(f.errorOf(MethodField.rzKeyId), 'Enter your Razorpay Key ID.');
      expect(f.errorOf(MethodField.rzSecret), 'Enter your Razorpay Key Secret.');
    });

    test('a key id starts with rzp_', () {
      final f = valid()..setField(MethodField.rzKeyId, 'abc123');

      expect(f.validate(), isFalse);
      expect(f.errorOf(MethodField.rzKeyId), 'A Razorpay Key ID starts with rzp_.');
    });

    test('saves the credentials, then the method is a razorpay one', () async {
      final f = valid();

      expect(f.validate(), isTrue);
      await f.saveRazorpayCredentials();

      expect(razorpay.saved.single, (
        businessId: 'BUS1',
        keyId: 'rzp_test_AbC123xyz',
        secret: 'secret-value',
        webhook: 'hook-secret',
      ));
      expect(f.build().type, 'razorpay');
    });

    test('editing keeps the saved secret when the field is left blank', () {
      final existing = PaymentMethod(
        id: 'm1',
        businessId: 'BUS1',
        type: 'razorpay',
        isActive: true,
        isPreferred: false,
        createdAt: now,
      );
      final f = form(MethodType.razorpay, existing: existing);

      expect(f.validate(), isTrue, reason: 'nothing needs re-entering');
      expect(f.hasNewRazorpayCredentials, isFalse);
    });
  });

  group('editing', () {
    test('starts from the saved details and keeps its identity', () {
      final existing = PaymentMethod(
        id: 'm9',
        businessId: 'BUS1',
        type: 'upi',
        upiId: 'old@bank',
        isActive: false,
        isPreferred: true,
        createdAt: DateTime(2026, 1, 1),
      );
      final f = form(MethodType.upi, existing: existing);

      expect(f.valueOf(MethodField.upiId), 'old@bank');
      f.setField(MethodField.upiId, 'new@bank');
      final m = f.build();

      expect(m.id, 'm9');
      expect(m.upiId, 'new@bank');
      expect(m.isActive, isFalse, reason: 'editing does not switch it on');
      expect(m.isPreferred, isTrue);
      expect(m.createdAt, DateTime(2026, 1, 1));
      expect(m.updatedAt, now.toUtc());
    });

    test('typing clears that field\'s error', () {
      final f = form(MethodType.upi)..validate();
      expect(f.errorOf(MethodField.upiId), isNotNull);

      f.setField(MethodField.upiId, 'a@b');

      expect(f.errorOf(MethodField.upiId), isNull);
    });
  });

  group('RazorpayStatus label', () {
    String label({
      bool configured = true,
      bool enabled = true,
      bool verified = false,
      String kyc = '',
    }) =>
        RazorpayStatus(configured: configured, enabled: enabled, verified: verified, kycStatus: kyc).label;

    test('says what is true of the keys', () {
      expect(label(configured: false), 'Not set');
      expect(label(verified: true), 'Verified');
      expect(label(enabled: false), 'Disabled');
      expect(label(), 'Not verified');
    });

    test('"activated" only means payments were switched on, so it is not shown as a status', () {
      expect(label(kyc: 'activated'), 'Not verified');
      expect(label(kyc: 'configured'), 'Not verified');
      expect(label(kyc: 'pending'), 'Not verified');
    });

    test('shows the states Razorpay itself reports', () {
      expect(label(kyc: 'under_review'), 'Under review');
      expect(label(kyc: 'needs_clarification'), 'Needs clarification');
      expect(label(kyc: 'suspended'), 'Suspended');
    });

    test('verified wins over any review state', () {
      expect(label(verified: true, kyc: 'under_review'), 'Verified');
    });
  });
}
