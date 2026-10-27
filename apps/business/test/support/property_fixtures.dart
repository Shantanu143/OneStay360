import 'package:models/business/property/property_amenities_model.dart';
import 'package:models/business/property/property_model.dart';
import 'package:models/business/property/property_pricing_model.dart';
import 'package:models/business/property/property_rating_model.dart';
import 'package:models/business/property/property_rules_model.dart';
import 'package:models/business/property/property_totals_model.dart';

/// A fully-populated [Property] with sensible defaults; override what a test
/// cares about.
Property makeProperty({
  String id = 'P1',
  String name = 'Green Valley Co-living',
  String address = 'Baner-Pashan Link Rd',
  String city = 'Pune',
  String status = 'active',
  int single = 12000,
  int double = 8000,
  int triple = 6500,
  int beds = 10,
  int availableBeds = 2,
  int rooms = 4,
  int deposit = 10000,
  int maintenance = 0,
  bool maintenanceDeducted = false,
  List<SharingPricingEntry>? sharingPrices,
  List<String>? images,
  DateTime? createdAt,
  DateTime? updatedAt,
  String businessId = 'BUS1',
}) {
  return Property(
    id: id,
    name: name,
    address: address,
    city: city,
    cityCode: city.length >= 3 ? city.substring(0, 3).toUpperCase() : 'XXX',
    numberOfFloors: 2,
    description: '',
    landmarks: '',
    googleMapsLink: '',
    pricing: PropertyPricing(
      single: single,
      double: double,
      triple: triple,
      securityDeposit: deposit,
      oneTimeMaintenance: maintenance,
      maintenanceDeductedFromDeposit: maintenanceDeducted,
      sharing: sharingPrices,
    ),
    rooms: const [],
    amenities: PropertyAmenities(
      wifi: true,
      ac: false,
      laundry: false,
      foodIncluded: false,
      parking: false,
      geyser: false,
      powerBackup: false,
      cctv: false,
      housekeeping: false,
    ),
    rules: PropertyRules(
      genderAllowed: 'Co-ed',
      curfew: false,
      visitorsAllowed: true,
      smokingAllowed: false,
      alcoholAllowed: false,
      noticePeriodDays: 30,
    ),
    totals: PropertyTotals(
      rooms: rooms,
      beds: beds,
      availableBeds: availableBeds,
    ),
    images: images,
    rating: PropertyRating(average: 0, count: 0),
    status: status,
    businessId: businessId,
    businessName: 'Apex',
    businessPhone: '9000000000',
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    updatedAt: updatedAt ?? DateTime(2026, 1, 1),
  );
}
