import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'services/config_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize config service (loads .env file)
  await ConfigService.init();

  runApp(const QuickPizzaApp());
}

class QuickPizzaApp extends StatelessWidget {
  const QuickPizzaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();

    // Note: User must login via LoginScreen to get a valid token.
    // Some APIs (quotes, config) work without auth, but others (ratings, pizza, tools) require authentication.

    return MaterialApp(
      title: 'QuickPizza',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(apiService: apiService),
    );
  }
}
