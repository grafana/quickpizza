import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/restrictions.dart';

/// Provider for the current pizza restrictions/preferences.
/// This is shared state that both CustomizeSection (writes) and PizzaButton (reads) use.
final restrictionsProvider =
    NotifierProvider<RestrictionsNotifier, Restrictions>(
      RestrictionsNotifier.new,
    );

/// Notifier that manages the pizza restrictions state.
class RestrictionsNotifier extends Notifier<Restrictions> {
  @override
  Restrictions build() => Restrictions();

  void setMaxCaloriesPerSlice(int value) {
    state = state.copyWith(maxCaloriesPerSlice: value);
  }

  void setMustBeVegetarian(bool value) {
    state = state.copyWith(mustBeVegetarian: value);
  }

  void setMinNumberOfToppings(int value) {
    state = state.copyWith(minNumberOfToppings: value);
  }

  void setMaxNumberOfToppings(int value) {
    state = state.copyWith(maxNumberOfToppings: value);
  }

  void setCustomName(String value) {
    state = state.copyWith(customName: value);
  }

  void toggleExcludedTool(String tool) {
    final currentExcluded = List<String>.from(state.excludedTools);
    if (currentExcluded.contains(tool)) {
      currentExcluded.remove(tool);
    } else {
      currentExcluded.add(tool);
    }
    state = state.copyWith(excludedTools: currentExcluded);
  }

  void reset() {
    state = Restrictions();
  }
}
