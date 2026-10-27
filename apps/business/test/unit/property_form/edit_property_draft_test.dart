import 'package:business/presentation/view_models/add_property_viewmodel.dart';
import 'package:firebase_services/repositories/property_repository.dart';
import 'package:firebase_services/services/image_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/business/property/meal_enum.dart';
import 'package:models/business/property/property_model.dart';

class _Images implements ImageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repo implements PropertyRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Property listed() => Property.fromMap({
      'name': 'Green Nest',
      'address': '12 Baner Road',
      'city': 'Pune',
      'cityCode': 'PNR',
      'pincode': '411045',
      'numberOfFloors': 2,
      'description': 'Calm',
      'landmarks': 'Near metro',
      'googleMapsLink': '',
      'images': ['https://x/a.jpg', 'https://x/b.jpg'],
      'pricing': {
        'maxSharing': 2,
        'sharing': [
          {'sharing': 1, 'nonAc': 12000, 'ac': null},
          {'sharing': 2, 'nonAc': 8000, 'ac': 9500},
        ],
        'securityDeposit': 10000,
        'oneTimeMaintenance': 500,
        'maintenanceDeductedFromDeposit': true,
      },
      'amenities': {'wifi': true, 'foodIncluded': true, 'cctv': true},
      'foodPlan': {
        'plan': {
          'Monday': ['Breakfast', 'Dinner'],
          'Sunday': ['Lunch'],
        },
        'notes': 'Veg only',
      },
      'rules': {'genderAllowed': 'Female', 'visitorsAllowed': true, 'noticePeriodDays': 15},
      'status': 'active',
      'businessId': 'BUS0000001',
    }, 'BUS0000001PNR001');

void main() {
  late AddPropertyViewModel vm;
  setUp(() => vm = AddPropertyViewModel(imageService: _Images(), propertyRepository: _Repo()));
  tearDown(() => vm.dispose());

  test('loadFrom fills every step from the listed property', () {
    vm.loadFrom(listed());

    expect(vm.propertyNameController.text, 'Green Nest');
    expect(vm.selectedCity, 'Pune');
    expect(vm.pincodeController.text, '411045');
    expect(vm.numberOfFloorsController.text, '2');
    expect(vm.existingImages, ['https://x/a.jpg', 'https://x/b.jpg']);
    expect(vm.currentMaxSharing, 2);
    expect(vm.sharingRows, hasLength(2));
    expect((vm.sharingRows[0]['nonAcController'] as TextEditingController).text, '12000');
    expect((vm.sharingRows[0]['acController'] as TextEditingController).text, '');
    expect((vm.sharingRows[1]['acController'] as TextEditingController).text, '9500');
    expect(vm.securityDepositController.text, '10000');
    expect(vm.isMaintenanceDeductedFromDeposit, isTrue);
    expect(vm.hasWifi && vm.hasFood && vm.hasCCTV, isTrue);
    expect(vm.hasAC, isFalse);
    expect(vm.weeklyMeals['Monday'], {Meal.breakfast, Meal.dinner});
    expect(vm.weeklyMeals['Sunday'], {Meal.lunch});
    expect(vm.foodNotesController.text, 'Veg only');
    expect(vm.genderAllowed, 'Female');
    expect(vm.visitorsAllowed, isTrue);
    expect(vm.noticePeriodController.text, '15');
  });

  test('editDetails is what updatePropertyDetails expects', () {
    vm.loadFrom(listed());
    vm.propertyNameController.text = ' Green Nest 2 ';
    vm.removeExistingImage('https://x/a.jpg');

    final d = vm.editDetails(['https://x/b.jpg', 'https://x/new.jpg']);
    expect(d['name'], 'Green Nest 2');
    expect(d['images'], ['https://x/b.jpg', 'https://x/new.jpg']);
    expect(d['numberOfFloors'], 2);
    expect(d['pricing']['maxSharing'], 2);
    expect(d['pricing']['sharing'], [
      {'sharing': 1, 'nonAc': 12000, 'ac': null},
      {'sharing': 2, 'nonAc': 8000, 'ac': 9500},
    ]);
    expect(d['pricing']['securityDeposit'], 10000);
    expect(d['amenities']['foodIncluded'], isTrue);
    expect(d['foodPlan']['plan']['Monday'], ['Breakfast', 'Dinner']);
    expect(d['rules']['genderAllowed'], 'Female');
    expect(d['rules']['noticePeriodDays'], 15);
    expect(d.containsKey('city'), isFalse);
    expect(d.containsKey('rooms'), isFalse);
  });

  test('saveEdits uploads new photos and sends the details', () async {
    Map<String, dynamic>? sent;
    final vm2 = AddPropertyViewModel(
      imageService: _Images(),
      propertyRepository: _Repo(),
      updateDetails: (b, p, details) async {
        expect((b, p), ('BUS0000001', 'BUS0000001PNR001'));
        sent = details;
      },
    )..loadFrom(listed());
    addTearDown(vm2.dispose);

    await vm2.saveEdits(businessId: 'BUS0000001', propertyId: 'BUS0000001PNR001');
    expect(sent!['images'], ['https://x/a.jpg', 'https://x/b.jpg']);
    expect(vm2.isLoading, isFalse);
  });
}
