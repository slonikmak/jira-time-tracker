import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:jira_time_tracker/app_state.dart';
import 'package:jira_time_tracker/connection_store.dart';
import 'package:jira_time_tracker/jira_client.dart';
import 'package:jira_time_tracker/local_store.dart';
import 'package:jira_time_tracker/main.dart';
import 'package:jira_time_tracker/models.dart';
import 'package:jira_time_tracker/secure_storage.dart';

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
    currentTime = DateTime.utc(2026, 9, 14, 10, 0, 0);

    // Добавим задачу в SQLite
    store.upsertIssue(
      Issue(
        scope: 'default',
        issueId: '10001',
        key: 'PROJ-1',
        summary: 'Разработка фичи',
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

  testWidgets(
    'AddTimeDialog открывается из карточки задачи и сохраняет 3 часа (A01)',
    (WidgetTester tester) async {
      final appState = createAppState();

      await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
      await tester.pumpAndSettle();

      expect(find.text('PROJ-1'), findsOneWidget);
      expect(find.text('Разработка фичи'), findsOneWidget);

      // Нажимаем иконку «Добавить время» на карточке задачи
      final addTimeBtn = find.byTooltip('Добавить время вручную').first;
      await tester.tap(addTimeBtn);
      await tester.pumpAndSettle();

      // Открылся диалог
      expect(find.text('Добавить время'), findsOneWidget);
      expect(find.text('Часы'), findsOneWidget);
      expect(find.text('Минуты'), findsOneWidget);

      // Вводим 3 часа
      final hoursField = find.widgetWithText(TextField, 'Часы');
      await tester.enterText(hoursField, '3');
      await tester.pumpAndSettle();

      // Сохраняем
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      // Диалог закрылся, лог появился в очереди справа
      expect(find.text('Добавить время'), findsNothing);
      expect(find.text('Логи к сборке (1)'), findsOneWidget);
      expect(find.text('Всего: 3ч 00м'), findsOneWidget);
      expect(find.text('3ч 00м'), findsOneWidget);

      // В SQLite 10 800 секунд
      expect(appState.unconsumedLogs.first.accumulatedSeconds, 10800);
      expect(appState.unconsumedLogs.first.isRunning, isFalse);
    },
  );

  testWidgets(
    'Запуск (Start) и остановка (Stop) таймера на карточке задачи в UI (A03)',
    (WidgetTester tester) async {
      final appState = createAppState();

      await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
      await tester.pumpAndSettle();

      // Кнопка «Новый лог на задаче» (playlist_add) убрана за ненадобностью
      expect(find.byIcon(Icons.playlist_add), findsNothing);

      // Кликаем Play (Запустить таймер)
      final playBtn = find.byTooltip('Запустить таймер').first;
      await tester.tap(playBtn);
      await tester.pumpAndSettle();

      // Таймер запустился: иконка сменилась на Stop
      expect(find.byTooltip('Остановить таймер'), findsWidgets);
      expect(appState.unconsumedLogs.first.isRunning, isTrue);

      // Перематываем время на 10 минут
      currentTime = currentTime.add(const Duration(minutes: 10));
      await tester.pump();

      // Кликаем Stop (Остановить таймер)
      final stopBtn = find.byTooltip('Остановить таймер').first;
      await tester.tap(stopBtn);
      await tester.pumpAndSettle();

      // Таймер остановлен, зафиксировано 10 минут, карточка сброшена на 00:00:00
      expect(find.byTooltip('Запустить таймер'), findsWidgets);
      expect(appState.unconsumedLogs.first.isRunning, isFalse);
      expect(appState.unconsumedLogs.first.accumulatedSeconds, 600);
      expect(find.text('Всего: 10м'), findsOneWidget);
    },
  );
}
