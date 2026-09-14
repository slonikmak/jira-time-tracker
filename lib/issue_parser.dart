/// Утилита для разбора ключа задачи, числового ID или URL из поля ввода.
class IssueParser {
  static final RegExp _keyRegExp = RegExp(r'^[A-Za-z][A-Za-z0-9_]*-\d+$');
  static final RegExp _idRegExp = RegExp(r'^\d+$');
  static final RegExp _browseRegExp = RegExp(
    r'/browse/([A-Za-z][A-Za-z0-9_]*-\d+)',
    caseSensitive: false,
  );

  /// Извлекает канонический идентификатор (ключ или ID) из пользовательского ввода.
  /// Поддерживает:
  /// - Ключ: `PROJ-123`, `proj-123`
  /// - Числовой ID: `10023`
  /// - URL или относительный путь: `https://domain.atlassian.net/browse/PROJ-123`, `/browse/PROJ-123`
  static String? parse(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return null;

    // 1. Проверка на наличие /browse/<KEY> в URL или пути
    final browseMatch = _browseRegExp.firstMatch(trimmed);
    if (browseMatch != null) {
      return browseMatch.group(1)!.toUpperCase();
    }

    // 2. Если передан прямой ключ (например, PROJ-123)
    if (_keyRegExp.hasMatch(trimmed)) {
      return trimmed.toUpperCase();
    }

    // 3. Если передан числовой Jira ID
    if (_idRegExp.hasMatch(trimmed)) {
      return trimmed;
    }

    // 4. Попытка разобрать как URL и проверить последний сегмент пути
    try {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        final lastSegment = uri.pathSegments.last;
        if (_keyRegExp.hasMatch(lastSegment)) {
          return lastSegment.toUpperCase();
        }
        if (_idRegExp.hasMatch(lastSegment)) {
          return lastSegment;
        }
      }
    } catch (_) {}

    return null;
  }
}
