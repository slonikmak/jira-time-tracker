import 'package:flutter/foundation.dart';
import 'connection_store.dart';
import 'issue_parser.dart';
import 'jira_client.dart';
import 'local_store.dart';
import 'models.dart';

/// Период фильтрации задач по времени последнего использования.
enum IssueFilterPeriod {
  days7,
  days30,
  all;

  String get label {
    switch (this) {
      case IssueFilterPeriod.days7:
        return '7 дней';
      case IssueFilterPeriod.days30:
        return '30 дней';
      case IssueFilterPeriod.all:
        return 'Все';
    }
  }
}

/// Состояние приложения, координация данных, задач и подключений.
class AppState extends ChangeNotifier {
  final LocalStore store;
  final ConnectionStore connectionStore;
  final JiraClient jiraClient;
  final bool isReadOnly;

  int _selectedTabIndex = 0;
  String? _statusMessage;
  JiraConnection? _currentConnection;

  List<Issue> _issues = [];
  String _issueSearchQuery = '';
  IssueFilterPeriod _filterPeriod = IssueFilterPeriod.all;
  final Set<String> _selectedIssueIds = {};

  AppState({
    required this.store,
    required this.connectionStore,
    required this.jiraClient,
    required this.isReadOnly,
    JiraConnection? initialConnection,
  }) : _currentConnection = initialConnection;

  int get selectedTabIndex => _selectedTabIndex;
  String? get statusMessage => _statusMessage;
  JiraConnection? get currentConnection => _currentConnection;

  /// Активный scope (normalized baseUrl#accountId) для изоляции данных в SQLite (A17).
  String get activeScope => _currentConnection?.scope ?? 'default';

  List<Issue> get issues => List.unmodifiable(_issues);
  String get issueSearchQuery => _issueSearchQuery;
  IssueFilterPeriod get filterPeriod => _filterPeriod;
  Set<String> get selectedIssueIds => Set.unmodifiable(_selectedIssueIds);

  /// Отфильтрованный список задач по поисковому запросу и периоду давности.
  List<Issue> get filteredIssues {
    final now = DateTime.now().toUtc();
    return _issues.where((issue) {
      // 1. Фильтр по давности
      if (_filterPeriod == IssueFilterPeriod.days7) {
        if (issue.lastUsedAtUtc.isBefore(
          now.subtract(const Duration(days: 7)),
        )) {
          return false;
        }
      } else if (_filterPeriod == IssueFilterPeriod.days30) {
        if (issue.lastUsedAtUtc.isBefore(
          now.subtract(const Duration(days: 30)),
        )) {
          return false;
        }
      }

      // 2. Поиск по строке (ключ или summary)
      if (_issueSearchQuery.isNotEmpty) {
        final query = _issueSearchQuery.toLowerCase();
        final matchesKey = issue.key.toLowerCase().contains(query);
        final matchesSummary = issue.summary.toLowerCase().contains(query);
        if (!matchesKey && !matchesSummary) return false;
      }

      return true;
    }).toList();
  }

  Future<void> loadSavedConnection() async {
    final conn = await connectionStore.getSavedConnection();
    if (conn != null) {
      _currentConnection = conn;
      await loadIssues();
      notifyListeners();
    }
  }

  void selectTab(int index) {
    if (_selectedTabIndex != index) {
      _selectedTabIndex = index;
      notifyListeners();
    }
  }

  Future<void> updateConnection(JiraConnection connection, String token) async {
    await connectionStore.saveConnection(connection, token);
    _currentConnection = connection;
    await loadIssues();
    notifyListeners();
  }

  Future<void> removeConnection() async {
    await connectionStore.clearConnection();
    _currentConnection = null;
    await loadIssues();
    notifyListeners();
  }

  // --- Задачи (Issues) ---

  Future<void> loadIssues() async {
    _issues = store.getIssues(scope: activeScope);
    notifyListeners();
  }

  /// Добавляет задачу по ключу, ID или ссылке (сценарий A05).
  Future<Issue> addIssue(String rawInput) async {
    final identifier = IssueParser.parse(rawInput);
    if (identifier == null) {
      throw const FormatException(
        'Некорректный ввод: укажите ключ (PROJ-123), числовой ID или ссылку /browse/...',
      );
    }

    if (_currentConnection == null) {
      throw StateError(
        'Сначала проверьте и сохраните подключение к Jira в Настройках',
      );
    }

    final token = await connectionStore.getSavedToken();
    if (token == null || token.isEmpty) {
      throw StateError('API токен Jira не найден в защищённом хранилище');
    }

    final issue = await jiraClient.getIssue(
      identifier,
      connection: _currentConnection!,
      token: token,
    );

    // Сохраняем в базу данных (upsert поднимает lastUsedAtUtc)
    store.upsertIssue(issue);
    await loadIssues();
    return issue;
  }

  void setIssueSearchQuery(String query) {
    _issueSearchQuery = query.trim();
    notifyListeners();
  }

  void setIssueFilterPeriod(IssueFilterPeriod period) {
    _filterPeriod = period;
    notifyListeners();
  }

  void toggleIssueSelection(String issueId) {
    if (_selectedIssueIds.contains(issueId)) {
      _selectedIssueIds.remove(issueId);
    } else {
      _selectedIssueIds.add(issueId);
    }
    notifyListeners();
  }

  void clearIssueSelection() {
    _selectedIssueIds.clear;
    notifyListeners();
  }

  void setStatusMessage(String? message) {
    _statusMessage = message;
    notifyListeners();
  }

  void clearStatusMessage() {
    if (_statusMessage != null) {
      _statusMessage = null;
      notifyListeners();
    }
  }
}
