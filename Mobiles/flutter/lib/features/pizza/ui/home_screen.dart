import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/o11y/errors/o11y_errors.dart';
import '../../../core/o11y/loggers/o11y_logger.dart';
import '../../auth/logic/auth_provider.dart';
import '../../auth/ui/login_screen.dart';
import '../../ratings/logic/ratings_provider.dart';
import '../logic/pizza_provider.dart';
import '../models/restrictions.dart';
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
  Restrictions _restrictions = Restrictions();

  @override
  void initState() {
    super.initState();
    ref.read(o11yLoggerProvider).debug('Home screen initialized');
  }

  Future<void> _navigateToProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
    if (result == true) {
      // User logged in, refresh tools
      ref.invalidate(toolsProvider);
    }
  }

  Future<void> _getPizza() async {
    await ref.read(pizzaStateProvider.notifier).getPizza(_restrictions);
  }

  Future<void> _ratePizza(int stars, String type) async {
    final pizzaState = ref.read(pizzaStateProvider);
    if (pizzaState.pizza == null) return;

    try {
      final success = await ref.read(ratingsProvider.notifier).ratePizza(
            pizzaState.pizza!.pizza.id,
            stars,
            type,
          );

      if (success) {
        ref.read(pizzaStateProvider.notifier).setRateResult(
              type == 'love' ? '❤️ Saved to favorites!' : '👎 Got it, next time!',
            );
      } else {
        ref.read(pizzaStateProvider.notifier).setRateResult('Please log in first.');
      }
    } catch (e, stackTrace) {
      final errorStr = e.toString();
      final message = errorStr.startsWith('Exception: ')
          ? errorStr.substring(10)
          : errorStr;
      ref.read(pizzaStateProvider.notifier).setRateResult(message);

      ref.read(o11yErrorsProvider).reportError(
            type: 'UI',
            error: 'Failed to rate pizza: ${e.toString()}',
            stacktrace: stackTrace,
            context: {
              'screen': 'home',
              'action': 'ratePizza',
              'pizza_id': pizzaState.pizza!.pizza.id.toString(),
            },
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final quoteAsync = ref.watch(quoteProvider);
    final toolsAsync = ref.watch(toolsProvider);
    final pizzaState = ref.watch(pizzaStateProvider);

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
                backgroundColor: isLoggedIn ? Colors.orange : Colors.grey.shade300,
                child: Icon(
                  isLoggedIn ? Icons.person : Icons.person_outline,
                  color: isLoggedIn ? Colors.white : Colors.grey.shade600,
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
              quoteAsync.when(
                data: (quote) => QuoteCard(quote: quote),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),

              // Hero Text
              const HeroText(),
              const SizedBox(height: 24),

              // Customize Card (Expandable)
              toolsAsync.when(
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
                error: (_, __) => CustomizeSection(
                  restrictions: _restrictions,
                  tools: const [],
                  onRestrictionsChanged: () => setState(() {}),
                ),
              ),
              const SizedBox(height: 24),

              // Pizza Please Button
              _buildPizzaButton(pizzaState.isLoading),

              // Error Message
              if (pizzaState.errorMessage != null) _buildErrorMessage(pizzaState.errorMessage!),

              // Pizza Recommendation
              if (pizzaState.pizza != null)
                PizzaCard(
                  recommendation: pizzaState.pizza!,
                  onRate: _ratePizza,
                  rateResult: pizzaState.rateResult,
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPizzaButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : _getPizza,
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
