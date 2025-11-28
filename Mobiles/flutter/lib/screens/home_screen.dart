import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/pizza.dart';
import '../models/restrictions.dart';
import '../services/api_service.dart';
import '../services/config_service.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final ApiService apiService;

  const HomeScreen({super.key, required this.apiService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _quote = '';
  PizzaRecommendation? _pizza;
  bool _isLoading = false;
  String? _errorMessage;
  String? _rateResult;
  bool _advanced = false;
  Restrictions _restrictions = Restrictions();
  List<String> _tools = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Load quote (doesn't require auth)
    final quote = await widget.apiService.getQuote();

    // Load tools (requires auth - will fail if user not logged in)
    final tools = await widget.apiService.getTools();

    setState(() {
      _quote = quote;
      _tools = tools;
      // If tools is empty, user may not be logged in, but that's OK
      // They can still use the app and will be prompted to login when needed
    });
  }

  Future<void> _getPizza() async {
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
    } catch (e) {
      setState(() {
        _isLoading = false;
        final errorStr = e.toString();
        _errorMessage = errorStr.startsWith('Exception: ')
            ? errorStr.substring(10)
            : errorStr;
      });
    }
  }

  Future<void> _ratePizza(int stars) async {
    if (_pizza == null) return;

    try {
      final success = await widget.apiService.ratePizza(
        _pizza!.pizza.id,
        stars,
      );
      setState(() {
        _rateResult = success ? 'Rated!' : 'Please log in first.';
      });
    } catch (e) {
      setState(() {
        final errorStr = e.toString();
        _rateResult = errorStr.startsWith('Exception: ')
            ? errorStr.substring(10)
            : errorStr;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5E6), // Light cream background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.local_pizza, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            const Text(
              'QuickPizza',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      LoginScreen(apiService: widget.apiService),
                ),
              );
            },
            child: const Text(
              'Login/Profile',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              Switch(
                value: _advanced,
                onChanged: (value) {
                  setState(() {
                    _advanced = value;
                    if (!value) {
                      _restrictions = Restrictions();
                    }
                  });
                },
                activeThumbColor: Colors.red,
              ),
              const Text('Advanced', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 16),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (_quote.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _quote,
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 20),
              const Text(
                'Looking to break out of your pizza routine?',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'QuickPizza has your back!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'With just one click, you\'ll discover new and exciting pizza combinations that you never knew existed.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              if (_advanced) _buildAdvancedOptions(),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _getPizza,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Pizza, Please!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (_pizza != null) _buildPizzaRecommendation(),
              const SizedBox(height: 40),
              const Text(
                'Made with ❤️ by QuickPizza Labs.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 12),
                  children: [
                    const TextSpan(text: 'Looking for the admin page? '),
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: () async {
                          final adminUrl = Uri.parse(
                            '${ConfigService.baseUrl}/admin',
                          );
                          if (await canLaunchUrl(adminUrl)) {
                            await launchUrl(
                              adminUrl,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        child: const Text(
                          'Click here',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 12),
                  children: [
                    const TextSpan(text: 'Contribute to QuickPizza on '),
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: () async {
                          final githubUrl = Uri.parse(
                            'https://github.com/grafana/quickpizza',
                          );
                          if (await canLaunchUrl(githubUrl)) {
                            await launchUrl(
                              githubUrl,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        child: const Text(
                          'GitHub',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedOptions() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Max Calories per Slice',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    _restrictions.maxCaloriesPerSlice =
                        int.tryParse(value) ?? 1000;
                  },
                  controller: TextEditingController(
                    text: _restrictions.maxCaloriesPerSlice.toString(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Min Toppings',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    _restrictions.minNumberOfToppings =
                        int.tryParse(value) ?? 2;
                  },
                  controller: TextEditingController(
                    text: _restrictions.minNumberOfToppings.toString(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Max Toppings',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    _restrictions.maxNumberOfToppings =
                        int.tryParse(value) ?? 5;
                  },
                  controller: TextEditingController(
                    text: _restrictions.maxNumberOfToppings.toString(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Excluded Tools:'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _tools.map((tool) {
                        return FilterChip(
                          label: Text(tool),
                          selected: _restrictions.excludedTools.contains(tool),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _restrictions.excludedTools.add(tool);
                              } else {
                                _restrictions.excludedTools.remove(tool);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _restrictions.mustBeVegetarian,
                onChanged: (value) {
                  setState(() {
                    _restrictions.mustBeVegetarian = value ?? false;
                  });
                },
                fillColor: WidgetStateProperty.all(Colors.red),
              ),
              const Text('Must be vegetarian'),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Custom Pizza Name',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              _restrictions.customName = value;
            },
            controller: TextEditingController(text: _restrictions.customName),
          ),
        ],
      ),
    );
  }

  Widget _buildPizzaRecommendation() {
    final pizza = _pizza!.pizza;
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Our recommendation:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text('Name: ${pizza.name}'),
              const SizedBox(height: 8),
              Text('Dough: ${pizza.dough.name}'),
              const SizedBox(height: 8),
              const Text('Ingredients:'),
              const SizedBox(height: 4),
              ...pizza.ingredients.map(
                (ingredient) => Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text('• ${ingredient.name}'),
                ),
              ),
              const SizedBox(height: 8),
              Text('Tool: ${pizza.tool}'),
              const SizedBox(height: 8),
              Text('Calories per slice: ${_pizza!.calories ?? 'N/A'}'),
              const SizedBox(height: 8),
              Text(
                'Vegetarian: ${_pizza!.vegetarian == true ? 'Yes' : 'No'}',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: _pizza!.vegetarian == true
                      ? Colors.green[700]
                      : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _ratePizza(1),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[400],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('No thanks'),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () => _ratePizza(5),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Love it!'),
            ),
          ],
        ),
        if (_rateResult != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _rateResult!,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
      ],
    );
  }
}
