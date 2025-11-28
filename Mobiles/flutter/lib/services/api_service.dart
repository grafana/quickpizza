import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/pizza.dart';
import '../models/restrictions.dart';
import '../models/rating.dart';
import 'config_service.dart';

class ApiService {
  // Get baseUrl from ConfigService which handles env variables and platform detection
  String get baseUrl => ConfigService.baseUrl;

  String? _userToken;

  void setUserToken(String? token) {
    _userToken = token;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_userToken != null && _userToken!.isNotEmpty)
      'Authorization': 'Token $_userToken',
  };

  Future<String> getQuote() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/quotes'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final quotes = json['quotes'] as List;
        if (quotes.isNotEmpty) {
          return quotes[0] as String;
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  Future<List<String>> getTools() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tools'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final tools = json['tools'] as List;
        return tools.map((t) => t as String).toList();
      }
      // 401 means authentication required - return empty list
      // User can still use the app, they just won't see tools in advanced options
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<PizzaRecommendation?> getPizzaRecommendation(
    Restrictions restrictions,
  ) async {
    try {
      final url = '$baseUrl/api/pizza';
      final body = jsonEncode(restrictions.toJson());

      final response = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return PizzaRecommendation.fromJson(json);
      } else if (response.statusCode == 401) {
        return null;
      } else if (response.statusCode == 403) {
        // 403 Forbidden - user doesn't have permission
        try {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final error = json['error'] as String?;
          throw Exception(error ?? 'Operation not permitted');
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception('Operation not permitted');
        }
      } else {
        return null;
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> ratePizza(int pizzaId, int stars) async {
    try {
      final rating = Rating(id: 0, pizzaId: pizzaId, stars: stars);
      final response = await http.post(
        Uri.parse('$baseUrl/api/ratings'),
        headers: _headers,
        body: jsonEncode(rating.toJson()),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('You may need to be logged in');
      } else if (response.statusCode == 403) {
        // 403 Forbidden - user doesn't have permission
        try {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final error = json['error'] as String?;
          throw Exception(
            error ?? 'You don\'t have permission to do this operation',
          );
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception('You don\'t have permission to do this operation');
        }
      } else {
        throw Exception('Failed to rate pizza. Please try again.');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Rating>> getRatings() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/ratings'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final ratings = json['ratings'] as List;
        return ratings
            .map((r) => Rating.fromJson(r as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> deleteRatings() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/ratings'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('You may need to be logged in');
      } else if (response.statusCode == 403) {
        try {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final error = json['error'] as String?;
          throw Exception(
            error ?? 'You don\'t have permission to do this operation',
          );
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception('You don\'t have permission to do this operation');
        }
      } else {
        throw Exception('Failed to delete ratings. Please try again.');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      // For mobile apps, we don't use set_cookie=true to avoid CSRF token requirements
      // The token will be returned in the JSON response and stored in memory
      final url = '$baseUrl/api/users/token/login';

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final token = json['token'] as String?;
        if (token != null) {
          _userToken = token;
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
