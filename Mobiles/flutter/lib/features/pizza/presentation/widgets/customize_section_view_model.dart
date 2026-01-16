import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pizza_provider.dart';
import '../../domain/restrictions_provider.dart';
import '../../models/restrictions.dart';

class CustomizeSectionUiState extends Equatable {
  const CustomizeSectionUiState({
    required this.restrictions,
    required this.tools,
  });

  final Restrictions restrictions;
  final List<String> tools;

  @override
  List<Object?> get props => [restrictions, tools];
}

abstract interface class CustomizeSectionActions {
  /// Sets the maximum calories per slice.
  void setMaxCaloriesPerSlice(int value);

  /// Sets the minimum number of toppings.
  void setMinNumberOfToppings(int value);

  /// Sets the maximum number of toppings.
  void setMaxNumberOfToppings(int value);

  /// Sets whether pizza must be vegetarian.
  void setMustBeVegetarian(bool value);

  /// Toggles a tool in the excluded tools list.
  void toggleExcludedTool(String tool);

  /// Sets a custom name for the pizza.
  void setCustomName(String value);
}

class _CustomizeSectionViewModel extends Notifier<CustomizeSectionUiState>
    implements CustomizeSectionActions {
  late RestrictionsNotifier _restrictionsNotifier;

  @override
  CustomizeSectionUiState build() {
    // Initialize dependencies
    _restrictionsNotifier = ref.read(restrictionsProvider.notifier);

    // Watch state providers (triggers rebuild when these change)
    final restrictions = ref.watch(restrictionsProvider);
    final toolsAsync = ref.watch(toolsProvider);

    // Resolve async tools to a simple list (empty if loading/error)
    final tools = toolsAsync.maybeWhen(
      data: (data) => data,
      orElse: () => <String>[],
    );

    return CustomizeSectionUiState(restrictions: restrictions, tools: tools);
  }

  // ---------------------------------------------------------------------------
  // Actions Implementation
  // ---------------------------------------------------------------------------

  @override
  void setMaxCaloriesPerSlice(int value) {
    _restrictionsNotifier.setMaxCaloriesPerSlice(value);
  }

  @override
  void setMinNumberOfToppings(int value) {
    _restrictionsNotifier.setMinNumberOfToppings(value);
  }

  @override
  void setMaxNumberOfToppings(int value) {
    _restrictionsNotifier.setMaxNumberOfToppings(value);
  }

  @override
  void setMustBeVegetarian(bool value) {
    _restrictionsNotifier.setMustBeVegetarian(value);
  }

  @override
  void toggleExcludedTool(String tool) {
    _restrictionsNotifier.toggleExcludedTool(tool);
  }

  @override
  void setCustomName(String value) {
    _restrictionsNotifier.setCustomName(value);
  }
}

// =============================================================================
// Providers
// =============================================================================

final _customizeSectionViewModelProvider =
    NotifierProvider<_CustomizeSectionViewModel, CustomizeSectionUiState>(
      _CustomizeSectionViewModel.new,
    );

final customizeSectionUiStateProvider = Provider<CustomizeSectionUiState>((
  ref,
) {
  return ref.watch(_customizeSectionViewModelProvider);
});

final customizeSectionActionsProvider = Provider<CustomizeSectionActions>((
  ref,
) {
  return ref.read(_customizeSectionViewModelProvider.notifier);
});
