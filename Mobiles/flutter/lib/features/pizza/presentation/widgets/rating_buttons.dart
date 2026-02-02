import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations_provider.dart';
import '../../models/pizza.dart';
import 'rating_buttons_view_model.dart';

class RatingButtons extends ConsumerWidget {
  const RatingButtons({super.key, required this.pizza});

  final PizzaRecommendation pizza;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appLocalizationsProvider);
    final pizzaId = pizza.pizza.id;

    final uiState = ref.watch(ratingButtonsUiStateProvider(pizzaId));
    final actions = ref.read(ratingButtonsActionsProvider(pizzaId));

    return Column(
      children: [
        Row(
          children: [
            _RatingButton(
              icon: '👎',
              label: l10n.pass,
              isLoading: uiState.isLoading,
              isPrimary: false,
              onPressed: () => actions.ratePizza(stars: 1),
            ),
            const SizedBox(width: 16),
            _RatingButton(
              icon: '❤️',
              label: l10n.loveIt,
              isLoading: uiState.isLoading,
              isPrimary: true,
              onPressed: () => actions.ratePizza(stars: 5),
            ),
          ],
        ),
        if (uiState.rateResult != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              uiState.rateResult!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
      ],
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.icon,
    required this.label,
    required this.isLoading,
    required this.isPrimary,
    required this.onPressed,
  });

  final String icon;
  final String label;
  final bool isLoading;
  final bool isPrimary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: isPrimary
          ? ElevatedButton.icon(
              onPressed: isLoading ? null : onPressed,
              icon: Text(icon, style: const TextStyle(fontSize: 18)),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: isLoading ? null : onPressed,
              icon: Text(icon, style: const TextStyle(fontSize: 18)),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
    );
  }
}
