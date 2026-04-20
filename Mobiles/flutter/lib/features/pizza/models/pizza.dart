import 'package:equatable/equatable.dart';

class Pizza extends Equatable {
  final int id;
  final String name;
  final Dough dough;
  final List<Ingredient> ingredients;
  final String tool;

  const Pizza({
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

  /// Parses the upcoming v2 schema. v2 renamed `name` -> `displayName`
  /// and `tool` -> `tooling`. The rest of the shape is unchanged.
  factory Pizza.fromJsonV2(Map<String, dynamic> json) {
    return Pizza(
      id: json['id'] as int,
      name: json['displayName'] as String,
      dough: Dough.fromJson(json['dough'] as Map<String, dynamic>),
      ingredients: (json['ingredients'] as List)
          .map((i) => Ingredient.fromJson(i as Map<String, dynamic>))
          .toList(),
      tool: json['tooling'] as String,
    );
  }

  @override
  List<Object?> get props => [id, name, dough, ingredients, tool];
}

class Dough extends Equatable {
  final int id;
  final String name;
  final int? caloriesPerSlice;

  const Dough({required this.id, required this.name, this.caloriesPerSlice});

  factory Dough.fromJson(Map<String, dynamic> json) {
    // Handle both "ID" (uppercase) and "id" (lowercase) for compatibility
    final idValue = json['ID'] ?? json['id'];
    return Dough(
      id: idValue as int,
      name: json['name'] as String,
      caloriesPerSlice: json['caloriesPerSlice'] as int?,
    );
  }

  @override
  List<Object?> get props => [id, name, caloriesPerSlice];
}

class Ingredient extends Equatable {
  final int id;
  final String name;
  final int? caloriesPerSlice;
  final bool? vegetarian;

  const Ingredient({
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

  @override
  List<Object?> get props => [id, name, caloriesPerSlice, vegetarian];
}

class PizzaRecommendation extends Equatable {
  final Pizza pizza;
  final int? calories;
  final bool? vegetarian;

  const PizzaRecommendation({
    required this.pizza,
    this.calories,
    this.vegetarian,
  });

  factory PizzaRecommendation.fromJson(Map<String, dynamic> json) {
    return PizzaRecommendation(
      pizza: Pizza.fromJson(json['pizza'] as Map<String, dynamic>),
      calories: json['calories'] as int?,
      vegetarian: json['vegetarian'] as bool?,
    );
  }

  /// Parses the upcoming v2 response schema. The wrapper keeps its
  /// `pizza` field; the inner [Pizza] is parsed with [Pizza.fromJsonV2].
  factory PizzaRecommendation.fromJsonV2(Map<String, dynamic> json) {
    return PizzaRecommendation(
      pizza: Pizza.fromJsonV2(json['pizza'] as Map<String, dynamic>),
      calories: json['calories'] as int?,
      vegetarian: json['vegetarian'] as bool?,
    );
  }

  @override
  List<Object?> get props => [pizza, calories, vegetarian];
}
