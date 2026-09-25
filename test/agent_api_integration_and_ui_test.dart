import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jira_time_tracker/agent_api_server.dart';
import 'package:jira_time_tracker/app_state.dart';
import 'package:jira_time_tracker/connection_store.dart';
import 'package:jira_time_tracker/jira_client.dart';
import 'package:jira_time_tracker/local_store.dart';
import 'package:jira_time_tracker/secure_storage.dart';
import 'package:jira_time_tracker/ui/settings_dialog.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('AgentApiServer AppState Integration & Settings UI (Ticket 03)', () {
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

    test('AppState управляет жизненным циклом AgentApiServer', () async {
      final appState = createTestAppState();
      expect(appState.isApiServerRunning, isFalse);
      expect(appState.apiServerUrl, isNull);

      // Запуск сервера на свободном порту (0)
      await appState.startApiServer(port: 0);
      expect(appState.isApiServerRunning, isTrue);
      expect(appState.apiServerUrl, startsWith('http://127.0.0.1:'));
      expect(appState.apiServerPort, greaterThan(0));

      final activeUrl = appState.apiServerUrl;

      // Повторный вызов startApiServer идемпотентен
      await appState.startApiServer(port: 0);
      expect(appState.apiServerUrl, equals(activeUrl));

      // Остановка сервера
      await appState.stopApiServer();
      expect(appState.isApiServerRunning, isFalse);
      expect(appState.apiServerUrl, isNull);

      // Read-only режим не запускает сервер
      final readOnlyAppState = createTestAppState(isReadOnly: true);
      await readOnlyAppState.startApiServer(port: 0);
      expect(readOnlyAppState.isApiServerRunning, isFalse);
      expect(readOnlyAppState.apiServerUrl, isNull);

      appState.dispose();
      readOnlyAppState.dispose();
    });

    test(
      'AgentApiServer.generateSkillPrompt формирует валидный промпт со ссылкой на URL',
      () {
        final prompt = AgentApiServer.generateSkillPrompt(
          'http://127.0.0.1:8765',
        );
        expect(prompt, contains('http://127.0.0.1:8765'));
        expect(prompt, contains('/api/logs'));
        expect(prompt, contains('/api/day'));
        expect(prompt, contains('/api/help'));
        expect(prompt, contains('/api/openapi.json'));
        expect(prompt, contains('/api/quick-issues'));
        expect(prompt, isNot(contains('/api/service-tickets')));
        expect(prompt, contains('/api/issues'));
        expect(prompt, contains('source_log_id'));
        expect(prompt, contains('base_revision'));
        expect(prompt, contains('только пользователь'));
      },
    );

    testWidgets(
      'SettingsDialog отображает хост/порт и секцию скилла для агента',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final appState = createTestAppState();

        String? copiedString;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (
              MethodCall methodCall,
            ) async {
              if (methodCall.method == 'Clipboard.setData') {
                copiedString = (methodCall.arguments as Map)['text'] as String?;
              }
              return null;
            });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => SettingsDialog.show(ctx, appState),
                  child: const Text('Open Settings'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Открываем диалог
        await tester.tap(find.text('Open Settings'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Открываем секцию API в новой навигации настроек.
        final sectionSelector = find.byKey(
          const ValueKey('settings-section-selector'),
        );
        await tester.tap(sectionSelector);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Локальный API').last);
        await tester.pumpAndSettle();

        // Проверяем наличие секции Local Agent API
        expect(find.text('Локальный API для AI-агентов'), findsOneWidget);
        expect(
          find.textContaining('Встроенный HTTP-сервер позволяет AI-агентам'),
          findsOneWidget,
        );

        // Проверяем наличие URL сервера в поле
        expect(find.text('http://127.0.0.1:8765'), findsOneWidget);

        // Проверяем наличие кнопки копирования инструкции для агента
        final copyBtn = find.widgetWithText(
          FilledButton,
          'Скопировать инструкцию',
        );
        expect(copyBtn, findsOneWidget);

        await tester.ensureVisible(copyBtn);
        await tester.pump();

        // Вызываем нажатие кнопки копирования инструкции
        final btn = tester.widget<FilledButton>(copyBtn);
        expect(btn.onPressed, isNotNull);
        btn.onPressed!();
        await tester.pump();

        // Проверяем, что в буфер скопирован промпт
        expect(copiedString, isNotNull);
        expect(copiedString, contains('http://127.0.0.1:8765'));
        expect(
          copiedString,
          contains('Навык: Взаимодействие с локальным Jira Time Tracker'),
        );

        // Проматываем таймер SnackBar
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        // Очищаем mock handler платформы
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);

        appState.dispose();
      },
    );
  });
}
