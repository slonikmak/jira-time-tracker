import 'package:sqlite3/sqlite3.dart';
import 'models.dart';

/// Исключение при попытке записи во втором (read-only) экземпляре приложения.
class ReadOnlyException implements Exception {
  final String message;
  const ReadOnlyException([
    this.message =
        'Хранилище работает в режиме только чтения: другой экземпляр приложения удерживает блокировку записи.',
  ]);

  @override
  String toString() => message;
}

/// Управление локальной SQLite базой данных приложения.
class LocalStore {
  final Database _db;
  final bool isReadOnly;

  LocalStore(this._db, {this.isReadOnly = false});

  Database get db => _db;

  /// Инициализирует базу данных: включает foreign keys и применяет миграции.
  void init() {
    _db.execute('PRAGMA foreign_keys = ON;');
    _runMigrations();
  }

  void _runMigrations() {
    final versionRow = _db.select('PRAGMA user_version;');
    final currentVersion = versionRow.first.values.first as int;

    if (currentVersion < 1) {
      _db.execute('BEGIN TRANSACTION;');
      try {
        _db.execute('''
          CREATE TABLE IF NOT EXISTS issues (
            scope TEXT NOT NULL,
            issue_id TEXT NOT NULL,
            key TEXT NOT NULL,
            summary TEXT NOT NULL,
            last_used_at_utc TEXT NOT NULL,
            current_log_id TEXT,
            PRIMARY KEY (scope, issue_id)
          );

          CREATE INDEX IF NOT EXISTS idx_issues_scope_key ON issues (scope, key);
          CREATE INDEX IF NOT EXISTS idx_issues_last_used ON issues (scope, last_used_at_utc DESC);

          CREATE TABLE IF NOT EXISTS local_logs (
            id TEXT PRIMARY KEY,
            scope TEXT NOT NULL,
            issue_id TEXT NOT NULL,
            title_snapshot TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            accumulated_seconds INTEGER NOT NULL DEFAULT 0,
            running_since_utc TEXT,
            created_at_utc TEXT NOT NULL,
            consumed_at_utc TEXT,
            FOREIGN KEY (scope, issue_id) REFERENCES issues (scope, issue_id) ON DELETE CASCADE
          );

          CREATE INDEX IF NOT EXISTS idx_local_logs_scope ON local_logs (scope, consumed_at_utc);

          CREATE TABLE IF NOT EXISTS day_drafts (
            id TEXT PRIMARY KEY,
            scope TEXT NOT NULL,
            date TEXT NOT NULL,
            start_utc TEXT NOT NULL,
            end_utc TEXT NOT NULL,
            seed INTEGER NOT NULL,
            settings_snapshot TEXT NOT NULL,
            imported_worklogs_snapshot TEXT NOT NULL DEFAULT '[]',
            status TEXT NOT NULL,
            UNIQUE (scope, date)
          );

          CREATE TABLE IF NOT EXISTS draft_logs (
            draft_id TEXT NOT NULL,
            source_log_id TEXT NOT NULL,
            source_duration_seconds INTEGER NOT NULL,
            description_snapshot TEXT NOT NULL,
            duration_locked INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (draft_id, source_log_id),
            FOREIGN KEY (draft_id) REFERENCES day_drafts (id) ON DELETE CASCADE,
            FOREIGN KEY (source_log_id) REFERENCES local_logs (id) ON DELETE CASCADE
          );

          CREATE TABLE IF NOT EXISTS segments (
            id TEXT PRIMARY KEY,
            draft_id TEXT NOT NULL,
            source_log_id TEXT NOT NULL,
            issue_id TEXT NOT NULL,
            start_utc TEXT NOT NULL,
            duration_seconds INTEGER NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            send_state TEXT NOT NULL,
            jira_worklog_id TEXT,
            last_error TEXT,
            frozen_payload TEXT,
            FOREIGN KEY (draft_id) REFERENCES day_drafts (id) ON DELETE CASCADE,
            FOREIGN KEY (source_log_id) REFERENCES local_logs (id) ON DELETE CASCADE
          );

          CREATE INDEX IF NOT EXISTS idx_segments_draft ON segments (draft_id);

          CREATE TABLE IF NOT EXISTS breaks (
            id TEXT PRIMARY KEY,
            draft_id TEXT NOT NULL,
            start_utc TEXT NOT NULL,
            duration_seconds INTEGER NOT NULL,
            kind TEXT NOT NULL,
            FOREIGN KEY (draft_id) REFERENCES day_drafts (id) ON DELETE CASCADE
          );

          CREATE INDEX IF NOT EXISTS idx_breaks_draft ON breaks (draft_id);

          PRAGMA user_version = 1;
        ''');
        _db.execute('COMMIT;');
      } catch (e) {
        _db.execute('ROLLBACK;');
        rethrow;
      }
    }
  }

  void _checkWritable() {
    if (isReadOnly) {
      throw const ReadOnlyException();
    }
  }

  /// Восстановление после аварии: переводит зависшие sending в unknown (сценарий A19).
  void recoverUnfinishedSending() {
    _checkWritable();
    _db.execute(
      "UPDATE segments SET send_state = 'unknown' WHERE send_state = 'sending';",
    );
  }

  // --- Операции с задачами (Issue) ---

