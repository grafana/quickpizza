import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations_provider.dart';
import '../../models/pizza.dart';
import 'rating_buttons.dart';

class PizzaCard extends ConsumerWidget {
  const PizzaCard({super.key, required this.recommendation});

  final PizzaRecommendation recommendation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appLocalizationsProvider);
    final pizza = recommendation.pizza;

    return Column(
      children: [
        const SizedBox(height: 24),

        // Pizza Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PizzaHeader(title: pizza.name, subtitle: l10n.ourRecommendation),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // Details
              _PizzaDetailRow(
                icon: Icons.layers,
                label: l10n.dough,
                value: pizza.dough.name,
              ),
              const SizedBox(height: 8),
              _PizzaDetailRow(
                icon: Icons.restaurant,
                label: l10n.tool,
                value: pizza.tool,
              ),
              const SizedBox(height: 8),
              _PizzaDetailRow(
                icon: Icons.local_fire_department,
                label: l10n.calories,
                value: l10n.caloriesPerSlice(
                  recommendation.calories?.toString() ?? l10n.notAvailable,
                ),
              ),
              const SizedBox(height: 12),

              if (recommendation.vegetarian == true)
                _VegetarianBadge(label: l10n.vegetarian),

              const SizedBox(height: 16),

              _IngredientsSection(
                label: l10n.ingredients,
                ingredients: pizza.ingredients,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        RatingButtons(pizza: recommendation),
      ],
    );
  }
}

class _IngredientsSection extends StatelessWidget {
  const _IngredientsSection({required this.label, required this.ingredients});

  final String label;
  final List<Ingredient> ingredients;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: ingredients.map((ingredient) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                ingredient.name,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _VegetarianBadge extends StatelessWidget {
  const _VegetarianBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.eco, size: 16, color: Colors.green.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.green.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PizzaHeader extends StatelessWidget {
  const _PizzaHeader({required this.subtitle, required this.title});

  final String subtitle;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.local_pizza, color: Colors.orange, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PizzaDetailRow extends StatelessWidget {
  const _PizzaDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
