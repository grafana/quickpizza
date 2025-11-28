class Pizza {
  final int id;
  final String name;
  final Dough dough;
  final List<Ingredient> ingredients;
  final String tool;
  final int calories;

  Pizza({
    required this.id,
    required this.name,
    required this.dough,
    required this.ingredients,
    required this.tool,
    required this.calories,
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
      calories: json['calories'] as int? ?? 0,
    );
  }
}

class Dough {
  final int id;
  final String name;

  Dough({required this.id, required this.name});

  factory Dough.fromJson(Map<String, dynamic> json) {
    return Dough(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

class Ingredient {
  final int id;
  final String name;

  Ingredient({required this.id, required this.name});

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

class PizzaRecommendation {
  final Pizza pizza;
  final int calories;

  PizzaRecommendation({
    required this.pizza,
    required this.calories,
  });

  factory PizzaRecommendation.fromJson(Map<String, dynamic> json) {
    return PizzaRecommendation(
      pizza: Pizza.fromJson(json['pizza'] as Map<String, dynamic>),
      calories: json['calories'] as int? ?? 0,
    );
  }
}

