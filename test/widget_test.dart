import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:jira_time_tracker/app_state.dart';
import 'package:jira_time_tracker/connection_store.dart';
import 'package:jira_time_tracker/jira_client.dart';
import 'package:jira_time_tracker/local_store.dart';
import 'package:jira_time_tracker/main.dart';
import 'package:jira_time_tracker/secure_storage.dart';

void main() {
  late Database db;
  late LocalStore store;
  late SecureStorage secureStorage;
  late ConnectionStore connectionStore;
  late JiraClient jiraClient;

  setUp(() {
    db = sqlite3.openInMemory();
    store = LocalStore(db);
    store.init();
    secureStorage = InMemorySecureStorage();
    connectionStore = ConnectionStore(
      secureStorage: secureStorage,
      environment: {},
    );
    jiraClient = JiraClient();
  });

  tearDown(() {
    store.close();
    jiraClient.close();
  });

  AppState createTestAppState({bool isReadOnly = false}) {
    return AppState(
      store: store,
      connectionStore: connectionStore,
      jiraClient: jiraClient,
      isReadOnly: isReadOnly,
    );
  }

  testWidgets('Renders main shell with tabs and settings button', (
    WidgetTester tester,
  ) async {
    final appState = createTestAppState(isReadOnly: false);

    await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
    await tester.pumpAndSettle();

    // Заголовок приложения
    expect(find.text('Jira Time Tracker'), findsOneWidget);

    // Вкладки
    expect(find.text('Работа'), findsOneWidget);
    expect(find.text('День'), findsOneWidget);

    // Начальный экран - Работа
    expect(find.text('ID или URL задачи'), findsOneWidget);
    expect(find.text('Добавить'), findsOneWidget);
    expect(find.text('Недавние задачи (0)'), findsOneWidget);

    // Переключение на вкладку «День»
    await tester.tap(find.text('День'));
    await tester.pumpAndSettle();
    expect(find.text('Полный день: '), findsOneWidget);

    // Кнопка настроек
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    // Открылся диалог настроек
    expect(find.text('Настройки подключения к Jira'), findsOneWidget);
    expect(find.text('URL Jira Cloud'), findsOneWidget);
    expect(find.text('Email аккаунта Atlassian'), findsOneWidget);
    expect(find.text('API токен Atlassian'), findsOneWidget);

    // Кнопка отмены закрывает диалог
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.text('Настройки подключения к Jira'), findsNothing);

    // В обычном режиме баннер read-only отсутствует
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });

  testWidgets('Shows read-only warning banner when isReadOnly is true (A19)', (
    WidgetTester tester,
  ) async {
    final readOnlyAppState = createTestAppState(isReadOnly: true);

    await tester.pumpWidget(JiraTimeTrackerApp(appState: readOnlyAppState));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(
      find.textContaining('Режим только чтения: другой экземпляр приложения'),
      findsOneWidget,
    );
  });
}
