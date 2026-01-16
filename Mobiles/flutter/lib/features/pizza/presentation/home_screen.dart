import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/quick_pizza_app_bar.dart';
import 'home_screen_view_model.dart';
import 'widgets/customize_section.dart';
import 'widgets/hero_text.dart';
import 'widgets/pizza_button.dart';
import 'widgets/pizza_card.dart';
import 'widgets/quote_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(homeScreenUiStateProvider);
    final actions = ref.read(homeScreenActionsProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: const QuickPizzaAppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Quote Card
              const QuoteCard(),
              const SizedBox(height: 24),

              // Hero Text
              const HeroText(),
              const SizedBox(height: 24),

              const CustomizeSection(),
              const SizedBox(height: 24),

              const PizzaButton(),

              // Error Message
              if (uiState.pizzaState.errorMessage != null)
                _buildErrorMessage(uiState.pizzaState.errorMessage!),

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
