import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'property_pricing_model.dart';
import 'property_room_model.dart';
import 'property_amenities_model.dart';
import 'property_food_plan_model.dart';
import 'property_rules_model.dart';
import 'property_totals_model.dart';
import 'property_rating_model.dart';

class Property {
  final String? id;
  final String name;
  final String address;
  final String city;
  final String cityCode;
  final String pincode; // NEW
  final int numberOfFloors;
  final String description;
  final String landmarks;
  final String googleMapsLink;
  final PropertyPricing pricing;
  final List<PropertyRoom> rooms;
  final PropertyAmenities amenities;
  final PropertyFoodPlan? foodPlan;
  final PropertyRules rules;
  final PropertyTotals totals;
  final List<String>? images;
  final PropertyRating rating;
  final String status;
  final String billingStatus; // paid | payment_due | trial
  final int pricePerBed; // INR per active bed per month
  final int totalBeds;
  final int activeBedCount;
  final int billedBedCount;
  final DateTime? billingStartDate;
  final DateTime? nextBillingDate;
  final String? lastPaymentId;
  final String? couponCode;
  final double? couponDiscountPercent;
  final Map<String, dynamic>? plan;
  final String businessId;
  final String businessName;
  final String businessPhone;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool featured;

  Property({
    this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.cityCode,
    this.pincode = '', // NEW (default empty for backward compatibility)
    required this.numberOfFloors,
    required this.description,
    required this.landmarks,
    required this.googleMapsLink,
    required this.pricing,
    required this.rooms,
    required this.amenities,
    this.foodPlan,
    required this.rules,
    required this.totals,
    this.images,
    required this.rating,
    required this.status,
    this.billingStatus = 'payment_due',
    this.pricePerBed = 30,
    this.totalBeds = 0,
    this.activeBedCount = 0,
    this.billedBedCount = 0,
    this.billingStartDate,
    this.nextBillingDate,
    this.lastPaymentId,
    this.couponCode,
    this.couponDiscountPercent,
    this.plan,
    required this.businessId,
    required this.businessName,
    required this.businessPhone,
    required this.createdAt,
    required this.updatedAt,
    this.featured = false,
  });

  // copyWith updated to include pincode
  Property copyWith({
    String? id,
    String? name,
    String? address,
    String? city,
    String? cityCode,
    String? pincode,
    int? numberOfFloors,
    String? description,
    String? landmarks,
    String? googleMapsLink,
    PropertyPricing? pricing,
    List<PropertyRoom>? rooms,
    PropertyAmenities? amenities,
    PropertyFoodPlan? foodPlan,
    PropertyRules? rules,
    PropertyTotals? totals,
    List<String>? images,
    PropertyRating? rating,
    String? status,
    String? billingStatus,
    int? pricePerBed,
    int? totalBeds,
    int? activeBedCount,
    int? billedBedCount,
    DateTime? billingStartDate,
    DateTime? nextBillingDate,
    String? lastPaymentId,
    String? couponCode,
    double? couponDiscountPercent,
    Map<String, dynamic>? plan,
    String? businessId,
    String? businessName,
    String? businessPhone,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? featured,
  }) {
    return Property(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      cityCode: cityCode ?? this.cityCode,
      pincode: pincode ?? this.pincode,
      numberOfFloors: numberOfFloors ?? this.numberOfFloors,
      description: description ?? this.description,
      landmarks: landmarks ?? this.landmarks,
      googleMapsLink: googleMapsLink ?? this.googleMapsLink,
      pricing: pricing ?? this.pricing,
      rooms: rooms ?? this.rooms,
      amenities: amenities ?? this.amenities,
      foodPlan: foodPlan ?? this.foodPlan,
      rules: rules ?? this.rules,
      totals: totals ?? this.totals,
      images: images ?? this.images,
      rating: rating ?? this.rating,
      status: status ?? this.status,
      billingStatus: billingStatus ?? this.billingStatus,
      pricePerBed: pricePerBed ?? this.pricePerBed,
      totalBeds: totalBeds ?? this.totalBeds,
      activeBedCount: activeBedCount ?? this.activeBedCount,
      billedBedCount: billedBedCount ?? this.billedBedCount,
      billingStartDate: billingStartDate ?? this.billingStartDate,
      nextBillingDate: nextBillingDate ?? this.nextBillingDate,
      lastPaymentId: lastPaymentId ?? this.lastPaymentId,
      couponCode: couponCode ?? this.couponCode,
      couponDiscountPercent: couponDiscountPercent ?? this.couponDiscountPercent,
      plan: plan ?? this.plan,
      businessId: businessId ?? this.businessId,
      businessName: businessName ?? this.businessName,
      businessPhone: businessPhone ?? this.businessPhone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      featured: featured ?? this.featured,
    );
  }

