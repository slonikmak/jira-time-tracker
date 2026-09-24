import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' hide Row;
import 'package:jira_time_tracker/app_state.dart';
import 'package:jira_time_tracker/connection_store.dart';
import 'package:jira_time_tracker/jira_client.dart';
import 'package:jira_time_tracker/local_store.dart';
import 'package:jira_time_tracker/main.dart';
import 'package:jira_time_tracker/secure_storage.dart';
import 'package:jira_time_tracker/service_tickets.dart';
import 'package:jira_time_tracker/ui/add_time_dialog.dart';

void main() {
  late Database db;
  late LocalStore store;
  late ConnectionStore connectionStore;
  late JiraClient jiraClient;
  late DateTime currentTime;

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
      nowProvider: () => currentTime,
    );
  }

  test('Каталог служебных тикетов содержит 18 тикетов с описанием', () {
    expect(kServiceTickets.length, 18);

    final meetingTicket = findServiceTicket('EG-294');
    expect(meetingTicket, isNotNull);
    expect(meetingTicket!.category, 'Non-utilized Meeting/Events');
    expect(
      meetingTicket.description,
      'Созвоны, синги, таунхоллы (не привязанные к конкретной задаче)',
    );

    // Регистронезависимый поиск
    expect(findServiceTicket('eg-294'), equals(meetingTicket));
    expect(findServiceTicket('  EG-294  '), equals(meetingTicket));

    // Несуществующий тикет
    expect(findServiceTicket('UNKNOWN-999'), isNull);
  });

  test(
    'AppState.addServiceTicket сохраняет тикет в базу и обновляет список задач',
    () async {
      final appState = createAppState();
      final ticket = findServiceTicket('EG-297')!;

      final issue = await appState.addServiceTicket(ticket);
      expect(issue.key, 'EG-297');
      expect(issue.summary, 'Work with e-mails (internal/external)');

      expect(appState.issues.any((i) => i.key == 'EG-297'), isTrue);

      // В базе данных сохранилась
      final fromDb = store.getIssueByKey('default', 'EG-297');
      expect(fromDb, isNotNull);
      expect(fromDb!.summary, 'Work with e-mails (internal/external)');
    },
  );

  testWidgets(
    'В AddTimeDialog выпадающее меню содержит служебные тикеты с описанием и позволяет записать время',
    (WidgetTester tester) async {
      final appState = createAppState();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () =>
                      AddTimeDialog.show(context, appState: appState),
                  child: const Text('Открыть диалог'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Открываем диалог
      await tester.tap(find.text('Открыть диалог'));
      await tester.pumpAndSettle();

      // Проверяем, что отображается выпадающий список задач
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

      // В выпадающем меню отображается описание служебного тикета
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Созвоны, синги, таунхоллы (не привязанные к конкретной задаче)',
        ),
        findsWidgets,
      );
      await tester.tap(
        find
            .text(
              'Созвоны, синги, таунхоллы (не привязанные к конкретной задаче)',
            )
            .last,
      );
      await tester.pumpAndSettle();

      // Нажимаем Сохранить (по умолчанию выбран первый служебный тикет EG-294)
      await tester.tap(find.text('Сохранить запись'));
      await tester.pumpAndSettle();

      // Проверяем, что лог успешно создан в очереди
      expect(appState.unconsumedLogs, hasLength(1));
      final log = appState.unconsumedLogs.first;
      expect(log.titleSnapshot, 'Non-utilized Meeting/Events');
      expect(log.accumulatedSeconds, 3600);
    },
  );

  testWidgets(
    'На экране «Работа» карточка служебного тикета отображает его описание',
    (WidgetTester tester) async {
      final appState = createAppState();
      // Добавим служебный тикет
      await appState.addServiceTicket(findServiceTicket('EG-294')!);

      await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
      await tester.pumpAndSettle();

      // На карточке задачи виден ключ, название и описание
      expect(find.text('EG-294'), findsOneWidget);
      expect(find.text('Non-utilized Meeting/Events'), findsOneWidget);
      expect(
        find.text(
          'Созвоны, синги, таунхоллы (не привязанные к конкретной задаче)',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Кнопка «Служебный тикет» на экране «Работа» открывает диалог добавления времени и добавляет лог в список неотправленных',
    (WidgetTester tester) async {
      final appState = createAppState();

      await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
      await tester.pumpAndSettle();

      // Нажимаем кнопку «Служебный тикет»
      await tester.tap(find.text('Служебный тикет'));
      await tester.pumpAndSettle();

      // В меню видны тикеты с описаниями
      expect(
        find.text('Разбор и написание писем (коллегам или контрагентам)'),
        findsOneWidget,
      );

      // Выбираем EG-297
      await tester.tap(
        find.text('Разбор и написание писем (коллегам или контрагентам)'),
      );
      await tester.pumpAndSettle();

      // Должен открыться диалог «Добавить время» с выбранным тикетом
      expect(find.byType(AddTimeDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AddTimeDialog),
          matching: find.text('Добавить время'),
        ),
        findsOneWidget,
      );

      // Сохраняем время (1 час по умолчанию)
      await tester.tap(find.text('Сохранить запись'));
      await tester.pumpAndSettle();

      // Диалог закрылся
      expect(find.byType(AddTimeDialog), findsNothing);

      // Тикет появился в списке задач на экране
      expect(find.text('EG-297'), findsWidgets);
      expect(find.text('Work with e-mails (internal/external)'), findsWidgets);

      // И лог добавлен в список неотправленных (unconsumed)
      expect(appState.unconsumedLogs, hasLength(1));
      expect(
        appState.unconsumedLogs.first.titleSnapshot,
        'Work with e-mails (internal/external)',
      );
      expect(find.textContaining('Очередь'), findsWidgets);
    },
  );
}
