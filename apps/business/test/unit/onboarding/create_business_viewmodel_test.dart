import 'package:business/presentation/onboarding/create_business_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCreator implements BusinessCreator {
  final created = <String>[];
  Object? failure;

  @override
  Future<String> create(String name) async {
    created.add(name);
    if (failure != null) throw failure!;
    return 'BUS0000042';
  }
}

void main() {
  late FakeCreator creator;
  var reloads = 0;
  Object? reloadFailure;
  late CreateBusinessViewModel vm;

  setUp(() {
    creator = FakeCreator();
    reloads = 0;
    reloadFailure = null;
    vm = CreateBusinessViewModel(
      creator: creator,
      reloadSession: () async {
        reloads++;
        if (reloadFailure != null) throw reloadFailure!;
      },
    );
  });

  tearDown(() => vm.dispose());

  test('starts with nothing wrong', () {
    expect(vm.nameError, isNull);
    expect(vm.error, isNull);
    expect(vm.busy, isFalse);
  });

  test('asks for a name, only after a try', () async {
    expect(await vm.submit(), isFalse);

    expect(vm.nameError, 'Enter your business name.');
    expect(creator.created, isEmpty);
  });

  test('a single letter is not a name', () async {
    vm.setName(' a ');

    await vm.submit();

    expect(vm.nameError, 'Use at least 2 characters.');
  });

  test('a very long name is refused', () async {
    vm.setName('x' * 61);

    await vm.submit();

    expect(vm.nameError, 'Keep it under 60 characters.');
  });

  test('clears the complaint as soon as the name is fixed', () async {
    await vm.submit();
    vm.setName('Sunrise Stays');

    expect(vm.nameError, isNull);
  });

  test('creates the business with a tidy name, then reloads the session', () async {
    vm.setName('  Sunrise   Stays ');

    expect(await vm.submit(), isTrue);

    expect(creator.created, ['Sunrise Stays']);
    expect(reloads, 1);
    expect(vm.createdId, 'BUS0000042');
  });

  test('shows why it could not be created, and can try again', () async {
    creator.failure = Exception('A business already exists for this account.');
    vm.setName('Sunrise Stays');

    expect(await vm.submit(), isFalse);

    expect(vm.error, 'A business already exists for this account.');
    expect(vm.busy, isFalse);

    creator.failure = null;
    expect(await vm.submit(), isTrue);
    expect(vm.error, isNull);
  });

  test('the business exists even if reloading the session fails, and says so', () async {
    reloadFailure = Exception('offline');
    vm.setName('Sunrise Stays');

    expect(await vm.submit(), isTrue, reason: 'it was created; the app can load it on the next try');
    expect(vm.createdId, 'BUS0000042');
  });

  test('does not create two at once', () async {
    vm.setName('Sunrise Stays');

    final a = vm.submit();
    final b = vm.submit();
    await Future.wait([a, b]);

    expect(creator.created, hasLength(1));
  });
}
