import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/app_localizations_provider.dart';
import '../../../../core/o11y/errors/o11y_errors.dart';
import '../../../ratings/domain/ratings_provider.dart';

class RatingButtonsUiState {
  const RatingButtonsUiState({this.rateResult, this.isLoading = false});

  final String? rateResult;
  final bool isLoading;
}

abstract interface class RatingButtonsActions {
  Future<void> ratePizza({required int stars});
}

final ratingButtonsUiStateProvider =
    NotifierProvider.family<RatingButtonsViewModel, RatingButtonsUiState, int>(
      RatingButtonsViewModel.new,
    );

final ratingButtonsActionsProvider = Provider.family<RatingButtonsActions, int>(
  (ref, pizzaId) {
    return ref.watch(ratingButtonsUiStateProvider(pizzaId).notifier);
  },
);

class RatingButtonsViewModel extends Notifier<RatingButtonsUiState>
    implements RatingButtonsActions {
  RatingButtonsViewModel(this.pizzaId);

  final int pizzaId;

  late RatingsNotifier _ratingsNotifier;
  late AppLocalizations _l10n;
  late O11yErrors _o11yErrors;

  @override
  RatingButtonsUiState build() {
    _ratingsNotifier = ref.watch(ratingsProvider.notifier);
    _l10n = ref.watch(appLocalizationsProvider);
    _o11yErrors = ref.watch(o11yErrorsProvider);

    return const RatingButtonsUiState();
  }

  @override
  Future<void> ratePizza({required int stars}) async {
    state = const RatingButtonsUiState(isLoading: true);

    try {
      final success = await _ratingsNotifier.ratePizza(
        pizzaId: pizzaId,
        stars: stars,
      );
      final resultMessage = success ? _l10n.thanksFeedback : _l10n.pleaseLoginFirst;

      state = RatingButtonsUiState(rateResult: resultMessage);
    } catch (error, stackTrace) {
      final errorStr = error.toString();
      final message = errorStr.startsWith('Exception: ')
          ? errorStr.substring(10)
          : errorStr;

      state = RatingButtonsUiState(rateResult: message);

      _o11yErrors.reportError(
        type: 'UI',
        error: 'Failed to rate pizza: $error',
        stacktrace: stackTrace,
        context: {
          'widget': 'RatingButtons',
          'action': 'ratePizza',
          'pizza_id': pizzaId.toString(),
        },
      );
    }
  }
}
