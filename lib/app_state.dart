import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'connection_store.dart';
import 'issue_parser.dart';
import 'jira_client.dart';
import 'local_store.dart';
import 'log_clock.dart';
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

/// Состояние приложения, координация данных, задач, таймеров и подключений.
class AppState extends ChangeNotifier {
  final LocalStore store;
  final ConnectionStore connectionStore;
  final JiraClient jiraClient;
  final bool isReadOnly;
  final DateTime Function() nowProvider;

  int _selectedTabIndex = 0;
  String? _statusMessage;
  JiraConnection? _currentConnection;

  List<Issue> _issues = [];
  String _issueSearchQuery = '';
  IssueFilterPeriod _filterPeriod = IssueFilterPeriod.all;
  final Set<String> _selectedIssueIds = {};

  List<LocalLog> _logs = [];
  final Set<String> _selectedLogIds = {};
  Timer? _tickerTimer;

  AppState({
    required this.store,
    required this.connectionStore,
    required this.jiraClient,
    required this.isReadOnly,
    JiraConnection? initialConnection,
    DateTime Function()? nowProvider,
  }) : _currentConnection = initialConnection,
       nowProvider = nowProvider ?? (() => DateTime.now().toUtc()) {
    _initData();
  }

  Map<String, String> _activeDraftDatesBySourceLogId = {};

  void _initData() {
    _issues = store.getIssues(scope: activeScope);
    _logs = store.getLocalLogs(scope: activeScope);
    _activeDraftDatesBySourceLogId = store.getActiveDraftDatesBySourceLogId(
      scope: activeScope,
    );
    _updateTicker();
  }

  Map<String, String> get activeDraftDatesBySourceLogId =>
      Map.unmodifiable(_activeDraftDatesBySourceLogId);

  bool isLogInDraft(String logId) =>
      _activeDraftDatesBySourceLogId.containsKey(logId);

  String? getDraftDateForLog(String logId) =>
      _activeDraftDatesBySourceLogId[logId];

  int get selectedTabIndex => _selectedTabIndex;
  String? get statusMessage => _statusMessage;
  JiraConnection? get currentConnection => _currentConnection;

  /// Активный scope (normalized baseUrl#accountId) для изоляции данных в SQLite (A17).
  String get activeScope => _currentConnection?.scope ?? 'default';

  List<Issue> get issues => List.unmodifiable(_issues);
  String get issueSearchQuery => _issueSearchQuery;
  IssueFilterPeriod get filterPeriod => _filterPeriod;
  Set<String> get selectedIssueIds => Set.unmodifiable(_selectedIssueIds);

  List<LocalLog> get logs => List.unmodifiable(_logs);
  List<LocalLog> get unconsumedLogs =>
      _logs.where((l) => !l.isConsumed).toList();
  List<LocalLog> get consumedLogs => _logs.where((l) => l.isConsumed).toList();
  Set<String> get selectedLogIds => Set.unmodifiable(_selectedLogIds);

