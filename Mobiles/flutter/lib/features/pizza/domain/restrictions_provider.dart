import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/toast_service.dart';
import '../models/restrictions.dart';

/// Validation constants for pizza restrictions.
abstract class RestrictionLimits {
  static const int minCalories = 500;
  static const int minToppings = 1;
}

/// Provider for the current pizza restrictions/preferences.
/// This is shared state that both CustomizeSection (writes) and PizzaButton (reads) use.
final restrictionsProvider =
    NotifierProvider<RestrictionsNotifier, Restrictions>(
      RestrictionsNotifier.new,
    );

/// Notifier that manages the pizza restrictions state.
/// Includes validation logic that auto-corrects invalid values and shows toast messages.
class RestrictionsNotifier extends Notifier<Restrictions> {
  late ToastService _toast;

  @override
  Restrictions build() {
    _toast = ref.read(toastServiceProvider);
    return const Restrictions();
  }

  void setMaxCaloriesPerSlice(int value) {
    final minCalories = RestrictionLimits.minCalories;
    final adjusted = value < minCalories ? minCalories : value;

    if (adjusted != value) {
      _toast.warning('Minimum calories is $minCalories');
    }

    state = state.copyWith(maxCaloriesPerSlice: adjusted);
  }

  void setMustBeVegetarian(bool value) {
    state = state.copyWith(mustBeVegetarian: value);
  }

  void setMinNumberOfToppings(int value) {
    final minAllowed = RestrictionLimits.minToppings;

    // Ensure at least the minimum
    var min = value < minAllowed ? minAllowed : value;
    var max = state.maxNumberOfToppings;

    // If min > max, bump max up to match min
    if (min > max) {
      max = min;
      _toast.warning('Max toppings adjusted to $max to match minimum');
    } else if (min != value) {
      _toast.warning('Minimum toppings is $minAllowed');
    }

    state = state.copyWith(minNumberOfToppings: min, maxNumberOfToppings: max);
  }

  void setMaxNumberOfToppings(int value) {
    final minAllowed = RestrictionLimits.minToppings;

    // Ensure at least the minimum
    var max = value < minAllowed ? minAllowed : value;
    var min = state.minNumberOfToppings;

    // If max < min, reduce min down to match max
    if (max < min) {
      min = max;
      _toast.warning('Min toppings adjusted to $min to match maximum');
    } else if (max != value) {
      _toast.warning('Minimum toppings is $minAllowed');
    }

    state = state.copyWith(minNumberOfToppings: min, maxNumberOfToppings: max);
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
    state = const Restrictions();
  }
}
