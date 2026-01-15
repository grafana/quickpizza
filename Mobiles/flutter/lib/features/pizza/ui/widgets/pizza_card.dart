import 'package:flutter/material.dart';

import '../../models/pizza.dart';

class PizzaCard extends StatelessWidget {
  const PizzaCard({
    super.key,
    required this.recommendation,
    required this.onRate,
    this.rateResult,
  });

  final PizzaRecommendation recommendation;
  final void Function(int stars, String type) onRate;
  final String? rateResult;

  @override
  Widget build(BuildContext context) {
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
                color: Colors.orange.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with pizza icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_pizza,
                      color: Colors.orange,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Our Recommendation',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          pizza.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // Details
              _buildPizzaDetail(
                icon: Icons.layers,
                label: 'Dough',
                value: pizza.dough.name,
              ),
              const SizedBox(height: 8),
              _buildPizzaDetail(
                icon: Icons.restaurant,
                label: 'Tool',
                value: pizza.tool,
              ),
              const SizedBox(height: 8),
              _buildPizzaDetail(
                icon: Icons.local_fire_department,
                label: 'Calories',
                value: '${recommendation.calories ?? 'N/A'} per slice',
              ),
              const SizedBox(height: 12),

              // Vegetarian badge
              if (recommendation.vegetarian == true)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
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
                        'Vegetarian',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Ingredients
              const Text(
                'Ingredients',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: pizza.ingredients.map((ingredient) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      ingredient.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Rating Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onRate(1, 'pass'),
                icon: const Text('👎', style: TextStyle(fontSize: 18)),
                label: const Text('Pass'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => onRate(5, 'love'),
                icon: const Text('❤️', style: TextStyle(fontSize: 18)),
                label: const Text('Love it!'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),

        // Rate Result
        if (rateResult != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              rateResult!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: rateResult!.contains('❤️')
                    ? Colors.red.shade600
                    : Colors.grey.shade600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPizzaDetail({
    required IconData icon,
    required String label,
    required String value,
  }) {
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
