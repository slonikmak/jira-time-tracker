import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:jira_time_tracker/app_state.dart';
import 'package:jira_time_tracker/connection_store.dart';
import 'package:jira_time_tracker/jira_client.dart';
import 'package:jira_time_tracker/local_store.dart';
import 'package:jira_time_tracker/main.dart';
import 'package:jira_time_tracker/secure_storage.dart';
import 'package:jira_time_tracker/ui/settings_dialog.dart';

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
    expect(find.text('Работа'), findsWidgets);
    expect(find.text('День'), findsWidgets);

    // Начальный экран - Работа
    expect(find.textContaining('задачу Jira'), findsWidgets);
    expect(find.textContaining('Добавить задач'), findsWidgets);
    expect(find.textContaining('Недавние задачи'), findsWidgets);

    // Переключение на вкладку «День»
    await tester.tap(find.text('День').first);
    await tester.pumpAndSettle();
    expect(find.text('Соберите день из своих логов'), findsOneWidget);

    // Кнопка настроек
    final settingsButton = find.widgetWithText(OutlinedButton, 'Настройки');
    expect(settingsButton, findsOneWidget);
    await tester.tap(settingsButton);
    await tester.pumpAndSettle();

    // Открылась страница настроек с прежними полями подключения.
    expect(find.text('Подключение к Jira'), findsOneWidget);
    expect(find.byType(TextField), findsAtLeastNWidgets(3));

    // Возврат к работе сохраняет навигацию.
    await tester.tap(find.text('Работа').first);
    await tester.pumpAndSettle();
    expect(find.text('Подключение к Jira'), findsNothing);

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

    await tester.tap(find.widgetWithText(OutlinedButton, 'Настройки'));
    await tester.pumpAndSettle();
    final themePicker = tester.widget<SegmentedButton<UiThemeMode>>(
      find.byType(SegmentedButton<UiThemeMode>),
    );
    expect(themePicker.onSelectionChanged, isNull);
    expect(
      find.text('В режиме только чтения изменить тему нельзя.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Отмена настроек сбрасывает несохранённые поля при следующем открытии',
    (WidgetTester tester) async {
      final appState = createTestAppState();
      await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Настройки'));
      await tester.pumpAndSettle();
      final initialUrl = tester
          .widget<TextField>(find.byType(TextField).first)
          .controller!
          .text;
      await tester.enterText(
        find.byType(TextField).first,
        'https://changed.example',
      );
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Настройки'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        initialUrl,
      );
    },
  );

  testWidgets('Theme setting changes the app and survives a restart', (
    WidgetTester tester,
  ) async {
    final appState = createTestAppState();
    await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Настройки'));
    await tester.pumpAndSettle();
    expect(find.text('Тема оформления'), findsOneWidget);
    expect(appState.themeMode.value, UiThemeMode.system);

    await tester.tap(find.text('Тёмная'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(SettingsPage))).brightness,
      Brightness.dark,
    );
    expect(store.getSetting('theme_mode'), 'dark');

    await tester.tap(find.text('Светлая'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(SettingsPage))).brightness,
      Brightness.light,
    );

    await tester.tap(find.text('Тёмная'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    appState.dispose();

    final restored = createTestAppState();
    await tester.pumpWidget(JiraTimeTrackerApp(appState: restored));
    await tester.pumpAndSettle();
    expect(restored.themeMode.value, UiThemeMode.dark);
    expect(
      Theme.of(tester.element(find.text('Jira Time Tracker'))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('Настройки дня сохраняют диапазон для умной пересборки', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final appState = createTestAppState();
    await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Настройки'));
    await tester.pumpAndSettle();

    expect(find.text('Сборка дня'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('day-start-min')),
      '08:30',
    );
    await tester.enterText(
      find.byKey(const ValueKey('day-start-max')),
      '09:30',
    );
    await tester.tap(find.text('Сохранить параметры'));
    await tester.pumpAndSettle();

    expect(appState.daySettings.startMinutesMin, 8 * 60 + 30);
    expect(appState.daySettings.startMinutesMax, 9 * 60 + 30);
    expect(store.getSetting('day_settings'), isNotNull);
  });

  testWidgets('Неверный диапазон не сохраняется, сброс ждёт сохранения', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final appState = createTestAppState();
    await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Настройки'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('day-start-min')),
      '10:00',
    );
    await tester.enterText(
      find.byKey(const ValueKey('day-start-max')),
      '09:00',
    );
    await tester.tap(find.text('Сохранить параметры'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Начало дня: укажите'), findsOneWidget);
    expect(store.getSetting('day_settings'), isNull);

    await tester.enterText(
      find.byKey(const ValueKey('day-start-min')),
      '08:30',
    );
    await tester.tap(find.text('Сохранить параметры'));
    await tester.pumpAndSettle();
    expect(appState.daySettings.startMinutesMin, 8 * 60 + 30);

    await tester.tap(find.text('Сбросить'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('day-start-min')))
          .controller!
          .text,
      '08:00',
    );
    expect(appState.daySettings.startMinutesMin, 8 * 60 + 30);
    await tester.tap(find.text('Сохранить параметры'));
    await tester.pumpAndSettle();
    expect(appState.daySettings.startMinutesMin, 8 * 60);
  });
}
