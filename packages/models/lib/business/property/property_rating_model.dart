class PropertyRating {
  final double average;
  final int count;

  PropertyRating({
    required this.average,
    required this.count,
  });

  factory PropertyRating.fromMap(Map<String, dynamic> map) {
    return PropertyRating(
      average: (map['average'] ?? 0).toDouble(),
      count: map['count'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'average': average,
      'count': count,
    };
  }
}
