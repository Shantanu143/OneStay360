import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:models/business/property/property_model.dart';
import 'package:models/business/property/property_pricing_model.dart';
import 'package:models/business/property/property_amenities_model.dart';
import 'package:models/business/property/property_rules_model.dart';
import 'package:models/business/property/property_totals_model.dart';
import 'package:models/business/property/property_rating_model.dart';

Property _makeTestProperty({String id = 'PROP001'}) {
  return Property(
    id: id,
    name: 'Sunrise PG',
    address: '123 MG Road',
    city: 'Pune',
    cityCode: 'PNE',
    pincode: '411001',
    numberOfFloors: 3,
    description: 'A comfortable PG for working professionals',
    landmarks: 'Near Pune Station',
    googleMapsLink: 'https://maps.google.com/test',
    pricing: PropertyPricing(
      single: 8000,
      double: 6000,
      triple: 5000,
      securityDeposit: 10000,
      oneTimeMaintenance: 1500,
      maintenanceDeductedFromDeposit: false,
    ),
    rooms: [],
    amenities: PropertyAmenities(
      wifi: true,
      ac: false,
      foodIncluded: true,
      laundry: true,
      parking: false,
      geyser: true,
      powerBackup: true,
      cctv: true,
      housekeeping: false,
    ),
    rules: PropertyRules(
      genderAllowed: 'Co-ed',
      curfew: true,
      visitorsAllowed: true,
      smokingAllowed: false,
      alcoholAllowed: false,
      noticePeriodDays: 30,
    ),
    totals: PropertyTotals(rooms: 10, beds: 30, availableBeds: 15),
    rating: PropertyRating(average: 4.2, count: 25),
    status: 'active',
    billingStatus: 'paid',
    pricePerBed: 30,
    totalBeds: 30,
    activeBedCount: 30,
    billedBedCount: 30,
    businessId: 'BUS0000001',
    businessName: 'Test Business',
    businessPhone: '9876543210',
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 6, 1),
  );
}

