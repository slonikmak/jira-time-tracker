import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' hide Row;
import 'package:jira_time_tracker/app_state.dart';
import 'package:jira_time_tracker/connection_store.dart';
import 'package:jira_time_tracker/jira_client.dart';
import 'package:jira_time_tracker/local_store.dart';
import 'package:jira_time_tracker/main.dart';
import 'package:jira_time_tracker/models.dart';
import 'package:jira_time_tracker/secure_storage.dart';
import 'package:jira_time_tracker/ui/merge_logs_dialog.dart';

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
    store.setSetting('ui_language', 'ru');
    connectionStore = ConnectionStore(
      secureStorage: InMemorySecureStorage(),
      environment: {},
    );
    jiraClient = JiraClient();
    currentTime = DateTime.utc(2026, 9, 14, 10, 0, 0);

    store.upsertIssue(
      Issue(
        scope: 'default',
        issueId: '10001',
        key: 'PROJ-1',
        summary: 'Разработка фичи',
        status: 'В работе',
        lastUsedAtUtc: currentTime,
      ),
    );
    store.upsertIssue(
      Issue(
        scope: 'default',
        issueId: '10002',
        key: 'PROJ-2',
        summary: 'Тестирование фичи',
        status: 'В работе',
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

  Future<void> revealLogRow(WidgetTester tester, String id) async {
    final row = find.byKey(ValueKey('log-$id'));
    final pageScroll = find.byType(SingleChildScrollView);
    if (row.evaluate().isEmpty && pageScroll.evaluate().isNotEmpty) {
      await tester.drag(pageScroll.first, const Offset(0, -420));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
  }

  testWidgets('Показывает фиксированное время старта в строке лога', (
    WidgetTester tester,
  ) async {
    final appState = createAppState();
    await appState.addManualLog(
      issueId: '10001',
      durationSeconds: 3600,
      fixedStartTime: '10:30',
    );
    final logId = appState.unconsumedLogs.single.id;

    await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
    await tester.pumpAndSettle();

    await revealLogRow(tester, logId);
    expect(find.text('10:30'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets('Разделение лога через меню «Разбить»', (
    WidgetTester tester,
  ) async {
    final appState = createAppState();
    await appState.addManualLog(
      issueId: '10001',
      durationSeconds: 7200,
      description: 'Общая работа',
    );
    final logId = appState.unconsumedLogs.single.id;

    await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
    await tester.pumpAndSettle();

    await revealLogRow(tester, logId);

    expect(appState.unconsumedLogs.length, 1);
    expect(find.text('2ч 00м'), findsOneWidget);

    // Нажимаем на меню действий лога (три точки)
    final menuBtn = find.byTooltip('Действия с логом').first;
    await tester.tap(menuBtn);
    await tester.pumpAndSettle();

    // Нажимаем «Разбить»
    await tester.tap(find.text('Разбить'));
    await tester.pumpAndSettle();

    // Проверяем открытие диалога
    expect(find.text('Разбить запись времени'), findsOneWidget);

    // Вводим 1 час для первой части
    final h1Field = find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        )
        .first;
    await tester.enterText(h1Field, '1');
    await tester.pumpAndSettle();

    // Нажимаем подтвердить «Разбить»
    final submitBtn = find.widgetWithText(FilledButton, 'Разбить');
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    // Проверяем результат: теперь 2 лога по 1ч
    expect(appState.unconsumedLogs.length, 2);
    expect(appState.unconsumedLogs[0].accumulatedSeconds, 3600);
    expect(appState.unconsumedLogs[1].accumulatedSeconds, 3600);
    expect(find.text('1ч 00м'), findsNWidgets(2));
  });

  testWidgets('Объединение логов через меню «Объединить с...»', (
    WidgetTester tester,
  ) async {
    final appState = createAppState();
    await appState.addManualLog(
      issueId: '10001',
      durationSeconds: 3600,
      description: 'Часть 1',
    );
    final firstLogId = appState.unconsumedLogs.first.id;
    await appState.addManualLog(
      issueId: '10001',
      durationSeconds: 7200,
      description: 'Часть 2',
    );
    final secondLogId = appState.unconsumedLogs.last.id;
    expect(secondLogId, isNot(firstLogId));

    await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
    await tester.pumpAndSettle();

    await revealLogRow(tester, firstLogId);

    expect(appState.unconsumedLogs.length, 2);

    // Открываем меню первого лога
    final menuBtn = find.byTooltip('Действия с логом').first;
    await tester.tap(menuBtn);
    await tester.pumpAndSettle();

    // Нажимаем «Объединить с...»
    await tester.tap(find.text('Объединить с…'));
    await tester.pumpAndSettle();

    // Проверяем диалог
    expect(find.text('Объединить с другим логом'), findsOneWidget);
    expect(find.text('Выберите лог для объединения:'), findsOneWidget);

    // Выбираем второй лог внутри диалога
    // (оба источника остаются перечислены в меню диалога)
    final candidateTile = find.descendant(
      of: find.byType(MergeLogsDialog),
      matching: find.text('Часть 2'),
    );
    await tester.tap(candidateTile);
    await tester.pumpAndSettle();

    // Нажимаем объединить
    final mergeBtn = find.descendant(
      of: find.byType(MergeLogsDialog),
      matching: find.widgetWithText(FilledButton, 'Объединить'),
    );
    await tester.tap(mergeBtn);
    await tester.pumpAndSettle();

    // Теперь 1 лог с длительностью 3 часа (10800 сек)
    expect(appState.unconsumedLogs.length, 1);
    expect(appState.unconsumedLogs.first.accumulatedSeconds, 10800);
    expect(find.text('3ч 00м'), findsOneWidget);
    expect(find.text('Всего 3ч 00м'), findsOneWidget);
  });
}