  /// Отфильтрованный список задач по поисковому запросу и периоду давности.
  List<Issue> get filteredIssues {
    final now = nowProvider();
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

  /// Возвращает текущий привязанный лог для задачи, если он есть.
  LocalLog? getCurrentLogForIssue(String issueId) {
    final issue = _issues.where((i) => i.issueId == issueId).firstOrNull;
    if (issue?.currentLogId == null) return null;
    return _logs.where((l) => l.id == issue!.currentLogId).firstOrNull;
  }

  /// Суммарная длительность неиспользованных логов с учётом тикающих таймеров.
  int get totalUnconsumedSeconds {
    final now = nowProvider();
    int sum = 0;
    for (final log in unconsumedLogs) {
      sum += LogClock.calculateElapsed(log: log, nowUtc: now).elapsedSeconds;
    }
    return sum;
  }

  /// Суммарная длительность логов, выбранных для сборки дня.
  int get totalSelectedSeconds {
    final now = nowProvider();
    int sum = 0;
    for (final log in unconsumedLogs) {
      if (_selectedLogIds.contains(log.id)) {
        sum += LogClock.calculateElapsed(log: log, nowUtc: now).elapsedSeconds;
      }
    }
    return sum;
  }

  Future<void> loadSavedConnection() async {
    final conn = await connectionStore.getSavedConnection();
    if (conn != null) {
      _currentConnection = conn;
      await loadIssues();
      await loadLogs();
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
    await loadLogs();
    notifyListeners();
  }

  Future<void> removeConnection() async {
    await connectionStore.clearConnection();
    _currentConnection = null;
    await loadIssues();
    await loadLogs();
    notifyListeners();
  }

  // --- Задачи (Issues) ---

  Future<void> loadIssues() async {
    _issues = store.getIssues(scope: activeScope);
    notifyListeners();
  }

  Future<void> loadLogs() async {
    _logs = store.getLocalLogs(scope: activeScope);
    _activeDraftDatesBySourceLogId = store.getActiveDraftDatesBySourceLogId(
      scope: activeScope,
    );
    _updateTicker();
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
    _selectedIssueIds.clear();
    notifyListeners();
  }

  // --- Таймеры и логирование (Сценарии A01, A02, A03, A04) ---

  /// Ручной ввод времени без запуска таймера (сценарий A01).
  Future<LocalLog> addManualLog({
    required String issueId,
    required int durationSeconds,
    String description = '',
  }) async {
    if (durationSeconds <= 0) {
      throw ArgumentError('Длительность времени должна быть больше нуля');
    }

    final issue = _issues.where((i) => i.issueId == issueId).firstOrNull;
    if (issue == null) {
      throw StateError('Задача с ID $issueId не найдена в локальном каталоге');
    }

    final now = nowProvider();
    final logId = const Uuid().v4();
    final log = LocalLog(
      id: logId,
      scope: activeScope,
      issueId: issue.issueId,
      titleSnapshot: issue.summary,
      description: description.trim(),
      accumulatedSeconds: durationSeconds,
      runningSinceUtc: null,
      createdAtUtc: now,
    );

    final updatedIssue = issue.copyWith(lastUsedAtUtc: now);
    store.saveLogAndIssue(log: log, issue: updatedIssue);

    await loadIssues();
    await loadLogs();
    return log;
  }

  /// Запуск или продолжение таймера для задачи (Play, сценарии A02, A03).
  Future<LocalLog> playTimer(String issueId) async {
    final issue = _issues.where((i) => i.issueId == issueId).firstOrNull;
    if (issue == null) {
      throw StateError('Задача с ID $issueId не найдена в локальном каталоге');
    }

    final now = nowProvider();
    LocalLog? existingLog;
    if (issue.currentLogId != null) {
      existingLog = _logs.where((l) => l.id == issue.currentLogId).firstOrNull;
    }

    // Если есть текущий неиспользованный лог задачи
    if (existingLog != null && !existingLog.isConsumed) {
      if (existingLog.isRunning) {
        return existingLog; // Уже запущен
      }
      final startedLog = LogClock.start(log: existingLog, nowUtc: now);
      final updatedIssue = issue.copyWith(lastUsedAtUtc: now);
      store.saveLogAndIssue(log: startedLog, issue: updatedIssue);

      await loadIssues();
      await loadLogs();
      return startedLog;
    }

    // Создаём новый запущенный лог
    final logId = const Uuid().v4();
    final newLog = LocalLog(
      id: logId,
      scope: activeScope,
      issueId: issue.issueId,
      titleSnapshot: issue.summary,
      accumulatedSeconds: 0,
      runningSinceUtc: now,
      createdAtUtc: now,
    );

    final updatedIssue = issue.copyWith(
      currentLogId: logId,
      lastUsedAtUtc: now,
    );
    store.saveLogAndIssue(log: newLog, issue: updatedIssue);

    await loadIssues();
    await loadLogs();
    return newLog;
  }

  /// Остановка таймера задачи (Pause, сценарий A03).
  Future<LocalLog?> pauseTimer(String issueId) async {
    final issue = _issues.where((i) => i.issueId == issueId).firstOrNull;
    if (issue == null) return null;

    final currentLog = getCurrentLogForIssue(issueId);
    if (currentLog == null || !currentLog.isRunning) return currentLog;

    final now = nowProvider();
    final (pausedLog, result) = LogClock.pause(log: currentLog, nowUtc: now);

    if (result.hasClockRollback) {
      setStatusMessage(result.errorMessage);
    }

    final updatedIssue = issue.copyWith(lastUsedAtUtc: now);
    store.saveLogAndIssue(log: pausedLog, issue: updatedIssue);

    await loadIssues();
    await loadLogs();
    return pausedLog;
  }

  /// Остановка работающего лога напрямую по его ID.
  Future<LocalLog?> pauseLog(String logId) async {
    final log = _logs.where((l) => l.id == logId).firstOrNull;
    if (log == null || !log.isRunning) return log;

    final issue = _issues.where((i) => i.issueId == log.issueId).firstOrNull;
    final now = nowProvider();
    final (pausedLog, result) = LogClock.pause(log: log, nowUtc: now);

    if (result.hasClockRollback) {
      setStatusMessage(result.errorMessage);
    }

    if (issue != null) {
      final updatedIssue = issue.copyWith(lastUsedAtUtc: now);
      store.saveLogAndIssue(log: pausedLog, issue: updatedIssue);
      await loadIssues();
    } else {
      store.upsertLocalLog(pausedLog);
    }

    await loadLogs();
    return pausedLog;
  }

  /// Остановка всех активных таймеров.
  Future<void> pauseAllTimers() async {
    final running = _logs.where((l) => l.isRunning).toList();
    if (running.isEmpty) return;

    final now = nowProvider();
    for (final log in running) {
      final (pausedLog, result) = LogClock.pause(log: log, nowUtc: now);
      if (result.hasClockRollback) {
        setStatusMessage(result.errorMessage);
      }
      final issue = _issues.where((i) => i.issueId == log.issueId).firstOrNull;
      if (issue != null) {
        store.saveLogAndIssue(
          log: pausedLog,
          issue: issue.copyWith(lastUsedAtUtc: now),
        );
      } else {
        store.upsertLocalLog(pausedLog);
      }
    }
    await loadIssues();
    await loadLogs();
  }

  /// Создание нового лога для задачи (сценарий A04).
  ///
  /// Если предыдущий таймер задачи был запущен, он сохраняется и останавливается.
  /// Новая запись создаётся остановленной и привязывается как currentLogId.
  Future<LocalLog> createNewLogForIssue(String issueId) async {
    final issue = _issues.where((i) => i.issueId == issueId).firstOrNull;
    if (issue == null) {
      throw StateError('Задача с ID $issueId не найдена в локальном каталоге');
    }

    final now = nowProvider();
    final currentLog = getCurrentLogForIssue(issueId);
    final List<LocalLog> logsToSave = [];

    if (currentLog != null && currentLog.isRunning) {
      final (pausedLog, result) = LogClock.pause(log: currentLog, nowUtc: now);
      if (result.hasClockRollback) {
        setStatusMessage(result.errorMessage);
      }
      logsToSave.add(pausedLog);
    }

    final newLogId = const Uuid().v4();
    final newLog = LocalLog(
      id: newLogId,
      scope: activeScope,
      issueId: issue.issueId,
      titleSnapshot: issue.summary,
      accumulatedSeconds: 0,
      runningSinceUtc: null,
      createdAtUtc: now,
    );
    logsToSave.add(newLog);

    final updatedIssue = issue.copyWith(
      currentLogId: newLogId,
      lastUsedAtUtc: now,
    );

    store.saveLogsAndIssue(logs: logsToSave, issue: updatedIssue);

    await loadIssues();
    await loadLogs();
    return newLog;
  }

  /// Запуск таймеров на всех выбранных задачах параллельно (сценарий A02).
  Future<void> startSelectedIssues() async {
    final issueIds = _selectedIssueIds.toList();
    for (final issueId in issueIds) {
      await playTimer(issueId);
    }
    clearIssueSelection();
  }

  /// Редактирование остановленного неиспользованного лога.
  Future<void> editLog({
    required String logId,
    required int durationSeconds,
    required String description,
  }) async {
    if (durationSeconds <= 0) {
      throw ArgumentError('Длительность времени должна быть больше нуля');
    }
    final log = _logs.where((l) => l.id == logId).firstOrNull;
    if (log == null) {
      throw StateError('Лог с ID $logId не найден');
    }
    if (log.isRunning) {
      throw StateError(
        'Нельзя редактировать работающий лог. Сначала поставьте его на паузу.',
      );
    }
    if (log.isConsumed) {
      throw StateError('Нельзя редактировать уже использованный лог.');
    }
    if (isLogInDraft(logId)) {
      throw StateError(
        'Нельзя редактировать лог, уже включенный в черновик дня (${getDraftDateForLog(logId)}).',
      );
    }

    final updated = log.copyWith(
      accumulatedSeconds: durationSeconds,
      description: description.trim(),
    );
    store.upsertLocalLog(updated);
    await loadLogs();
  }

  /// Удаление остановленного лога.
  Future<void> deleteLog(String logId) async {
    final log = _logs.where((l) => l.id == logId).firstOrNull;
    if (log == null) return;
    if (log.isRunning) {
      throw StateError(
        'Нельзя удалить работающий лог. Сначала поставьте его на паузу.',
      );
    }
    if (isLogInDraft(logId)) {
      throw StateError(
        'Нельзя удалить лог, уже включенный в черновик дня (${getDraftDateForLog(logId)}).',
      );
    }
    _selectedLogIds.remove(logId);
    store.deleteLocalLog(logId);
    await loadIssues();
    await loadLogs();
  }

  /// Переключение выбора лога для сборки дня.
  void toggleLogSelection(String logId) {
    final log = _logs.where((l) => l.id == logId).firstOrNull;
    if (log == null || log.isRunning || isLogInDraft(logId)) return;

    if (_selectedLogIds.contains(logId)) {
      _selectedLogIds.remove(logId);
    } else {
      _selectedLogIds.add(logId);
    }
    notifyListeners();
  }

  void clearLogSelection() {
    _selectedLogIds.clear();
    notifyListeners();
  }

  void _updateTicker() {
    final hasRunning = _logs.any((l) => l.isRunning);
    if (hasRunning && _tickerTimer == null) {
      _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        notifyListeners();
      });
    } else if (!hasRunning && _tickerTimer != null) {
      _tickerTimer?.cancel();
      _tickerTimer = null;
    }
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

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _tickerTimer = null;
    super.dispose();
  }
}
