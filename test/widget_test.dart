import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:jira_time_tracker/app_state.dart';
import 'package:jira_time_tracker/local_store.dart';
import 'package:jira_time_tracker/main.dart';

void main() {
  late Database db;
  late LocalStore store;

  setUp(() {
    db = sqlite3.openInMemory();
    store = LocalStore(db);
    store.init();
  });

  tearDown(() {
    store.close();
  });

  testWidgets('Renders main shell with tabs and settings button', (
    WidgetTester tester,
  ) async {
    final appState = AppState(store: store, isReadOnly: false);

    await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
    await tester.pumpAndSettle();

    // Заголовок приложения
    expect(find.text('Jira Time Tracker'), findsOneWidget);

    // Вкладки
    expect(find.text('Работа'), findsOneWidget);
    expect(find.text('День'), findsOneWidget);

    // Начальный экран - Работа
    expect(find.text('Экран «Работа»'), findsOneWidget);

    // Переключение на вкладку «День»
    await tester.tap(find.text('День'));
    await tester.pumpAndSettle();
    expect(find.text('Экран «День»'), findsOneWidget);

    // Кнопка настроек
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Настройки'), findsOneWidget);

    // Закрытие диалога
    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();
    expect(find.text('Настройки'), findsNothing);

    // В обычном режиме баннер read-only отсутствует
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });

  testWidgets('Shows read-only warning banner when isReadOnly is true (A19)', (
    WidgetTester tester,
  ) async {
    final readOnlyAppState = AppState(store: store, isReadOnly: true);

    await tester.pumpWidget(JiraTimeTrackerApp(appState: readOnlyAppState));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(
      find.textContaining('Режим только чтения: другой экземпляр приложения'),
      findsOneWidget,
    );
  });
}
