import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' hide Row;
import 'package:jira_time_tracker/app_state.dart';
import 'package:jira_time_tracker/connection_store.dart';
import 'package:jira_time_tracker/jira_client.dart';
import 'package:jira_time_tracker/local_store.dart';
import 'package:jira_time_tracker/models.dart';
import 'package:jira_time_tracker/secure_storage.dart';
import 'package:jira_time_tracker/ui/day_screen.dart';
import 'package:jira_time_tracker/ui/merge_segments_dialog.dart';
import 'package:jira_time_tracker/ui/split_segment_dialog.dart';

void main() {
  late Database db;
  late LocalStore store;
  late ConnectionStore connectionStore;
  late JiraClient jiraClient;
  late DateTime currentTime;

  DateTime testNow() => currentTime;

  setUp(() {
    db = sqlite3.openInMemory();
    store = LocalStore(db);
    store.init();
    connectionStore = ConnectionStore(
      secureStorage: InMemorySecureStorage(),
      environment: {},
    );
    jiraClient = JiraClient();
    currentTime = DateTime.utc(2026, 9, 14, 9, 0, 0);

    store.upsertIssue(
      Issue(
        scope: 'default',
        issueId: '10001',
        key: 'PROJ-1',
        summary: 'Первая задача',
        lastUsedAtUtc: currentTime,
      ),
    );
    store.upsertIssue(
      Issue(
        scope: 'default',
        issueId: '10002',
        key: 'PROJ-2',
        summary: 'Вторая задача',
        lastUsedAtUtc: currentTime,
      ),
    );
  });

  tearDown(() {
    store.close();
    jiraClient.close();
  });

  AppState createAppState() {
    return AppState(
      store: store,
      connectionStore: connectionStore,
      jiraClient: jiraClient,
      isReadOnly: false,
      nowProvider: testNow,
    );
  }

  Future<void> seedDraftWithSegments(AppState appState) async {
    final log1 = await appState.addManualLog(issueId: '10001', durationSeconds: 3600);
    final log2 = await appState.addManualLog(issueId: '10002', durationSeconds: 3600);

    final draft = DayDraft(
      id: 'draft-1',
      scope: 'default',
      date: appState.selectedDateString,
      startUtc: currentTime,
      endUtc: currentTime.add(const Duration(hours: 4)),
      seed: 1,
      settingsSnapshot: '{}',
      status: DraftStatus.draft,
    );

    final seg1 = Segment(
      id: 'seg-1',
      draftId: 'draft-1',
      sourceLogId: log1.id,
      issueId: '10001',
      startUtc: currentTime,
      durationSeconds: 3600,
      description: 'Работа по PROJ-1',
    );
    final seg2 = Segment(
      id: 'seg-2',
      draftId: 'draft-1',
      sourceLogId: log2.id,
      issueId: '10002',
      startUtc: currentTime.add(const Duration(hours: 1)),
      durationSeconds: 3600,
      description: 'Работа по PROJ-2',
    );

    store.saveDayDraft(
      draft: draft,
      draftLogs: [
        DraftLog(
          draftId: 'draft-1',
          sourceLogId: log1.id,
          sourceDurationSeconds: 3600,
          descriptionSnapshot: log1.description,
        ),
        DraftLog(
          draftId: 'draft-1',
          sourceLogId: log2.id,
          sourceDurationSeconds: 3600,
          descriptionSnapshot: log2.description,
        ),
      ],
      segments: [seg1, seg2],
      breaks: [],
    );

    appState.loadDraftForSelectedDate();
  }

  testWidgets(
    'Фиксация времени сегмента (замок) переключает isFixed и показывает индикатор',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = createAppState();
      await seedDraftWithSegments(appState);

      await tester.pumpWidget(
        MaterialApp(home: DayScreen(appState: appState)),
      );
      await tester.pumpAndSettle();

      expect(appState.currentSegments[0].isFixed, isFalse);

      // Нажимаем кнопку фиксации времени на первом сегменте
      final lockBtn = find.byTooltip('Зафиксировать время').first;
      await tester.tap(lockBtn);
      await tester.pumpAndSettle();

      expect(appState.currentSegments[0].isFixed, isTrue);
      expect(find.byTooltip('Время зафиксировано'), findsOneWidget);
      expect(find.byTooltip('Снять фиксацию времени'), findsOneWidget);

      // Снимаем фиксацию
      final unlockBtn = find.byTooltip('Снять фиксацию времени').first;
      await tester.tap(unlockBtn);
      await tester.pumpAndSettle();

      expect(appState.currentSegments[0].isFixed, isFalse);
    },
  );

  testWidgets(
    'Кнопки «Вверх» и «Вниз» перемещают сегменты в списке',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = createAppState();
      await seedDraftWithSegments(appState);

      await tester.pumpWidget(
        MaterialApp(home: DayScreen(appState: appState)),
      );
      await tester.pumpAndSettle();

      expect(appState.currentSegments.map((s) => s.id).toList(), ['seg-1', 'seg-2']);

      // Нажимаем переместить вниз на первом сегменте
      final moveDownBtn = find.byTooltip('Переместить вниз').first;
      await tester.tap(moveDownBtn);
      await tester.pumpAndSettle();

      // Порядок изменился
      expect(appState.currentSegments.map((s) => s.id).toList(), ['seg-2', 'seg-1']);

      // Нажимаем переместить вверх на seg-1 (он теперь второй)
      final moveUpBtns = find.byTooltip('Переместить вверх');
      // seg-1 находится на позиции 1, его кнопка активна
      await tester.tap(moveUpBtns.last);
      await tester.pumpAndSettle();

      // Порядок вернулся
      expect(appState.currentSegments.map((s) => s.id).toList(), ['seg-1', 'seg-2']);
    },
  );

  testWidgets(
    'Разбиение сегмента через SplitSegmentDialog',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = createAppState();
      await seedDraftWithSegments(appState);

      await tester.pumpWidget(
        MaterialApp(home: DayScreen(appState: appState)),
      );
      await tester.pumpAndSettle();

      expect(appState.currentSegments.length, 2);

      // Нажимаем «Разбить интервал» на первом сегменте (3600 сек)
      final splitBtn = find.byTooltip('Разбить интервал').first;
      await tester.tap(splitBtn);
      await tester.pumpAndSettle();

      expect(find.byType(SplitSegmentDialog), findsOneWidget);
      expect(find.text('Разбить интервал'), findsOneWidget);

      // Диалог по умолчанию предлагает 30 мин (половина)
      // Нажимаем подтвердить «Разбить»
      final submitBtn = find.descendant(
        of: find.byType(SplitSegmentDialog),
        matching: find.widgetWithText(FilledButton, 'Разбить'),
      );
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Диалог закрыт, сегментов стало 3
      expect(find.byType(SplitSegmentDialog), findsNothing);
      expect(appState.currentSegments.length, 3);
      expect(appState.currentSegments[0].durationSeconds, 1800);
      expect(appState.currentSegments[1].durationSeconds, 1800);
    },
  );

  testWidgets(
    'Объединение сегментов через MergeSegmentsDialog',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = createAppState();
      await seedDraftWithSegments(appState);

      await tester.pumpWidget(
        MaterialApp(home: DayScreen(appState: appState)),
      );
      await tester.pumpAndSettle();

      expect(appState.currentSegments.length, 2);

      // Нажимаем «Объединить интервалы» на первом сегменте
      final mergeBtn = find.byTooltip('Объединить интервалы').first;
      await tester.tap(mergeBtn);
      await tester.pumpAndSettle();

      expect(find.byType(MergeSegmentsDialog), findsOneWidget);
      expect(find.text('Объединить интервалы'), findsOneWidget);

      // Выбираем второй сегмент (PROJ-2)
      final candidateTile = find.descendant(
        of: find.byType(MergeSegmentsDialog),
        matching: find.text('Работа по PROJ-2'),
      );
      await tester.tap(candidateTile);
      await tester.pumpAndSettle();

      // Нажимаем «Объединить»
      final submitBtn = find.descendant(
        of: find.byType(MergeSegmentsDialog),
        matching: find.widgetWithText(FilledButton, 'Объединить'),
      );
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Диалог закрыт, сегментов стал 1
      expect(find.byType(MergeSegmentsDialog), findsNothing);
      expect(appState.currentSegments.length, 1);
      expect(appState.currentSegments.first.durationSeconds, 7200);
    },
  );

  testWidgets(
    'Кнопка «Пересобрать день» в шапке пересчитывает расписание',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = createAppState();
      await seedDraftWithSegments(appState);

      await tester.pumpWidget(
        MaterialApp(home: DayScreen(appState: appState)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Пересобрать день'), findsOneWidget);

      final rebuildBtn = find.widgetWithText(OutlinedButton, 'Пересобрать день');
      await tester.tap(rebuildBtn);
      await tester.pumpAndSettle();

      expect(find.text('День пересобран с сохранением порядка и якорей.'), findsOneWidget);
    },
  );
}
