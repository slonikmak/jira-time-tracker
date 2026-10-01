import 'dart:convert';

/// A message owned by the application, with its original Russian diagnostic.
/// Domain modules carry identifiers and arguments without depending on Flutter.
class AppMessage {
  final String id;
  final List<Object?> arguments;
  final String fallback;

  const AppMessage(this.id, this.arguments, this.fallback);

  factory AppMessage.date(String? isoDate) =>
      AppMessage('calendarDate', [isoDate], isoDate ?? '');

  factory AppMessage.duration(int seconds) =>
      AppMessage('duration', [seconds], '$seconds s');

  factory AppMessage.join(
    Iterable<Object?> messages, [
    String separator = '\n',
  ]) {
    final parts = messages.toList();
    return AppMessage('joinedMessages', [
      separator,
      ...parts,
    ], parts.join(separator));
  }

  @override
  String toString() => fallback;
}

abstract interface class MessageException {
  Object get messageText;
}

class AppStateError extends StateError implements MessageException {
  @override
  final Object messageText;
  AppStateError(this.messageText) : super(messageText.toString());
}

class AppArgumentError extends ArgumentError implements MessageException {
  @override
  final Object messageText;
  AppArgumentError(this.messageText) : super(messageText.toString());
}

class AppFormatException extends FormatException implements MessageException {
  @override
  final Object messageText;
  const AppFormatException(this.messageText);
  @override
  String get message => messageText.toString();
}

const _messagePrefix = 'jtt-message-v1:';

/// Only new application messages are encoded. Jira and legacy text stay raw.
String serializeMessage(Object message) {
  Object? encode(Object? value) {
    if (value is MessageException) return encode(value.messageText);
    if (value is AppMessage) {
      return {
        'id': value.id,
        'args': value.arguments.map(encode).toList(),
        'fallback': value.fallback,
      };
    }
    if (value is num || value is bool || value == null) return value;
    return value.toString();
  }

  if (message is! AppMessage && message is! MessageException) {
    return message.toString();
  }
  return '$_messagePrefix${jsonEncode(encode(message))}';
}

Object deserializeMessage(String text) {
  if (!text.startsWith(_messagePrefix)) return text;
  Object? decode(Object? value) {
    if (value is Map<String, dynamic> &&
        value['id'] is String &&
        value['args'] is List &&
        value['fallback'] is String) {
      return AppMessage(
        value['id'] as String,
        (value['args'] as List).map(decode).toList(),
        value['fallback'] as String,
      );
    }
    return value;
  }

  try {
    return decode(jsonDecode(text.substring(_messagePrefix.length))) ?? text;
  } catch (_) {
    return text;
  }
}
