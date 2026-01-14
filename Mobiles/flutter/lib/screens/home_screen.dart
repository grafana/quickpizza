import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/application_layer/o11y/events/o11y_events.dart';
import '../core/application_layer/o11y/errors/o11y_errors.dart';
import '../core/application_layer/o11y/loggers/o11y_logger.dart';
import '../core/application_layer/o11y/metrics/o11y_metrics.dart';
import '../models/pizza.dart';
import '../models/restrictions.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final ApiService apiService;

  const HomeScreen({super.key, required this.apiService});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  String _quote = '';
  PizzaRecommendation? _pizza;
  bool _isLoading = false;
  String? _errorMessage;
  String? _rateResult;
  bool _customizeExpanded = false;
  Restrictions _restrictions = Restrictions();
  List<String> _tools = [];
  bool _isLoggedIn = false;
  String? _username;

  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  O11yEvents get _o11yEvents => ref.read(o11yEventsProvider);
  O11yErrors get _o11yErrors => ref.read(o11yErrorsProvider);
  O11yMetrics get _o11yMetrics => ref.read(o11yMetricsProvider);

  @override
  void initState() {
    super.initState();
    ref.read(o11yLoggerProvider).debug('Home screen initialized');

    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );

    _loadInitialData();
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final quote = await widget.apiService.getQuote();
      final tools = await widget.apiService.getTools();

      setState(() {
        _quote = quote;
        _tools = tools;
        _isLoggedIn = tools.isNotEmpty;
      });

      ref
          .read(o11yLoggerProvider)
          .debug(
            'Initial data loaded',
            context: {
              'has_quote': quote.isNotEmpty.toString(),
              'tools_count': tools.length.toString(),
            },
          );
    } catch (e, stackTrace) {
      _o11yErrors.reportError(
        type: 'UI',
        error: 'Failed to load initial data: ${e.toString()}',
        stacktrace: stackTrace,
        context: {'screen': 'home'},
      );
    }
  }

  void _toggleCustomize() {
    setState(() {
      _customizeExpanded = !_customizeExpanded;
      if (_customizeExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
        _restrictions = Restrictions();
      }
    });
    _o11yEvents.trackEvent(
      'customize_toggled',
      context: {'expanded': _customizeExpanded.toString()},
    );
  }

  Future<void> _navigateToProfile() async {
    _o11yEvents.trackEvent('profile_button_clicked');
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoginScreen(apiService: widget.apiService),
      ),
    );
    // Refresh data when returning from login/profile
    await _loadInitialData();
  }

  Future<void> _getPizza() async {
    _o11yEvents.startUserAction('getPizza', {
      'customized': _customizeExpanded.toString(),
      'vegetarian': _restrictions.mustBeVegetarian.toString(),
      'max_calories': _restrictions.maxCaloriesPerSlice.toString(),
      'min_toppings': _restrictions.minNumberOfToppings.toString(),
      'max_toppings': _restrictions.maxNumberOfToppings.toString(),
    }, triggerName: 'getPizzaButtonClick');

    _o11yEvents.trackEvent(
      'pizza_requested',
      context: {
        'customized': _customizeExpanded.toString(),
        'vegetarian': _restrictions.mustBeVegetarian.toString(),
      },
    );

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _rateResult = null;
    });

    try {
      final pizza = await widget.apiService.getPizzaRecommendation(
        _restrictions,
      );
      setState(() {
        _pizza = pizza;
        _isLoading = false;
        if (pizza == null) {
          _errorMessage =
              'Failed to get pizza recommendation. Please log in and try again.';
        }
      });

      if (pizza != null) {
        _o11yEvents.trackEvent(
          'pizza_received',
          context: {
            'pizza_id': pizza.pizza.id.toString(),
            'pizza_name': pizza.pizza.name,
          },
        );
        _o11yMetrics.addMeasurement('pizza.recommendation', {
          'pizza_id': pizza.pizza.id,
          'calories': pizza.calories ?? 0,
          'vegetarian': pizza.vegetarian == true ? 1 : 0,
        });
      } else {
        ref
            .read(o11yLoggerProvider)
            .warning('Pizza recommendation returned null');
      }
    } catch (e, stackTrace) {
      setState(() {
        _isLoading = false;
        final errorStr = e.toString();
        _errorMessage = errorStr.startsWith('Exception: ')
            ? errorStr.substring(10)
            : errorStr;
      });

      _o11yErrors.reportError(
        type: 'UI',
        error: 'Failed to get pizza: ${e.toString()}',
        stacktrace: stackTrace,
        context: {'screen': 'home', 'action': 'getPizza'},
      );
    }
  }

  Future<void> _ratePizza(int stars, String type) async {
    if (_pizza == null) return;

    _o11yEvents.startUserAction('ratePizza', {
      'pizza_id': _pizza!.pizza.id.toString(),
      'stars': stars.toString(),
      'type': type,
    }, triggerName: 'ratePizzaButtonClick');

    _o11yEvents.trackEvent(
      'pizza_rated',
      context: {
        'pizza_id': _pizza!.pizza.id.toString(),
        'stars': stars.toString(),
        'rating_type': type,
      },
    );

    try {
      final success = await widget.apiService.ratePizza(
        _pizza!.pizza.id,
        stars,
      );
      setState(() {
        _rateResult = success
            ? (type == 'love'
                  ? '❤️ Saved to favorites!'
                  : '👎 Got it, next time!')
            : 'Please log in first.';
      });

      if (success) {
        _o11yMetrics.addMeasurement('pizza.rating', {
          'pizza_id': _pizza!.pizza.id,
          'stars': stars,
        });
      }
    } catch (e, stackTrace) {
      setState(() {
        final errorStr = e.toString();
        _rateResult = errorStr.startsWith('Exception: ')
            ? errorStr.substring(10)
            : errorStr;
      });

      _o11yErrors.reportError(
        type: 'UI',
        error: 'Failed to rate pizza: ${e.toString()}',
        stacktrace: stackTrace,
        context: {
          'screen': 'home',
          'action': 'ratePizza',
          'pizza_id': _pizza!.pizza.id.toString(),
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5E6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.local_pizza, color: Colors.red.shade600, size: 28),
            const SizedBox(width: 8),
            Text(
              'QuickPizza',
              style: TextStyle(
                color: Colors.red.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: _navigateToProfile,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: _isLoggedIn
                    ? Colors.orange
                    : Colors.grey.shade300,
                child: Icon(
                  _isLoggedIn ? Icons.person : Icons.person_outline,
                  color: _isLoggedIn ? Colors.white : Colors.grey.shade600,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Quote Card
              if (_quote.isNotEmpty) _buildQuoteCard(),
              const SizedBox(height: 24),

              // Hero Text
              _buildHeroText(),
              const SizedBox(height: 24),

              // Customize Card (Expandable)
              _buildCustomizeCard(),
              const SizedBox(height: 24),

              // Pizza Please Button
              _buildPizzaButton(),

              // Error Message
              if (_errorMessage != null) _buildErrorMessage(),

              // Pizza Recommendation
              if (_pizza != null) _buildPizzaRecommendation(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuoteCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Icon(Icons.format_quote, color: Colors.orange.shade300, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _quote,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroText() {
    return Column(
      children: [
        const Text(
          'Looking to break out of\nyour pizza routine?',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'QuickPizza has your back!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.red.shade600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'With just one click, you\'ll discover new and exciting pizza combinations.',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade600,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCustomizeCard() {
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
            onTap: _toggleCustomize,
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
                    turns: _customizeExpanded ? 0.5 : 0,
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
                          value: _restrictions.maxCaloriesPerSlice,
                          onChanged: (v) =>
                              _restrictions.maxCaloriesPerSlice = v,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildNumberField(
                          label: 'Min Toppings',
                          value: _restrictions.minNumberOfToppings,
                          onChanged: (v) =>
                              _restrictions.minNumberOfToppings = v,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildNumberField(
                          label: 'Max Toppings',
                          value: _restrictions.maxNumberOfToppings,
                          onChanged: (v) =>
                              _restrictions.maxNumberOfToppings = v,
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
                      color: _restrictions.mustBeVegetarian
                          ? Colors.green.shade50
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _restrictions.mustBeVegetarian
                            ? Colors.green.shade200
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.eco,
                          color: _restrictions.mustBeVegetarian
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
                          value: _restrictions.mustBeVegetarian,
                          onChanged: (value) {
                            setState(() {
                              _restrictions.mustBeVegetarian = value;
                            });
                          },
                          activeColor: Colors.green,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Excluded Tools
                  if (_tools.isNotEmpty) ...[
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
                      children: _tools.map((tool) {
                        final isSelected = _restrictions.excludedTools.contains(
                          tool,
                        );
                        return FilterChip(
                          label: Text(tool),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _restrictions.excludedTools.add(tool);
                              } else {
                                _restrictions.excludedTools.remove(tool);
                              }
                            });
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
                      _restrictions.customName = value;
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

  Widget _buildPizzaButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _getPizza,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_pizza, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Pizza, Please!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildErrorMessage() {
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
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPizzaRecommendation() {
    final pizza = _pizza!.pizza;
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
                value: '${_pizza!.calories ?? 'N/A'} per slice',
              ),
              const SizedBox(height: 12),

              // Vegetarian badge
              if (_pizza!.vegetarian == true)
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
                onPressed: () => _ratePizza(1, 'pass'),
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
                onPressed: () => _ratePizza(5, 'love'),
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
        if (_rateResult != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _rateResult!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _rateResult!.contains('❤️')
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
