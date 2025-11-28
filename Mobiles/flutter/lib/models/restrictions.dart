class Restrictions {
  int maxCaloriesPerSlice;
  bool mustBeVegetarian;
  List<String> excludedIngredients;
  List<String> excludedTools;
  int maxNumberOfToppings;
  int minNumberOfToppings;
  String customName;

  Restrictions({
    this.maxCaloriesPerSlice = 1000,
    this.mustBeVegetarian = false,
    this.excludedIngredients = const [],
    this.excludedTools = const [],
    this.maxNumberOfToppings = 5,
    this.minNumberOfToppings = 2,
    this.customName = '',
  });

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
}

