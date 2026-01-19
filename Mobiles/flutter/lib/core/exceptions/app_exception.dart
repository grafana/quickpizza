/// A simple application exception with a user-friendly message.
///
/// Unlike Dart's built-in [Exception], the [toString] method returns
/// only the message without any "Exception: " prefix, making it suitable
/// for displaying directly to users.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}
