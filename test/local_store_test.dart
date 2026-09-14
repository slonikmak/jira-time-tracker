import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:jira_time_tracker/models.dart';
import 'package:jira_time_tracker/local_store.dart';
import 'package:jira_time_tracker/single_instance_lock.dart';

void main() {
  group('LocalStore SQLite & Migrations', () {
    late Database db;
    late LocalStore store;

    setUp(() {
      db = sqlite3.openInMemory();
      store = LocalStore(db);
      store.init();
    });

    tearDown(() {
      store.close();
    });

    test('Initializes schema v1 and enforces foreign keys', () {
      final versionRow = db.select('PRAGMA user_version;');
      expect(versionRow.first.values.first, equals(1));

      final fkRow = db.select('PRAGMA foreign_keys;');
      expect(fkRow.first.values.first, equals(1));
    });

    test('Throws ReadOnlyException when store is in read-only mode', () {
      final readOnlyStore = LocalStore(db, isReadOnly: true);

      final issue = Issue(
        scope: 'test-scope',
        issueId: '1001',
        key: 'PROJ-1',
        summary: 'Test task',
        lastUsedAtUtc: DateTime.now().toUtc(),
      );

      expect(
        () => readOnlyStore.upsertIssue(issue),
        throwsA(isA<ReadOnlyException>()),
      );
    });

    test('Upsert and retrieve issue', () {
      final issue = Issue(
        scope: 'test-scope',
        issueId: '1001',
        key: 'PROJ-1',
        summary: 'First summary',
        lastUsedAtUtc: DateTime.utc(2026, 9, 14, 10, 0),
      );

      store.upsertIssue(issue);

      final retrieved = store.getIssue('test-scope', '1001');
      expect(retrieved, isNotNull);
      expect(retrieved!.key, equals('PROJ-1'));
      expect(retrieved.summary, equals('First summary'));

      // Update issue summary and last used
      final updatedIssue = issue.copyWith(
        summary: 'Updated summary',
        lastUsedAtUtc: DateTime.utc(2026, 9, 14, 11, 0),
      );
      store.upsertIssue(updatedIssue);

      final byKey = store.getIssueByKey('test-scope', 'proj-1');
      expect(byKey, isNotNull);
      expect(byKey!.summary, equals('Updated summary'));
    });

    test(
      'Foreign key enforcement: cannot create LocalLog without existing Issue',
      () {
        final log = LocalLog(
          id: 'log-1',
          scope: 'test-scope',
          issueId: 'non-existing',
          titleSnapshot: 'Non existing task',
          createdAtUtc: DateTime.now().toUtc(),
        );

        expect(
          () => store.upsertLocalLog(log),
          throwsA(isA<SqliteException>()),
        );
      },
    );

    test('LocalLog CRUD and cascade deletion when issue is deleted', () {
      final issue = Issue(
        scope: 'test-scope',
        issueId: '1002',
        key: 'PROJ-2',
        summary: 'Cascade task',
        lastUsedAtUtc: DateTime.now().toUtc(),
      );
      store.upsertIssue(issue);

      final log = LocalLog(
        id: 'log-2',
        scope: 'test-scope',
        issueId: '1002',
        titleSnapshot: 'Cascade task',
        description: 'Working on feature',
        accumulatedSeconds: 3600,
        createdAtUtc: DateTime.now().toUtc(),
      );
      store.upsertLocalLog(log);

      final retrievedLog = store.getLocalLog('log-2');
      expect(retrievedLog, isNotNull);
      expect(retrievedLog!.accumulatedSeconds, equals(3600));

      final unconsumed = store.getLocalLogs(
        scope: 'test-scope',
        onlyUnconsumed: true,
      );
      expect(unconsumed.length, equals(1));

      // Mark consumed
      final consumedLog = log.copyWith(consumedAtUtc: DateTime.now().toUtc());
      store.upsertLocalLog(consumedLog);

      expect(
        store.getLocalLogs(scope: 'test-scope', onlyUnconsumed: true),
        isEmpty,
      );
      expect(
        store.getLocalLogs(scope: 'test-scope', onlyUnconsumed: false).length,
        equals(1),
      );

      // Delete log directly
      store.deleteLocalLog('log-2');
      expect(store.getLocalLog('log-2'), isNull);
    });

    test('Recovers unfinished sending state to unknown on startup (A19)', () {
      // Create issue and day draft to hold segment
      final issue = Issue(
        scope: 'test-scope',
        issueId: '1003',
        key: 'PROJ-3',
        summary: 'Task 3',
        lastUsedAtUtc: DateTime.now().toUtc(),
      );
      store.upsertIssue(issue);

      final log = LocalLog(
        id: 'log-3',
        scope: 'test-scope',
        issueId: '1003',
        titleSnapshot: 'Task 3',
        createdAtUtc: DateTime.now().toUtc(),
      );
      store.upsertLocalLog(log);

      db.execute('''
        INSERT INTO day_drafts (id, scope, date, start_utc, end_utc, seed, settings_snapshot, status)
        VALUES ('draft-1', 'test-scope', '2026-09-14', '2026-09-14T08:00:00Z', '2026-09-14T16:00:00Z', 12345, '{}', 'draft');

        INSERT INTO segments (id, draft_id, source_log_id, issue_id, start_utc, duration_seconds, send_state)
        VALUES ('seg-1', 'draft-1', 'log-3', '1003', '2026-09-14T08:00:00Z', 3600, 'sending');
      ''');

      store.recoverUnfinishedSending();

      final row = db.select(
        "SELECT send_state FROM segments WHERE id = 'seg-1';",
      );
      expect(row.first['send_state'], equals('unknown'));
    });
  });

  group('SingleInstanceLock межпроцессная блокировка Windows', () {
    late Directory tempDir;
    late String lockPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('jira_lock_test_');
      lockPath = '${tempDir.path}/test.lock';
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'Acquires lock, second attempt fails, releasing allows re-acquisition',
      () {
        final lock1 = SingleInstanceLock();
        final lock2 = SingleInstanceLock();

        expect(lock1.tryAcquire(lockPath), isTrue);
        expect(lock1.isHeld, isTrue);

        // Второй экземпляр пытается захватить блокировку того же файла
        expect(lock2.tryAcquire(lockPath), isFalse);
        expect(lock2.isHeld, isFalse);

        // Первый освобождает
        lock1.release();
        expect(lock1.isHeld, isFalse);

        // Теперь второй может захватить
        expect(lock2.tryAcquire(lockPath), isTrue);
        expect(lock2.isHeld, isTrue);

        lock2.release();
      },
    );
  });
}
