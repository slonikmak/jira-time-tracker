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
  final DateTime lastUsedAtUtc;
  final String? currentLogId;

  const Issue({
    required this.scope,
    required this.issueId,
    required this.key,
    required this.summary,
    required this.lastUsedAtUtc,
    this.currentLogId,
  });

  Map<String, dynamic> toMap() {
    return {
      'scope': scope,
      'issue_id': issueId,
      'key': key,
      'summary': summary,
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
      lastUsedAtUtc: DateTime.parse(map['last_used_at_utc'] as String),
      currentLogId: map['current_log_id'] as String?,
    );
  }

  Issue copyWith({
    String? scope,
    String? issueId,
    String? key,
    String? summary,
    DateTime? lastUsedAtUtc,
    String? currentLogId,
  }) {
    return Issue(
      scope: scope ?? this.scope,
      issueId: issueId ?? this.issueId,
      key: key ?? this.key,
      summary: summary ?? this.summary,
      lastUsedAtUtc: lastUsedAtUtc ?? this.lastUsedAtUtc,
      currentLogId: currentLogId ?? this.currentLogId,
    );
  }
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
    );
  }
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
