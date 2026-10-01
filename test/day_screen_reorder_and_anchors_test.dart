import 'package:jira_time_tracker/l10n/app_localizations.dart';
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

  Future<void> tapRowAction(
    WidgetTester tester,
    String action, {
    int rowIndex = 0,
  }) async {
    final rowMenus = find.byTooltip('Другие действия');
    await tester.ensureVisible(rowMenus.at(rowIndex));
    await tester.tap(rowMenus.at(rowIndex));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action).last);
    await tester.pumpAndSettle();
  }

  setUp(() {
    db = sqlite3.openInMemory();
    store = LocalStore(db);
    store.init();
    store.setSetting('ui_language', 'ru');
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

  Future<void> seedDraftWithSegments(
    AppState appState, {
    bool sameSource = false,
  }) async {
    final log1 = await appState.addManualLog(
      issueId: '10001',
      durationSeconds: sameSource ? 7200 : 3600,
    );
    final log2 = sameSource
        ? log1
        : await appState.addManualLog(issueId: '10002', durationSeconds: 3600);

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
      issueId: sameSource ? '10001' : '10002',
      startUtc: currentTime.add(const Duration(hours: 1)),
      durationSeconds: 3600,
      description: sameSource
          ? 'Работа по PROJ-1 (часть 2)'
          : 'Работа по PROJ-2',
    );

    final draftLogs = [
      DraftLog(
        draftId: 'draft-1',
        sourceLogId: log1.id,
        sourceDurationSeconds: log1.accumulatedSeconds,
        descriptionSnapshot: log1.description,
      ),
      if (!sameSource)
        DraftLog(
          draftId: 'draft-1',
          sourceLogId: log2.id,
          sourceDurationSeconds: log2.accumulatedSeconds,
          descriptionSnapshot: log2.description,
        ),
    ];

    store.saveDayDraft(
      draft: draft,
      draftLogs: draftLogs,
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
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DayScreen(appState: appState),
        ),
      );
      await tester.pumpAndSettle();

      expect(appState.currentSegments[0].isFixed, isFalse);

      // Открываем компактное меню действий и фиксируем время сегмента.
      await tapRowAction(tester, 'Зафиксировать время');

      expect(appState.currentSegments[0].isFixed, isTrue);
      expect(find.byTooltip('Время зафиксировано'), findsOneWidget);
      // Снимаем фиксацию через то же меню действий.
      final firstMenu = find.byTooltip('Другие действия').first;
      await tester.tap(firstMenu);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Снять фиксацию времени'), findsOneWidget);
      await tester.tap(find.text('Снять фиксацию'));
      await tester.pumpAndSettle();

      expect(appState.currentSegments[0].isFixed, isFalse);
    },
  );

  testWidgets('Кнопки «Вверх» и «Вниз» перемещают сегменты в списке', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final appState = createAppState();
    await seedDraftWithSegments(appState);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DayScreen(appState: appState),
      ),
    );
    await tester.pumpAndSettle();

    expect(appState.currentSegments.map((s) => s.id).toList(), [
      'seg-1',
      'seg-2',
    ]);

    // Нажимаем переместить вниз на первом сегменте
    await tapRowAction(tester, 'Переместить вниз');

    // Порядок изменился
    expect(appState.currentSegments.map((s) => s.id).toList(), [
      'seg-2',
      'seg-1',
    ]);

    // Нажимаем переместить вверх на seg-1 (он теперь второй)
    // seg-1 находится на позиции 1, его меню — второе.
    await tapRowAction(tester, 'Переместить вверх', rowIndex: 1);

    // Порядок вернулся
    expect(appState.currentSegments.map((s) => s.id).toList(), [
      'seg-1',
      'seg-2',
    ]);
  });

  testWidgets('Разбиение сегмента через SplitSegmentDialog', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final appState = createAppState();
    await seedDraftWithSegments(appState);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DayScreen(appState: appState),
      ),
    );
    await tester.pumpAndSettle();

    expect(appState.currentSegments.length, 2);

    // Нажимаем «Разбить интервал» на первом сегменте (3600 сек)
    await tapRowAction(tester, 'Разбить интервал');

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
  });

  testWidgets('Объединение сегментов через MergeSegmentsDialog', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final appState = createAppState();
    await seedDraftWithSegments(appState, sameSource: true);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DayScreen(appState: appState),
      ),
    );
    await tester.pumpAndSettle();

    expect(appState.currentSegments.length, 2);

    // Нажимаем «Объединить интервалы» на первом сегменте
    await tapRowAction(tester, 'Объединить интервалы');

    expect(find.byType(MergeSegmentsDialog), findsOneWidget);
    expect(find.text('Объединить интервалы'), findsOneWidget);

    // Выбираем вторую часть того же исходного лога.
    final candidateTile = find.descendant(
      of: find.byType(MergeSegmentsDialog),
      matching: find.text('Работа по PROJ-1 (часть 2)'),
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
  });

  testWidgets('Кнопка «Пересобрать день» в шапке пересчитывает расписание', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final appState = createAppState();
    await seedDraftWithSegments(appState);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DayScreen(appState: appState),
      ),
    );
    await tester.pumpAndSettle();

    final menu = find.byTooltip('Другие действия с расписанием');
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.text('Пересобрать день'), findsOneWidget);
    await tester.tap(find.text('Пересобрать день'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Ручные правки времени будут заменены.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Пересобрать'));
    await tester.pumpAndSettle();

    expect(
      find.text('День пересобран с сохранением порядка и якорей.'),
      findsOneWidget,
    );
  });
}
