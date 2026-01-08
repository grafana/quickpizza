import 'package:flutter/material.dart';
import '../core/application_layer/o11y/events/o11y_events.dart';
import '../core/application_layer/o11y/errors/o11y_errors.dart';
import '../core/application_layer/o11y/loggers/o11y_logger.dart';
import '../services/api_service.dart';
import '../models/rating.dart';

class LoginScreen extends StatefulWidget {
  final ApiService apiService;

  const LoginScreen({super.key, required this.apiService});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoggedIn = false;
  List<Rating> _ratings = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    o11yEvents.trackEvent('login_screen_opened', attributes: {});
    o11yLogger.debug('Login screen initialized', context: {});
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await _loadRatings();
  }

  Future<void> _loadRatings() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final ratings = await widget.apiService.getRatings();
      setState(() {
        _ratings = ratings;
        _isLoggedIn = ratings.isNotEmpty || _usernameController.text.isNotEmpty;
        _isLoading = false;
      });
      o11yLogger.debug(
        'Ratings loaded',
        context: {'count': ratings.length.toString()},
      );
    } catch (e, stackTrace) {
      setState(() {
        _isLoading = false;
      });
      o11yErrors.reportError(
        type: 'UI',
        error: 'Failed to load ratings: ${e.toString()}',
        stacktrace: stackTrace,
        context: {'screen': 'login'},
      );
    }
  }

  Future<void> _handleLogin() async {
    o11yEvents.startUserAction(
      'userLogin',
      {'username': _usernameController.text},
      triggerName: 'userLoginButtonClick',
      importance: 'critical',
    );

    o11yEvents.trackStartEvent('login_attempt', 'user_login');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.apiService.login(
        _usernameController.text,
        _passwordController.text,
      );
      if (success) {
        o11yEvents.trackEndEvent(
          'login_attempt',
          'user_login',
          attributes: {'success': 'true', 'username': _usernameController.text},
        );
        o11yEvents.setUser(
          id: _usernameController.text,
          name: _usernameController.text,
          email: '${_usernameController.text}@quickpizza.com',
        );
        await _loadRatings();
      } else {
        o11yEvents.trackEndEvent(
          'login_attempt',
          'user_login',
          attributes: {
            'success': 'false',
            'username': _usernameController.text,
          },
        );
        setState(() {
          _errorMessage = 'Login failed. Please check your credentials.';
          _isLoading = false;
        });
        o11yLogger.warning(
          'Login failed',
          context: {'username': _usernameController.text},
        );
      }
    } catch (e, stackTrace) {
      o11yEvents.trackEndEvent(
        'login_attempt',
        'user_login',
        attributes: {'success': 'false', 'error': e.toString()},
      );
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
      o11yErrors.reportError(
        type: 'UI',
        error: 'Login error: ${e.toString()}',
        stacktrace: stackTrace,
        context: {'screen': 'login', 'username': _usernameController.text},
      );
    }
  }

  Future<void> _handleLogout() async {
    o11yEvents.trackEvent(
      'user_logged_out',
      attributes: {'username': _usernameController.text},
    );
    widget.apiService.setUserToken(null);
    setState(() {
      _isLoggedIn = false;
      _ratings = [];
      _usernameController.clear();
      _passwordController.clear();
    });
    o11yLogger.debug('User logged out', context: {});
  }

  Future<void> _deleteRatings() async {
    o11yEvents.startUserAction(
      'userDeleteRatings',
      {'username': _usernameController.text},
      triggerName: 'userDeleteRatingsButtonClick',
      importance: 'critical',
    );

    o11yEvents.trackEvent(
      'ratings_deleted',
      attributes: {'count': _ratings.length.toString()},
    );

    try {
      final success = await widget.apiService.deleteRatings();
      if (success) {
        await _loadRatings();
        if (mounted) {
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
        }
        o11yLogger.debug('Ratings deleted successfully', context: {});
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
      o11yErrors.reportError(
        type: 'UI',
        error: 'Failed to delete ratings: ${e.toString()}',
        stacktrace: stackTrace,
        context: {'screen': 'login', 'action': 'deleteRatings'},
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isLoggedIn ? 'Profile' : 'Login',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoggedIn ? _buildProfileView() : _buildLoginView(),
    );
  }

  Widget _buildLoginView() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  size: 64,
                  color: Colors.orange.shade400,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Welcome to QuickPizza',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to save your favorite pizzas',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),

              // Login Card
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      obscureText: true,
                    ),
                    if (_errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hint: Use "default" / "12345678" to login',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tip: You can create a new user via the POST http://quickpizza.grafana.com/api/users endpoint. Attach a JSON payload with username and password keys.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileView() {
    return SingleChildScrollView(
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
                    _usernameController.text.isNotEmpty
                        ? _usernameController.text
                        : 'Pizza Lover',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_ratings.length} pizza${_ratings.length == 1 ? '' : 's'} rated',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Ratings Section
            Container(
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
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_ratings.isEmpty)
                    Center(
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
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _ratings.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final rating = _ratings[index];
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
                                  rating.stars >= 4
                                      ? Icons.favorite
                                      : Icons.thumb_down,
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
                                      rating.stars >= 4
                                          ? 'Loved it!'
                                          : 'Passed',
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
                                    i < rating.stars
                                        ? Icons.star
                                        : Icons.star_border,
                                    size: 16,
                                    color: i < rating.stars
                                        ? Colors.orange
                                        : Colors.grey.shade300,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                if (_ratings.isNotEmpty)
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
                if (_ratings.isNotEmpty) const SizedBox(width: 12),
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
            ),
          ],
        ),
      ),
    );
  }
}
