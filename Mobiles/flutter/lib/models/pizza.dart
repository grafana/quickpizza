class Pizza {
  final int id;
  final String name;
  final Dough dough;
  final List<Ingredient> ingredients;
  final String tool;

  Pizza({
    required this.id,
    required this.name,
    required this.dough,
    required this.ingredients,
    required this.tool,
  });

  factory Pizza.fromJson(Map<String, dynamic> json) {
    return Pizza(
      id: json['id'] as int,
      name: json['name'] as String,
      dough: Dough.fromJson(json['dough'] as Map<String, dynamic>),
      ingredients: (json['ingredients'] as List)
          .map((i) => Ingredient.fromJson(i as Map<String, dynamic>))
          .toList(),
      tool: json['tool'] as String,
    );
  }
}

class Dough {
  final int id;
  final String name;
  final int? caloriesPerSlice;

  Dough({required this.id, required this.name, this.caloriesPerSlice});

  factory Dough.fromJson(Map<String, dynamic> json) {
    // Handle both "ID" (uppercase) and "id" (lowercase) for compatibility
    final idValue = json['ID'] ?? json['id'];
    return Dough(
      id: idValue as int,
      name: json['name'] as String,
      caloriesPerSlice: json['caloriesPerSlice'] as int?,
    );
  }
}

class Ingredient {
  final int id;
  final String name;
  final int? caloriesPerSlice;
  final bool? vegetarian;

  Ingredient({
    required this.id,
    required this.name,
    this.caloriesPerSlice,
    this.vegetarian,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    // Handle both "ID" (uppercase) and "id" (lowercase) for compatibility
    final idValue = json['ID'] ?? json['id'];
    return Ingredient(
      id: idValue as int,
      name: json['name'] as String,
      caloriesPerSlice: json['caloriesPerSlice'] as int?,
      vegetarian: json['vegetarian'] as bool?,
    );
  }
}

class PizzaRecommendation {
  final Pizza pizza;
  final int? calories;
  final bool? vegetarian;

  PizzaRecommendation({required this.pizza, this.calories, this.vegetarian});

  factory PizzaRecommendation.fromJson(Map<String, dynamic> json) {
    return PizzaRecommendation(
      pizza: Pizza.fromJson(json['pizza'] as Map<String, dynamic>),
      calories: json['calories'] as int?,
      vegetarian: json['vegetarian'] as bool?,
    );
  }
}
