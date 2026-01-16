import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations_provider.dart';
import 'customize_section_view_model.dart';

/// Self-contained widget that allows users to customize their pizza preferences.
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
    final uiState = ref.watch(customizeSectionUiStateProvider);
    final actions = ref.read(customizeSectionActionsProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _Header(
            title: l10n.customizeYourPizza,
            isExpanded: _expanded,
            onTap: _toggleExpand,
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
                      _NumberField(
                        label: l10n.maxCalories,
                        value: uiState.restrictions.maxCaloriesPerSlice,
                        onChanged: actions.setMaxCaloriesPerSlice,
                      ),
                      const SizedBox(width: 12),
                      _NumberField(
                        label: l10n.minToppings,
                        value: uiState.restrictions.minNumberOfToppings,
                        onChanged: actions.setMinNumberOfToppings,
                      ),
                      const SizedBox(width: 12),
                      _NumberField(
                        label: l10n.maxToppings,
                        value: uiState.restrictions.maxNumberOfToppings,
                        onChanged: actions.setMaxNumberOfToppings,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _VegetarianToggle(
                    label: l10n.vegetarianOnly,
                    value: uiState.restrictions.mustBeVegetarian,
                    onChanged: actions.setMustBeVegetarian,
                  ),
                  const SizedBox(height: 16),

                  // Excluded Tools - only shown when not empty
                  if (uiState.tools.isNotEmpty)
                    _ExcludedToolsSection(
                      label: l10n.excludeTools,
                      tools: uiState.tools,
                      excludedTools: uiState.restrictions.excludedTools,
                      onToggle: actions.toggleExcludedTool,
                    ),

                  // Custom Name
                  _CustomNameField(
                    label: l10n.customPizzaName,
                    onChanged: actions.setCustomName,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Private widget for the custom pizza name text field.
class _CustomNameField extends StatelessWidget {
  const _CustomNameField({required this.label, required this.onChanged});

  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
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
      onChanged: onChanged,
    );
  }
}

/// Private widget for the excluded tools section with filter chips.
class _ExcludedToolsSection extends StatelessWidget {
  const _ExcludedToolsSection({
    required this.label,
    required this.tools,
    required this.excludedTools,
    required this.onToggle,
  });

  final String label;
  final List<String> tools;
  final List<String> excludedTools;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tools.map((tool) {
            final isSelected = excludedTools.contains(tool);
            return FilterChip(
              label: Text(tool),
              selected: isSelected,
              onSelected: (_) => onToggle(tool),
              selectedColor: Colors.red.shade100,
              checkmarkColor: Colors.red.shade700,
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Private widget for the vegetarian toggle.
class _VegetarianToggle extends StatelessWidget {
  const _VegetarianToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: value ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value ? Colors.green.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.eco,
            color: value ? Colors.green.shade600 : Colors.grey.shade400,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: Colors.green,
          ),
        ],
      ),
    );
  }
}

/// Private widget for the expandable header row.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.isExpanded,
    required this.onTap,
  });

  final String title;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
              child: Icon(Icons.tune, color: Colors.orange.shade600, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 300),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Private widget for number input fields in the customize section.
/// Wraps itself in [Expanded] for use in a [Row].
class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextField(
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
      ),
    );
  }
}
