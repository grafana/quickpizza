import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations_provider.dart';
import '../../domain/pizza_provider.dart';
import '../../domain/restrictions_provider.dart';

/// Self-contained widget that allows users to customize their pizza preferences.
/// Watches toolsProvider and restrictionsProvider directly.
class CustomizeSection extends ConsumerStatefulWidget {
  const CustomizeSection({super.key});

  @override
  ConsumerState<CustomizeSection> createState() => _CustomizeSectionState();
}

class _CustomizeSectionState extends ConsumerState<CustomizeSection>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocalizationsProvider);
    final restrictions = ref.watch(restrictionsProvider);
    final restrictionsNotifier = ref.read(restrictionsProvider.notifier);
    final toolsAsync = ref.watch(toolsProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header (always visible)
          InkWell(
            onTap: _toggleExpand,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.tune,
                      color: Colors.orange.shade600,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.customizeYourPizza,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable Content
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(),
                  const SizedBox(height: 12),

                  // Calories and Toppings Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildNumberField(
                          label: l10n.maxCalories,
                          value: restrictions.maxCaloriesPerSlice,
                          onChanged:
                              restrictionsNotifier.setMaxCaloriesPerSlice,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildNumberField(
                          label: l10n.minToppings,
                          value: restrictions.minNumberOfToppings,
                          onChanged:
                              restrictionsNotifier.setMinNumberOfToppings,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildNumberField(
                          label: l10n.maxToppings,
                          value: restrictions.maxNumberOfToppings,
                          onChanged:
                              restrictionsNotifier.setMaxNumberOfToppings,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Vegetarian Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: restrictions.mustBeVegetarian
                          ? Colors.green.shade50
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: restrictions.mustBeVegetarian
                            ? Colors.green.shade200
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.eco,
                          color: restrictions.mustBeVegetarian
                              ? Colors.green.shade600
                              : Colors.grey.shade400,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.vegetarianOnly,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Switch(
                          value: restrictions.mustBeVegetarian,
                          onChanged: restrictionsNotifier.setMustBeVegetarian,
                          activeColor: Colors.green,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Excluded Tools - only shown when loaded and not empty
                  ...toolsAsync.maybeWhen(
                    data: (tools) => tools.isEmpty
                        ? []
                        : [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                l10n.excludeTools,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: tools.map((tool) {
                                final isSelected = restrictions.excludedTools
                                    .contains(tool);
                                return FilterChip(
                                  label: Text(tool),
                                  selected: isSelected,
                                  onSelected: (_) {
                                    restrictionsNotifier.toggleExcludedTool(
                                      tool,
                                    );
                                  },
                                  selectedColor: Colors.red.shade100,
                                  checkmarkColor: Colors.red.shade700,
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                          ],
                    orElse: () => [],
                  ),

                  // Custom Name
                  TextField(
                    decoration: InputDecoration(
                      labelText: l10n.customPizzaName,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      isDense: true,
                    ),
                    onChanged: restrictionsNotifier.setCustomName,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required int value,
    required Function(int) onChanged,
  }) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      controller: TextEditingController(text: value.toString()),
      onChanged: (v) => onChanged(int.tryParse(v) ?? value),
    );
  }
}
