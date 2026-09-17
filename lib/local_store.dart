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
            status TEXT,
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
            is_manual INTEGER NOT NULL DEFAULT 0,
            fixed_start_time TEXT,
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
            is_fixed INTEGER NOT NULL DEFAULT 0,
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

          PRAGMA user_version = 2;
        ''');
        _db.execute('COMMIT;');
      } catch (e) {
        _db.execute('ROLLBACK;');
        rethrow;
      }
    }

    // Для существующих баз гарантируем наличие колонки status
    final columns = _db.select('PRAGMA table_info(issues);');
    final hasStatus = columns.any((c) => c['name'] == 'status');
    if (!hasStatus) {
      _db.execute('ALTER TABLE issues ADD COLUMN status TEXT;');
    }

    // Для существующих баз гарантируем наличие колонки is_manual
    final logColumns = _db.select('PRAGMA table_info(local_logs);');
    final hasIsManual = logColumns.any((c) => c['name'] == 'is_manual');
    if (!hasIsManual) {
      _db.execute(
        'ALTER TABLE local_logs ADD COLUMN is_manual INTEGER NOT NULL DEFAULT 0;',
      );
    }

    // Для существующих баз гарантируем наличие колонки fixed_start_time
    final hasFixedStartTime = logColumns.any((c) => c['name'] == 'fixed_start_time');
    if (!hasFixedStartTime) {
      _db.execute('ALTER TABLE local_logs ADD COLUMN fixed_start_time TEXT;');
    }

    // Для существующих баз гарантируем наличие колонки is_fixed
    final segmentColumns = _db.select('PRAGMA table_info(segments);');
    final hasIsFixed = segmentColumns.any((c) => c['name'] == 'is_fixed');
    if (!hasIsFixed) {
      _db.execute(
        'ALTER TABLE segments ADD COLUMN is_fixed INTEGER NOT NULL DEFAULT 0;',
      );
    }

    if (currentVersion < 2) {
      _db.execute('PRAGMA user_version = 2;');
    }
  }

  void _checkWritable() {
    if (isReadOnly) {
      throw const ReadOnlyException();
    }
  }

  /// Восстановление после аварии: переводит зависшие sending в unknown (сценарий A19).
  void recoverUnfinishedSending() {
    if (isReadOnly) return;
    _db.execute('''
      UPDATE segments
      SET send_state = 'unknown',
          last_error = 'Прервано до получения подтверждения (восстановлено при запуске)'
      WHERE send_state = 'sending';
    ''');
    _db.execute('''
      UPDATE day_drafts
      SET status = 'draft'
      WHERE status = 'sending';
    ''');
  }

  // --- Операции с задачами (Issue) ---

  void upsertIssue(Issue issue) {
    _checkWritable();
    final stmt = _db.prepare('''
      INSERT INTO issues (scope, issue_id, key, summary, status, last_used_at_utc, current_log_id)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(scope, issue_id) DO UPDATE SET
        key = excluded.key,
        summary = excluded.summary,
        status = excluded.status,
        last_used_at_utc = excluded.last_used_at_utc,
        current_log_id = excluded.current_log_id;
    ''');
    try {
      stmt.execute([
        issue.scope,
        issue.issueId,
        issue.key,
        issue.summary,
        issue.status,
        issue.lastUsedAtUtc.toIso8601String(),
        issue.currentLogId,
      ]);
    } finally {
      stmt.close();
    }
  }

  List<Issue> getIssues({required String scope}) {
    final stmt = _db.prepare('''
      SELECT scope, issue_id, key, summary, status, last_used_at_utc, current_log_id
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
      SELECT scope, issue_id, key, summary, status, last_used_at_utc, current_log_id
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
      SELECT scope, issue_id, key, summary, status, last_used_at_utc, current_log_id
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
      INSERT INTO local_logs (id, scope, issue_id, title_snapshot, description, accumulated_seconds, running_since_utc, created_at_utc, consumed_at_utc, is_manual, fixed_start_time)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        title_snapshot = excluded.title_snapshot,
        description = excluded.description,
        accumulated_seconds = excluded.accumulated_seconds,
        running_since_utc = excluded.running_since_utc,
        consumed_at_utc = excluded.consumed_at_utc,
        is_manual = excluded.is_manual,
        fixed_start_time = excluded.fixed_start_time;
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
        log.isManual ? 1 : 0,
        log.fixedStartTime,
      ]);
    } finally {
      stmt.close();
    }
  }

  LocalLog? getLocalLog(String id) {
    final stmt = _db.prepare('''
      SELECT id, scope, issue_id, title_snapshot, description, accumulated_seconds, running_since_utc, created_at_utc, consumed_at_utc, is_manual, fixed_start_time
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
          SELECT id, scope, issue_id, title_snapshot, description, accumulated_seconds, running_since_utc, created_at_utc, consumed_at_utc, is_manual, fixed_start_time
          FROM local_logs
          WHERE scope = ? AND consumed_at_utc IS NULL
          ORDER BY created_at_utc DESC;
        '''
        : '''
          SELECT id, scope, issue_id, title_snapshot, description, accumulated_seconds, running_since_utc, created_at_utc, consumed_at_utc, is_manual, fixed_start_time
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

  /// Возвращает соответствие {sourceLogId: draftDate} для всех логов,
  /// включенных в незавершённые черновики (сценарии A04, A11).
  Map<String, String> getActiveDraftDatesBySourceLogId({
    required String scope,
  }) {
    final stmt = _db.prepare('''
      SELECT dl.source_log_id, dd.date
      FROM draft_logs dl
      JOIN day_drafts dd ON dl.draft_id = dd.id
      WHERE dd.scope = ? AND dd.status != 'completed';
    ''');
    try {
      final rows = stmt.select([scope]);
      final map = <String, String>{};
      for (final row in rows) {
        map[row['source_log_id'] as String] = row['date'] as String;
      }
      return map;
    } finally {
      stmt.close();
    }
  }

  /// Транзакционное сохранение нескольких логов и задачи (сценарии A01-A04).
  void saveLogsAndIssue({required List<LocalLog> logs, required Issue issue}) {
    _checkWritable();
    _db.execute('BEGIN TRANSACTION;');
    try {
      upsertIssue(issue);
      for (final log in logs) {
        upsertLocalLog(log);
      }
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

  /// Сохранение/замена черновика дня со всеми привязками логов, сегментами и паузами (транзакционно).
  void saveDayDraft({
    required DayDraft draft,
    required List<DraftLog> draftLogs,
    required List<Segment> segments,
    required List<Break> breaks,
  }) {
    _checkWritable();
    _db.execute('BEGIN TRANSACTION;');
    try {
      // Проверка: один активный незавершенный черновик на (scope, date)
      final existingDraft = getDayDraft(scope: draft.scope, date: draft.date);
      if (existingDraft != null && existingDraft.id != draft.id) {
        _db.execute('DELETE FROM day_drafts WHERE id = ?;', [existingDraft.id]);
      }

      // Проверка: лог не может быть включен в черновик на другую незавершенную дату (A04, A11)
      final activeDates = getActiveDraftDatesBySourceLogId(scope: draft.scope);
      for (final dl in draftLogs) {
        final existingDate = activeDates[dl.sourceLogId];
        if (existingDate != null && existingDate != draft.date) {
          throw StateError(
            'Лог ${dl.sourceLogId} уже включен в черновик на дату $existingDate.',
          );
        }
      }

      // Upsert day_drafts
      _db.execute(
        '''
        INSERT OR REPLACE INTO day_drafts (id, scope, date, start_utc, end_utc, seed, settings_snapshot, imported_worklogs_snapshot, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
      ''',
        [
          draft.id,
          draft.scope,
          draft.date,
          draft.startUtc.toIso8601String(),
          draft.endUtc.toIso8601String(),
          draft.seed,
          draft.settingsSnapshot,
          draft.importedWorklogsSnapshot,
          draft.status.name,
        ],
      );

      // Очищаем старые связанные записи этого черновика
      _db.execute('DELETE FROM draft_logs WHERE draft_id = ?;', [draft.id]);
      _db.execute('DELETE FROM segments WHERE draft_id = ?;', [draft.id]);
      _db.execute('DELETE FROM breaks WHERE draft_id = ?;', [draft.id]);

      // Вставляем draft_logs
      for (final dl in draftLogs) {
        _db.execute(
          '''
          INSERT INTO draft_logs (draft_id, source_log_id, source_duration_seconds, description_snapshot, duration_locked)
          VALUES (?, ?, ?, ?, ?);
        ''',
          [
            draft.id,
            dl.sourceLogId,
            dl.sourceDurationSeconds,
            dl.descriptionSnapshot,
            dl.durationLocked ? 1 : 0,
          ],
        );
      }

      // Вставляем segments
      for (final s in segments) {
        _db.execute(
          '''
          INSERT INTO segments (id, draft_id, source_log_id, issue_id, start_utc, duration_seconds, description, send_state, jira_worklog_id, last_error, frozen_payload, is_fixed)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        ''',
          [
            s.id,
            draft.id,
            s.sourceLogId,
            s.issueId,
            s.startUtc.toIso8601String(),
            s.durationSeconds,
            s.description,
            s.sendState.name,
            s.jiraWorklogId,
            s.lastError,
            s.frozenPayload,
            s.isFixed ? 1 : 0,
          ],
        );
      }

      // Вставляем breaks
      for (final b in breaks) {
        _db.execute(
          '''
          INSERT INTO breaks (id, draft_id, start_utc, duration_seconds, kind)
          VALUES (?, ?, ?, ?, ?);
        ''',
          [
            b.id,
            draft.id,
            b.startUtc.toIso8601String(),
            b.durationSeconds,
            b.kind.name,
          ],
        );
      }

      _db.execute('COMMIT;');
    } catch (e) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  /// Получение черновика по scope и дате.
  DayDraft? getDayDraft({required String scope, required String date}) {
    final stmt = _db.prepare('''
      SELECT id, scope, date, start_utc, end_utc, seed, settings_snapshot, imported_worklogs_snapshot, status
      FROM day_drafts
      WHERE scope = ? AND date = ?;
    ''');
    try {
      final rows = stmt.select([scope, date]);
      if (rows.isEmpty) return null;
      return DayDraft.fromMap(rows.first);
    } finally {
      stmt.close();
    }
  }

  /// Получение черновика по ID.
  DayDraft? getDayDraftById(String draftId) {
    final stmt = _db.prepare('''
      SELECT id, scope, date, start_utc, end_utc, seed, settings_snapshot, imported_worklogs_snapshot, status
      FROM day_drafts
      WHERE id = ?;
    ''');
    try {
      final rows = stmt.select([draftId]);
      if (rows.isEmpty) return null;
      return DayDraft.fromMap(rows.first);
    } finally {
      stmt.close();
    }
  }

  /// Получение списка DraftLog для черновика.
  List<DraftLog> getDraftLogs({required String draftId}) {
    final stmt = _db.prepare('''
      SELECT draft_id, source_log_id, source_duration_seconds, description_snapshot, duration_locked
      FROM draft_logs
      WHERE draft_id = ?;
    ''');
    try {
      final rows = stmt.select([draftId]);
      return rows.map((r) => DraftLog.fromMap(r)).toList();
    } finally {
      stmt.close();
    }
  }

  /// Получение списка Segment для черновика, отсортированных по start_utc.
  List<Segment> getSegments({required String draftId}) {
    final stmt = _db.prepare('''
      SELECT id, draft_id, source_log_id, issue_id, start_utc, duration_seconds, description, send_state, jira_worklog_id, last_error, frozen_payload, is_fixed
      FROM segments
      WHERE draft_id = ?
      ORDER BY start_utc ASC;
    ''');
    try {
      final rows = stmt.select([draftId]);
      return rows.map((r) => Segment.fromMap(r)).toList();
    } finally {
      stmt.close();
    }
  }

  /// Получение списка Break для черновика, отсортированных по start_utc.
  List<Break> getBreaks({required String draftId}) {
    final stmt = _db.prepare('''
      SELECT id, draft_id, start_utc, duration_seconds, kind
      FROM breaks
      WHERE draft_id = ?
      ORDER BY start_utc ASC;
    ''');
    try {
      final rows = stmt.select([draftId]);
      return rows.map((r) => Break.fromMap(r)).toList();
    } finally {
      stmt.close();
    }
  }

  /// Полная замена списка перерывов черновика в базе данных.
  void replaceBreaks({
    required String draftId,
    required List<Break> breaks,
  }) {
    _checkWritable();
    _db.execute('BEGIN TRANSACTION;');
    try {
      _db.execute('DELETE FROM breaks WHERE draft_id = ?;', [draftId]);
      for (final b in breaks) {
        _db.execute(
          '''
          INSERT INTO breaks (id, draft_id, start_utc, duration_seconds, kind)
          VALUES (?, ?, ?, ?, ?);
          ''',
          [
            b.id,
            draftId,
            b.startUtc.toIso8601String(),
            b.durationSeconds,
            b.kind.name,
          ],
        );
      }
      _db.execute('COMMIT;');
    } catch (e) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  /// Вставка одного сегмента в базу данных.
  void insertSegment(Segment segment) {
    _checkWritable();
    _db.execute(
      '''
      INSERT INTO segments (id, draft_id, source_log_id, issue_id, start_utc, duration_seconds, description, send_state, jira_worklog_id, last_error, frozen_payload, is_fixed)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    ''',
      [
        segment.id,
        segment.draftId,
        segment.sourceLogId,
        segment.issueId,
        segment.startUtc.toIso8601String(),
        segment.durationSeconds,
        segment.description,
        segment.sendState.name,
        segment.jiraWorklogId,
        segment.lastError,
        segment.frozenPayload,
        segment.isFixed ? 1 : 0,
      ],
    );
  }

  /// Обновление одного сегмента в базе данных.
  void updateSegment(Segment segment) {
    _checkWritable();
    _db.execute(
      '''
      UPDATE segments
      SET start_utc = ?, duration_seconds = ?, description = ?, send_state = ?, jira_worklog_id = ?, last_error = ?, frozen_payload = ?, is_fixed = ?
      WHERE id = ?;
    ''',
      [
        segment.startUtc.toIso8601String(),
        segment.durationSeconds,
        segment.description,
        segment.sendState.name,
        segment.jiraWorklogId,
        segment.lastError,
        segment.frozenPayload,
        segment.isFixed ? 1 : 0,
        segment.id,
      ],
    );
  }

  /// Обновление черновика (например, границ начала/конца или статуса).
  void updateDayDraft(DayDraft draft) {
    _checkWritable();
    _db.execute(
      '''
      UPDATE day_drafts
      SET start_utc = ?, end_utc = ?, seed = ?, settings_snapshot = ?, imported_worklogs_snapshot = ?, status = ?
      WHERE id = ?;
    ''',
      [
        draft.startUtc.toIso8601String(),
        draft.endUtc.toIso8601String(),
        draft.seed,
        draft.settingsSnapshot,
        draft.importedWorklogsSnapshot,
        draft.status.name,
        draft.id,
      ],
    );
  }

  /// Удаление сегмента. Если для sourceLogId больше не осталось сегментов,
  /// удаляет привязку draft_logs, освобождая исходный лог обратно в очередь (A10, A13).
  void deleteSegment({required String draftId, required String segmentId}) {
    _checkWritable();
    _db.execute('BEGIN TRANSACTION;');
    try {
      // Находим sourceLogId удаляемого сегмента
      final stmt = _db.prepare(
        'SELECT source_log_id FROM segments WHERE id = ?;',
      );
      final rows = stmt.select([segmentId]);
      final sourceLogId = rows.isNotEmpty
          ? rows.first['source_log_id'] as String
          : null;
      stmt.close();

      _db.execute('DELETE FROM segments WHERE id = ?;', [segmentId]);

      if (sourceLogId != null) {
        // Проверяем, остались ли ещё сегменты с этим sourceLogId в этом черновике
        final countStmt = _db.prepare(
          'SELECT COUNT(*) as cnt FROM segments WHERE draft_id = ? AND source_log_id = ?;',
        );
        final countRows = countStmt.select([draftId, sourceLogId]);
        final count = countRows.first['cnt'] as int;
        countStmt.close();

        if (count == 0) {
          // Больше нет частей этого лога - освобождаем лог из черновика
          _db.execute(
            'DELETE FROM draft_logs WHERE draft_id = ? AND source_log_id = ?;',
            [draftId, sourceLogId],
          );
        }
      }

      // Проверяем, остались ли вообще сегменты в черновике
      final totalSegmentsStmt = _db.prepare(
        'SELECT COUNT(*) as cnt FROM segments WHERE draft_id = ?;',
      );
      final totalSegments =
          totalSegmentsStmt.select([draftId]).first['cnt'] as int;
      totalSegmentsStmt.close();

      if (totalSegments == 0) {
        // Черновик пуст - удаляем его полностью
        _db.execute('DELETE FROM day_drafts WHERE id = ?;', [draftId]);
      }

      _db.execute('COMMIT;');
    } catch (e) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  /// Исключает из неотправленного черновика лог вместе со всеми его частями.
  void removeLogFromDraft({
    required String draftId,
    required String sourceLogId,
  }) {
    _checkWritable();
    _db.execute('BEGIN TRANSACTION;');
    try {
      final rows = _db.select(
        '''
        SELECT dd.status,
               EXISTS(
                 SELECT 1 FROM segments s
                 WHERE s.draft_id = dl.draft_id
                   AND s.send_state != 'pending'
               ) AS has_started_sending
        FROM draft_logs dl
        JOIN day_drafts dd ON dd.id = dl.draft_id
        WHERE dl.draft_id = ? AND dl.source_log_id = ?;
        ''',
        [draftId, sourceLogId],
      );

      if (rows.isEmpty) {
        _db.execute('COMMIT;');
        return;
      }

      final status = rows.first['status'] as String;
      final hasStartedSending = rows.first['has_started_sending'] as int == 1;
      if (status != DraftStatus.draft.name || hasStartedSending) {
        throw StateError(
          'Нельзя исключить лог после начала отправки дня в Jira.',
        );
      }

      _db.execute(
        'DELETE FROM segments WHERE draft_id = ? AND source_log_id = ?;',
        [draftId, sourceLogId],
      );
      _db.execute(
        'DELETE FROM draft_logs WHERE draft_id = ? AND source_log_id = ?;',
        [draftId, sourceLogId],
      );

      final remainingSources =
          _db.select(
                'SELECT COUNT(*) AS count FROM draft_logs WHERE draft_id = ?;',
                [draftId],
              ).first['count']
              as int;
      if (remainingSources == 0) {
        _db.execute('DELETE FROM day_drafts WHERE id = ?;', [draftId]);
      }

      _db.execute('COMMIT;');
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  /// Полное удаление черновика дня (каскадно удалит draft_logs, segments, breaks).
  void deleteDayDraft(String draftId) {
    _checkWritable();
    _db.execute('DELETE FROM day_drafts WHERE id = ?;', [draftId]);
  }

  /// Пометка исходного лога как использованного (consumedAtUtc) (A10, A14).
  void markLocalLogConsumed(String logId, DateTime consumedAtUtc) {
    _checkWritable();
    _db.execute('UPDATE local_logs SET consumed_at_utc = ? WHERE id = ?;', [
      consumedAtUtc.toIso8601String(),
      logId,
    ]);
  }

  /// Проверяет, переведены ли ВСЕ сегменты данного исходного лога в статус sent (A10, A14).
  bool areAllSegmentsSentForLog(String draftId, String sourceLogId) {
    final stmt = _db.prepare(
      "SELECT COUNT(*) as cnt FROM segments WHERE draft_id = ? AND source_log_id = ? AND send_state != 'sent';",
    );
    try {
      final rows = stmt.select([draftId, sourceLogId]);
      return (rows.first['cnt'] as int) == 0;
    } finally {
      stmt.close();
    }
  }

  /// Проверяет, переведены ли ВСЕ сегменты черновика в статус sent.
  bool areAllSegmentsSentForDraft(String draftId) {
    final stmt = _db.prepare(
      "SELECT COUNT(*) as cnt FROM segments WHERE draft_id = ? AND send_state != 'sent';",
    );
    try {
      final rows = stmt.select([draftId]);
      return (rows.first['cnt'] as int) == 0;
    } finally {
      stmt.close();
    }
  }

  void close() {
    _db.close();
  }
}
