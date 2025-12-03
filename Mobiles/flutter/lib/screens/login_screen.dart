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
    // Track user action for Frontend Observability
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
    // Track user action for Frontend Observability
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
            const SnackBar(content: Text('Ratings deleted successfully.')),
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
          SnackBar(content: Text(message), backgroundColor: Colors.red),
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Login / Profile',
          style: TextStyle(color: Colors.black),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
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
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'QuickPizza User Login',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username (hint: default)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password (hint: 12345678)',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign in'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tip: You can create a new user via the POST /api/users endpoint.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
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
            const Text(
              'Your Pizza Ratings:',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_ratings.isEmpty)
              const Text('No ratings yet')
            else
              ..._ratings.map(
                (rating) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('Rating ID: ${rating.id}'),
                    subtitle: Text(
                      'Stars: ${rating.stars}, Pizza ID: ${rating.pizzaId}',
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _deleteRatings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Clear Ratings'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _handleLogout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Logout'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
