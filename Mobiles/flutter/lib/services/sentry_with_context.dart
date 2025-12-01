import 'package:sentry_flutter/sentry_flutter.dart';

/// Utility to send Sentry errors with source context.
///
/// Since Flutter/Dart compiled code doesn't have access to source files at runtime,
/// the Sentry SDK cannot include preContext, contextLine, and postContext in error payloads.
///
/// This utility manually constructs error events with source context for testing
/// purposes when sending to a Sentry-compatible backend like Grafault.

class FrameWithContext {
  final String filename;
  final String function;
  final int lineno;
  final int? colno;
  final bool inApp;
  final List<String>? preContext;
  final String? contextLine;
  final List<String>? postContext;

  FrameWithContext({
    required this.filename,
    required this.function,
    required this.lineno,
    this.colno,
    required this.inApp,
    this.preContext,
    this.contextLine,
    this.postContext,
  });

  SentryStackFrame toSentryFrame() {
    return SentryStackFrame(
      fileName: filename,
      function: function,
      lineNo: lineno,
      colNo: colno,
      inApp: inApp,
      preContext: preContext,
      contextLine: contextLine,
      postContext: postContext,
    );
  }
}

class ErrorTemplate {
  final String type;
  final String value;
  final List<FrameWithContext> frames;

  ErrorTemplate({
    required this.type,
    required this.value,
    required this.frames,
  });
}

/// Pre-defined error templates with source context for testing
final Map<String, ErrorTemplate> errorTemplates = {
  'NullPointerException': ErrorTemplate(
    type: 'NullPointerException',
    value: 'Null check operator used on a null value',
    frames: [
      FrameWithContext(
        filename: 'lib/screens/home_screen.dart',
        function: '_buildPizzaCard',
        lineno: 245,
        colno: 28,
        inApp: true,
        preContext: [
          '  Widget _buildPizzaCard(Pizza? pizza) {',
          '    // Display pizza details',
          '    final ingredients = pizza!.ingredients;',
        ],
        contextLine: '    return Text(pizza!.name);',
        postContext: ['  }', '', '  @override'],
      ),
      FrameWithContext(
        filename: 'lib/screens/home_screen.dart',
        function: 'build',
        lineno: 180,
        colno: 12,
        inApp: true,
        preContext: ['  @override', '  Widget build(BuildContext context) {'],
        contextLine: '    return _buildPizzaCard(_currentPizza);',
        postContext: ['  }', '}'],
      ),
      FrameWithContext(
        filename: 'package:flutter/src/widgets/framework.dart',
        function: 'StatefulElement.build',
        lineno: 4919,
        inApp: false,
      ),
    ],
  ),
  'NetworkException': ErrorTemplate(
    type: 'NetworkException',
    value: 'Failed to fetch pizza recommendations: Connection refused',
    frames: [
      FrameWithContext(
        filename: 'lib/services/api_service.dart',
        function: 'getPizzaRecommendation',
        lineno: 78,
        colno: 15,
        inApp: true,
        preContext: [
          '  Future<Pizza> getPizzaRecommendation() async {',
          '    try {',
          '      final response = await http.post(',
        ],
        contextLine: "        Uri.parse('\$baseUrl/api/pizza'),",
        postContext: [
          '        headers: _headers,',
          '        body: jsonEncode(restrictions),',
          '      );',
        ],
      ),
      FrameWithContext(
        filename: 'lib/screens/home_screen.dart',
        function: '_onPizzaPlease',
        lineno: 156,
        colno: 22,
        inApp: true,
        preContext: [
          '  Future<void> _onPizzaPlease() async {',
          '    setState(() => _isLoading = true);',
        ],
        contextLine:
            '    final pizza = await _apiService.getPizzaRecommendation();',
        postContext: [
          '    setState(() {',
          '      _currentPizza = pizza;',
          '      _isLoading = false;',
        ],
      ),
    ],
  ),
  'FormatException': ErrorTemplate(
    type: 'FormatException',
    value: 'Invalid JSON response from server',
    frames: [
      FrameWithContext(
        filename: 'lib/services/api_service.dart',
        function: '_parseResponse',
        lineno: 112,
        colno: 18,
        inApp: true,
        preContext: [
          '  Map<String, dynamic> _parseResponse(String body) {',
          '    try {',
        ],
        contextLine: '      return jsonDecode(body) as Map<String, dynamic>;',
        postContext: [
          '    } on FormatException catch (e) {',
          "      throw FormatException('Invalid JSON response from server');",
          '    }',
        ],
      ),
      FrameWithContext(
        filename: 'lib/services/api_service.dart',
        function: 'getPizzaRecommendation',
        lineno: 85,
        colno: 20,
        inApp: true,
        preContext: ['      if (response.statusCode == 200) {'],
        contextLine: '        final data = _parseResponse(response.body);',
        postContext: ['        return Pizza.fromJson(data);', '      }'],
      ),
    ],
  ),
  'StateError': ErrorTemplate(
    type: 'StateError',
    value: 'Bad state: Cannot add event after closing',
    frames: [
      FrameWithContext(
        filename: 'lib/screens/home_screen.dart',
        function: '_updatePizzaStream',
        lineno: 198,
        colno: 10,
        inApp: true,
        preContext: [
          '  void _updatePizzaStream(Pizza pizza) {',
          '    // Add pizza to stream for listeners',
        ],
        contextLine: '    _pizzaController.add(pizza);',
        postContext: ['  }', '', '  @override'],
      ),
      FrameWithContext(
        filename: 'lib/screens/home_screen.dart',
        function: 'dispose',
        lineno: 210,
        colno: 5,
        inApp: true,
        preContext: ['  @override', '  void dispose() {'],
        contextLine: '    _pizzaController.close();',
        postContext: ['    super.dispose();', '  }'],
      ),
    ],
  ),
};

/// Available error types for UI selection
List<String> getAvailableErrorTypes() {
  return errorTemplates.keys.toList();
}

/// Send a test error to Sentry with source context included.
/// This manually constructs the event payload with preContext, contextLine, and postContext.
Future<void> sendErrorWithContext(String errorType) async {
  final template = errorTemplates[errorType];
  if (template == null) {
    throw ArgumentError('Unknown error type: $errorType');
  }

  // Create the exception with stack trace
  final exception = SentryException(
    type: template.type,
    value: template.value,
    stackTrace: SentryStackTrace(
      frames: template.frames.map((f) => f.toSentryFrame()).toList(),
    ),
  );

  // Create the event
  final event = SentryEvent(
    timestamp: DateTime.now().toUtc(),
    platform: 'dart',
    environment: 'development',
    exceptions: [exception],
    tags: {'source': 'test-button', 'has_context': 'true'},
  );

  // Capture the event
  await Sentry.captureEvent(event);
}
