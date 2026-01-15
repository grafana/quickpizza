import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/o11y/errors/o11y_errors.dart';
import '../../../core/o11y/loggers/o11y_logger.dart';
import '../../auth/logic/auth_provider.dart';
import '../../ratings/logic/ratings_provider.dart';
import '../../ratings/models/rating.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Load ratings when screen is opened
    Future.microtask(() {
      ref.read(ratingsProvider.notifier).loadRatings();
    });
  }

  Future<void> _handleLogout() async {
    ref.read(authStateProvider.notifier).logout();
    ref.read(ratingsProvider.notifier).clear();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _deleteRatings() async {
    try {
      final success = await ref.read(ratingsProvider.notifier).deleteRatings();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Ratings cleared successfully!'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        ref.read(o11yLoggerProvider).debug('Ratings deleted successfully');
      }
    } catch (e, stackTrace) {
      if (mounted) {
        final errorStr = e.toString();
        final message = errorStr.startsWith('Exception: ')
            ? errorStr.substring(10)
            : errorStr;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      ref.read(o11yErrorsProvider).reportError(
            type: 'UI',
            error: 'Failed to delete ratings: ${e.toString()}',
            stacktrace: stackTrace,
            context: {'screen': 'profile', 'action': 'deleteRatings'},
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final ratingsAsync = ref.watch(ratingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5E6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Profile Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        size: 48,
                        color: Colors.orange.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      authState.username ?? 'Pizza Lover',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ratingsAsync.when(
                      data: (ratings) => Text(
                        '${ratings.length} pizza${ratings.length == 1 ? '' : 's'} rated',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                      loading: () => Text(
                        'Loading...',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                      error: (_, __) => Text(
                        '0 pizzas rated',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Ratings Section
              _buildRatingsSection(ratingsAsync),
              const SizedBox(height: 24),

              // Action Buttons
              ratingsAsync.when(
                data: (ratings) => _buildActionButtons(ratings),
                loading: () => _buildActionButtons([]),
                error: (_, __) => _buildActionButtons([]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingsSection(AsyncValue<List<Rating>> ratingsAsync) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: Colors.orange.shade400, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Your Ratings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ratingsAsync.when(
            data: (ratings) => ratings.isEmpty
                ? _buildEmptyRatings()
                : _buildRatingsList(ratings),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => _buildEmptyRatings(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRatings() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.local_pizza_outlined,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              'No ratings yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Rate some pizzas to see them here!',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingsList(List<Rating> ratings) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: ratings.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final rating = ratings[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: rating.stars >= 4
                      ? Colors.red.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  rating.stars >= 4 ? Icons.favorite : Icons.thumb_down,
                  size: 20,
                  color: rating.stars >= 4
                      ? Colors.red.shade400
                      : Colors.grey.shade500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pizza #${rating.pizzaId}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      rating.stars >= 4 ? 'Loved it!' : 'Passed',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < rating.stars ? Icons.star : Icons.star_border,
                    size: 16,
                    color: i < rating.stars ? Colors.orange : Colors.grey.shade300,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(List<Rating> ratings) {
    return Row(
      children: [
        if (ratings.isNotEmpty)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _deleteRatings,
              icon: const Icon(Icons.delete_outline, size: 20),
              label: const Text('Clear Ratings'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade600,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.red.shade200),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        if (ratings.isNotEmpty) const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout, size: 20),
            label: const Text('Sign Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
