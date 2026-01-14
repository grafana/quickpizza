import 'package:faro/faro.dart';
import 'package:flutter_mobile_o11y_demo/core/application_layer/o11y/faro/faro.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final o11yEventsProvider = Provider<O11yEvents>((ref) {
  return FaroO11yEvents(faro: ref.watch(faroProvider));
});

abstract class O11yEvents {
  void trackEvent(String name, {Map<String, String>? context});
  void trackStartEvent(String key, String name);
  void trackEndEvent(String key, String name, {Map<String, String>? context});

  void setUser({
    String? id,
    String? name,
    String? email,
    Map<String, String>? attributes,
  });
  void startUserAction(
    String actionName,
    Map<String, String>? context, {
    String? triggerName,
    String? importance,
  });
}

class FaroO11yEvents implements O11yEvents {
  FaroO11yEvents({required Faro faro}) : _faro = faro;

  final Faro _faro;

  @override
  void trackEvent(String name, {Map<String, String>? context}) {
    _faro.pushEvent(name, attributes: context);
  }

  @override
  void trackStartEvent(String key, String name) {
    _faro.markEventStart(key, name);
  }

  @override
  void trackEndEvent(String key, String name, {Map<String, String>? context}) {
    _faro.markEventEnd(key, name, attributes: context ?? {});
  }

  @override
  void setUser({
    String? id,
    String? name,
    String? email,
    Map<String, String>? attributes,
  }) {
    final user =
        id == null && name == null && email == null && attributes == null
        ? FaroUser.cleared()
        : FaroUser(
            id: id,
            username: name,
            email: email,
            attributes: attributes,
          );
    _faro.setUser(user);
  }

  /// Start tracking a user action (equivalent to faro.api.startUserAction in web SDK)
  /// This method marks the start of a user action that will be visible in Frontend Observability

  @override
  void startUserAction(
    String actionName,
    Map<String, String>? context, {
    String? triggerName,
    String? importance,
  }) {
    // Convert context to a format suitable for markEventStart
    // Use actionName as both key and name for consistency
    final eventKey = 'userAction_$actionName';
    final eventName = actionName;

    // Add trigger name and importance to context if provided
    final enhancedContext = <String, String>{...context ?? {}};
    if (triggerName != null) {
      enhancedContext['triggerName'] = triggerName;
    }
    if (importance != null) {
      enhancedContext['importance'] = importance;
    }

    // Mark the start of the user action
    _faro.markEventStart(eventKey, eventName);

    // Also push an event with attributes for better visibility
    _faro.pushEvent(actionName, attributes: enhancedContext);
  }
}
