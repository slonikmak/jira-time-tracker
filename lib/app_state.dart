import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'agent_api_server.dart';
import 'connection_store.dart';
import 'day_builder.dart';
import 'issue_parser.dart';
import 'jira_client.dart';
import 'local_store.dart';
import 'log_clock.dart';
import 'models.dart';
import 'worklog_sender.dart';

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

enum UiThemeMode { system, light, dark }

class AgentDayRevisionConflict implements Exception {
  final String message;
  const AgentDayRevisionConflict(this.message);

  @override
  String toString() => message;
}

/// Состояние приложения, координация данных, задач, таймеров и подключений.
class AppState extends ChangeNotifier {
  final LocalStore store;
  final ConnectionStore connectionStore;
  final JiraClient jiraClient;
  final WorklogSender worklogSender;
  final bool isReadOnly;
  final DateTime Function() nowProvider;
  late final ValueNotifier<UiThemeMode> themeMode;

  int _selectedTabIndex = 0;
  String? _statusMessage;
  JiraConnection? _currentConnection;

  List<Issue> _issues = [];
  List<QuickIssue> _quickIssues = [];
  String _issueSearchQuery = '';
  IssueFilterPeriod _filterPeriod = IssueFilterPeriod.all;
  final Set<String> _selectedIssueIds = {};

  List<LocalLog> _logs = [];
  final Set<String> _selectedLogIds = {};
  Timer? _tickerTimer;
  AgentApiServer? _apiServer;

  AppState({
    required this.store,
    required this.connectionStore,
    required this.jiraClient,
    required this.isReadOnly,
    WorklogSender? worklogSender,
    JiraConnection? initialConnection,
    DateTime Function()? nowProvider,
    AgentApiServer? apiServer,
    bool autoStartApiServer = false,
  }) : _currentConnection = initialConnection,
       _apiServer = apiServer,
       nowProvider = nowProvider ?? (() => DateTime.now().toUtc()),
       worklogSender =
           worklogSender ??
           WorklogSender(
             store: store,
             jiraClient: jiraClient,
             nowProvider: nowProvider,
           ) {
    final savedThemeMode = store.getSetting('theme_mode');
    themeMode = ValueNotifier(
      UiThemeMode.values.firstWhere(
        (mode) => mode.name == savedThemeMode,
        orElse: () => UiThemeMode.system,
      ),
    );
    final savedDaySettings = store.getSetting('day_settings');
    if (savedDaySettings != null) {
      try {
        final loaded = DaySettings.fromJson(savedDaySettings);
        if (loaded.validationErrors().isEmpty) _daySettings = loaded;
      } catch (_) {
        _daySettings = const DaySettings();
      }
    }
    _initData();
    if (autoStartApiServer && !isReadOnly) {
      startApiServer();
    }
  }

  AgentApiServer? get apiServer => _apiServer;
  String? get apiServerUrl =>
      _apiServer?.isRunning == true ? _apiServer!.url : null;
  int? get apiServerPort =>
      _apiServer?.isRunning == true ? _apiServer!.port : null;
  bool get isApiServerRunning => _apiServer?.isRunning == true;

  Future<void> startApiServer({int port = 8765}) async {
    if (isReadOnly || (_apiServer != null && _apiServer!.isRunning)) return;
    _apiServer ??= AgentApiServer(appState: this, initialPort: port);
    await _apiServer!.start();
    notifyListeners();
  }

  Future<void> stopApiServer() async {
    if (_apiServer != null) {
      await _apiServer!.stop();
      _apiServer = null;
      notifyListeners();
    }
  }

  Map<String, String> _activeDraftDatesBySourceLogId = {};

  void _initData() {
    final now = nowProvider();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _issues = store.getIssues(scope: activeScope);
    _quickIssues = store.getQuickIssues(scope: activeScope);
    _logs = store.getLocalLogs(scope: activeScope);
    _activeDraftDatesBySourceLogId = store.getActiveDraftDatesBySourceLogId(
      scope: activeScope,
    );
    loadDraftForSelectedDate();
    _updateTicker();
  }

  DateTime _selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  DayDraft? _currentDraft;
  List<DraftLog> _currentDraftLogs = [];
  List<Segment> _currentSegments = [];
  List<Break> _currentBreaks = [];
  List<ImportedWorklog> _importedWorklogs = [];
  DaySettings _daySettings = const DaySettings();
  final Set<String> _lockedSourceLogIds = {};
  List<String> _validationErrors = [];
  bool _isBuildingDay = false;
  bool _isFetchingJiraWorklogs = false;
  bool _hasLoadedJiraWorklogs = false;
  bool _jiraWorklogsLoadFailed = false;
  int _jiraWorklogsRequestId = 0;
  bool _isSubmittingDay = false;

  DateTime get selectedDate => _selectedDate;
  DayDraft? get currentDraft => _currentDraft;
  List<DraftLog> get currentDraftLogs => List.unmodifiable(_currentDraftLogs);
  List<Segment> get currentSegments => List.unmodifiable(_currentSegments);
  List<Break> get currentBreaks {
    if (_currentDraft == null) return const [];
    return DayBuilder.computeTimelineGaps(
      dayStartUtc: _currentDraft!.startUtc,
      dayEndUtc: _currentDraft!.endUtc,
      segments: _currentSegments,
      existingWorklogs: _importedWorklogs,
      plannedBreaks: _currentBreaks,
      draftId: _currentDraft!.id,
    );
  }

  List<ImportedWorklog> get importedWorklogs =>
      List.unmodifiable(_importedWorklogs);
  bool get isFetchingJiraWorklogs => _isFetchingJiraWorklogs;
  bool get hasLoadedJiraWorklogs => _hasLoadedJiraWorklogs;
  bool get jiraWorklogsLoadFailed => _jiraWorklogsLoadFailed;
  bool get isSubmittingDay => _isSubmittingDay;
  DaySettings get daySettings => _daySettings;
  Set<String> get lockedSourceLogIds => Set.unmodifiable(_lockedSourceLogIds);
  List<String> get validationErrors => List.unmodifiable(_validationErrors);
  bool get isBuildingDay => _isBuildingDay;

  String get selectedDateString =>
      '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

  bool get isDraftLockedFromRebuild =>
      _currentDraft != null &&
      (_currentDraft!.status != DraftStatus.draft ||
          _currentSegments.any((s) => s.sendState == SendState.sent));

  int get totalDayDurationSeconds => _currentDraft != null
      ? _currentDraft!.endUtc.difference(_currentDraft!.startUtc).inSeconds
      : 0;

  int get totalBreaksDurationSeconds =>
      currentBreaks.fold<int>(0, (sum, b) => sum + b.durationSeconds);

  int get totalSegmentsDurationSeconds =>
      _currentSegments.fold<int>(0, (sum, s) => sum + s.durationSeconds);

  int get totalExistingDurationSeconds =>
      _importedWorklogs.fold<int>(0, (sum, ew) => sum + ew.durationSeconds);

  int get totalJiraDurationSeconds =>
      totalSegmentsDurationSeconds + totalExistingDurationSeconds;

  Map<String, String> get activeDraftDatesBySourceLogId =>
      Map.unmodifiable(_activeDraftDatesBySourceLogId);

  bool isLogInDraft(String logId) =>
      _activeDraftDatesBySourceLogId.containsKey(logId);

  String? getDraftDateForLog(String logId) =>
      _activeDraftDatesBySourceLogId[logId];

  int get selectedTabIndex => _selectedTabIndex;

  void selectThemeMode(UiThemeMode mode) {
    if (themeMode.value == mode) return;
    store.setSetting('theme_mode', mode.name);
    themeMode.value = mode;
    notifyListeners();
  }

  String? get statusMessage => _statusMessage;
  JiraConnection? get currentConnection => _currentConnection;

  /// Активный scope (normalized baseUrl#accountId) для изоляции данных в SQLite (A17).
  String get activeScope => _currentConnection?.scope ?? 'default';

  List<Issue> get issues => List.unmodifiable(_issues);
  List<QuickIssue> get quickIssues => List.unmodifiable(_quickIssues);
  String get issueSearchQuery => _issueSearchQuery;
  IssueFilterPeriod get filterPeriod => _filterPeriod;
  Set<String> get selectedIssueIds => Set.unmodifiable(_selectedIssueIds);

  List<LocalLog> get logs => List.unmodifiable(_logs);
  List<LocalLog> get unconsumedLogs =>
      _logs.where((l) => !l.isConsumed).toList();
  List<LocalLog> get consumedLogs => _logs.where((l) => l.isConsumed).toList();
  Set<String> get selectedLogIds => Set.unmodifiable(_selectedLogIds);

