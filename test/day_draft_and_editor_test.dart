import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:jira_time_tracker/app_state.dart';
import 'package:jira_time_tracker/connection_store.dart';
import 'package:jira_time_tracker/jira_client.dart';
import 'package:jira_time_tracker/local_store.dart';
import 'package:jira_time_tracker/models.dart';
import 'package:jira_time_tracker/secure_storage.dart';
import 'package:jira_time_tracker/ui/day_screen.dart';
import 'package:jira_time_tracker/ui/edit_segment_dialog.dart';

void main() {
  group('DayDraft & Schedule Editor (Ticket 07)', () {
    late Database db;
    late LocalStore store;
    const testScope = 'https://test.atlassian.net#acc-123';

    setUp(() {
      db = sqlite3.openInMemory();
      store = LocalStore(db);
      store.init();
    });

    tearDown(() {
      store.close();
    });

    test('Сохранение DayDraft, DraftLog, Segment и Break в SQLite', () {
      final now = DateTime.utc(2026, 9, 14, 8, 0);

      // Подготавливаем задачу и логи
      final issue = Issue(
        scope: testScope,
        issueId: '1001',
        key: 'PROJ-1',
        summary: 'Фича',
        lastUsedAtUtc: now,
      );
      final log1 = LocalLog(
        id: 'log-1',
        scope: testScope,
        issueId: '1001',
        titleSnapshot: 'PROJ-1',
        accumulatedSeconds: 7200,
        createdAtUtc: now,
      );
      final log2 = LocalLog(
        id: 'log-2',
        scope: testScope,
        issueId: '1001',
        titleSnapshot: 'PROJ-1',
        accumulatedSeconds: 3600,
        createdAtUtc: now,
      );
      store.saveLogsAndIssue(logs: [log1, log2], issue: issue);

      final draft = DayDraft(
        id: 'draft-1',
        scope: testScope,
        date: '2026-09-14',
        startUtc: now,
        endUtc: now.add(const Duration(hours: 8)),
        seed: 42,
        settingsSnapshot: const DaySettings().toJson(),
        status: DraftStatus.draft,
      );

      final draftLogs = [
        const DraftLog(
          draftId: 'draft-1',
          sourceLogId: 'log-1',
          sourceDurationSeconds: 7200,
          descriptionSnapshot: 'Разработка',
          durationLocked: true,
        ),
        const DraftLog(
          draftId: 'draft-1',
          sourceLogId: 'log-2',
          sourceDurationSeconds: 3600,
          descriptionSnapshot: 'Тестирование',
          durationLocked: false,
        ),
      ];

      final segments = [
        Segment(
          id: 'seg-1',
          draftId: 'draft-1',
          sourceLogId: 'log-1',
          issueId: '1001',
          startUtc: now,
          durationSeconds: 3600,
          description: 'Разработка часть 1',
        ),
        Segment(
          id: 'seg-2',
          draftId: 'draft-1',
          sourceLogId: 'log-1',
          issueId: '1001',
          startUtc: now.add(const Duration(hours: 1)),
          durationSeconds: 3600,
          description: 'Разработка часть 2',
        ),
        Segment(
          id: 'seg-3',
          draftId: 'draft-1',
          sourceLogId: 'log-2',
          issueId: '1001',
          startUtc: now.add(const Duration(hours: 3)),
          durationSeconds: 3600,
          description: 'Тестирование',
        ),
      ];

      final breaks = [
        Break(
          id: 'brk-1',
          draftId: 'draft-1',
          startUtc: now.add(const Duration(hours: 2)),
          durationSeconds: 3600,
          kind: BreakKind.lunch,
        ),
      ];

      store.saveDayDraft(
        draft: draft,
        draftLogs: draftLogs,
        segments: segments,
        breaks: breaks,
      );

      // Проверяем чтение из SQLite
      final loadedDraft = store.getDayDraft(
        scope: testScope,
        date: '2026-09-14',
      );
      expect(loadedDraft, isNotNull);
      expect(loadedDraft!.id, 'draft-1');
      expect(loadedDraft.seed, 42);

      final loadedDraftLogs = store.getDraftLogs(draftId: 'draft-1');
      expect(loadedDraftLogs.length, 2);
      expect(loadedDraftLogs.first.durationLocked, isTrue);

      final loadedSegments = store.getSegments(draftId: 'draft-1');
      expect(loadedSegments.length, 3);
      expect(loadedSegments[0].id, 'seg-1');
      expect(loadedSegments[1].id, 'seg-2');

      final loadedBreaks = store.getBreaks(draftId: 'draft-1');
      expect(loadedBreaks.length, 1);
      expect(loadedBreaks.first.kind, BreakKind.lunch);

      // Проверяем привязку логов к черновику
      final activeDates = store.getActiveDraftDatesBySourceLogId(
        scope: testScope,
      );
      expect(activeDates['log-1'], '2026-09-14');
      expect(activeDates['log-2'], '2026-09-14');
    });

    test(
      'Один незавершенный черновик на (scope, date) и защита от дублирования привязки (A04, A11)',
      () {
        final now = DateTime.utc(2026, 9, 14, 8, 0);
        final issue = Issue(
          scope: testScope,
          issueId: '1001',
          key: 'PROJ-1',
          summary: 'Фича',
          lastUsedAtUtc: now,
        );
        final log1 = LocalLog(
          id: 'log-1',
          scope: testScope,
          issueId: '1001',
          titleSnapshot: 'PROJ-1',
          accumulatedSeconds: 3600,
          createdAtUtc: now,
        );
        store.saveLogAndIssue(log: log1, issue: issue);

        final draft1 = DayDraft(
          id: 'draft-1',
          scope: testScope,
          date: '2026-09-14',
          startUtc: now,
          endUtc: now.add(const Duration(hours: 8)),
          seed: 1,
          settingsSnapshot: const DaySettings().toJson(),
          status: DraftStatus.draft,
        );

        store.saveDayDraft(
          draft: draft1,
          draftLogs: [
            const DraftLog(
              draftId: 'draft-1',
              sourceLogId: 'log-1',
              sourceDurationSeconds: 3600,
              descriptionSnapshot: '',
            ),
          ],
          segments: [
            Segment(
              id: 'seg-1',
              draftId: 'draft-1',
              sourceLogId: 'log-1',
              issueId: '1001',
              startUtc: now,
              durationSeconds: 3600,
            ),
          ],
          breaks: [],
        );

        // Попытка привязать log-1 к черновику на ДРУГУЮ дату должна выбросить ошибку
        final draft2 = DayDraft(
          id: 'draft-2',
          scope: testScope,
          date: '2026-09-15',
          startUtc: now.add(const Duration(days: 1)),
          endUtc: now.add(const Duration(days: 1, hours: 8)),
          seed: 2,
          settingsSnapshot: const DaySettings().toJson(),
          status: DraftStatus.draft,
        );

        expect(
          () => store.saveDayDraft(
            draft: draft2,
            draftLogs: [
              const DraftLog(
                draftId: 'draft-2',
                sourceLogId: 'log-1',
                sourceDurationSeconds: 3600,
                descriptionSnapshot: '',
              ),
            ],
            segments: [],
            breaks: [],
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'Удаление сегмента освобождает лог обратно в очередь только когда удалены ВСЕ его части (A10, A13)',
      () {
        final now = DateTime.utc(2026, 9, 14, 8, 0);
        final issue = Issue(
          scope: testScope,
          issueId: '1001',
          key: 'PROJ-1',
          summary: 'Фича',
          lastUsedAtUtc: now,
        );
        final log1 = LocalLog(
          id: 'log-1',
          scope: testScope,
          issueId: '1001',
          titleSnapshot: 'PROJ-1',
          accumulatedSeconds: 7200,
          createdAtUtc: now,
        );
        store.saveLogAndIssue(log: log1, issue: issue);
        final log2 = LocalLog(
          id: 'log-2',
          scope: testScope,
          issueId: '1001',
          titleSnapshot: 'PROJ-1',
          accumulatedSeconds: 1800,
          createdAtUtc: now,
        );
        store.upsertLocalLog(log2);

        final draft = DayDraft(
          id: 'draft-1',
          scope: testScope,
          date: '2026-09-14',
          startUtc: now,
          endUtc: now.add(const Duration(hours: 8)),
          seed: 42,
          settingsSnapshot: const DaySettings().toJson(),
          status: DraftStatus.draft,
        );

        store.saveDayDraft(
          draft: draft,
          draftLogs: [
            const DraftLog(
              draftId: 'draft-1',
              sourceLogId: 'log-1',
              sourceDurationSeconds: 7200,
              descriptionSnapshot: '',
            ),
            const DraftLog(
              draftId: 'draft-1',
              sourceLogId: 'log-2',
              sourceDurationSeconds: 1800,
              descriptionSnapshot: '',
            ),
          ],
          segments: [
            Segment(
              id: 'seg-1',
              draftId: 'draft-1',
              sourceLogId: 'log-1',
              issueId: '1001',
              startUtc: now,
              durationSeconds: 3600,
            ),
            Segment(
              id: 'seg-2',
              draftId: 'draft-1',
              sourceLogId: 'log-1',
              issueId: '1001',
              startUtc: now.add(const Duration(hours: 1)),
              durationSeconds: 3600,
            ),
          ],
          breaks: [],
        );

        // Изначально log-1 привязан к черновику
        expect(
          store
              .getActiveDraftDatesBySourceLogId(scope: testScope)
              .containsKey('log-1'),
          isTrue,
        );

        final failedSegment = store
            .getSegments(draftId: 'draft-1')
            .first
            .copyWith(sendState: SendState.failed);
        store.updateSegment(failedSegment);
        expect(
          () => store.removeLogFromDraft(
            draftId: 'draft-1',
            sourceLogId: 'log-2',
          ),
          throwsStateError,
        );
        expect(store.getSegments(draftId: 'draft-1'), hasLength(2));
        expect(
          store
              .getActiveDraftDatesBySourceLogId(scope: testScope)
              .containsKey('log-2'),
          isTrue,
        );
        store.updateSegment(
          failedSegment.copyWith(sendState: SendState.pending),
        );

        // Удаляем первый сегмент
        store.deleteSegment(draftId: 'draft-1', segmentId: 'seg-1');

        // Второй сегмент остался, log-1 всё ещё привязан
        final remainingSegments = store.getSegments(draftId: 'draft-1');
        expect(remainingSegments.length, 1);
        expect(remainingSegments.first.id, 'seg-2');
        expect(
          store
              .getActiveDraftDatesBySourceLogId(scope: testScope)
              .containsKey('log-1'),
          isTrue,
        );

        // Удаляем второй (последний) сегмент этого лога
        store.deleteSegment(draftId: 'draft-1', segmentId: 'seg-2');

        // Теперь лог освобождён обратно в очередь
        expect(
          store
              .getActiveDraftDatesBySourceLogId(scope: testScope)
              .containsKey('log-1'),
          isFalse,
        );
      },
    );

    test(
      'A18: Точный UTC timestamp сохраняется около полуночи без суточного сдвига',
      () {
        // 23:45 UTC на границе суток
        final midnightEdgeUtc = DateTime.utc(2026, 9, 14, 23, 45, 0);

        final issue = Issue(
          scope: testScope,
          issueId: '1001',
          key: 'PROJ-1',
          summary: 'Фича',
          lastUsedAtUtc: midnightEdgeUtc,
        );
        final log1 = LocalLog(
          id: 'log-edge',
          scope: testScope,
          issueId: '1001',
          titleSnapshot: 'PROJ-1',
          accumulatedSeconds: 1800,
          createdAtUtc: midnightEdgeUtc,
        );
        store.saveLogAndIssue(log: log1, issue: issue);

        final draft = DayDraft(
          id: 'draft-edge',
          scope: testScope,
          date: '2026-09-14',
          startUtc: midnightEdgeUtc,
          endUtc: midnightEdgeUtc.add(const Duration(hours: 4)),
          seed: 123,
          settingsSnapshot: const DaySettings().toJson(),
          status: DraftStatus.draft,
        );

        store.saveDayDraft(
          draft: draft,
          draftLogs: [
            const DraftLog(
              draftId: 'draft-edge',
              sourceLogId: 'log-edge',
              sourceDurationSeconds: 1800,
              descriptionSnapshot: '',
            ),
          ],
          segments: [
            Segment(
              id: 'seg-edge',
              draftId: 'draft-edge',
              sourceLogId: 'log-edge',
              issueId: '1001',
              startUtc: midnightEdgeUtc,
              durationSeconds: 1800,
            ),
          ],
          breaks: [],
        );

        final loadedDraft = store.getDayDraft(
          scope: testScope,
          date: '2026-09-14',
        )!;
        expect(loadedDraft.startUtc, midnightEdgeUtc);

        final loadedSeg = store.getSegments(draftId: 'draft-edge').first;
        expect(loadedSeg.startUtc, midnightEdgeUtc);
        expect(loadedSeg.startUtc.isUtc, isTrue);
      },
    );

    test(
      'A13: Редактирование сегмента в AppState обновляет расписание и запускает валидацию',
      () async {
        final now = DateTime.utc(2026, 9, 14, 8, 0);
        final issue = Issue(
          scope: testScope,
          issueId: '1001',
          key: 'PROJ-1',
          summary: 'Фича',
          lastUsedAtUtc: now,
        );
        final log1 = LocalLog(
          id: 'log-1',
          scope: testScope,
          issueId: '1001',
          titleSnapshot: 'PROJ-1',
          accumulatedSeconds: 7200,
          createdAtUtc: now,
        );
        store.saveLogAndIssue(log: log1, issue: issue);

        final connectionStore = ConnectionStore(
          secureStorage: InMemorySecureStorage(),
        );
        final appState = AppState(
          store: store,
          connectionStore: connectionStore,
          jiraClient: JiraClient(),
          isReadOnly: false,
          initialConnection: const JiraConnection(
            baseUrl: 'https://test.atlassian.net',
            email: 'test@example.com',
            accountId: 'acc-123',
            displayName: 'Tester',
            route: JiraAuthRoute.direct,
            scope: testScope,
          ),
        );

        appState.setSelectedDate(DateTime(2026, 9, 14));

        // Выбираем лог и собираем день
        appState.toggleLogSelection('log-1');
        await appState.buildDay(customSeed: 42);

        expect(appState.currentDraft, isNotNull);
        expect(appState.currentSegments.isNotEmpty, isTrue);
        expect(appState.validationErrors, isEmpty);

        final firstSeg = appState.currentSegments.first;

        // Ручное изменение начала, длительности и описания (A13)
        final newStartUtc = firstSeg.startUtc.add(const Duration(minutes: 10));
        const newDuration = 5400; // 1.5 часа
        const newDescription = 'Обновленное описание работы';

        appState.updateSegment(
          segmentId: firstSeg.id,
          startUtc: newStartUtc,
          durationSeconds: newDuration,
          description: newDescription,
        );

        final updatedSeg = appState.currentSegments.firstWhere(
          (s) => s.id == firstSeg.id,
        );
        expect(updatedSeg.startUtc, newStartUtc);
        expect(updatedSeg.durationSeconds, newDuration);
        expect(updatedSeg.description, newDescription);

        // Проверяем сохранение в SQLite
        final fromDb = store
            .getSegments(draftId: appState.currentDraft!.id)
            .firstWhere((s) => s.id == firstSeg.id);
        expect(fromDb.startUtc, newStartUtc);
        expect(fromDb.durationSeconds, newDuration);
        expect(fromDb.description, newDescription);
      },
    );

    testWidgets(
      'DayScreen: отображает расписание и открывает диалог редактирования сегмента (A13)',
      (tester) async {
        final now = DateTime.utc(2026, 9, 14, 8, 0);
        final issue = Issue(
          scope: testScope,
          issueId: '1001',
          key: 'PROJ-1',
          summary: 'Фича',
          lastUsedAtUtc: now,
        );
        final log1 = LocalLog(
          id: 'log-1',
          scope: testScope,
          issueId: '1001',
          titleSnapshot: 'PROJ-1',
          accumulatedSeconds: 7200,
          createdAtUtc: now,
        );
        store.saveLogAndIssue(log: log1, issue: issue);

        final connectionStore = ConnectionStore(
          secureStorage: InMemorySecureStorage(),
        );
        final appState = AppState(
          store: store,
          connectionStore: connectionStore,
          jiraClient: JiraClient(),
          isReadOnly: false,
          initialConnection: const JiraConnection(
            baseUrl: 'https://test.atlassian.net',
            email: 'test@example.com',
            accountId: 'acc-123',
            displayName: 'Tester',
            route: JiraAuthRoute.direct,
            scope: testScope,
          ),
        );

        appState.setSelectedDate(DateTime(2026, 9, 14));
        appState.toggleLogSelection('log-1');
        await appState.buildDay(customSeed: 42);

        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(home: DayScreen(appState: appState)),
        );
        await tester.pumpAndSettle();

        // Проверяем отображение заголовка, дат и метрик дня
        expect(find.textContaining('Весь день:'), findsOneWidget);
        expect(find.text('Паузы'), findsWidgets);
        expect(find.text('Новое время'), findsOneWidget);
        expect(find.text('PROJ-1'), findsWidgets);

        // Нажимаем иконку редактирования интервала
        final editButton = find.byTooltip('Редактировать интервал (A13)').first;
        await tester.tap(editButton);
        await tester.pumpAndSettle();

        // Открылся EditSegmentDialog
        expect(find.byType(EditSegmentDialog), findsOneWidget);
        expect(find.text('Сохранить'), findsOneWidget);

        // Меняем описание работы
        await tester.enterText(
          find.widgetWithText(
            TextField,
            'Что было сделано за этот интервал...',
          ),
          'Моя отредактированная работа',
        );
        await tester.pumpAndSettle();

        // Нажимаем Сохранить
        await tester.tap(find.text('Сохранить'));
        await tester.pumpAndSettle();

        // Проверяем, что диалог закрылся и новое описание отображается
        expect(find.byType(EditSegmentDialog), findsNothing);
        expect(find.text('Моя отредактированная работа'), findsOneWidget);
      },
    );

    test(
      'При повторной сборке дня с новыми выбранными логами черновик пересобирается именно из них',
      () async {
        final now = DateTime.utc(2026, 9, 14, 8, 0);
        final issue = Issue(
          scope: testScope,
          issueId: '1001',
          key: 'PROJ-1',
          summary: 'Фича',
          lastUsedAtUtc: now,
        );
        final log1 = LocalLog(
          id: 'log-1',
          scope: testScope,
          issueId: '1001',
          titleSnapshot: 'Лог 1',
          accumulatedSeconds: 3600,
          createdAtUtc: now,
        );
        final log2 = LocalLog(
          id: 'log-2',
          scope: testScope,
          issueId: '1001',
          titleSnapshot: 'Лог 2',
          accumulatedSeconds: 3600,
          createdAtUtc: now,
        );
        store.saveLogAndIssue(log: log1, issue: issue);
        store.saveLogAndIssue(log: log2, issue: issue);

        final connectionStore = ConnectionStore(
          secureStorage: InMemorySecureStorage(),
        );
        final appState = AppState(
          store: store,
          connectionStore: connectionStore,
          jiraClient: JiraClient(),
          isReadOnly: false,
          initialConnection: const JiraConnection(
            baseUrl: 'https://test.atlassian.net',
            email: 'test@example.com',
            accountId: 'acc-123',
            displayName: 'Tester',
            route: JiraAuthRoute.direct,
            scope: testScope,
          ),
        );

        appState.setSelectedDate(DateTime(2026, 9, 14));

        // 1. Собираем день с log-1
        appState.toggleLogSelection('log-1');
        await appState.buildDay(customSeed: 42);

        expect(appState.currentDraftLogs.map((d) => d.sourceLogId).toList(), [
          'log-1',
        ]);
        expect(appState.isLogInDraft('log-1'), isTrue);
        expect(appState.isLogInDraft('log-2'), isFalse);

        // 2. Выбираем log-2 и повторно нажимаем собрать день (оба лога теперь выбраны)
        appState.toggleLogSelection('log-2');
        await appState.buildDay(customSeed: 42);

        expect(appState.currentDraftLogs.map((d) => d.sourceLogId).toSet(), {
          'log-1',
          'log-2',
        });
        expect(appState.isLogInDraft('log-1'), isTrue);
        expect(appState.isLogInDraft('log-2'), isTrue);

        // 3. Исключаем log-1 из черновика
        appState.removeLogFromDraft('log-1');
        expect(appState.currentDraftLogs.map((d) => d.sourceLogId).toList(), [
          'log-2',
        ]);
        expect(appState.isLogInDraft('log-1'), isFalse);
        expect(appState.isLogInDraft('log-2'), isTrue);
        expect(appState.selectedLogIds, {'log-2'});
      },
    );
  });
}