  factory Property.fromMap(Map<String, dynamic> map, String id) {
    debugPrint('Parsing property with id: $id');

    return Property(
      id: id,
      name: map['name']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      cityCode: map['cityCode']?.toString() ?? '',
      pincode: map['pincode']?.toString() ?? '', // NEW
      numberOfFloors: (map['numberOfFloors'] as num?)?.toInt() ?? 0,
      description: map['description']?.toString() ?? '',
      landmarks: map['landmarks']?.toString() ?? '',
      googleMapsLink: map['googleMapsLink']?.toString() ?? '',
      pricing: PropertyPricing.fromMap(Map<String, dynamic>.from(map['pricing'] ?? {})),
      rooms: List<PropertyRoom>.from(
        (map['rooms'] as List? ?? []).map((x) => PropertyRoom.fromMap(Map<String, dynamic>.from(x))),
      ),
      amenities: PropertyAmenities.fromMap(Map<String, dynamic>.from(map['amenities'] ?? {})),
      foodPlan: map['foodPlan'] != null
          ? PropertyFoodPlan.fromMap(Map<String, dynamic>.from(map['foodPlan']))
          : null,
      rules: PropertyRules.fromMap(Map<String, dynamic>.from(map['rules'] ?? {})),
      totals: PropertyTotals.fromMap(Map<String, dynamic>.from(map['totals'] ?? {})),
      images: _parseImages(map['images']),
      rating: PropertyRating.fromMap(Map<String, dynamic>.from(map['rating'] ?? {})),
      status: map['status']?.toString() ?? 'active',
      billingStatus: map['billingStatus']?.toString() ?? 'payment_due',
      pricePerBed: (map['pricePerBed'] as num?)?.toInt() ?? 30,
      totalBeds: (map['totalBeds'] as num?)?.toInt() ?? (map['rooms'] is List ? (map['rooms'] as List).length : 0),
      activeBedCount: (map['activeBedCount'] as num?)?.toInt() ?? ((map['rooms'] as List?)?.where((room) => (room is Map) && ((room['isActive'] ?? false) == true)).length ?? 0),
      billedBedCount: (map['billedBedCount'] as num?)?.toInt() ?? ((map['activeBedCount'] as num?)?.toInt() ?? 0),
      billingStartDate: (map['billingStartDate'] as Timestamp?)?.toDate(),
      nextBillingDate: (map['nextBillingDate'] as Timestamp?)?.toDate(),
      lastPaymentId: map['lastPaymentId']?.toString(),
      couponCode: map['couponCode']?.toString(),
      couponDiscountPercent: (map['couponDiscountPercent'] as num?)?.toDouble(),
        plan: map['plan'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(map['plan'] as Map)
          : null,
      businessId: map['businessId']?.toString() ?? '',
      businessName: map['businessName']?.toString() ?? '',
      businessPhone: map['businessPhone']?.toString() ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      featured: map['featured'] as bool? ?? false,
    );
  }

  static List<String>? _parseImages(dynamic imagesData) {
    if (imagesData == null) return null;
    try {
      if (imagesData is List) {
        return imagesData.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      }
      return [imagesData.toString()];
    } catch (e) {
      debugPrint('Error parsing images: $e');
      return null;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'city': city,
      'cityCode': cityCode,
      'pincode': pincode, // NEW
      'numberOfFloors': numberOfFloors,
      'description': description,
      'landmarks': landmarks,
      'googleMapsLink': googleMapsLink,
      'pricing': pricing.toMap(),
      'rooms': rooms.map((x) => x.toMap()).toList(),
      'amenities': amenities.toMap(),
      'foodPlan': foodPlan?.toMap(),
      'rules': rules.toMap(),
      'totals': totals.toMap(),
      'images': images,
      'rating': rating.toMap(),
      'status': status,
      'billingStatus': billingStatus,
      'pricePerBed': pricePerBed,
      'totalBeds': totalBeds,
      'activeBedCount': activeBedCount,
      'billedBedCount': billedBedCount,
      'billingStartDate': billingStartDate != null ? Timestamp.fromDate(billingStartDate!) : null,
      'nextBillingDate': nextBillingDate != null ? Timestamp.fromDate(nextBillingDate!) : null,
      'lastPaymentId': lastPaymentId,
      'couponCode': couponCode,
      'couponDiscountPercent': couponDiscountPercent,
      if (plan != null) 'plan': plan,
      'businessId': businessId,
      'businessName': businessName,
      'businessPhone': businessPhone,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'featured': featured,
    };
  }

  @override
  String toString() {
    return 'Property(id: $id, name: $name, city: $city, pincode: $pincode)';
  }
}

