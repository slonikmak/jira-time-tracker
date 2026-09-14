import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
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

/// Состояние приложения, координация данных, задач, таймеров и подключений.
class AppState extends ChangeNotifier {
  final LocalStore store;
  final ConnectionStore connectionStore;
  final JiraClient jiraClient;
  final WorklogSender worklogSender;
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
    WorklogSender? worklogSender,
    JiraConnection? initialConnection,
    DateTime Function()? nowProvider,
  }) : _currentConnection = initialConnection,
       nowProvider = nowProvider ?? (() => DateTime.now().toUtc()),
       worklogSender =
           worklogSender ??
           WorklogSender(
             store: store,
             jiraClient: jiraClient,
             nowProvider: nowProvider,
           ) {
    _initData();
  }

  Map<String, String> _activeDraftDatesBySourceLogId = {};

  void _initData() {
    _issues = store.getIssues(scope: activeScope);
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
  bool _isSubmittingDay = false;

  DateTime get selectedDate => _selectedDate;
  DayDraft? get currentDraft => _currentDraft;
  List<DraftLog> get currentDraftLogs => List.unmodifiable(_currentDraftLogs);
  List<Segment> get currentSegments => List.unmodifiable(_currentSegments);
  List<Break> get currentBreaks => List.unmodifiable(_currentBreaks);
  List<ImportedWorklog> get importedWorklogs =>
      List.unmodifiable(_importedWorklogs);
  bool get isFetchingJiraWorklogs => _isFetchingJiraWorklogs;
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
      _currentBreaks.fold<int>(0, (sum, b) => sum + b.durationSeconds);

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

    // Сохраняем в базу данных (upsert поднимает lastUsedAtUtc, сохраняя currentLogId если был)
    final existing = store.getIssue(issue.scope, issue.issueId);
    final issueToSave = existing != null && existing.currentLogId != null
        ? issue.copyWith(currentLogId: existing.currentLogId)
        : issue;
    store.upsertIssue(issueToSave);
    await loadIssues();
    return issueToSave;
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

  void setSelectedDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    loadDraftForSelectedDate();
    fetchJiraWorklogsForDate();
  }

  Future<void> fetchJiraWorklogsForDate() async {
    final conn = _currentConnection;
    if (conn == null) return;
    final token = await connectionStore.getSavedToken();
    if (token == null || token.isEmpty) return;

    _isFetchingJiraWorklogs = true;
    notifyListeners();

    try {
      final additionalIds = <String>[
        ..._issues.map((i) => i.issueId),
        ..._logs.map((l) => l.issueId),
      ];

      final logs = await jiraClient.fetchDayWorklogs(
        date: _selectedDate,
        timeZoneOffset: DateTime.now().timeZoneOffset,
        connection: conn,
        token: token,
        additionalIssueIds: additionalIds,
      );

      _importedWorklogs = logs;

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
      _statusMessage = 'Ошибка загрузки записей Jira: $e';
    } finally {
      _isFetchingJiraWorklogs = false;
      notifyListeners();
    }
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

      _lockedSourceLogIds.clear();
      for (final dl in _currentDraftLogs) {
        if (dl.durationLocked) {
          _lockedSourceLogIds.add(dl.sourceLogId);
        }
      }

      try {
        _daySettings = DaySettings.fromJson(draft.settingsSnapshot);
      } catch (_) {}

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
      breaks: _currentBreaks,
      allocatedSecondsBySourceLogId: {},
      totalNewWorkSeconds: totalSegmentsDurationSeconds,
      totalBreaksSeconds: totalBreaksDurationSeconds,
      totalExistingSeconds: totalExistingDurationSeconds,
      totalDaySeconds: totalDayDurationSeconds,
    );

    _validationErrors = DayBuilder.validate(
      plan: plan,
      existingWorklogs: _importedWorklogs,
    );
  }

  Future<void> buildDay({int? customSeed}) async {
    if (isDraftLockedFromRebuild) {
      throw StateError(
        'Нельзя пересобрать частично или полностью отправленный день.',
      );
    }

    _isBuildingDay = true;
    notifyListeners();

    try {
      final builderLogs = <DayBuilderLogInput>[];

      if (_currentDraft != null && _currentDraftLogs.isNotEmpty) {
        // Пересборка существующего черновика: сохраняем привязанные логи
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
          builderLogs.add(
            DayBuilderLogInput(
              sourceLogId: dl.sourceLogId,
              issueId: srcLog.issueId,
              titleSnapshot: srcLog.titleSnapshot,
              description: dl.descriptionSnapshot,
              sourceDurationSeconds: dl.sourceDurationSeconds,
              durationLocked: isLocked,
            ),
          );
        }
      } else {
        // Первая сборка: берём выбранные логи из очереди (или все незавершенные, если ничего не выбрано)
        final candidates = _selectedLogIds.isNotEmpty
            ? _logs.where((l) => _selectedLogIds.contains(l.id)).toList()
            : unconsumedLogs.where((l) => !l.isRunning).toList();

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
          builderLogs.add(
            DayBuilderLogInput(
              sourceLogId: c.id,
              issueId: c.issueId,
              titleSnapshot: c.titleSnapshot,
              description: c.description,
              sourceDurationSeconds: c.accumulatedSeconds,
              durationLocked: _lockedSourceLogIds.contains(c.id),
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

      final plan = DayBuilder.build(input: input, seed: seed);

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
      _statusMessage = 'День успешно собран.';
    } finally {
      _isBuildingDay = false;
      notifyListeners();
    }
  }

  void updateSegment({
    required String segmentId,
    required DateTime startUtc,
    required int durationSeconds,
    required String description,
  }) {
    if (_currentDraft == null) return;
    final idx = _currentSegments.indexWhere((s) => s.id == segmentId);
    if (idx == -1) return;

    final oldSegment = _currentSegments[idx];
    final updatedSegment = oldSegment.copyWith(
      startUtc: startUtc,
      durationSeconds: durationSeconds,
      description: description,
    );

    final updatedList = List<Segment>.from(_currentSegments);
    updatedList[idx] = updatedSegment;
    updatedList.sort((a, b) => a.startUtc.compareTo(b.startUtc));

    _currentSegments = updatedList;

    // Проверяем, не расширились ли границы дня
    var newStart = _currentDraft!.startUtc;
    var newEnd = _currentDraft!.endUtc;
    if (updatedSegment.startUtc.isBefore(newStart)) {
      newStart = updatedSegment.startUtc;
    }
    if (updatedSegment.endUtc.isAfter(newEnd)) {
      newEnd = updatedSegment.endUtc;
    }

    if (newStart != _currentDraft!.startUtc ||
        newEnd != _currentDraft!.endUtc) {
      _currentDraft = _currentDraft!.copyWith(
        startUtc: newStart,
        endUtc: newEnd,
      );
      store.updateDayDraft(_currentDraft!);
    }

    store.updateSegment(updatedSegment);
    _revalidateCurrentPlan();
    notifyListeners();
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

  /// Отправка текущего черновика дня в Jira (сценарии A14, A17).
  Future<SendDraftResult?> submitCurrentDraft() async {
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
    super.dispose();
  }
}
