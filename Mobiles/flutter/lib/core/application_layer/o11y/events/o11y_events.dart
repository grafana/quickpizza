import 'package:faro/faro.dart';
import 'package:flutter_mobile_o11y_demo/core/application_layer/o11y/faro/faro.dart';

class O11yEvents {
  O11yEvents() : _faro = faro;

  final Faro _faro;

  void trackEvent(String name, {Map<String, String> attributes = const {}}) {
    _faro.pushEvent(name, attributes: attributes);
  }

  void trackStartEvent(String key, String name) {
    _faro.markEventStart(key, name);
  }

  void trackEndEvent(
    String key,
    String name, {
    Map<String, String> attributes = const {},
  }) {
    _faro.markEventEnd(key, name, attributes: attributes);
  }

  void setUser({
    required String id,
    required String name,
    required String email,
  }) {
    _faro.setUserMeta(userId: id, userName: name, userEmail: email);
  }

  /// Start tracking a user action (equivalent to faro.api.startUserAction in web SDK)
  /// This method marks the start of a user action that will be visible in Frontend Observability
  void startUserAction(
    String actionName,
    Map<String, String> attributes, {
    String? triggerName,
    String? importance,
  }) {
    // Convert attributes to a format suitable for markEventStart
    // Use actionName as both key and name for consistency
    final eventKey = 'userAction_$actionName';
    final eventName = actionName;

    // Add trigger name and importance to attributes if provided
    final enhancedAttributes = <String, String>{...attributes};
    if (triggerName != null) {
      enhancedAttributes['triggerName'] = triggerName;
    }
    if (importance != null) {
      enhancedAttributes['importance'] = importance;
    }

    // Mark the start of the user action
    _faro.markEventStart(eventKey, eventName);

    // Also push an event with attributes for better visibility
    _faro.pushEvent(actionName, attributes: enhancedAttributes);
  }
}

final o11yEvents = O11yEvents();
