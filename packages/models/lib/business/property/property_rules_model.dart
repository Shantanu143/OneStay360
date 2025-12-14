class PropertyRules {
  final String genderAllowed;
  final bool curfew;
  final bool visitorsAllowed;
  final bool smokingAllowed;
  final bool alcoholAllowed;
  final int noticePeriodDays;

  PropertyRules({
    required this.genderAllowed,
    required this.curfew,
    required this.visitorsAllowed,
    required this.smokingAllowed,
    required this.alcoholAllowed,
    required this.noticePeriodDays,
  });

  factory PropertyRules.fromMap(Map<String, dynamic> map) {
    return PropertyRules(
      genderAllowed: map['genderAllowed'] ?? 'Co-ed',
      curfew: map['curfew'] ?? false,
      visitorsAllowed: map['visitorsAllowed'] ?? false,
      smokingAllowed: map['smokingAllowed'] ?? false,
      alcoholAllowed: map['alcoholAllowed'] ?? false,
      noticePeriodDays: map['noticePeriodDays'] ?? 30,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'genderAllowed': genderAllowed,
      'curfew': curfew,
      'visitorsAllowed': visitorsAllowed,
      'smokingAllowed': smokingAllowed,
      'alcoholAllowed': alcoholAllowed,
      'noticePeriodDays': noticePeriodDays,
    };
  }
}
