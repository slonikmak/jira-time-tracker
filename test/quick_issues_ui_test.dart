import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jira_time_tracker/app_state.dart';
import 'package:jira_time_tracker/connection_store.dart';
import 'package:jira_time_tracker/jira_client.dart';
import 'package:jira_time_tracker/local_store.dart';
import 'package:jira_time_tracker/main.dart';
import 'package:jira_time_tracker/models.dart';
import 'package:jira_time_tracker/secure_storage.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  const connection = JiraConnection(
    baseUrl: 'https://team.atlassian.net',
    email: 'user@example.com',
    accountId: 'account-1',
    displayName: 'Team User',
    route: JiraAuthRoute.direct,
    scope: 'https://team.atlassian.net#account-1',
  );

  late Database db;
  late LocalStore store;
  late ConnectionStore connectionStore;
  late JiraClient jiraClient;

  setUp(() async {
    db = sqlite3.openInMemory();
    store = LocalStore(db)..init();
    store.setSetting('ui_language', 'ru');
    connectionStore = ConnectionStore(
      secureStorage: InMemorySecureStorage(),
      environment: {},
    );
    await connectionStore.saveConnection(connection, 'token');
    jiraClient = JiraClient(
      client: MockClient((request) async {
        final identifier = request.url.pathSegments.last;
        return http.Response(
          jsonEncode({
            'id': '1001',
            'key': identifier,
            'fields': {'summary': 'Командные встречи'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });

  tearDown(() {
    jiraClient.close();
    store.close();
  });

  AppState createAppState({
    bool readOnly = false,
    JiraConnection? initialConnection = connection,
  }) {
    return AppState(
      store: store,
      connectionStore: connectionStore,
      jiraClient: jiraClient,
      isReadOnly: readOnly,
      initialConnection: initialConnection,
      nowProvider: () => DateTime.utc(2026, 9, 25, 10),
    );
  }

  void useCompactWindow(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets(
    'добавляет быструю задачу через preview и открывает для неё ручное время',
    (tester) async {
      useCompactWindow(tester, const Size(1152, 800));
      final appState = createAppState();
      addTearDown(appState.dispose);

      await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Настройки'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('settings-section-quick-issues')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Быстрых задач пока нет'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('quick-issue-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('quick-issue-input')),
        'TEAM-42',
      );
      await tester.tap(find.byKey(const ValueKey('quick-issue-find')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('quick-issue-preview')), findsOneWidget);
      expect(find.text('Командные встречи'), findsOneWidget);
      expect(appState.issues, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('quick-issue-note')),
        'Еженедельные синки',
      );
      await tester.tap(find.byKey(const ValueKey('quick-issue-save')));
      await tester.pumpAndSettle();

      expect(appState.quickIssues, hasLength(1));
      expect(find.text('Еженедельные синки'), findsOneWidget);

      await tester.tap(find.text('Работа').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quick-issues-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Еженедельные синки'), findsNWidgets(2));
      await tester.tap(find.text('Командные встречи').last);
      await tester.pumpAndSettle();

      expect(find.text('Добавить время'), findsWidgets);
      expect(find.text('TEAM-42'), findsWidgets);
      expect(find.text('Еженедельные синки'), findsNWidgets(2));
    },
  );

  testWidgets('пустое меню ведёт прямо в настройки быстрых задач', (
    tester,
  ) async {
    useCompactWindow(tester, const Size(1152, 800));
    final appState = createAppState();
    addTearDown(appState.dispose);

    await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quick-issues-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Настроить быстрые задачи'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('quick-issues-section')), findsOneWidget);
    expect(find.text('Быстрых задач пока нет'), findsOneWidget);
  });

  testWidgets('узкие настройки используют селектор раздела', (tester) async {
    useCompactWindow(tester, const Size(960, 880));
    final appState = createAppState();
    addTearDown(appState.dispose);

    await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Настройки'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('settings-section-selector')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('settings-section-jira')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('settings-section-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Быстрые задачи').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quick-issues-section')), findsOneWidget);
  });

  testWidgets('режим только чтения отключает CRUD быстрых задач', (
    tester,
  ) async {
    useCompactWindow(tester, const Size(1152, 800));
    final issue = Issue(
      scope: connection.scope,
      issueId: '1001',
      key: 'TEAM-42',
      summary: 'Командные встречи',
      lastUsedAtUtc: DateTime.utc(2026, 9, 25),
    );
    store.upsertIssue(issue);
    store.addQuickIssue(
      QuickIssue(
        scope: connection.scope,
        issueId: issue.issueId,
        note: 'Еженедельные синки',
        createdAtUtc: DateTime.utc(2026, 9, 25),
      ),
    );
    final appState = createAppState(readOnly: true);
    addTearDown(appState.dispose);

    await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Настройки'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('settings-section-quick-issues')),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('quick-issue-add')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('quick-issue-edit-1001')),
          )
          .onPressed,
      isNull,
    );
    expect(find.textContaining('только чтения'), findsWidgets);
  });

  testWidgets('подсказку можно изменить, а удаление не удаляет Issue', (
    tester,
  ) async {
    useCompactWindow(tester, const Size(1152, 800));
    final issue = Issue(
      scope: connection.scope,
      issueId: '1001',
      key: 'TEAM-42',
      summary: 'Командные встречи',
      lastUsedAtUtc: DateTime.utc(2026, 9, 25),
    );
    store.upsertIssue(issue);
    store.addQuickIssue(
      QuickIssue(
        scope: connection.scope,
        issueId: issue.issueId,
        note: 'Старая подсказка',
        createdAtUtc: DateTime.utc(2026, 9, 25),
      ),
    );
    final appState = createAppState();
    addTearDown(appState.dispose);

    await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Настройки'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('settings-section-quick-issues')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('quick-issue-edit-1001')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('quick-issue-note')),
      'Новая подсказка',
    );
    await tester.tap(find.byKey(const ValueKey('quick-issue-save')));
    await tester.pumpAndSettle();
    expect(appState.quickIssues.single.note, 'Новая подсказка');

    await tester.tap(find.byTooltip('Действия'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить из быстрых'));
    await tester.pumpAndSettle();

    expect(appState.quickIssues, isEmpty);
    expect(find.text('Быстрых задач пока нет'), findsOneWidget);
    expect(store.getIssue(connection.scope, issue.issueId), isNotNull);
  });

  testWidgets('без подключения быстрые задачи ведут к Jira-разделу', (
    tester,
  ) async {
    useCompactWindow(tester, const Size(1152, 800));
    final appState = createAppState(initialConnection: null);
    addTearDown(appState.dispose);

    await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Настройки'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('settings-section-quick-issues')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Сначала подключите Jira'), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-issue-add')), findsNothing);
    await tester.tap(find.text('Перейти к подключению'));
    await tester.pumpAndSettle();
    expect(find.text('Адрес Jira'), findsOneWidget);
  });

  testWidgets('общий ввод времени группирует быстрые без дублей', (
    tester,
  ) async {
    useCompactWindow(tester, const Size(1152, 800));
    final quick = Issue(
      scope: connection.scope,
      issueId: '1001',
      key: 'TEAM-42',
      summary: 'Командные встречи',
      lastUsedAtUtc: DateTime.utc(2026, 9, 25),
    );
    final recent = Issue(
      scope: connection.scope,
      issueId: '1002',
      key: 'TEAM-99',
      summary: 'Обычная задача',
      lastUsedAtUtc: DateTime.utc(2026, 9, 25, 9),
    );
    store.upsertIssue(quick);
    store.upsertIssue(recent);
    store.addQuickIssue(
      QuickIssue(
        scope: connection.scope,
        issueId: quick.issueId,
        note: 'Еженедельные синки',
        createdAtUtc: DateTime.utc(2026, 9, 25),
      ),
    );
    final appState = createAppState();
    addTearDown(appState.dispose);

    await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-time-global')));
    await tester.pumpAndSettle();

    final dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    expect(dropdown.items, hasLength(2));
    expect(dropdown.items!.map((item) => item.value), ['1001', '1002']);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('БЫСТРЫЕ ЗАДАЧИ'), findsOneWidget);
    expect(find.text('НЕДАВНИЕ ЗАДАЧИ'), findsOneWidget);
    expect(find.text('Еженедельные синки'), findsNWidgets(2));
  });
}
