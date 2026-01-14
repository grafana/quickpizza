import 'package:faro/faro.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final faroProvider = Provider((ref) {
  return Faro();
});