  /// Отфильтрованный список задач по поисковому запросу и периоду давности,
  /// отсортированный по времени недавнего взаимодействия (активные задачи первыми,
  /// затем по убыванию времени последнего действия).
  List<Issue> get filteredIssues {
    final now = nowProvider();
    final list = _issues.where((issue) {
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

    list.sort((a, b) {
      final aRunning = getCurrentLogForIssue(a.issueId)?.isRunning ?? false;
      final bRunning = getCurrentLogForIssue(b.issueId)?.isRunning ?? false;
      if (aRunning != bRunning) {
        return aRunning ? -1 : 1;
      }
      return b.lastUsedAtUtc.compareTo(a.lastUsedAtUtc);
    });

    return list;
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
      _jiraWorklogsRequestId++;
      _isFetchingJiraWorklogs = false;
      _hasLoadedJiraWorklogs = false;
      _jiraWorklogsLoadFailed = false;
      _importedWorklogs = [];
      _currentConnection = conn;
      await loadIssues();
      await loadLogs();
      loadDraftForSelectedDate();
      notifyListeners();
      if (_selectedTabIndex == 1) unawaited(fetchJiraWorklogsForDate());
      unawaited(refreshIssuesFromJira());
    }
  }

  void selectTab(int index) {
    if (_selectedTabIndex != index) {
      _selectedTabIndex = index;
      notifyListeners();
      if (index == 1) unawaited(fetchJiraWorklogsForDate());
    }
  }

  Future<void> updateConnection(JiraConnection connection, String token) async {
    await connectionStore.saveConnection(connection, token);
    _jiraWorklogsRequestId++;
    _isFetchingJiraWorklogs = false;
    _hasLoadedJiraWorklogs = false;
    _jiraWorklogsLoadFailed = false;
    _importedWorklogs = [];
    _currentConnection = connection;
    await loadIssues();
    await loadLogs();
    loadDraftForSelectedDate();
    notifyListeners();
    if (_selectedTabIndex == 1) unawaited(fetchJiraWorklogsForDate());
    unawaited(refreshIssuesFromJira());
  }

  /// Фоновое обновление сведений о задачах (название, статус) из Jira.
  Future<void> refreshIssuesFromJira() async {
    if (_currentConnection == null) return;
    final token = await connectionStore.getSavedToken();
    if (token == null || token.isEmpty) return;

    var hasChanges = false;
    for (final issue in _issues) {
      try {
        final updated = await jiraClient.getIssue(
          issue.key,
          connection: _currentConnection!,
          token: token,
        );
        final existing = store.getIssue(issue.scope, issue.issueId);
        final toSave = existing != null
            ? updated.copyWith(
                currentLogId: existing.currentLogId,
                lastUsedAtUtc: existing.lastUsedAtUtc,
              )
            : updated;
        store.upsertIssue(toSave);
        hasChanges = true;
      } catch (_) {
        // Пропускаем сетевые ошибки при фоновом обновлении
      }
    }
    if (hasChanges) {
      await loadIssues();
    }
  }

  Future<void> removeConnection() async {
    await connectionStore.clearConnection();
    _jiraWorklogsRequestId++;
    _currentConnection = null;
    _isFetchingJiraWorklogs = false;
    _hasLoadedJiraWorklogs = false;
    _jiraWorklogsLoadFailed = false;
    _importedWorklogs = [];
    await loadIssues();
    await loadLogs();
    loadDraftForSelectedDate();
    notifyListeners();
  }

  // --- Задачи (Issues) ---

  Future<void> loadIssues() async {
    _issues = store.getIssues(scope: activeScope);
    _quickIssues = store.getQuickIssues(scope: activeScope);
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

    // Сохраняем в базу данных (upsert поднимает lastUsedAtUtc, сохраняя currentLogId если был)
    final existing = store.getIssue(issue.scope, issue.issueId);
    final issueToSave = existing != null && existing.currentLogId != null
        ? issue.copyWith(currentLogId: existing.currentLogId)
        : issue;
    store.upsertIssue(issueToSave);
    await loadIssues();
    return issueToSave;
  }

  /// Проверяет Jira-задачу для предпросмотра, не сохраняя её локально.
  Future<Issue> previewQuickIssue(String rawInput) async {
    final identifier = IssueParser.parse(rawInput);
    if (identifier == null) {
      throw const FormatException(
        'Некорректный ввод: укажите ключ (PROJ-123), числовой ID или ссылку /browse/...',
      );
    }
    final connection = _currentConnection;
    if (connection == null) {
      throw StateError('Сначала подключите Jira в Настройках.');
    }
    final token = await connectionStore.getSavedToken();
    if (token == null || token.isEmpty) {
      throw StateError('API токен Jira не найден в защищённом хранилище.');
    }
    return jiraClient.getIssue(
      identifier,
      connection: connection,
      token: token,
    );
  }

  Future<QuickIssue> addQuickIssue(String rawInput, {String note = ''}) async {
    if (isReadOnly) throw StateError('Приложение открыто только для чтения.');
    final issue = await addIssue(rawInput);
    final quickIssue = store.addQuickIssue(
      QuickIssue(
        scope: issue.scope,
        issueId: issue.issueId,
        note: note.trim().isEmpty ? null : note.trim(),
        createdAtUtc: nowProvider(),
      ),
    );
    _quickIssues = store.getQuickIssues(scope: activeScope);
    notifyListeners();
    return quickIssue;
  }

  Future<void> updateQuickIssueNote(String issueId, String note) async {
    if (isReadOnly) throw StateError('Приложение открыто только для чтения.');
    store.updateQuickIssueNote(activeScope, issueId, note);
    _quickIssues = store.getQuickIssues(scope: activeScope);
    notifyListeners();
  }

  Future<void> deleteQuickIssue(String issueId) async {
    if (isReadOnly) throw StateError('Приложение открыто только для чтения.');
    store.deleteQuickIssue(activeScope, issueId);
    _quickIssues = store.getQuickIssues(scope: activeScope);
    notifyListeners();
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

  /// Поиск задачи в локальном кэше, Jira или создание локального fallback.
  Future<Issue> resolveOrCreateIssue(String keyOrId) async {
    final clean = keyOrId.trim();
    if (clean.isEmpty) {
      throw ArgumentError('Ключ или ID задачи не может быть пустым');
    }

    final cached = _issues
        .where(
          (i) =>
              i.key.toUpperCase() == clean.toUpperCase() || i.issueId == clean,
        )
        .firstOrNull;
    if (cached != null) return cached;

    // Если есть подключение к Jira — запрашиваем в Jira
    final conn = _currentConnection;
    if (conn != null) {
      final token = await connectionStore.getSavedToken();
      if (token != null && token.isNotEmpty) {
        try {
          final fetched = await jiraClient.getIssue(
            clean,
            connection: conn,
            token: token,
          );
          store.upsertIssue(fetched);
          await loadIssues();
          return fetched;
        } catch (_) {
          // Игнорируем ошибку сети для создания локального fallback
        }
      }
    }

    // Локальный fallback (для оффлайн-режима или изолированных тестов)
    final fallback = Issue(
      scope: activeScope,
      issueId: clean,
      key: clean,
      summary: clean,
      lastUsedAtUtc: nowProvider(),
    );
    store.upsertIssue(fallback);
    await loadIssues();
    return fallback;
  }

  /// Resolves an Agent API issue reference without creating an offline fallback.
  Future<Issue> resolveIssueStrict(String keyOrId) async {
    final clean = keyOrId.trim();
    if (clean.isEmpty) {
      throw ArgumentError('Ключ или ID задачи не может быть пустым');
    }

    final cached = store
        .getIssues(scope: activeScope)
        .where(
          (issue) =>
              issue.key.toUpperCase() == clean.toUpperCase() ||
              issue.issueId == clean,
        )
        .firstOrNull;
    if (cached != null) return cached;

    final connection = _currentConnection;
    final token = await connectionStore.getSavedToken();
    if (connection == null || token == null || token.isEmpty) {
      throw StateError(
        'Задача "$clean" отсутствует в локальном каталоге, подключение к Jira недоступно.',
      );
    }

    final issue = await jiraClient.getIssue(
      clean,
      connection: connection,
      token: token,
    );
    store.upsertIssue(issue);
    await loadIssues();
    return issue;
  }

  List<Issue> searchIssuesLocally(String query) {
    final normalized = query.trim().toLowerCase();
    final issues = store.getIssues(scope: activeScope);
    if (normalized.isEmpty) return issues;
    return issues
        .where(
          (issue) =>
              issue.key.toLowerCase().contains(normalized) ||
              issue.summary.toLowerCase().contains(normalized) ||
              (issue.status?.toLowerCase().contains(normalized) ?? false),
        )
        .toList();
  }

  // --- Таймеры и логирование (Сценарии A01, A02, A03, A04) ---

  /// Ручной ввод времени без запуска таймера (сценарий A01).
  Future<LocalLog> addManualLog({
    required String issueId,
    required int durationSeconds,
    String description = '',
    String? fixedStartTime,
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
      isManual: true,
      fixedStartTime: fixedStartTime,
    );

    final updatedIssue = issue.copyWith(lastUsedAtUtc: now);
    store.saveLogAndIssue(log: log, issue: updatedIssue);

    await loadIssues();
    await loadLogs();
    return log;
  }

  /// Запуск таймера для задачи (Start, сценарии A02, A03).
  ///
  /// Каждый запуск начинает отдельную новую запись с нуля (упрощённая модель старт/стоп).
  /// Если на этой задаче таймер уже работает, повторный вызов не создаёт дубликат.
  Future<LocalLog> playTimer(String issueId) async {
    final issue = _issues.where((i) => i.issueId == issueId).firstOrNull;
    if (issue == null) {
      throw StateError('Задача с ID $issueId не найдена в локальном каталоге');
    }

    final currentLog = getCurrentLogForIssue(issueId);
    if (currentLog != null && currentLog.isRunning) {
      return currentLog; // Уже запущен
    }

    final now = nowProvider();
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

  /// Остановка таймера задачи (Stop, сценарий A03).
  ///
  /// Завершает текущий лог, фиксирует накопленное время в очереди логов
  /// и отвязывает лог от карточки задачи (счётчик карточки сбрасывается в 00:00:00).
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

    final updatedIssue = issue.copyWith(
      clearCurrentLogId: true,
      lastUsedAtUtc: now,
    );
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
      final shouldClearCurrent = issue.currentLogId == log.id;
      final updatedIssue = issue.copyWith(
        clearCurrentLogId: shouldClearCurrent,
        lastUsedAtUtc: now,
      );
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
        final shouldClearCurrent = issue.currentLogId == log.id;
        store.saveLogAndIssue(
          log: pausedLog,
          issue: issue.copyWith(
            clearCurrentLogId: shouldClearCurrent,
            lastUsedAtUtc: now,
          ),
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
    String? fixedStartTime,
    bool clearFixedStartTime = false,
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
      fixedStartTime: fixedStartTime,
      clearFixedStartTime: clearFixedStartTime,
    );
    store.upsertLocalLog(updated);
    await loadLogs();
  }

  /// Разбиение неиспользованного лога на две части.
  Future<(LocalLog, LocalLog)> splitLog({
    required String logId,
    required int part1DurationSeconds,
    String? part1Description,
    String? part2Description,
  }) async {
    final log = _logs.where((l) => l.id == logId).firstOrNull;
    if (log == null) {
      throw StateError('Лог с ID $logId не найден');
    }
    if (log.isRunning) {
      throw StateError(
        'Нельзя разбить работающий лог. Сначала остановите его.',
      );
    }
    if (log.isConsumed) {
      throw StateError('Нельзя разбить уже использованный лог.');
    }
    if (isLogInDraft(logId)) {
      throw StateError('Нельзя разбить лог, уже включенный в черновик дня.');
    }
    if (part1DurationSeconds <= 0 ||
        part1DurationSeconds >= log.accumulatedSeconds) {
      throw ArgumentError(
        'Длительность первой части должна быть больше 0 и меньше общей длительности (${log.accumulatedSeconds} с)',
      );
    }

    final part2DurationSeconds = log.accumulatedSeconds - part1DurationSeconds;

    final log1 = log.copyWith(
      accumulatedSeconds: part1DurationSeconds,
      description: (part1Description ?? log.description).trim(),
    );

    final log2Id = const Uuid().v4();
    final log2 = LocalLog(
      id: log2Id,
      scope: log.scope,
      issueId: log.issueId,
      titleSnapshot: log.titleSnapshot,
      description: (part2Description ?? log.description).trim(),
      accumulatedSeconds: part2DurationSeconds,
      runningSinceUtc: null,
      createdAtUtc: log.createdAtUtc.add(const Duration(milliseconds: 1)),
      isManual: log.isManual,
      fixedStartTime: null,
    );

    store.upsertLocalLog(log1);
    store.upsertLocalLog(log2);

    await loadLogs();
    return (log1, log2);
  }

  /// Объединение нескольких неиспользованных логов в один.
  Future<LocalLog> mergeLogs({
    required List<String> logIds,
    String? targetIssueId,
    String? description,
  }) async {
    if (logIds.length < 2) {
      throw ArgumentError('Для объединения требуется минимум два лога');
    }
    final selected = _logs.where((l) => logIds.contains(l.id)).toList();
    if (selected.length != logIds.length) {
      throw StateError('Некоторые из указанных логов не найдены');
    }
    if (selected.any((l) => l.isRunning)) {
      throw StateError('Нельзя объединять работающие логи.');
    }
    if (selected.any((l) => l.isConsumed || isLogInDraft(l.id))) {
      throw StateError(
        'Нельзя объединять логи, уже включенные в черновик дня.',
      );
    }

    final primaryLog = selected.first;
    final effectiveIssueId = targetIssueId ?? primaryLog.issueId;
    final issue = _issues
        .where((i) => i.issueId == effectiveIssueId)
        .firstOrNull;

    final totalSeconds = selected.fold<int>(
      0,
      (sum, l) => sum + l.accumulatedSeconds,
    );
    final combinedDesc =
        description?.trim() ??
        selected
            .map((l) => l.description.trim())
            .where((d) => d.isNotEmpty)
            .toSet()
            .join('\n');

    final mergedLog = primaryLog.copyWith(
      issueId: effectiveIssueId,
      titleSnapshot: issue?.summary ?? primaryLog.titleSnapshot,
      accumulatedSeconds: totalSeconds,
      description: combinedDesc,
    );

    store.upsertLocalLog(mergedLog);

    for (final other in selected.skip(1)) {
      _selectedLogIds.remove(other.id);
      store.deleteLocalLog(other.id);
    }

    await loadIssues();
    await loadLogs();
    return mergedLog;
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

  bool canRemoveLogFromDraft(String logId) {
    final date = getDraftDateForLog(logId);
    if (date == null) return false;
    final draft = store.getDayDraft(scope: activeScope, date: date);
    if (draft == null || draft.status != DraftStatus.draft) return false;
    return store
        .getSegments(draftId: draft.id)
        .every((segment) => segment.sendState == SendState.pending);
  }

  void removeLogFromDraft(String logId) {
    final date = getDraftDateForLog(logId);
    if (date == null) return;
    final draft = store.getDayDraft(scope: activeScope, date: date);
    if (draft == null) return;

    store.removeLogFromDraft(draftId: draft.id, sourceLogId: logId);
    _activeDraftDatesBySourceLogId = store.getActiveDraftDatesBySourceLogId(
      scope: activeScope,
    );
    if (date == selectedDateString) {
      loadDraftForSelectedDate();
    } else {
      notifyListeners();
    }
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

  void setSelectedDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    _hasLoadedJiraWorklogs = false;
    _jiraWorklogsLoadFailed = false;
    _importedWorklogs = [];
    loadDraftForSelectedDate();
    unawaited(fetchJiraWorklogsForDate());
  }

  Future<void> fetchJiraWorklogsForDate() async {
    final requestId = ++_jiraWorklogsRequestId;
    final requestedDate = _selectedDate;
    final requestedScope = activeScope;
    if (_currentConnection == null) {
      _isFetchingJiraWorklogs = false;
      notifyListeners();
      return;
    }

    _isFetchingJiraWorklogs = true;
    _jiraWorklogsLoadFailed = false;
    if (_statusMessage?.startsWith('Ошибка загрузки записей Jira:') == true) {
      _statusMessage = null;
    }
    notifyListeners();

    try {
      final logs = await fetchJiraWorklogsForDateScoped(requestedDate);
      if (requestId != _jiraWorklogsRequestId ||
          requestedDate != _selectedDate ||
          requestedScope != activeScope) {
        return;
      }

      _importedWorklogs = logs;
      _hasLoadedJiraWorklogs = true;
      if (_statusMessage?.startsWith('Ошибка загрузки записей Jira:') == true) {
        _statusMessage = null;
      }

      if (_currentDraft != null) {
        _currentDraft = _currentDraft!.copyWith(
          importedWorklogsSnapshot: jsonEncode(
            _importedWorklogs.map((e) => e.toMap()).toList(),
          ),
        );
        store.updateDayDraft(_currentDraft!);
      }

      _revalidateCurrentPlan();
    } catch (e) {
      if (requestId == _jiraWorklogsRequestId) {
        _jiraWorklogsLoadFailed = true;
        _statusMessage = 'Ошибка загрузки записей Jira: $e';
      }
    } finally {
      if (requestId == _jiraWorklogsRequestId) {
        _isFetchingJiraWorklogs = false;
        notifyListeners();
      }
    }
  }

  /// Reads a Jira day without changing the date or draft currently shown in UI.
  Future<List<ImportedWorklog>> fetchJiraWorklogsForDateScoped(
    DateTime date,
  ) async {
    final connection = _currentConnection;
    final token = await connectionStore.getSavedToken();
    if (connection == null || token == null || token.isEmpty) {
      throw StateError(
        'Нет активного подключения к Jira для загрузки worklogs.',
      );
    }

    return jiraClient.fetchDayWorklogs(
      date: DateTime(date.year, date.month, date.day),
      timeZoneOffset: DateTime(
        date.year,
        date.month,
        date.day,
        12,
      ).timeZoneOffset,
      connection: connection,
      token: token,
      additionalIssueIds: [
        ...store.getIssues(scope: activeScope).map((issue) => issue.issueId),
        ...store.getLocalLogs(scope: activeScope).map((log) => log.issueId),
      ],
    );
  }

  /// Reads all Jira worklogs visible on one issue without changing the UI day.
  Future<(Issue, List<ImportedWorklog>, String)> fetchJiraWorklogsForIssue(
    String issueRef,
  ) async {
    final parsed = IssueParser.parse(issueRef);
    if (parsed == null) {
      throw ArgumentError('Ожидается ключ или числовой ID задачи Jira.');
    }
    final connection = _currentConnection;
    final token = await connectionStore.getSavedToken();
    if (connection == null || token == null || token.isEmpty) {
      throw StateError(
        'Нет активного подключения к Jira для загрузки worklogs.',
      );
    }
    final issue = await resolveIssueStrict(parsed);
    final worklogs =
        await jiraClient.getIssueWorklogs(
            issueIdOrKey: issue.issueId,
            issueKey: issue.key,
            connection: connection,
            token: token,
          )
          ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
    return (issue, worklogs, connection.accountId);
  }

  /// Reads fresh issue details; the local issue cache is not used for content.
  Future<Map<String, dynamic>> fetchJiraIssueDetails(String issueRef) async {
    final parsed = IssueParser.parse(issueRef);
    if (parsed == null) {
      throw ArgumentError('Ожидается ключ или числовой ID задачи Jira.');
    }
    final connection = _currentConnection;
    final token = await connectionStore.getSavedToken();
    if (connection == null || token == null || token.isEmpty) {
      throw StateError('Нет активного подключения к Jira.');
    }
    return jiraClient.getIssueDetails(
      issueIdOrKey: parsed,
      connection: connection,
      token: token,
    );
  }

  Future<(Map<String, dynamic>, http.StreamedResponse)> downloadJiraAttachment(
    String issueRef,
    String attachmentId,
  ) async {
    final parsed = IssueParser.parse(issueRef);
    if (parsed == null || !RegExp(r'^\d+$').hasMatch(attachmentId)) {
      throw ArgumentError('Ожидается ключ задачи Jira и числовой ID вложения.');
    }
    final connection = _currentConnection;
    final token = await connectionStore.getSavedToken();
    if (connection == null || token == null || token.isEmpty) {
      throw StateError('Нет активного подключения к Jira.');
    }
    return jiraClient.downloadIssueAttachment(
      issueIdOrKey: parsed,
      attachmentId: attachmentId,
      connection: connection,
      token: token,
    );
  }

  void previousDay() {
    setSelectedDate(_selectedDate.subtract(const Duration(days: 1)));
  }

  void nextDay() {
    setSelectedDate(_selectedDate.add(const Duration(days: 1)));
  }

  void today() {
    final now = DateTime.now();
    setSelectedDate(DateTime(now.year, now.month, now.day));
  }

  void updateDaySettings(DaySettings settings) {
    final errors = settings.validationErrors();
    if (errors.isNotEmpty) {
      throw ArgumentError(errors.values.join('\n'));
    }
    store.setSetting('day_settings', settings.toJson());
    _daySettings = settings;
    notifyListeners();
  }

  void toggleLogLock(String sourceLogId) {
    if (_lockedSourceLogIds.contains(sourceLogId)) {
      _lockedSourceLogIds.remove(sourceLogId);
    } else {
      _lockedSourceLogIds.add(sourceLogId);
    }
    notifyListeners();
  }

  void loadDraftForSelectedDate() {
    final draft = store.getDayDraft(
      scope: activeScope,
      date: selectedDateString,
    );

    if (draft != null) {
      _currentDraft = draft;
      _currentDraftLogs = store.getDraftLogs(draftId: draft.id);
      _currentSegments = store.getSegments(draftId: draft.id);
      _currentBreaks = store.getBreaks(draftId: draft.id);
      _selectedLogIds.clear();
      _selectedLogIds.addAll(_currentDraftLogs.map((dl) => dl.sourceLogId));

      _lockedSourceLogIds.clear();
      for (final dl in _currentDraftLogs) {
        if (dl.durationLocked) {
          _lockedSourceLogIds.add(dl.sourceLogId);
        }
      }

      try {
        final list = jsonDecode(draft.importedWorklogsSnapshot) as List;
        _importedWorklogs = list
            .map((m) => ImportedWorklog.fromMap(m as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _importedWorklogs = [];
      }

      _revalidateCurrentPlan();
    } else {
      _currentDraft = null;
      _currentDraftLogs = [];
      _currentSegments = [];
      _currentBreaks = [];
      _validationErrors = [];
      _selectedLogIds.clear();
    }
    notifyListeners();
  }

  void setImportedWorklogs(List<ImportedWorklog> worklogs) {
    _importedWorklogs = List.from(worklogs);
    _revalidateCurrentPlan();
    notifyListeners();
  }

  void _revalidateCurrentPlan() {
    if (_currentDraft == null) {
      _validationErrors = [];
      return;
    }

    final plan = DayPlanResult(
      dayStartUtc: _currentDraft!.startUtc,
      dayEndUtc: _currentDraft!.endUtc,
      segments: _currentSegments,
      breaks: currentBreaks,
      allocatedSecondsBySourceLogId: {},
      totalNewWorkSeconds: totalSegmentsDurationSeconds,
      totalBreaksSeconds: totalBreaksDurationSeconds,
      totalExistingSeconds: totalExistingDurationSeconds,
      totalDaySeconds: totalDayDurationSeconds,
    );

    _validationErrors = DayBuilder.validate(
      plan: plan,
      existingWorklogs: _importedWorklogs,
      requirePauses: _currentBreaks.isNotEmpty,
      allowWorklogOverlaps: true,
    );
  }

  Future<void> smartRebuildDay({int? customSeed}) =>
      buildDay(customSeed: customSeed, smart: true);

  Future<void> buildDay({int? customSeed, bool smart = false}) async {
    if (isDraftLockedFromRebuild) {
      throw StateError(
        'Нельзя пересобрать частично или полностью отправленный день.',
      );
    }

    _isBuildingDay = true;
    notifyListeners();

    try {
      final builderLogs = <DayBuilderLogInput>[];

      if (_selectedLogIds.isNotEmpty) {
        // Пользователь явно выбрал логи: всегда собираем день ровно из выбранных
        final candidates = _logs
            .where((l) => _selectedLogIds.contains(l.id))
            .toList();

        if (candidates.isEmpty) {
          throw const DayBuilderException(
            'Не выбрано ни одного лога для сборки дня.',
          );
        }

        for (final c in candidates) {
          if (c.isRunning) {
            throw const DayBuilderException(
              'Работающий лог нельзя включить в черновик дня.',
            );
          }
          if (isLogInDraft(c.id) &&
              getDraftDateForLog(c.id) != selectedDateString) {
            throw DayBuilderException(
              'Лог ${c.titleSnapshot} уже включен в черновик на дату ${getDraftDateForLog(c.id)}.',
            );
          }
          final origStart = c.isManual
              ? c.createdAtUtc.subtract(Duration(seconds: c.accumulatedSeconds))
              : c.createdAtUtc;
          final origEnd = c.isManual
              ? c.createdAtUtc
              : c.createdAtUtc.add(Duration(seconds: c.accumulatedSeconds));

          builderLogs.add(
            DayBuilderLogInput(
              sourceLogId: c.id,
              issueId: c.issueId,
              titleSnapshot: c.titleSnapshot,
              description: c.description,
              sourceDurationSeconds: c.accumulatedSeconds,
              durationLocked: _lockedSourceLogIds.contains(c.id),
              originalStartUtc: origStart,
              originalEndUtc: origEnd,
            ),
          );
        }
      } else if (_currentDraft != null && _currentDraftLogs.isNotEmpty) {
        // Пересборка существующего черновика (без изменения состава логов): сохраняем привязанные логи
        for (final dl in _currentDraftLogs) {
          final isLocked = _lockedSourceLogIds.contains(dl.sourceLogId);
          final srcLog = _logs.firstWhere(
            (l) => l.id == dl.sourceLogId,
            orElse: () => LocalLog(
              id: dl.sourceLogId,
              scope: activeScope,
              issueId: '',
              titleSnapshot: '',
              accumulatedSeconds: dl.sourceDurationSeconds,
              createdAtUtc: DateTime.now().toUtc(),
            ),
          );
          final origStart = srcLog.isManual
              ? srcLog.createdAtUtc.subtract(
                  Duration(seconds: dl.sourceDurationSeconds),
                )
              : srcLog.createdAtUtc;
          final origEnd = srcLog.isManual
              ? srcLog.createdAtUtc
              : srcLog.createdAtUtc.add(
                  Duration(seconds: dl.sourceDurationSeconds),
                );

          builderLogs.add(
            DayBuilderLogInput(
              sourceLogId: dl.sourceLogId,
              issueId: srcLog.issueId,
              titleSnapshot: srcLog.titleSnapshot,
              description: dl.descriptionSnapshot,
              sourceDurationSeconds: dl.sourceDurationSeconds,
              durationLocked: isLocked,
              originalStartUtc: origStart,
              originalEndUtc: origEnd,
            ),
          );
        }
      } else {
        // Первая сборка без выбора: берём все свободные неработающие логи из очереди
        final candidates = unconsumedLogs.where((l) => !l.isRunning).toList();

        if (candidates.isEmpty) {
          throw const DayBuilderException(
            'Не выбрано ни одного лога для сборки дня.',
          );
        }

        for (final c in candidates) {
          if (c.isRunning) {
            throw const DayBuilderException(
              'Работающий лог нельзя включить в черновик дня.',
            );
          }
          if (isLogInDraft(c.id) &&
              getDraftDateForLog(c.id) != selectedDateString) {
            throw DayBuilderException(
              'Лог ${c.titleSnapshot} уже включен в черновик на дату ${getDraftDateForLog(c.id)}.',
            );
          }
          final origStart = c.isManual
              ? c.createdAtUtc.subtract(Duration(seconds: c.accumulatedSeconds))
              : c.createdAtUtc;
          final origEnd = c.isManual
              ? c.createdAtUtc
              : c.createdAtUtc.add(Duration(seconds: c.accumulatedSeconds));

          builderLogs.add(
            DayBuilderLogInput(
              sourceLogId: c.id,
              issueId: c.issueId,
              titleSnapshot: c.titleSnapshot,
              description: c.description,
              sourceDurationSeconds: c.accumulatedSeconds,
              durationLocked: _lockedSourceLogIds.contains(c.id),
              originalStartUtc: origStart,
              originalEndUtc: origEnd,
              isFixed: c.fixedStartTime != null && c.fixedStartTime!.isNotEmpty,
              fixedStartTime: c.fixedStartTime,
            ),
          );
        }
      }

      final seed = customSeed ?? Random().nextInt(1000000000);
      final draftId = _currentDraft?.id ?? const Uuid().v4();

      final input = DayBuilderInput(
        localDate: _selectedDate,
        timeZoneOffset: DateTime.now().timeZoneOffset,
        settings: _daySettings,
        logs: builderLogs,
        existingWorklogs: _importedWorklogs,
        draftId: draftId,
      );

      final DayPlanResult plan;
      if (smart) {
        plan = DayBuilder.build(input: input, seed: seed);
      } else {
        plan = DayBuilder.buildAsRecorded(input: input);
      }

      final newDraft = DayDraft(
        id: draftId,
        scope: activeScope,
        date: selectedDateString,
        startUtc: plan.dayStartUtc,
        endUtc: plan.dayEndUtc,
        seed: seed,
        settingsSnapshot: _daySettings.toJson(),
        importedWorklogsSnapshot: jsonEncode(
          _importedWorklogs.map((e) => e.toMap()).toList(),
        ),
        status: DraftStatus.draft,
      );

      final newDraftLogs = builderLogs
          .map(
            (b) => DraftLog(
              draftId: draftId,
              sourceLogId: b.sourceLogId,
              sourceDurationSeconds: b.sourceDurationSeconds,
              descriptionSnapshot: b.description,
              durationLocked: b.durationLocked,
            ),
          )
          .toList();

      store.saveDayDraft(
        draft: newDraft,
        draftLogs: newDraftLogs,
        segments: plan.segments,
        breaks: plan.breaks,
      );

      _currentDraft = newDraft;
      _currentDraftLogs = newDraftLogs;
      _currentSegments = plan.segments;
      _currentBreaks = plan.breaks;
      _activeDraftDatesBySourceLogId = store.getActiveDraftDatesBySourceLogId(
        scope: activeScope,
      );
      _revalidateCurrentPlan();
      _selectedLogIds.clear();
      _selectedLogIds.addAll(newDraftLogs.map((dl) => dl.sourceLogId));
      _statusMessage = smart
          ? 'День успешно пересобран (умная пересборка).'
          : 'День успешно собран.';
    } finally {
      _isBuildingDay = false;
      notifyListeners();
    }
  }

  /// Применение и сохранение готового плана дня, построенного внешним AI-агентом.
  Future<DayDraft> applyAgentDayPlan({
    required DateTime targetDate,
    required List<AgentSegmentInput> inputSegments,
    required List<ImportedWorklog> existingWorklogs,
    String? baseRevision,
  }) async {
    if (inputSegments.isEmpty) {
      throw ArgumentError('Список сегментов не может быть пустым.');
    }

    final localDate = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );
    final dateStr =
        '${localDate.year.toString().padLeft(4, '0')}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';
    final targetDraft = store.getDayDraft(scope: activeScope, date: dateStr);
    final targetSegments = targetDraft == null
        ? const <Segment>[]
        : store.getSegments(draftId: targetDraft.id);
    if (targetDraft != null) {
      if (targetDraft.status != DraftStatus.draft ||
          targetSegments.any((s) => s.sendState != SendState.pending)) {
        throw const AgentDayRevisionConflict(
          'Нельзя заменить черновик после начала отправки дня.',
        );
      }
      if (baseRevision == null ||
          baseRevision != dayDraftRevision(targetDraft)) {
        throw const AgentDayRevisionConflict(
          'Черновик дня изменился после чтения. Получите актуальный snapshot и повторите запись.',
        );
      }
    }

    final draftId = targetDraft?.id ?? const Uuid().v4();
    final activeDraftDates = store.getActiveDraftDatesBySourceLogId(
      scope: activeScope,
    );
    final builtSegments = <Segment>[];
    final draftLogsBySourceId = <String, DraftLog>{};
    final availableIssues = {
      for (final issue in store.getIssues(scope: activeScope))
        issue.issueId: issue,
    };

    for (var i = 0; i < inputSegments.length; i++) {
      final input = inputSegments[i];
      final sourceLog = store.getLocalLog(input.sourceLogId);
      if (sourceLog == null || sourceLog.scope != activeScope) {
        throw ArgumentError('Источник "${input.sourceLogId}" не найден.');
      }
      if (sourceLog.isRunning) {
        throw ArgumentError(
          'Работающий источник "${sourceLog.id}" нельзя включить в день.',
        );
      }
      if (sourceLog.isConsumed) {
        throw ArgumentError(
          'Отправленный источник "${sourceLog.id}" нельзя включить повторно.',
        );
      }
      if (sourceLog.accumulatedSeconds <= 0) {
        throw ArgumentError(
          'Источник "${sourceLog.id}" не содержит записанного времени.',
        );
      }
      final reservedDate = activeDraftDates[sourceLog.id];
      if (reservedDate != null && reservedDate != dateStr) {
        throw ArgumentError(
          'Источник "${sourceLog.id}" уже включён в черновик на дату $reservedDate.',
        );
      }
      final issue = availableIssues[sourceLog.issueId];
      if (issue == null) {
        throw StateError(
          'В локальном каталоге не найдена задача источника ${sourceLog.id}.',
        );
      }
      if (input.issueKey != null &&
          input.issueKey!.toUpperCase() != issue.key.toUpperCase() &&
          input.issueKey != issue.issueId) {
        throw ArgumentError(
          'Задача "${input.issueKey}" не соответствует источнику ${sourceLog.id} (${issue.key}).',
        );
      }
      if (input.durationSeconds <= 0) {
        throw ArgumentError('Длительность сегмента должна быть больше нуля.');
      }
      final localStart = input.startUtc.toLocal();
      if (localStart.year != localDate.year ||
          localStart.month != localDate.month ||
          localStart.day != localDate.day) {
        throw ArgumentError(
          'Начало сегмента должно попадать в целевую дату $dateStr.',
        );
      }
      final nextLocalMidnight = DateTime(
        localDate.year,
        localDate.month,
        localDate.day + 1,
      ).toUtc();
      if (input.startUtc
          .add(Duration(seconds: input.durationSeconds))
          .isAfter(nextLocalMidnight)) {
        throw ArgumentError(
          'Сегмент должен полностью помещаться в целевую дату $dateStr.',
        );
      }

      draftLogsBySourceId.putIfAbsent(
        sourceLog.id,
        () => DraftLog(
          draftId: draftId,
          sourceLogId: sourceLog.id,
          sourceDurationSeconds: sourceLog.accumulatedSeconds,
          descriptionSnapshot: sourceLog.description,
          durationLocked: true,
        ),
      );

      builtSegments.add(
        Segment(
          id: const Uuid().v4(),
          draftId: draftId,
          sourceLogId: sourceLog.id,
          issueId: sourceLog.issueId,
          startUtc: input.startUtc,
          durationSeconds: input.durationSeconds,
          description: input.description.isNotEmpty
              ? input.description
              : sourceLog.description,
          sendState: SendState.pending,
          isFixed: input.isFixed,
        ),
      );
    }

    // Сортируем сегменты по времени начала
    builtSegments.sort((a, b) => a.startUtc.compareTo(b.startUtc));

    final occupiedStarts = <DateTime>[
      ...builtSegments.map((segment) => segment.startUtc),
      ...existingWorklogs.map((worklog) => worklog.startUtc),
    ];
    final occupiedEnds = <DateTime>[
      ...builtSegments.map((segment) => segment.endUtc),
      ...existingWorklogs.map((worklog) => worklog.endUtc),
    ];
    final dayStartUtc = occupiedStarts.reduce((a, b) => a.isBefore(b) ? a : b);
    final dayEndUtc = occupiedEnds.reduce((a, b) => a.isAfter(b) ? a : b);

    // Вычисляем зазоры (паузы)
    final breaks = DayBuilder.computeTimelineGaps(
      dayStartUtc: dayStartUtc,
      dayEndUtc: dayEndUtc,
      segments: builtSegments,
      existingWorklogs: existingWorklogs,
      draftId: draftId,
    );

    final totalNewWork = builtSegments.fold<int>(
      0,
      (sum, s) => sum + s.durationSeconds,
    );
    final totalBreaks = breaks.fold<int>(
      0,
      (sum, b) => sum + b.durationSeconds,
    );
    final totalExisting = existingWorklogs.fold<int>(
      0,
      (sum, e) => sum + e.durationSeconds,
    );

    final plan = DayPlanResult(
      dayStartUtc: dayStartUtc,
      dayEndUtc: dayEndUtc,
      segments: builtSegments,
      breaks: breaks,
      allocatedSecondsBySourceLogId: {},
      totalNewWorkSeconds: totalNewWork,
      totalBreaksSeconds: totalBreaks,
      totalExistingSeconds: totalExisting,
      totalDaySeconds: dayEndUtc.difference(dayStartUtc).inSeconds,
    );

    // Валидация расписания
    final validationErrors = DayBuilder.validate(
      plan: plan,
      existingWorklogs: existingWorklogs,
      requirePauses: false,
      allowWorklogOverlaps: true,
    );

    if (validationErrors.isNotEmpty) {
      throw DayBuilderException(validationErrors.join('; '));
    }

    final newDraft = DayDraft(
      id: draftId,
      scope: activeScope,
      date: dateStr,
      startUtc: dayStartUtc,
      endUtc: dayEndUtc,
      seed: 0,
      settingsSnapshot: _daySettings.toJson(),
      importedWorklogsSnapshot: jsonEncode(
        existingWorklogs.map((e) => e.toMap()).toList(),
      ),
      status: DraftStatus.draft,
    );

    // Повторная проверка непосредственно перед транзакционной заменой snapshot.
    final currentTarget = store.getDayDraft(scope: activeScope, date: dateStr);
    if (targetDraft == null && currentTarget != null ||
        targetDraft != null &&
            (currentTarget == null ||
                currentTarget.id != targetDraft.id ||
                baseRevision != dayDraftRevision(currentTarget) ||
                currentTarget.status != DraftStatus.draft ||
                store
                    .getSegments(draftId: currentTarget.id)
                    .any((s) => s.sendState != SendState.pending))) {
      throw const AgentDayRevisionConflict(
        'Черновик дня изменился во время подготовки snapshot. Получите актуальный snapshot и повторите запись.',
      );
    }

    store.saveDayDraft(
      draft: newDraft,
      draftLogs: draftLogsBySourceId.values.toList(),
      segments: builtSegments,
      breaks: breaks,
    );

    _selectedDate = localDate;
    _importedWorklogs = List.from(existingWorklogs);
    await loadLogs();
    loadDraftForSelectedDate();
    notifyListeners();

    return newDraft;
  }

  String dayDraftRevision(DayDraft draft) {
    final payload = jsonEncode({
      'draft': draft.toMap(),
      'draft_logs':
          store
              .getDraftLogs(draftId: draft.id)
              .map((log) => log.toMap())
              .toList()
            ..sort(
              (a, b) => (a['source_log_id'] as String).compareTo(
                b['source_log_id'] as String,
              ),
            ),
      'segments':
          store
              .getSegments(draftId: draft.id)
              .map((segment) => segment.toMap())
              .toList()
            ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String)),
      'breaks':
          store
              .getBreaks(draftId: draft.id)
              .map((item) => item.toMap())
              .toList()
            ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String)),
    });
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(payload)) {
      hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  void updateSegment({
    required String segmentId,
    required DateTime startUtc,
    required int durationSeconds,
    required String description,
  }) {
    if (_currentDraft == null) return;
    if (isReadOnly) throw StateError('Приложение открыто только для чтения.');
    final idx = _currentSegments.indexWhere((s) => s.id == segmentId);
    if (idx == -1) return;

    final oldSegment = _currentSegments[idx];
    if (oldSegment.sendState == SendState.sent ||
        oldSegment.sendState == SendState.unknown ||
        oldSegment.sendState == SendState.sending) {
      throw StateError(
        'Этот интервал уже отправлен или ожидает сверки с Jira.',
      );
    }
    if (durationSeconds <= 0) {
      throw ArgumentError('Длительность должна быть больше 0 минут.');
    }
    final updatedSegment = oldSegment.copyWith(
      startUtc: startUtc,
      durationSeconds: durationSeconds,
      description: description,
    );

    // Сохраняем расстояния между последующими записями и их длительности.
    // Порядок списка не меняем: пользователь мог переставить строки перед пересборкой.
    final delta = updatedSegment.endUtc.difference(oldSegment.endUtc);
    final segments = <Segment>[];
    for (final segment in _currentSegments) {
      if (segment.id == oldSegment.id) {
        segments.add(updatedSegment);
      } else if (delta != Duration.zero &&
          !segment.startUtc.isBefore(oldSegment.endUtc)) {
        if (segment.isFixed || segment.sendState != SendState.pending) {
          throw ArgumentError(
            'Следующий интервал закреплён или уже отправлялся. Сдвиг невозможен.',
          );
        }
        segments.add(segment.copyWith(startUtc: segment.startUtc.add(delta)));
      } else {
        segments.add(segment);
      }
    }
    final breaks = [
      for (final item in _currentBreaks)
        if (delta != Duration.zero &&
            !item.startUtc.isBefore(oldSegment.endUtc))
          item.copyWith(startUtc: item.startUtc.add(delta))
        else
          item,
    ];

    var dayStart = _currentDraft!.startUtc;
    var dayEnd = _currentDraft!.endUtc;
    for (final segment in segments) {
      if (segment.startUtc.isBefore(dayStart)) dayStart = segment.startUtc;
      if (segment.endUtc.isAfter(dayEnd)) dayEnd = segment.endUtc;
    }
    for (final item in breaks) {
      if (item.endUtc.isAfter(dayEnd)) dayEnd = item.endUtc;
    }
    final draft = _currentDraft!.copyWith(startUtc: dayStart, endUtc: dayEnd);
    store.saveDayDraft(
      draft: draft,
      draftLogs: _currentDraftLogs,
      segments: segments,
      breaks: breaks,
    );
    _currentDraft = draft;
    _currentSegments = segments;
    _currentBreaks = breaks;
    _revalidateCurrentPlan();
    notifyListeners();
  }

  void _sortSegmentsAndExpandDraft() {
    _currentSegments.sort((a, b) => a.startUtc.compareTo(b.startUtc));
    if (_currentSegments.isEmpty || _currentDraft == null) return;

    var newStart = _currentDraft!.startUtc;
    var newEnd = _currentDraft!.endUtc;

    final firstSeg = _currentSegments.first;
    final lastSeg = _currentSegments.last;

    if (firstSeg.startUtc.isBefore(newStart)) {
      newStart = firstSeg.startUtc;
    }
    if (lastSeg.endUtc.isAfter(newEnd)) {
      newEnd = lastSeg.endUtc;
    }

    if (newStart != _currentDraft!.startUtc ||
        newEnd != _currentDraft!.endUtc) {
      _currentDraft = _currentDraft!.copyWith(
        startUtc: newStart,
        endUtc: newEnd,
      );
      store.updateDayDraft(_currentDraft!);
    }
  }

  void deleteSegment(String segmentId) {
    if (_currentDraft == null) return;
    store.deleteSegment(draftId: _currentDraft!.id, segmentId: segmentId);
    loadDraftForSelectedDate();
    _activeDraftDatesBySourceLogId = store.getActiveDraftDatesBySourceLogId(
      scope: activeScope,
    );
    notifyListeners();
  }

  /// Переключение фиксированного времени старта у сегмента дня.
  void toggleSegmentFixed(String segmentId) {
    if (_currentDraft == null) return;
    final idx = _currentSegments.indexWhere((s) => s.id == segmentId);
    if (idx == -1) return;

    final segment = _currentSegments[idx];
    final updated = segment.copyWith(isFixed: !segment.isFixed);
    _currentSegments[idx] = updated;
    store.updateSegment(updated);
    _revalidateCurrentPlan();
    notifyListeners();
  }

  /// Разрезание сегмента дня на два последовательных сегмента.
  void splitSegment({
    required String segmentId,
    required int splitOffsetSeconds,
    String? part1Description,
    String? part2Description,
  }) {
    if (_currentDraft == null) return;
    final idx = _currentSegments.indexWhere((s) => s.id == segmentId);
    if (idx == -1) return;

    final oldSegment = _currentSegments[idx];
    if (splitOffsetSeconds <= 0 ||
        splitOffsetSeconds >= oldSegment.durationSeconds) {
      throw ArgumentError(
        'Смещение точки разделения должно быть больше 0 и меньше длительности сегмента (${oldSegment.durationSeconds} с)',
      );
    }

    final part2Duration = oldSegment.durationSeconds - splitOffsetSeconds;
    final seg1 = oldSegment.copyWith(
      durationSeconds: splitOffsetSeconds,
      description: (part1Description ?? oldSegment.description).trim(),
    );

    final seg2Id = const Uuid().v4();
    final seg2 = Segment(
      id: seg2Id,
      draftId: oldSegment.draftId,
      sourceLogId: oldSegment.sourceLogId,
      issueId: oldSegment.issueId,
      startUtc: oldSegment.startUtc.add(Duration(seconds: splitOffsetSeconds)),
      durationSeconds: part2Duration,
      description: (part2Description ?? oldSegment.description).trim(),
      sendState: SendState.pending,
      isFixed: false,
    );

    _currentSegments[idx] = seg1;
    _currentSegments.insert(idx + 1, seg2);

    store.updateSegment(seg1);
    store.insertSegment(seg2);

    _sortSegmentsAndExpandDraft();
    _revalidateCurrentPlan();
    notifyListeners();
  }

  /// Объединение двух сегментов дня в один.
  void mergeSegments({
    required String segmentId1,
    required String segmentId2,
    String? description,
  }) {
    if (_currentDraft == null) return;
    final idx1 = _currentSegments.indexWhere((s) => s.id == segmentId1);
    final idx2 = _currentSegments.indexWhere((s) => s.id == segmentId2);
    if (idx1 == -1 || idx2 == -1 || idx1 == idx2) return;

    final seg1 = _currentSegments[idx1];
    final seg2 = _currentSegments[idx2];
    if (seg1.sourceLogId != seg2.sourceLogId) {
      throw ArgumentError(
        'Можно объединить только сегменты одного исходного лога.',
      );
    }
    final sourceLog = store.getLocalLog(seg1.sourceLogId);
    if (sourceLog == null || sourceLog.scope != activeScope) {
      throw StateError('Исходный лог сегментов не найден.');
    }

    final firstSeg = seg1.startUtc.isBefore(seg2.startUtc) ? seg1 : seg2;
    final secondSeg = identical(firstSeg, seg1) ? seg2 : seg1;

    final totalDuration = firstSeg.durationSeconds + secondSeg.durationSeconds;
    final combinedDesc =
        description?.trim() ??
        [
          firstSeg.description.trim(),
          secondSeg.description.trim(),
        ].where((d) => d.isNotEmpty).toSet().join('\n');

    final mergedSeg = firstSeg.copyWith(
      issueId: sourceLog.issueId,
      durationSeconds: totalDuration,
      description: combinedDesc,
    );

    _currentSegments.removeWhere((s) => s.id == secondSeg.id);
    final replaceIdx = _currentSegments.indexWhere((s) => s.id == firstSeg.id);
    if (replaceIdx != -1) {
      _currentSegments[replaceIdx] = mergedSeg;
    }

    store.updateSegment(mergedSeg);
    store.deleteSegment(draftId: _currentDraft!.id, segmentId: secondSeg.id);

    _sortSegmentsAndExpandDraft();
    _revalidateCurrentPlan();
    notifyListeners();
  }

  /// Ручное изменение порядка сегментов в черновике дня.
  void reorderSegments(int oldIndex, int newIndex) {
    if (_currentDraft == null) return;
    if (oldIndex < 0 || oldIndex >= _currentSegments.length) return;
    if (newIndex < 0 || newIndex > _currentSegments.length) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _currentSegments.removeAt(oldIndex);
    _currentSegments.insert(newIndex, item);
    notifyListeners();
  }

  /// Перемещение сегмента на одну позицию вверх.
  void moveSegmentUp(String segmentId) {
    final idx = _currentSegments.indexWhere((s) => s.id == segmentId);
    if (idx > 0) {
      reorderSegments(idx, idx - 1);
    }
  }

  /// Перемещение сегмента на одну позицию вниз.
  void moveSegmentDown(String segmentId) {
    final idx = _currentSegments.indexWhere((s) => s.id == segmentId);
    if (idx != -1 && idx < _currentSegments.length - 1) {
      reorderSegments(idx, idx + 2);
    }
  }

  /// Пересборка текущего дня с сохранением пользовательской последовательности и якорей.
  Future<void> rebuildCurrentDay({int? customSeed}) async {
    if (_currentDraft == null || _currentSegments.isEmpty) {
      return;
    }
    if (isReadOnly || isDraftLockedFromRebuild) {
      throw StateError(
        'Нельзя пересобрать день после начала отправки или в режиме только чтения.',
      );
    }
    _isBuildingDay = true;
    notifyListeners();

    try {
      final draftId = _currentDraft!.id;
      final seed = customSeed ?? Random().nextInt(1000000000);

      final builderLogs = <DayBuilderLogInput>[];
      final sourceLogIdBySegmentId = <String, String>{};
      for (final s in _currentSegments) {
        sourceLogIdBySegmentId[s.id] = s.sourceLogId;
        final title =
            _issues.where((i) => i.issueId == s.issueId).firstOrNull?.summary ??
            s.issueId;
        builderLogs.add(
          DayBuilderLogInput(
            sourceLogId: s.id,
            issueId: s.issueId,
            titleSnapshot: title,
            description: s.description,
            sourceDurationSeconds: s.durationSeconds,
            durationLocked: true,
            isFixed: s.isFixed,
            fixedStartUtc: s.isFixed ? s.startUtc : null,
          ),
        );
      }

      final input = DayBuilderInput(
        localDate: _selectedDate,
        timeZoneOffset: DateTime.now().timeZoneOffset,
        settings: _daySettings,
        logs: builderLogs,
        existingWorklogs: _importedWorklogs,
        draftId: draftId,
      );

      final plan = DayBuilder.rebuildDayPlan(input: input, seed: seed);
      final rebuiltSegments = [
        for (final segment in plan.segments)
          segment.copyWith(
            sourceLogId: sourceLogIdBySegmentId[segment.sourceLogId]!,
          ),
      ];

      final updatedDraft = _currentDraft!.copyWith(
        startUtc: plan.dayStartUtc,
        endUtc: plan.dayEndUtc,
        seed: seed,
        settingsSnapshot: _daySettings.toJson(),
      );

      store.saveDayDraft(
        draft: updatedDraft,
        draftLogs: _currentDraftLogs,
        segments: rebuiltSegments,
        breaks: plan.breaks,
      );

      _currentDraft = updatedDraft;
      _currentSegments = rebuiltSegments;
      _currentBreaks = plan.breaks;
      _activeDraftDatesBySourceLogId = store.getActiveDraftDatesBySourceLogId(
        scope: activeScope,
      );
      _revalidateCurrentPlan();
      _statusMessage = 'День успешно пересобран с сохранением порядка.';
    } finally {
      _isBuildingDay = false;
      notifyListeners();
    }
  }

  /// Поиск смежных элементов расписания, прилегающих к промежутку (Timeline Gap).
  GapNeighbors findGapNeighbors(Break gap) {
    if (_currentDraft == null) return const GapNeighbors();

    Segment? leftSegment;
    ImportedWorklog? leftExisting;
    DateTime? maxEndBeforeGap;

    for (final s in _currentSegments) {
      if (!s.endUtc.isAfter(gap.startUtc)) {
        if (maxEndBeforeGap == null || s.endUtc.isAfter(maxEndBeforeGap)) {
          maxEndBeforeGap = s.endUtc;
          leftSegment = s;
          leftExisting = null;
        }
      }
    }
    for (final ew in importedWorklogs) {
      if (!ew.endUtc.isAfter(gap.startUtc)) {
        if (maxEndBeforeGap == null || ew.endUtc.isAfter(maxEndBeforeGap)) {
          maxEndBeforeGap = ew.endUtc;
          leftExisting = ew;
          leftSegment = null;
        }
      }
    }

    Segment? rightSegment;
    ImportedWorklog? rightExisting;
    DateTime? minStartAfterGap;

    for (final s in _currentSegments) {
      if (!s.startUtc.isBefore(gap.endUtc)) {
        if (minStartAfterGap == null || s.startUtc.isBefore(minStartAfterGap)) {
          minStartAfterGap = s.startUtc;
          rightSegment = s;
          rightExisting = null;
        }
      }
    }
    for (final ew in importedWorklogs) {
      if (!ew.startUtc.isBefore(gap.endUtc)) {
        if (minStartAfterGap == null ||
            ew.startUtc.isBefore(minStartAfterGap)) {
          minStartAfterGap = ew.startUtc;
          rightExisting = ew;
          rightSegment = null;
        }
      }
    }

    final isStartOfDay = leftSegment == null && leftExisting == null;
    final isEndOfDay = rightSegment == null && rightExisting == null;

    return GapNeighbors(
      leftSegment: leftSegment,
      leftExisting: leftExisting,
      rightSegment: rightSegment,
      rightExisting: rightExisting,
      isStartOfDay: isStartOfDay,
      isEndOfDay: isEndOfDay,
    );
  }

  /// Валидация новых границ промежутка свободного времени.
  String? validateGapAdjustment({
    required Break gap,
    required DateTime newStartUtc,
    required DateTime newEndUtc,
  }) {
    if (!newEndUtc.isAfter(newStartUtc)) {
      return 'Время окончания должно быть позже времени начала.';
    }

    final neighbors = findGapNeighbors(gap);

    if (neighbors.leftExisting != null) {
      if (newStartUtc != neighbors.leftExisting!.endUtc) {
        return 'Нельзя изменять границу: слева находится запись из Jira (${neighbors.leftExisting!.issueKey}).';
      }
    } else if (neighbors.leftSegment != null) {
      final leftDur = newStartUtc
          .difference(neighbors.leftSegment!.startUtc)
          .inSeconds;
      if (leftDur < 60) {
        return 'Длительность предыдущей задачи не может быть меньше 1 минуты.';
      }
    }

    if (neighbors.rightExisting != null) {
      if (newEndUtc != neighbors.rightExisting!.startUtc) {
        return 'Нельзя изменять границу: справа находится запись из Jira (${neighbors.rightExisting!.issueKey}).';
      }
    } else if (neighbors.rightSegment != null) {
      final rightDur = neighbors.rightSegment!.endUtc
          .difference(newEndUtc)
          .inSeconds;
      if (rightDur < 60) {
        return 'Длительность следующей задачи не может быть меньше 1 минуты.';
      }
    }

    return null;
  }

  /// Интерактивное обновление границ и типа промежутка (Timeline Gap).
  void updateBreakGap({
    required Break gap,
    required DateTime newStartUtc,
    required DateTime newEndUtc,
    required BreakKind newKind,
  }) {
    if (_currentDraft == null) return;
    final error = validateGapAdjustment(
      gap: gap,
      newStartUtc: newStartUtc,
      newEndUtc: newEndUtc,
    );
    if (error != null) {
      throw ArgumentError(error);
    }

    final neighbors = findGapNeighbors(gap);

    // 1. Обновление левого соседа
    if (neighbors.leftSegment != null) {
      final newDur = newStartUtc
          .difference(neighbors.leftSegment!.startUtc)
          .inSeconds;
      final updatedLeft = neighbors.leftSegment!.copyWith(
        durationSeconds: newDur,
      );
      final idx = _currentSegments.indexWhere((s) => s.id == updatedLeft.id);
      if (idx != -1) {
        final list = List<Segment>.from(_currentSegments);
        list[idx] = updatedLeft;
        _currentSegments = list;
        store.updateSegment(updatedLeft);
      }
    } else if (neighbors.isStartOfDay) {
      _currentDraft = _currentDraft!.copyWith(startUtc: newStartUtc);
      store.updateDayDraft(_currentDraft!);
    }

    // 2. Обновление правого соседа
    if (neighbors.rightSegment != null) {
      final newDur = neighbors.rightSegment!.endUtc
          .difference(newEndUtc)
          .inSeconds;
      final updatedRight = neighbors.rightSegment!.copyWith(
        startUtc: newEndUtc,
        durationSeconds: newDur,
      );
      final idx = _currentSegments.indexWhere((s) => s.id == updatedRight.id);
      if (idx != -1) {
        final list = List<Segment>.from(_currentSegments);
        list[idx] = updatedRight;
        _currentSegments = list;
        store.updateSegment(updatedRight);
      }
    } else if (neighbors.isEndOfDay) {
      _currentDraft = _currentDraft!.copyWith(endUtc: newEndUtc);
      store.updateDayDraft(_currentDraft!);
    }

    // Проверяем расширение границ черновика
    var newDraftStart = _currentDraft!.startUtc;
    var newDraftEnd = _currentDraft!.endUtc;
    if (newStartUtc.isBefore(newDraftStart)) newDraftStart = newStartUtc;
    if (newEndUtc.isAfter(newDraftEnd)) newDraftEnd = newEndUtc;
    if (newDraftStart != _currentDraft!.startUtc ||
        newDraftEnd != _currentDraft!.endUtc) {
      _currentDraft = _currentDraft!.copyWith(
        startUtc: newDraftStart,
        endUtc: newDraftEnd,
      );
      store.updateDayDraft(_currentDraft!);
    }

    // Сортировка сегментов
    final sortedSegs = List<Segment>.from(_currentSegments)
      ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
    _currentSegments = sortedSegs;

    // 3. Сохранение предпочтения обеда
    final breaks = List<Break>.from(_currentBreaks);
    breaks.removeWhere(
      (b) => b.startUtc.isBefore(newEndUtc) && b.endUtc.isAfter(newStartUtc),
    );
    if (newKind == BreakKind.lunch) {
      breaks.add(
        Break(
          id: 'lunch-${newStartUtc.millisecondsSinceEpoch}',
          draftId: _currentDraft!.id,
          startUtc: newStartUtc,
          durationSeconds: newEndUtc.difference(newStartUtc).inSeconds,
          kind: BreakKind.lunch,
        ),
      );
    }
    breaks.sort((a, b) => a.startUtc.compareTo(b.startUtc));
    _currentBreaks = breaks;
    store.replaceBreaks(draftId: _currentDraft!.id, breaks: _currentBreaks);

    _revalidateCurrentPlan();
    notifyListeners();
  }

  /// Удаление промежутка свободного времени (смыкание смежных задач).
  void deleteBreakGap(Break gap) {
    if (_currentDraft == null) return;
    final neighbors = findGapNeighbors(gap);

    if (neighbors.leftSegment != null) {
      final targetEnd =
          neighbors.rightSegment?.startUtc ??
          neighbors.rightExisting?.startUtc ??
          gap.endUtc;
      final newDur = targetEnd
          .difference(neighbors.leftSegment!.startUtc)
          .inSeconds;
      final updatedLeft = neighbors.leftSegment!.copyWith(
        durationSeconds: newDur,
      );
      final idx = _currentSegments.indexWhere((s) => s.id == updatedLeft.id);
      if (idx != -1) {
        final list = List<Segment>.from(_currentSegments);
        list[idx] = updatedLeft;
        _currentSegments = list;
        store.updateSegment(updatedLeft);
      }
    } else if (neighbors.leftExisting != null &&
        neighbors.rightSegment != null) {
      final newStart = neighbors.leftExisting!.endUtc;
      final newDur = neighbors.rightSegment!.endUtc
          .difference(newStart)
          .inSeconds;
      final updatedRight = neighbors.rightSegment!.copyWith(
        startUtc: newStart,
        durationSeconds: newDur,
      );
      final idx = _currentSegments.indexWhere((s) => s.id == updatedRight.id);
      if (idx != -1) {
        final list = List<Segment>.from(_currentSegments);
        list[idx] = updatedRight;
        _currentSegments = list;
        store.updateSegment(updatedRight);
      }
    } else if (neighbors.isStartOfDay) {
      final targetStart =
          neighbors.rightSegment?.startUtc ??
          neighbors.rightExisting?.startUtc ??
          gap.endUtc;
      _currentDraft = _currentDraft!.copyWith(startUtc: targetStart);
      store.updateDayDraft(_currentDraft!);
    } else if (neighbors.isEndOfDay) {
      final targetEnd =
          neighbors.leftSegment?.endUtc ??
          neighbors.leftExisting?.endUtc ??
          gap.startUtc;
      _currentDraft = _currentDraft!.copyWith(endUtc: targetEnd);
      store.updateDayDraft(_currentDraft!);
    }

    final breaks = List<Break>.from(_currentBreaks);
    breaks.removeWhere(
      (b) => b.startUtc.isBefore(gap.endUtc) && b.endUtc.isAfter(gap.startUtc),
    );
    _currentBreaks = breaks;
    store.replaceBreaks(draftId: _currentDraft!.id, breaks: _currentBreaks);

    _revalidateCurrentPlan();
    notifyListeners();
  }

  /// Проверка возможности каскадного сдвига сегментов вправо (защита от наложения на записи Jira).
  String? canShiftSegmentsRight({
    required DateTime afterUtc,
    required int deltaSeconds,
  }) {
    if (deltaSeconds <= 0) return null;
    final affectedSegments = _currentSegments
        .where((s) => !s.startUtc.isBefore(afterUtc))
        .toList();
    if (affectedSegments.isEmpty) return null;

    for (final s in affectedSegments) {
      final shiftedStart = s.startUtc.add(Duration(seconds: deltaSeconds));
      final shiftedEnd = s.endUtc.add(Duration(seconds: deltaSeconds));

      for (final ew in importedWorklogs) {
        if (shiftedStart.isBefore(ew.endUtc) &&
            shiftedEnd.isAfter(ew.startUtc)) {
          final availableSec = ew.startUtc.difference(s.startUtc).inSeconds;
          final availMin = (availableSec / 60).round();
          final reqMin = (deltaSeconds / 60).round();
          return 'Недостаточно свободного времени перед записью Jira ${ew.issueKey}: требуется $reqMin мин, доступно $availMin мин.';
        }
      }
    }
    return null;
  }

  /// Прямое изменение правой границы задачи (Right Handle Drag):
  /// - newDurationSeconds >= 600 (мин. 10 минут).
  /// - Если delta > 0 (удлинение): проверяет упор в Jira worklogs и выталкивает
  ///   весь правый хвост (задачи и паузы) вправо синхронно (аккордеон).
  /// - Если delta < 0 (укорачивание): подтягивает весь правый хвост синхронно влево.
  void resizeSegmentRight(Segment segment, int newDurationSeconds) {
    if (_currentDraft == null) return;
    final idx = _currentSegments.indexWhere((s) => s.id == segment.id);
    if (idx == -1) return;

    final targetDuration = newDurationSeconds < 600 ? 600 : newDurationSeconds;
    final currentSegment = _currentSegments[idx];
    final delta = targetDuration - currentSegment.durationSeconds;
    if (delta == 0) return;

    if (delta > 0) {
      final err = canShiftSegmentsRight(
        afterUtc: currentSegment.endUtc,
        deltaSeconds: delta,
      );
      if (err != null) throw ArgumentError(err);

      final rightSegments =
          _currentSegments
              .where(
                (s) =>
                    s.id != currentSegment.id &&
                    !s.startUtc.isBefore(currentSegment.endUtc),
              )
              .toList()
            ..sort((a, b) => a.startUtc.compareTo(b.startUtc));

      for (final s in rightSegments) {
        final pushed = s.copyWith(
          startUtc: s.startUtc.add(Duration(seconds: delta)),
        );
        store.updateSegment(pushed);
        final sIdx = _currentSegments.indexWhere((x) => x.id == s.id);
        if (sIdx != -1) _currentSegments[sIdx] = pushed;
      }

      final updatedBreaks = _currentBreaks.map((b) {
        if (!b.startUtc.isBefore(currentSegment.endUtc)) {
          return b.copyWith(startUtc: b.startUtc.add(Duration(seconds: delta)));
        }
        return b;
      }).toList();
      _currentBreaks = updatedBreaks;
      store.replaceBreaks(draftId: _currentDraft!.id, breaks: _currentBreaks);
    } else {
      final shiftLeft = -delta;
      final rightSegments =
          _currentSegments
              .where(
                (s) =>
                    s.id != currentSegment.id &&
                    !s.startUtc.isBefore(currentSegment.endUtc),
              )
              .toList()
            ..sort((a, b) => a.startUtc.compareTo(b.startUtc));

      for (final s in rightSegments) {
        final pulled = s.copyWith(
          startUtc: s.startUtc.subtract(Duration(seconds: shiftLeft)),
        );
        store.updateSegment(pulled);
        final sIdx = _currentSegments.indexWhere((x) => x.id == s.id);
        if (sIdx != -1) _currentSegments[sIdx] = pulled;
      }

      final updatedBreaks = _currentBreaks.map((b) {
        if (!b.startUtc.isBefore(currentSegment.endUtc)) {
          return b.copyWith(
            startUtc: b.startUtc.subtract(Duration(seconds: shiftLeft)),
          );
        }
        return b;
      }).toList();
      _currentBreaks = updatedBreaks;
      store.replaceBreaks(draftId: _currentDraft!.id, breaks: _currentBreaks);
    }

    final updatedSegment = currentSegment.copyWith(
      durationSeconds: targetDuration,
    );
    _currentSegments[idx] = updatedSegment;
    store.updateSegment(updatedSegment);

    _sortSegmentsAndExpandDraft();
    _revalidateCurrentPlan();
    notifyListeners();
  }

  /// Прямое изменение левой границы задачи (Left Handle Drag):
  /// - Окончание segment.endUtc фиксировано.
  /// - Сосед слева не урезается: minAllowedStart = max(leftNeighbor.endUtc, dayDraft.startUtc).
  /// - Мин. размер задачи — 10 минут: maxAllowedStart = segment.endUtc - 10 min.
  /// - При сдвиге влево поглощает паузу перед задачей (до упора в соседа слева).
  /// - При сдвиге вправо увеличивает/создает паузу перед задачей.
  void resizeSegmentLeft(Segment segment, DateTime newStartUtc) {
    if (_currentDraft == null) return;
    final idx = _currentSegments.indexWhere((s) => s.id == segment.id);
    if (idx == -1) return;

    final currentSegment = _currentSegments[idx];

    // Находим границу соседа слева (не урезается!)
    var minAllowedStart = _currentDraft!.startUtc;
    for (final s in _currentSegments) {
      if (s.id != currentSegment.id &&
          !s.endUtc.isAfter(currentSegment.startUtc)) {
        if (s.endUtc.isAfter(minAllowedStart)) {
          minAllowedStart = s.endUtc;
        }
      }
    }
    for (final ew in importedWorklogs) {
      if (!ew.endUtc.isAfter(currentSegment.startUtc)) {
        if (ew.endUtc.isAfter(minAllowedStart)) {
          minAllowedStart = ew.endUtc;
        }
      }
    }

    // Ограничение справа: мин. 10 минут
    final maxAllowedStart = currentSegment.endUtc.subtract(
      const Duration(minutes: 10),
    );

    var effectiveStart = newStartUtc;
    if (effectiveStart.isBefore(minAllowedStart)) {
      effectiveStart = minAllowedStart;
    }
    if (effectiveStart.isAfter(maxAllowedStart)) {
      effectiveStart = maxAllowedStart;
    }

    final newDurationSeconds = currentSegment.endUtc
        .difference(effectiveStart)
        .inSeconds;
    final updatedSegment = currentSegment.copyWith(
      startUtc: effectiveStart,
      durationSeconds: newDurationSeconds,
    );

    // Удаляем любые breaks, оказавшиеся внутри нового диапазона задачи
    final breaks = List<Break>.from(_currentBreaks);
    breaks.removeWhere(
      (b) =>
          b.startUtc.isBefore(currentSegment.endUtc) &&
          b.endUtc.isAfter(effectiveStart),
    );
    _currentBreaks = breaks;
    store.replaceBreaks(draftId: _currentDraft!.id, breaks: _currentBreaks);

    _currentSegments[idx] = updatedSegment;
    store.updateSegment(updatedSegment);

    _sortSegmentsAndExpandDraft();
    _revalidateCurrentPlan();
    notifyListeners();
  }

  /// Схлопывание зазора (Snap Gap): придвигает правую цепочку сегментов влево встык к предыдущему интервалу.
  void snapGap(Break gap) {
    if (_currentDraft == null) return;
    final neighbors = findGapNeighbors(gap);
    final targetStart =
        neighbors.leftSegment?.endUtc ??
        neighbors.leftExisting?.endUtc ??
        _currentDraft!.startUtc;

    final rightSegments =
        _currentSegments.where((s) => !s.startUtc.isBefore(gap.endUtc)).toList()
          ..sort((a, b) => a.startUtc.compareTo(b.startUtc));

    if (rightSegments.isEmpty) {
      _currentDraft = _currentDraft!.copyWith(endUtc: targetStart);
      store.updateDayDraft(_currentDraft!);
    } else {
      final delta = rightSegments.first.startUtc
          .difference(targetStart)
          .inSeconds;
      if (delta > 0) {
        for (final s in rightSegments) {
          final newStart = s.startUtc.subtract(Duration(seconds: delta));
          final updated = s.copyWith(startUtc: newStart);
          store.updateSegment(updated);
          final idx = _currentSegments.indexWhere((x) => x.id == s.id);
          if (idx != -1) _currentSegments[idx] = updated;
        }
      }
    }

    final breaks = List<Break>.from(_currentBreaks);
    breaks.removeWhere(
      (b) => b.startUtc.isBefore(gap.endUtc) && b.endUtc.isAfter(gap.startUtc),
    );
    _currentBreaks = breaks;
    store.replaceBreaks(draftId: _currentDraft!.id, breaks: _currentBreaks);

    _sortSegmentsAndExpandDraft();
    _revalidateCurrentPlan();
    notifyListeners();
  }

  /// Растягивание левой задачи на весь зазор (Fill Gap with Left Segment).
  void fillGapWithLeftSegment(Break gap) {
    if (_currentDraft == null) return;
    final neighbors = findGapNeighbors(gap);
    if (neighbors.leftSegment == null) return;

    final newDur = neighbors.leftSegment!.durationSeconds + gap.durationSeconds;
    final updated = neighbors.leftSegment!.copyWith(durationSeconds: newDur);
    store.updateSegment(updated);
    final idx = _currentSegments.indexWhere((x) => x.id == updated.id);
    if (idx != -1) _currentSegments[idx] = updated;

    final breaks = List<Break>.from(_currentBreaks);
    breaks.removeWhere(
      (b) => b.startUtc.isBefore(gap.endUtc) && b.endUtc.isAfter(gap.startUtc),
    );
    _currentBreaks = breaks;
    store.replaceBreaks(draftId: _currentDraft!.id, breaks: _currentBreaks);

    _sortSegmentsAndExpandDraft();
    _revalidateCurrentPlan();
    notifyListeners();
  }

  /// Установка точной длительности паузы с выталкиванием/подтягиванием правой цепочки задач.
  void setGapDuration({
    required Break gap,
    required int newDurationSeconds,
    BreakKind? kind,
  }) {
    if (_currentDraft == null) return;
    final delta = newDurationSeconds - gap.durationSeconds;

    if (delta > 0) {
      final err = canShiftSegmentsRight(
        afterUtc: gap.endUtc,
        deltaSeconds: delta,
      );
      if (err != null) throw ArgumentError(err);

      final rightSegments =
          _currentSegments
              .where((s) => !s.startUtc.isBefore(gap.endUtc))
              .toList()
            ..sort((a, b) => a.startUtc.compareTo(b.startUtc));

      for (final s in rightSegments) {
        final newStart = s.startUtc.add(Duration(seconds: delta));
        final updated = s.copyWith(startUtc: newStart);
        store.updateSegment(updated);
        final idx = _currentSegments.indexWhere((x) => x.id == s.id);
        if (idx != -1) _currentSegments[idx] = updated;
      }
    } else if (delta < 0) {
      final shiftLeft = -delta;
      final rightSegments =
          _currentSegments
              .where((s) => !s.startUtc.isBefore(gap.endUtc))
              .toList()
            ..sort((a, b) => a.startUtc.compareTo(b.startUtc));

      for (final s in rightSegments) {
        final newStart = s.startUtc.subtract(Duration(seconds: shiftLeft));
        final updated = s.copyWith(startUtc: newStart);
        store.updateSegment(updated);
        final idx = _currentSegments.indexWhere((x) => x.id == s.id);
        if (idx != -1) _currentSegments[idx] = updated;
      }
    }

    final effectiveKind = kind ?? gap.kind;
    final breaks = List<Break>.from(_currentBreaks);
    breaks.removeWhere(
      (b) => b.startUtc.isBefore(gap.endUtc) && b.endUtc.isAfter(gap.startUtc),
    );
    if (effectiveKind == BreakKind.lunch) {
      breaks.add(
        Break(
          id: 'lunch-${gap.startUtc.millisecondsSinceEpoch}',
          draftId: _currentDraft!.id,
          startUtc: gap.startUtc,
          durationSeconds: newDurationSeconds,
          kind: BreakKind.lunch,
        ),
      );
    }
    _currentBreaks = breaks;
    store.replaceBreaks(draftId: _currentDraft!.id, breaks: _currentBreaks);

    _sortSegmentsAndExpandDraft();
    _revalidateCurrentPlan();
    notifyListeners();
  }

  /// Отправка текущего черновика дня в Jira (сценарии A14, A17).
  Future<SendDraftResult?> submitCurrentDraft() async {
    if (isReadOnly) return null;
    final draft = _currentDraft;
    final conn = _currentConnection;
    if (draft == null || conn == null) return null;
    final token = await connectionStore.getSavedToken();
    if (token == null || token.isEmpty) {
      _statusMessage = 'Токен Jira не найден в защищённом хранилище';
      notifyListeners();
      return null;
    }

    _isSubmittingDay = true;
    _statusMessage = 'Отправка записей в Jira...';
    notifyListeners();

    try {
      final result = await worklogSender.sendDraft(
        draft: draft,
        connection: conn,
        token: token,
        onSegmentProgress: (seg) {
          _currentSegments = store.getSegments(draftId: draft.id);
          notifyListeners();
        },
      );

      loadDraftForSelectedDate();
      _logs = store.getLocalLogs(scope: activeScope);

      if (result.isSuccess) {
        _statusMessage =
            'Все записи (${result.sent}) успешно отправлены в Jira!';
      } else if (result.errorMessage != null) {
        _statusMessage = 'Ошибка отправки: ${result.errorMessage}';
      } else {
        _statusMessage =
            'Отправка завершена: отправлено ${result.sent}, ошибок ${result.failed}, неизвестно ${result.unknown}.';
      }
      return result;
    } catch (e) {
      _statusMessage = 'Ошибка отправки в Jira: $e';
      return null;
    } finally {
      _isSubmittingDay = false;
      notifyListeners();
    }
  }

  /// Сверка сегмента со статусом unknown через Jira properties (сценарий A15).
  Future<ReconcileResult?> reconcileSegment(Segment segment) async {
    if (isReadOnly) return null;
    final conn = _currentConnection;
    if (conn == null) return null;
    final token = await connectionStore.getSavedToken();
    if (token == null || token.isEmpty) return null;

    try {
      final res = await worklogSender.reconcileSegment(
        segment: segment,
        connection: conn,
        token: token,
      );
      loadDraftForSelectedDate();
      _logs = store.getLocalLogs(scope: activeScope);
      _statusMessage = res.message;
      notifyListeners();
      return res;
    } catch (e) {
      _statusMessage = 'Ошибка сверки: $e';
      notifyListeners();
      return null;
    }
  }

  /// Ручная привязка ID записи в Jira (сценарий A15).
  Future<ManualResolveResult?> manuallyLinkWorklog(
    Segment segment,
    String worklogId,
  ) async {
    if (isReadOnly) return null;
    final conn = _currentConnection;
    if (conn == null) return null;
    final token = await connectionStore.getSavedToken();
    if (token == null || token.isEmpty) return null;

    final res = await worklogSender.manuallyLinkWorklog(
      segment: segment,
      worklogId: worklogId,
      connection: conn,
      token: token,
    );
    loadDraftForSelectedDate();
    _logs = store.getLocalLogs(scope: activeScope);
    _statusMessage = res.isSuccess
        ? 'Worklog успешно привязан!'
        : (res.errorMessage ?? 'Ошибка привязки worklog');
    notifyListeners();
    return res;
  }

  /// Пользователь подтвердил отсутствие записи и разрешил повтор (сценарий A15).
  void manuallyConfirmAbsenceAndAllowRetry(Segment segment) {
    if (isReadOnly) throw StateError('Приложение открыто только для чтения.');
    worklogSender.manuallyConfirmAbsenceAndAllowRetry(segment: segment);
    loadDraftForSelectedDate();
    _statusMessage =
        'Статус сегмента сброшен на «В очереди». Разрешена повторная отправка.';
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

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _tickerTimer = null;
    _apiServer?.stop();
    _apiServer = null;
    themeMode.dispose();
    super.dispose();
  }
}
