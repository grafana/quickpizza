import 'package:equatable/equatable.dart';

/// Immutable restrictions/preferences for pizza recommendations.
class Restrictions extends Equatable {
  final int maxCaloriesPerSlice;
  final bool mustBeVegetarian;
  final List<String> excludedIngredients;
  final List<String> excludedTools;
  final int maxNumberOfToppings;
  final int minNumberOfToppings;
  final String customName;

  const Restrictions({
    this.maxCaloriesPerSlice = 1000,
    this.mustBeVegetarian = false,
    this.excludedIngredients = const [],
    this.excludedTools = const [],
    this.maxNumberOfToppings = 5,
    this.minNumberOfToppings = 2,
    this.customName = '',
  });

  Restrictions copyWith({
    int? maxCaloriesPerSlice,
    bool? mustBeVegetarian,
    List<String>? excludedIngredients,
    List<String>? excludedTools,
    int? maxNumberOfToppings,
    int? minNumberOfToppings,
    String? customName,
  }) {
    return Restrictions(
      maxCaloriesPerSlice: maxCaloriesPerSlice ?? this.maxCaloriesPerSlice,
      mustBeVegetarian: mustBeVegetarian ?? this.mustBeVegetarian,
      excludedIngredients: excludedIngredients ?? this.excludedIngredients,
      excludedTools: excludedTools ?? this.excludedTools,
      maxNumberOfToppings: maxNumberOfToppings ?? this.maxNumberOfToppings,
      minNumberOfToppings: minNumberOfToppings ?? this.minNumberOfToppings,
      customName: customName ?? this.customName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maxCaloriesPerSlice': maxCaloriesPerSlice,
      'mustBeVegetarian': mustBeVegetarian,
      'excludedIngredients': excludedIngredients,
      'excludedTools': excludedTools,
      'maxNumberOfToppings': maxNumberOfToppings,
      'minNumberOfToppings': minNumberOfToppings,
      'customName': customName,
    };
  }

  @override
  List<Object?> get props => [
    maxCaloriesPerSlice,
    mustBeVegetarian,
    excludedIngredients,
    excludedTools,
    maxNumberOfToppings,
    minNumberOfToppings,
    customName,
  ];
}
