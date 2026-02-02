import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations_provider.dart';
import '../../domain/pizza_provider.dart';
import '../../domain/restrictions_provider.dart';

/// Self-contained pizza button that handles its own state and actions.
/// Reads restrictions from restrictionsProvider and triggers getPizza directly.
class PizzaButton extends ConsumerWidget {
  const PizzaButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      pizzaStateProvider.select((state) => state.isLoading),
    );
    final l10n = ref.watch(appLocalizationsProvider);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : () {
                final restrictions = ref.read(restrictionsProvider);
                ref.read(pizzaStateProvider.notifier).getPizza(restrictions);
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_pizza, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    l10n.pizzaPleaseButton,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