  void upsertIssue(Issue issue) {
    _checkWritable();
    final stmt = _db.prepare('''
      INSERT INTO issues (scope, issue_id, key, summary, last_used_at_utc, current_log_id)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(scope, issue_id) DO UPDATE SET
        key = excluded.key,
        summary = excluded.summary,
        last_used_at_utc = excluded.last_used_at_utc,
        current_log_id = COALESCE(excluded.current_log_id, issues.current_log_id);
    ''');
    try {
      stmt.execute([
        issue.scope,
        issue.issueId,
        issue.key,
        issue.summary,
        issue.lastUsedAtUtc.toIso8601String(),
        issue.currentLogId,
      ]);
    } finally {
      stmt.close();
    }
  }

  List<Issue> getIssues({required String scope}) {
    final stmt = _db.prepare('''
      SELECT scope, issue_id, key, summary, last_used_at_utc, current_log_id
      FROM issues
      WHERE scope = ?
      ORDER BY last_used_at_utc DESC;
    ''');
    try {
      final rows = stmt.select([scope]);
      return rows.map((row) => Issue.fromMap(row)).toList();
    } finally {
      stmt.close();
    }
  }

  Issue? getIssue(String scope, String issueId) {
    final stmt = _db.prepare('''
      SELECT scope, issue_id, key, summary, last_used_at_utc, current_log_id
      FROM issues
      WHERE scope = ? AND issue_id = ?;
    ''');
    try {
      final rows = stmt.select([scope, issueId]);
      if (rows.isEmpty) return null;
      return Issue.fromMap(rows.first);
    } finally {
      stmt.close();
    }
  }

  Issue? getIssueByKey(String scope, String key) {
    final stmt = _db.prepare('''
      SELECT scope, issue_id, key, summary, last_used_at_utc, current_log_id
      FROM issues
      WHERE scope = ? AND UPPER(key) = UPPER(?);
    ''');
    try {
      final rows = stmt.select([scope, key]);
      if (rows.isEmpty) return null;
      return Issue.fromMap(rows.first);
    } finally {
      stmt.close();
    }
  }

  // --- Операции с локальными логами (LocalLog) ---

  void upsertLocalLog(LocalLog log) {
    _checkWritable();
    final stmt = _db.prepare('''
      INSERT INTO local_logs (id, scope, issue_id, title_snapshot, description, accumulated_seconds, running_since_utc, created_at_utc, consumed_at_utc)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        title_snapshot = excluded.title_snapshot,
        description = excluded.description,
        accumulated_seconds = excluded.accumulated_seconds,
        running_since_utc = excluded.running_since_utc,
        consumed_at_utc = excluded.consumed_at_utc;
    ''');
    try {
      stmt.execute([
        log.id,
        log.scope,
        log.issueId,
        log.titleSnapshot,
        log.description,
        log.accumulatedSeconds,
        log.runningSinceUtc?.toIso8601String(),
        log.createdAtUtc.toIso8601String(),
        log.consumedAtUtc?.toIso8601String(),
      ]);
    } finally {
      stmt.close();
    }
  }

  LocalLog? getLocalLog(String id) {
    final stmt = _db.prepare('''
      SELECT id, scope, issue_id, title_snapshot, description, accumulated_seconds, running_since_utc, created_at_utc, consumed_at_utc
      FROM local_logs
      WHERE id = ?;
    ''');
    try {
      final rows = stmt.select([id]);
      if (rows.isEmpty) return null;
      return LocalLog.fromMap(rows.first);
    } finally {
      stmt.close();
    }
  }

  List<LocalLog> getLocalLogs({
    required String scope,
    bool onlyUnconsumed = false,
  }) {
    final sql = onlyUnconsumed
        ? '''
          SELECT id, scope, issue_id, title_snapshot, description, accumulated_seconds, running_since_utc, created_at_utc, consumed_at_utc
          FROM local_logs
          WHERE scope = ? AND consumed_at_utc IS NULL
          ORDER BY created_at_utc DESC;
        '''
        : '''
          SELECT id, scope, issue_id, title_snapshot, description, accumulated_seconds, running_since_utc, created_at_utc, consumed_at_utc
          FROM local_logs
          WHERE scope = ?
          ORDER BY created_at_utc DESC;
        ''';

    final stmt = _db.prepare(sql);
    try {
      final rows = stmt.select([scope]);
      return rows.map((row) => LocalLog.fromMap(row)).toList();
    } finally {
      stmt.close();
    }
  }

  /// Транзакционное сохранение нескольких логов и задачи (сценарии A01-A04).
  void saveLogsAndIssue({required List<LocalLog> logs, required Issue issue}) {
    _checkWritable();
    _db.execute('BEGIN TRANSACTION;');
    try {
      for (final log in logs) {
        upsertLocalLog(log);
      }
      upsertIssue(issue);
      _db.execute('COMMIT;');
    } catch (e) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  /// Транзакционное сохранение лога и задачи (сценарии A01-A04).
  void saveLogAndIssue({required LocalLog log, required Issue issue}) {
    saveLogsAndIssue(logs: [log], issue: issue);
  }

  void deleteLocalLog(String id) {
    _checkWritable();
    _db.execute('BEGIN TRANSACTION;');
    try {
      _db.execute(
        'UPDATE issues SET current_log_id = NULL WHERE current_log_id = ?;',
        [id],
      );
      _db.execute('DELETE FROM local_logs WHERE id = ?;', [id]);
      _db.execute('COMMIT;');
    } catch (e) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  void close() {
    _db.close();
  }
}
