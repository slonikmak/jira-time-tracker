import 'dart:convert';

/// Состояние отправки отдельного сегмента в Jira.
enum SendState {
  pending,
  sending,
  sent,
  failed,
  unknown;

  static SendState fromString(String value) {
    return SendState.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SendState.pending,
    );
  }
}

/// Тип перерыва внутри рабочего дня.
enum BreakKind {
  lunch,
  short;

  static BreakKind fromString(String value) {
    return BreakKind.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BreakKind.short,
    );
  }
}

/// Статус черновика дня.
enum DraftStatus {
  draft,
  sending,
  completed;

  static DraftStatus fromString(String value) {
    return DraftStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DraftStatus.draft,
    );
  }
}

/// Кэшированная Jira задача.
class Issue {
  final String scope;
  final String issueId;
  final String key;
  final String summary;
  final String? status;
  final DateTime lastUsedAtUtc;
  final String? currentLogId;

  const Issue({
    required this.scope,
    required this.issueId,
    required this.key,
    required this.summary,
    this.status,
    required this.lastUsedAtUtc,
    this.currentLogId,
  });

  Map<String, dynamic> toMap() {
    return {
      'scope': scope,
      'issue_id': issueId,
      'key': key,
      'summary': summary,
      'status': status,
      'last_used_at_utc': lastUsedAtUtc.toIso8601String(),
      'current_log_id': currentLogId,
    };
  }

  factory Issue.fromMap(Map<String, dynamic> map) {
    return Issue(
      scope: map['scope'] as String,
      issueId: map['issue_id'] as String,
      key: map['key'] as String,
      summary: map['summary'] as String,
      status: map['status'] as String?,
      lastUsedAtUtc: DateTime.parse(map['last_used_at_utc'] as String),
      currentLogId: map['current_log_id'] as String?,
    );
  }

  Issue copyWith({
    String? scope,
    String? issueId,
    String? key,
    String? summary,
    String? status,
    DateTime? lastUsedAtUtc,
    String? currentLogId,
    bool clearCurrentLogId = false,
  }) {
    return Issue(
      scope: scope ?? this.scope,
      issueId: issueId ?? this.issueId,
      key: key ?? this.key,
      summary: summary ?? this.summary,
      status: status ?? this.status,
      lastUsedAtUtc: lastUsedAtUtc ?? this.lastUsedAtUtc,
      currentLogId: clearCurrentLogId
          ? null
          : (currentLogId ?? this.currentLogId),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Issue &&
          runtimeType == other.runtimeType &&
          scope == other.scope &&
          issueId == other.issueId;

  @override
  int get hashCode => Object.hash(scope, issueId);
}

/// Исходная локальная запись о затраченном времени.
class LocalLog {
  final String id;
  final String scope;
  final String issueId;
  final String titleSnapshot;
  final String description;
  final int accumulatedSeconds;
  final DateTime? runningSinceUtc;
  final DateTime createdAtUtc;
  final DateTime? consumedAtUtc;
  final bool isManual;
  final String? fixedStartTime;

  const LocalLog({
    required this.id,
    required this.scope,
    required this.issueId,
    required this.titleSnapshot,
    this.description = '',
    this.accumulatedSeconds = 0,
    this.runningSinceUtc,
    required this.createdAtUtc,
    this.consumedAtUtc,
    this.isManual = false,
    this.fixedStartTime,
  });

  bool get isRunning => runningSinceUtc != null;
  bool get isConsumed => consumedAtUtc != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'scope': scope,
      'issue_id': issueId,
      'title_snapshot': titleSnapshot,
      'description': description,
      'accumulated_seconds': accumulatedSeconds,
      'running_since_utc': runningSinceUtc?.toIso8601String(),
      'created_at_utc': createdAtUtc.toIso8601String(),
      'consumed_at_utc': consumedAtUtc?.toIso8601String(),
      'is_manual': isManual ? 1 : 0,
      'fixed_start_time': fixedStartTime,
    };
  }