void main() {
  group('Property Model Tests', () {
    group('Serialization', () {
      test('toMap should include all required fields', () {
        final property = _makeTestProperty();
        final map = property.toMap();

        expect(map['name'], equals('Sunrise PG'));
        expect(map['address'], equals('123 MG Road'));
        expect(map['city'], equals('Pune'));
        expect(map['cityCode'], equals('PNE'));
        expect(map['pincode'], equals('411001'));
        expect(map['numberOfFloors'], equals(3));
        expect(map['description'], isNotEmpty);
        expect(map['businessId'], equals('BUS0000001'));
        expect(map['status'], equals('active'));
        expect(map['billingStatus'], equals('paid'));
        expect(map['totalBeds'], equals(30));
      });

      test('toMap should not include billing-sensitive fields from client', () {
        final property = _makeTestProperty();
        final map = property.toMap();

        // These fields should be present in the model but managed server-side
        expect(map.containsKey('billingStatus'), isTrue);
        expect(map.containsKey('pricePerBed'), isTrue);
      });

      test('fromMap should parse all fields correctly', () {
        final now = DateTime(2024, 1, 1);
        final map = {
          'name': 'Test PG',
          'address': '456 FC Road',
          'city': 'Pune',
          'cityCode': 'PNE',
          'pincode': '411004',
          'numberOfFloors': 2,
          'description': 'Test description',
          'landmarks': 'Near FC Road',
          'googleMapsLink': 'https://maps.google.com',
          'pricing': {'single': 7000, 'double': 5500, 'triple': 4500},
          'rooms': [],
          'amenities': {'wifi': true, 'ac': true},
          'rules': {'smokingAllowed': false},
          'totals': {'rooms': 5, 'beds': 15, 'availableBeds': 8},
          'rating': {'average': 4.0, 'count': 10},
          'status': 'active',
          'billingStatus': 'paid',
          'pricePerBed': 30,
          'totalBeds': 15,
          'activeBedCount': 15,
          'billedBedCount': 15,
          'businessId': 'BUS0000001',
          'businessName': 'Test Business',
          'businessPhone': '9876543210',
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
          'featured': false,
        };

        final property = Property.fromMap(map, 'PROP_TEST');

        expect(property.id, equals('PROP_TEST'));
        expect(property.name, equals('Test PG'));
        expect(property.city, equals('Pune'));
        expect(property.pincode, equals('411004'));
        expect(property.totalBeds, equals(15));
        expect(property.businessId, equals('BUS0000001'));
      });

      test('fromMap should handle missing optional fields with defaults', () {
        final map = {
          'name': 'Minimal PG',
          'address': '789 Test St',
          'city': 'Mumbai',
          'cityCode': 'MUM',
          'numberOfFloors': 1,
          'description': '',
          'landmarks': '',
          'googleMapsLink': '',
          'pricing': {},
          'rooms': [],
          'amenities': {},
          'rules': {},
          'totals': {},
          'rating': {},
          'status': 'active',
          'businessId': 'BUS0000002',
          'businessName': 'Minimal Business',
          'businessPhone': '9876543211',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        };

        final property = Property.fromMap(map, 'PROP_MIN');

        expect(property.billingStatus, equals('payment_due')); // default
        expect(property.pricePerBed, equals(30)); // default
        expect(property.totalBeds, equals(0)); // default
        expect(property.featured, isFalse); // default
        expect(property.pincode, equals('')); // default
      });
    });

    group('copyWith', () {
      test('should create copy with updated fields', () {
        final original = _makeTestProperty();
        final copy = original.copyWith(
          name: 'Updated PG Name',
          status: 'suspended',
          totalBeds: 25,
        );

        expect(copy.name, equals('Updated PG Name'));
        expect(copy.status, equals('suspended'));
        expect(copy.totalBeds, equals(25));

        // Unchanged fields
        expect(copy.id, equals(original.id));
        expect(copy.city, equals(original.city));
        expect(copy.businessId, equals(original.businessId));
      });

      test('should not mutate original', () {
        final original = _makeTestProperty();
        final originalName = original.name;

        original.copyWith(name: 'Different Name');

        expect(original.name, equals(originalName));
      });
    });

    group('Business Logic', () {
      test('should identify active and paid property', () {
        final property = _makeTestProperty();
        expect(property.status, equals('active'));
        expect(property.billingStatus, equals('paid'));
      });

      test('should handle suspended property', () {
        final property = _makeTestProperty().copyWith(
          status: 'suspended',
          billingStatus: 'past_due',
        );
        expect(property.status, equals('suspended'));
        expect(property.billingStatus, equals('past_due'));
      });

      test('should calculate available beds from totals', () {
        final property = _makeTestProperty();
        expect(property.totals.availableBeds, equals(15));
        expect(property.totals.beds, equals(30));
      });
    });

    group('Image Parsing', () {
      test('should parse list of image URLs', () {
        final map = {
          'name': 'PG with Images',
          'address': 'Test',
          'city': 'Pune',
          'cityCode': 'PNE',
          'numberOfFloors': 1,
          'description': '',
          'landmarks': '',
          'googleMapsLink': '',
          'pricing': {},
          'rooms': [],
          'amenities': {},
          'rules': {},
          'totals': {},
          'rating': {},
          'status': 'active',
          'businessId': 'BUS001',
          'businessName': 'Test',
          'businessPhone': '9876543210',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'images': [
            'https://storage.googleapis.com/img1.jpg',
            'https://storage.googleapis.com/img2.jpg',
          ],
        };

        final property = Property.fromMap(map, 'PROP_IMG');
        expect(property.images, isNotNull);
        expect(property.images!.length, equals(2));
      });

      test('should handle null images gracefully', () {
        final map = {
          'name': 'PG No Images',
          'address': 'Test',
          'city': 'Pune',
          'cityCode': 'PNE',
          'numberOfFloors': 1,
          'description': '',
          'landmarks': '',
          'googleMapsLink': '',
          'pricing': {},
          'rooms': [],
          'amenities': {},
          'rules': {},
          'totals': {},
          'rating': {},
          'status': 'active',
          'businessId': 'BUS001',
          'businessName': 'Test',
          'businessPhone': '9876543210',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          // No images field
        };

        final property = Property.fromMap(map, 'PROP_NO_IMG');
        expect(property.images, isNull);
      });
    });
  });
}
