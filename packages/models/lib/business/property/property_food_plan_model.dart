class PropertyFoodPlan {
  final Map<String, dynamic> plan; // Changed from List<String> to dynamic
  final String notes;

  PropertyFoodPlan({
    required this.plan,
    required this.notes,
  });

  factory PropertyFoodPlan.fromMap(Map<String, dynamic> map) {
    return PropertyFoodPlan(
      plan: Map<String, dynamic>.from(map['plan'] ?? {}),
      notes: map['notes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'plan': plan,
      'notes': notes,
    };
  }
}
