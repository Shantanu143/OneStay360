enum Meal {
  breakfast,
  lunch,
  dinner;

  String get displayName {
    switch (this) {
      case Meal.breakfast:
        return 'Breakfast';
      case Meal.lunch:
        return 'Lunch';
      case Meal.dinner:
        return 'Dinner';
    }
  }

  String get abbreviation {
    switch (this) {
      case Meal.breakfast:
        return 'B';
      case Meal.lunch:
        return 'L';
      case Meal.dinner:
        return 'D';
    }
  }
}
