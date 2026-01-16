import 'package:flutter/material.dart';
import 'package:flutter_mobile_o11y_demo/core/localization/app_localizations_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/quick_pizza_app_bar.dart';
import '../models/restrictions.dart';
import 'home_screen_view_model.dart';
import 'widgets/customize_section.dart';
import 'widgets/hero_text.dart';
import 'widgets/pizza_card.dart';
import 'widgets/quote_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Restrictions _restrictions = Restrictions();

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(homeScreenUiStateProvider);
    final actions = ref.read(homeScreenActionsProvider);
    final l10n = ref.watch(appLocalizationsProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: const QuickPizzaAppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Quote Card
              uiState.quoteAsync.when(
                data: (quote) => QuoteCard(quote: quote),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),

              // Hero Text
              const HeroText(),
              const SizedBox(height: 24),

              // Customize Card (Expandable)
              uiState.toolsAsync.when(
                data: (tools) => CustomizeSection(
                  restrictions: _restrictions,
                  tools: tools,
                  onRestrictionsChanged: () => setState(() {}),
                ),
                loading: () => CustomizeSection(
                  restrictions: _restrictions,
                  tools: const [],
                  onRestrictionsChanged: () => setState(() {}),
                ),
                error: (_, _) => CustomizeSection(
                  restrictions: _restrictions,
                  tools: const [],
                  onRestrictionsChanged: () => setState(() {}),
                ),
              ),
              const SizedBox(height: 24),

              // Pizza Please Button
              _buildPizzaButton(
                isLoading: uiState.pizzaState.isLoading,
                buttonText: l10n.pizzaPleaseButton,
                onPressed: () => actions.getPizza(_restrictions),
              ),

              // Error Message
              if (uiState.pizzaState.errorMessage != null)
                _buildErrorMessage(uiState.pizzaState.errorMessage!),

              // Pizza Recommendation
              if (uiState.pizzaState.pizza != null)
                PizzaCard(
                  recommendation: uiState.pizzaState.pizza!,
                  onRate: actions.ratePizza,
                  rateResult: uiState.pizzaState.rateResult,
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPizzaButton({
    required bool isLoading,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
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
                    buttonText,
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

  Widget _buildErrorMessage(String message) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