  factory LocalLog.fromMap(Map<String, dynamic> map) {
    return LocalLog(
      id: map['id'] as String,
      scope: map['scope'] as String,
      issueId: map['issue_id'] as String,
      titleSnapshot: map['title_snapshot'] as String,
      description: (map['description'] as String?) ?? '',
      accumulatedSeconds: (map['accumulated_seconds'] as int?) ?? 0,
      runningSinceUtc: map['running_since_utc'] != null
          ? DateTime.parse(map['running_since_utc'] as String)
          : null,
      createdAtUtc: DateTime.parse(map['created_at_utc'] as String),
      consumedAtUtc: map['consumed_at_utc'] != null
          ? DateTime.parse(map['consumed_at_utc'] as String)
          : null,
      isManual: (map['is_manual'] as int? ?? 0) == 1,
      fixedStartTime: map['fixed_start_time'] as String?,
    );
  }

  LocalLog copyWith({
    String? id,
    String? scope,
    String? issueId,
    String? titleSnapshot,
    String? description,
    int? accumulatedSeconds,
    DateTime? runningSinceUtc,
    bool clearRunningSince = false,
    DateTime? createdAtUtc,
    DateTime? consumedAtUtc,
    bool? isManual,
    String? fixedStartTime,
    bool clearFixedStartTime = false,
  }) {
    return LocalLog(
      id: id ?? this.id,
      scope: scope ?? this.scope,
      issueId: issueId ?? this.issueId,
      titleSnapshot: titleSnapshot ?? this.titleSnapshot,
      description: description ?? this.description,
      accumulatedSeconds: accumulatedSeconds ?? this.accumulatedSeconds,
      runningSinceUtc: clearRunningSince
          ? null
          : (runningSinceUtc ?? this.runningSinceUtc),
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      consumedAtUtc: consumedAtUtc ?? this.consumedAtUtc,
      isManual: isManual ?? this.isManual,
      fixedStartTime: clearFixedStartTime
          ? null
          : (fixedStartTime ?? this.fixedStartTime),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalLog && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Настройки сборки рабочего дня.
class DaySettings {
  final int startMinutesMin; // 08:00 = 480
  final int startMinutesMax; // 09:00 = 540
  final int totalDurationSecondsMin; // 7h30m = 27000
  final int totalDurationSecondsMax; // 8h = 28800
  final int lunchStartMinutesMin; // 12:00 = 720
  final int lunchStartMinutesMax; // 14:00 = 840
  final int lunchDurationSecondsMin; // 30m = 1800
  final int lunchDurationSecondsMax; // 45m = 2700
  final int shortBreakCountMin; // 2
  final int shortBreakCountMax; // 4
  final int shortBreakDurationSecondsMin; // 5m = 300
  final int shortBreakDurationSecondsMax; // 10m = 600

  const DaySettings({
    this.startMinutesMin = 8 * 60,
    this.startMinutesMax = 9 * 60,
    this.totalDurationSecondsMin = 7 * 3600 + 30 * 60,
    this.totalDurationSecondsMax = 8 * 3600,
    this.lunchStartMinutesMin = 12 * 60,
    this.lunchStartMinutesMax = 14 * 60,
    this.lunchDurationSecondsMin = 30 * 60,
    this.lunchDurationSecondsMax = 45 * 60,
    this.shortBreakCountMin = 2,
    this.shortBreakCountMax = 4,
    this.shortBreakDurationSecondsMin = 5 * 60,
    this.shortBreakDurationSecondsMax = 10 * 60,
  });

  Map<String, dynamic> toMap() {
    return {
      'start_minutes_min': startMinutesMin,
      'start_minutes_max': startMinutesMax,
      'total_duration_seconds_min': totalDurationSecondsMin,
      'total_duration_seconds_max': totalDurationSecondsMax,
      'lunch_start_minutes_min': lunchStartMinutesMin,
      'lunch_start_minutes_max': lunchStartMinutesMax,
      'lunch_duration_seconds_min': lunchDurationSecondsMin,
      'lunch_duration_seconds_max': lunchDurationSecondsMax,
      'short_break_count_min': shortBreakCountMin,
      'short_break_count_max': shortBreakCountMax,
      'short_break_duration_seconds_min': shortBreakDurationSecondsMin,
      'short_break_duration_seconds_max': shortBreakDurationSecondsMax,
    };
  }

  factory DaySettings.fromMap(Map<String, dynamic> map) {
    return DaySettings(
      startMinutesMin: (map['start_minutes_min'] as int?) ?? 8 * 60,
      startMinutesMax: (map['start_minutes_max'] as int?) ?? 9 * 60,
      totalDurationSecondsMin:
          (map['total_duration_seconds_min'] as int?) ?? 7 * 3600 + 30 * 60,
      totalDurationSecondsMax:
          (map['total_duration_seconds_max'] as int?) ?? 8 * 3600,
      lunchStartMinutesMin: (map['lunch_start_minutes_min'] as int?) ?? 12 * 60,
      lunchStartMinutesMax: (map['lunch_start_minutes_max'] as int?) ?? 14 * 60,
      lunchDurationSecondsMin:
          (map['lunch_duration_seconds_min'] as int?) ?? 30 * 60,
      lunchDurationSecondsMax:
          (map['lunch_duration_seconds_max'] as int?) ?? 45 * 60,
      shortBreakCountMin: (map['short_break_count_min'] as int?) ?? 2,
      shortBreakCountMax: (map['short_break_count_max'] as int?) ?? 4,
      shortBreakDurationSecondsMin:
          (map['short_break_duration_seconds_min'] as int?) ?? 5 * 60,
      shortBreakDurationSecondsMax:
          (map['short_break_duration_seconds_max'] as int?) ?? 10 * 60,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory DaySettings.fromJson(String source) =>
      DaySettings.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// Сохранённый план на конкретную дату.
class DayDraft {
  final String id;
  final String scope;
  final String date; // YYYY-MM-DD
  final DateTime startUtc;
  final DateTime endUtc;
  final int seed;
  final String settingsSnapshot;
  final String importedWorklogsSnapshot;
  final DraftStatus status;

  const DayDraft({
    required this.id,
    required this.scope,
    required this.date,
    required this.startUtc,
    required this.endUtc,
    required this.seed,
    required this.settingsSnapshot,
    this.importedWorklogsSnapshot = '[]',
    this.status = DraftStatus.draft,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'scope': scope,
      'date': date,
      'start_utc': startUtc.toIso8601String(),
      'end_utc': endUtc.toIso8601String(),
      'seed': seed,
      'settings_snapshot': settingsSnapshot,
      'imported_worklogs_snapshot': importedWorklogsSnapshot,
      'status': status.name,
    };
  }

  factory DayDraft.fromMap(Map<String, dynamic> map) {
    return DayDraft(
      id: map['id'] as String,
      scope: map['scope'] as String,
      date: map['date'] as String,
      startUtc: DateTime.parse(map['start_utc'] as String),
      endUtc: DateTime.parse(map['end_utc'] as String),
      seed: map['seed'] as int,
      settingsSnapshot: map['settings_snapshot'] as String,
      importedWorklogsSnapshot:
          (map['imported_worklogs_snapshot'] as String?) ?? '[]',
      status: DraftStatus.fromString(map['status'] as String),
    );
  }

  DayDraft copyWith({
    String? id,
    String? scope,
    String? date,
    DateTime? startUtc,
    DateTime? endUtc,
    int? seed,
    String? settingsSnapshot,
    String? importedWorklogsSnapshot,
    DraftStatus? status,
  }) {
    return DayDraft(
      id: id ?? this.id,
      scope: scope ?? this.scope,
      date: date ?? this.date,
      startUtc: startUtc ?? this.startUtc,
      endUtc: endUtc ?? this.endUtc,
      seed: seed ?? this.seed,
      settingsSnapshot: settingsSnapshot ?? this.settingsSnapshot,
      importedWorklogsSnapshot:
          importedWorklogsSnapshot ?? this.importedWorklogsSnapshot,
      status: status ?? this.status,
    );
  }
}

/// Привязка исходного лога к черновику.
class DraftLog {
  final String draftId;
  final String sourceLogId;
  final int sourceDurationSeconds;
  final String descriptionSnapshot;
  final bool durationLocked;

  const DraftLog({
    required this.draftId,
    required this.sourceLogId,
    required this.sourceDurationSeconds,
    required this.descriptionSnapshot,
    this.durationLocked = false,
  });

  DraftLog copyWith({
    String? draftId,
    String? sourceLogId,
    int? sourceDurationSeconds,
    String? descriptionSnapshot,
    bool? durationLocked,
  }) {
    return DraftLog(
      draftId: draftId ?? this.draftId,
      sourceLogId: sourceLogId ?? this.sourceLogId,
      sourceDurationSeconds:
          sourceDurationSeconds ?? this.sourceDurationSeconds,
      descriptionSnapshot: descriptionSnapshot ?? this.descriptionSnapshot,
      durationLocked: durationLocked ?? this.durationLocked,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'draft_id': draftId,
      'source_log_id': sourceLogId,
      'source_duration_seconds': sourceDurationSeconds,
      'description_snapshot': descriptionSnapshot,
      'duration_locked': durationLocked ? 1 : 0,
    };
  }

  factory DraftLog.fromMap(Map<String, dynamic> map) {
    return DraftLog(
      draftId: map['draft_id'] as String,
      sourceLogId: map['source_log_id'] as String,
      sourceDurationSeconds: map['source_duration_seconds'] as int,
      descriptionSnapshot: map['description_snapshot'] as String,
      durationLocked: (map['duration_locked'] as int?) == 1,
    );
  }
}

/// Отдельный интервал (сегмент), отправляемый в Jira как worklog.
class Segment {
  final String id;
  final String draftId;
  final String sourceLogId;
  final String issueId;
  final DateTime startUtc;
  final int durationSeconds;
  final String description;
  final SendState sendState;
  final String? jiraWorklogId;
  final String? lastError;
  final String? frozenPayload;
  final bool isFixed;

  const Segment({
    required this.id,
    required this.draftId,
    required this.sourceLogId,
    required this.issueId,
    required this.startUtc,
    required this.durationSeconds,
    this.description = '',
    this.sendState = SendState.pending,
    this.jiraWorklogId,
    this.lastError,
    this.frozenPayload,
    this.isFixed = false,
  });

  DateTime get endUtc => startUtc.add(Duration(seconds: durationSeconds));

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'draft_id': draftId,
      'source_log_id': sourceLogId,
      'issue_id': issueId,
      'start_utc': startUtc.toIso8601String(),
      'duration_seconds': durationSeconds,
      'description': description,
      'send_state': sendState.name,
      'jira_worklog_id': jiraWorklogId,
      'last_error': lastError,
      'frozen_payload': frozenPayload,
      'is_fixed': isFixed ? 1 : 0,
    };
  }

  factory Segment.fromMap(Map<String, dynamic> map) {
    return Segment(
      id: map['id'] as String,
      draftId: map['draft_id'] as String,
      sourceLogId: map['source_log_id'] as String,
      issueId: map['issue_id'] as String,
      startUtc: DateTime.parse(map['start_utc'] as String),
      durationSeconds: map['duration_seconds'] as int,
      description: (map['description'] as String?) ?? '',
      sendState: SendState.fromString(map['send_state'] as String),
      jiraWorklogId: map['jira_worklog_id'] as String?,
      lastError: map['last_error'] as String?,
      frozenPayload: map['frozen_payload'] as String?,
      isFixed: (map['is_fixed'] as int? ?? 0) == 1,
    );
  }

  Segment copyWith({
    String? id,
    String? draftId,
    String? sourceLogId,
    String? issueId,
    DateTime? startUtc,
    int? durationSeconds,
    String? description,
    SendState? sendState,
    String? jiraWorklogId,
    String? lastError,
    String? frozenPayload,
    bool? isFixed,
  }) {
    return Segment(
      id: id ?? this.id,
      draftId: draftId ?? this.draftId,
      sourceLogId: sourceLogId ?? this.sourceLogId,
      issueId: issueId ?? this.issueId,
      startUtc: startUtc ?? this.startUtc,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      description: description ?? this.description,
      sendState: sendState ?? this.sendState,
      jiraWorklogId: jiraWorklogId ?? this.jiraWorklogId,
      lastError: lastError ?? this.lastError,
      frozenPayload: frozenPayload ?? this.frozenPayload,
      isFixed: isFixed ?? this.isFixed,
    );
  }
}

/// Запланированная пауза (перерыв) внутри дня.
class Break {
  final String id;
  final String draftId;
  final DateTime startUtc;
  final int durationSeconds;
  final BreakKind kind;

  const Break({
    required this.id,
    required this.draftId,
    required this.startUtc,
    required this.durationSeconds,
    required this.kind,
  });

  DateTime get endUtc => startUtc.add(Duration(seconds: durationSeconds));

  Break copyWith({
    String? id,
    String? draftId,
    DateTime? startUtc,
    int? durationSeconds,
    BreakKind? kind,
  }) {
    return Break(
      id: id ?? this.id,
      draftId: draftId ?? this.draftId,
      startUtc: startUtc ?? this.startUtc,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      kind: kind ?? this.kind,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'draft_id': draftId,
      'start_utc': startUtc.toIso8601String(),
      'duration_seconds': durationSeconds,
      'kind': kind.name,
    };
  }

  factory Break.fromMap(Map<String, dynamic> map) {
    return Break(
      id: map['id'] as String,
      draftId: map['draft_id'] as String,
      startUtc: DateTime.parse(map['start_utc'] as String),
      durationSeconds: map['duration_seconds'] as int,
      kind: BreakKind.fromString(map['kind'] as String),
    );
  }
}

/// Описание смежных элементов расписания, прилегающих к вычисляемому промежутку (Timeline Gap).
class GapNeighbors {
  final Segment? leftSegment;
  final ImportedWorklog? leftExisting;
  final Segment? rightSegment;
  final ImportedWorklog? rightExisting;
  final bool isStartOfDay;
  final bool isEndOfDay;

  const GapNeighbors({
    this.leftSegment,
    this.leftExisting,
    this.rightSegment,
    this.rightExisting,
    this.isStartOfDay = false,
    this.isEndOfDay = false,
  });

  bool get isLeftLocked => leftExisting != null;
  bool get isRightLocked => rightExisting != null;

  String? get leftTitle {
    if (leftSegment != null) return 'Сегмент расписания';
    if (leftExisting != null) return 'Jira: ${leftExisting!.issueKey}';
    if (isStartOfDay) return 'Начало дня';
    return null;
  }

  String? get rightTitle {
    if (rightSegment != null) return 'Сегмент расписания';
    if (rightExisting != null) return 'Jira: ${rightExisting!.issueKey}';
    if (isEndOfDay) return 'Конец дня';
    return null;
  }
}


/// Тип маршрута авторизации в Jira Cloud.
enum JiraAuthRoute {
  direct,
  scoped;

  static JiraAuthRoute fromString(String value) {
    return JiraAuthRoute.values.firstWhere(
      (e) => e.name == value,
      orElse: () => JiraAuthRoute.direct,
    );
  }
}

/// Сведения об аккаунте Jira пользователя.
class JiraAccountInfo {
  final String accountId;
  final String displayName;
  final String email;

  const JiraAccountInfo({
    required this.accountId,
    required this.displayName,
    this.email = '',
  });
}

/// Подтверждённое рабочее подключение к Jira.
class JiraConnection {
  final String baseUrl;
  final String email;
  final String accountId;
  final String displayName;
  final JiraAuthRoute route;
  final String? cloudId;
  final String scope;

  const JiraConnection({
    required this.baseUrl,
    required this.email,
    required this.accountId,
    required this.displayName,
    required this.route,
    this.cloudId,
    required this.scope,
  });

  /// Базовый URL для REST API запросов в зависимости от маршрута.
  String get apiBaseUrl {
    if (route == JiraAuthRoute.scoped &&
        cloudId != null &&
        cloudId!.isNotEmpty) {
      return 'https://api.atlassian.com/ex/jira/$cloudId';
    }
    return baseUrl.replaceAll(RegExp(r'/+$'), '');
  }

  Map<String, dynamic> toMap() {
    return {
      'base_url': baseUrl,
      'email': email,
      'account_id': accountId,
      'display_name': displayName,
      'route': route.name,
      'cloud_id': cloudId,
      'scope': scope,
    };
  }

  factory JiraConnection.fromMap(Map<String, dynamic> map) {
    return JiraConnection(
      baseUrl: map['base_url'] as String,
      email: map['email'] as String,
      accountId: map['account_id'] as String,
      displayName: map['display_name'] as String,
      route: JiraAuthRoute.fromString(map['route'] as String),
      cloudId: map['cloud_id'] as String?,
      scope: map['scope'] as String,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory JiraConnection.fromJson(String source) =>
      JiraConnection.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// Данные формы подключения к Jira.
class JiraConnectionForm {
  final String baseUrl;
  final String email;
  final String token;

  const JiraConnectionForm({
    this.baseUrl = 'https://esprowteam.atlassian.net',
    this.email = '',
    this.token = '',
  });

  JiraConnectionForm copyWith({String? baseUrl, String? email, String? token}) {
    return JiraConnectionForm(
      baseUrl: baseUrl ?? this.baseUrl,
      email: email ?? this.email,
      token: token ?? this.token,
    );
  }
}

/// Существующая запись о затраченном времени, загруженная из Jira.
class ImportedWorklog {
  final String id;
  final String issueId;
  final String? issueKey;
  final DateTime startUtc;
  final int durationSeconds;
  final String authorAccountId;
  final String? comment;
  final String? segmentPropertyId;

  const ImportedWorklog({
    required this.id,
    required this.issueId,
    this.issueKey,
    required this.startUtc,
    required this.durationSeconds,
    required this.authorAccountId,
    this.comment,
    this.segmentPropertyId,
  });

  DateTime get endUtc => startUtc.add(Duration(seconds: durationSeconds));

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'issue_id': issueId,
      'issue_key': issueKey,
      'start_utc': startUtc.toIso8601String(),
      'duration_seconds': durationSeconds,
      'author_account_id': authorAccountId,
      'comment': comment,
      'segment_property_id': segmentPropertyId,
    };
  }

  factory ImportedWorklog.fromMap(Map<String, dynamic> map) {
    return ImportedWorklog(
      id: map['id'] as String,
      issueId: map['issue_id'] as String,
      issueKey: map['issue_key'] as String?,
      startUtc: DateTime.parse(map['start_utc'] as String),
      durationSeconds: map['duration_seconds'] as int,
      authorAccountId: map['author_account_id'] as String,
      comment: map['comment'] as String?,
      segmentPropertyId: map['segment_property_id'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory ImportedWorklog.fromJson(String source) =>
      ImportedWorklog.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// Входной сегмент для формирования дня от внешнего AI-агента.
class AgentSegmentInput {
  final String issueKey;
  final DateTime startUtc;
  final int durationSeconds;
  final String description;
  final String? sourceLogId;
  final bool isFixed;
  final String? fixedStartTime;

  const AgentSegmentInput({
    required this.issueKey,
    required this.startUtc,
    required this.durationSeconds,
    this.description = '',
    this.sourceLogId,
    this.isFixed = false,
    this.fixedStartTime,
  });
}

