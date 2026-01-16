import 'package:faro/faro.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../faro/faro.dart';

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
}
