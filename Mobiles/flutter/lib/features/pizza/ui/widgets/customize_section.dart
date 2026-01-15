import 'package:flutter/material.dart';

import '../../models/restrictions.dart';

class CustomizeSection extends StatefulWidget {
  const CustomizeSection({
    super.key,
    required this.restrictions,
    required this.tools,
    required this.onRestrictionsChanged,
  });

  final Restrictions restrictions;
  final List<String> tools;
  final VoidCallback onRestrictionsChanged;

  @override
  State<CustomizeSection> createState() => _CustomizeSectionState();
}

class _CustomizeSectionState extends State<CustomizeSection>
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
                  const Expanded(
                    child: Text(
                      'Customize Your Pizza',
                      style: TextStyle(
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
                          label: 'Max Calories',
                          value: widget.restrictions.maxCaloriesPerSlice,
                          onChanged: (v) {
                            widget.restrictions.maxCaloriesPerSlice = v;
                            widget.onRestrictionsChanged();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildNumberField(
                          label: 'Min Toppings',
                          value: widget.restrictions.minNumberOfToppings,
                          onChanged: (v) {
                            widget.restrictions.minNumberOfToppings = v;
                            widget.onRestrictionsChanged();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildNumberField(
                          label: 'Max Toppings',
                          value: widget.restrictions.maxNumberOfToppings,
                          onChanged: (v) {
                            widget.restrictions.maxNumberOfToppings = v;
                            widget.onRestrictionsChanged();
                          },
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
                      color: widget.restrictions.mustBeVegetarian
                          ? Colors.green.shade50
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.restrictions.mustBeVegetarian
                            ? Colors.green.shade200
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.eco,
                          color: widget.restrictions.mustBeVegetarian
                              ? Colors.green.shade600
                              : Colors.grey.shade400,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Vegetarian only',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        Switch(
                          value: widget.restrictions.mustBeVegetarian,
                          onChanged: (value) {
                            setState(() {
                              widget.restrictions.mustBeVegetarian = value;
                            });
                            widget.onRestrictionsChanged();
                          },
                          activeColor: Colors.green,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Excluded Tools
                  if (widget.tools.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Exclude tools:',
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
                      children: widget.tools.map((tool) {
                        final isSelected =
                            widget.restrictions.excludedTools.contains(tool);
                        return FilterChip(
                          label: Text(tool),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                widget.restrictions.excludedTools.add(tool);
                              } else {
                                widget.restrictions.excludedTools.remove(tool);
                              }
                            });
                            widget.onRestrictionsChanged();
                          },
                          selectedColor: Colors.red.shade100,
                          checkmarkColor: Colors.red.shade700,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Custom Name
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Custom Pizza Name (optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      widget.restrictions.customName = value;
                      widget.onRestrictionsChanged();
                    },
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
