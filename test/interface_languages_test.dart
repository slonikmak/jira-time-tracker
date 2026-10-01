import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:jira_time_tracker/app_state.dart';
import 'package:jira_time_tracker/connection_store.dart';
import 'package:jira_time_tracker/jira_client.dart';
import 'package:jira_time_tracker/local_store.dart';
import 'package:jira_time_tracker/main.dart';
import 'package:jira_time_tracker/secure_storage.dart';
import 'package:jira_time_tracker/models.dart';
import 'package:jira_time_tracker/ui/add_time_dialog.dart';
import 'package:jira_time_tracker/ui/settings_dialog.dart';
import 'package:jira_time_tracker/l10n/app_localizations.dart';
import 'package:jira_time_tracker/app_message.dart';
import 'package:jira_time_tracker/agent_instructions.dart';
import 'package:jira_time_tracker/ui/edit_log_dialog.dart';
import 'package:jira_time_tracker/ui/message_format.dart';
import 'package:jira_time_tracker/ui/app_theme.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUpAll(() async {
    for (final entry in {
      'Inter': 'Inter.ttf',
      'IBM Plex Mono': 'IBMPlexMono-Regular.ttf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(rootBundle.load('assets/fonts/${entry.value}'));
      await loader.load();
    }
  });
  AppState createState(LocalStore store, {bool readOnly = false}) {
    final jira = JiraClient(
      client: MockClient((request) async => http.Response('{}', 500)),
    );
    final state = AppState(
      store: store,
      connectionStore: ConnectionStore(
        secureStorage: InMemorySecureStorage(),
        environment: {},
      ),
      jiraClient: jira,
      isReadOnly: readOnly,
      nowProvider: () => DateTime.utc(2026, 9, 30, 10),
    );
    addTearDown(() {
      state.dispose();
      jira.close();
    });
    return state;
  }

  testWidgets(
    'open edit form and time picker follow a system language change',
    (tester) async {
      tester.binding.platformDispatcher.localesTestValue = [const Locale('ru')];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      final store = LocalStore(sqlite3.openInMemory())..init();
      addTearDown(store.close);
      store.upsertIssue(
        Issue(
          scope: 'default',
          issueId: '1001',
          key: 'PROJ-1',
          summary: 'Task',
          lastUsedAtUtc: DateTime.utc(2026, 9, 30),
        ),
      );
      final state = createState(store);
      final log = await state.addManualLog(
        issueId: '1001',
        durationSeconds: 60,
        description: 'Оригинал',
      );
      await tester.pumpWidget(JiraTimeTrackerApp(appState: state));
      await tester.pumpAndSettle();
      EditLogDialog.show(
        tester.element(find.text('Jira Time Tracker')),
        appState: state,
        log: log,
      );
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(EditLogDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), '0');
      await tester.enterText(fields.at(1), '0');
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      tester.binding.platformDispatcher.localesTestValue = [const Locale('en')];
      await tester.pumpAndSettle();
      expect(find.text('Duration must be greater than zero'), findsOneWidget);
      expect(find.text('Оригинал'), findsWidgets);
      await tester.tap(find.text('Set start time'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TimePickerDialog),
          matching: find.text('Cancel'),
        ),
        findsOneWidget,
      );
      tester.binding.platformDispatcher.localesTestValue = [const Locale('ru')];
      await tester.pumpAndSettle();
      expect(find.text('Cancel'), findsNothing);
      expect(find.byType(TimePickerDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TimePickerDialog),
          matching: find.text('Отмена'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'open day settings validation retranslates without resetting inputs',
    (tester) async {
      tester.binding.platformDispatcher.localesTestValue = [const Locale('ru')];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      final store = LocalStore(sqlite3.openInMemory())..init();
      addTearDown(store.close);
      final state = createState(store);
      await tester.pumpWidget(JiraTimeTrackerApp(appState: state));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Настройки'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-section-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сборка дня').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('day-start-min')),
        'bad time',
      );
      await tester.ensureVisible(find.text('Сохранить параметры'));
      await tester.tap(find.text('Сохранить параметры'));
      await tester.pumpAndSettle();
      tester.binding.platformDispatcher.localesTestValue = [const Locale('en')];
      await tester.pumpAndSettle();
      expect(find.text('Enter time in HH:MM format.'), findsOneWidget);
      expect(find.text('bad time'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('only the default day rule follows language changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = LocalStore(sqlite3.openInMemory())..init();
    addTearDown(store.close);
    final state = createState(store)..selectLanguage(UiLanguage.ru);
    await tester.pumpWidget(JiraTimeTrackerApp(appState: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-section-day')));
    await tester.pumpAndSettle();
    final rule = find.byKey(const ValueKey('agent-day-rule'));
    String text() => tester.widget<TextField>(rule).controller!.text;
    expect(text(), defaultAgentDayRuleRu);
    state.selectLanguage(UiLanguage.en);
    await tester.pumpAndSettle();
    expect(text(), defaultAgentDayRuleEn);
    const custom = 'Сначала поставь сложные задачи. Keep my text.';
    await tester.enterText(rule, custom);
    state.selectLanguage(UiLanguage.ru);
    await tester.pumpAndSettle();
    expect(text(), custom);
    await tester.ensureVisible(find.text('Сохранить параметры'));
    await tester.tap(find.text('Сохранить параметры'));
    await tester.pumpAndSettle();
    expect(state.agentDayRule, custom);
    state.selectLanguage(UiLanguage.en);
    await tester.pumpAndSettle();
    expect(text(), custom);
    await tester.ensureVisible(find.text('Reset'));
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(text(), defaultAgentDayRuleEn);
    await tester.tap(find.text('Save settings'));
    await tester.pumpAndSettle();
    expect(store.getSetting('agent_day_rule'), defaultAgentDayRuleRu);
    state.selectLanguage(UiLanguage.ru);
    await tester.pumpAndSettle();
    expect(text(), defaultAgentDayRuleRu);
  });

  testWidgets('system language updates the copied agent instructions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    tester.binding.platformDispatcher.localesTestValue = [const Locale('ru')];
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final store = LocalStore(sqlite3.openInMemory())..init();
    addTearDown(store.close);
    final state = createState(store);
    await tester.pumpWidget(JiraTimeTrackerApp(appState: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-section-agent-api')));
    await tester.pumpAndSettle();
    final prompt = find.byKey(const ValueKey('agent-skill-instructions'));
    expect(
      tester.widget<TextField>(prompt).controller!.text,
      startsWith('# Навык:'),
    );
    tester.binding.platformDispatcher.localesTestValue = [const Locale('en')];
    await tester.pumpAndSettle();
    final english = tester.widget<TextField>(prompt).controller!.text;
    expect(english, startsWith('# Skill:'));
    expect(english, contains('http://127.0.0.1:8765'));
    expect(english, contains('GET /api/day-settings'));
    await tester.ensureVisible(
      find.byKey(const ValueKey('copy-agent-instructions')),
    );
    await tester.tap(find.byKey(const ValueKey('copy-agent-instructions')));
    await tester.pumpAndSettle();
    expect(copied, english);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reconciliation messages and nested draft dates localise after decoding',
    (tester) async {
      final store = LocalStore(sqlite3.openInMemory())..init();
      addTearDown(store.close);
      final state = createState(store)..selectLanguage(UiLanguage.en);
      await tester.pumpWidget(JiraTimeTrackerApp(appState: state));
      await tester.pumpAndSettle();
      final context = tester.element(find.text('Jira Time Tracker'));
      final messages = [
        const AppMessage('connectionMismatchTheDraftBelongsToSiteAccount', [
          'site',
          'account',
        ], 'русский'),
        const AppMessage('entrySuccessfullyFoundAndConfirmedInJiraId', [
          '123',
        ], 'русский'),
        const AppMessage('theDraftIsEmptyThereAreNoIntervals', [], 'русский'),
        const AppMessage(
          'theJiraTimeTrackerSegmentPropertyWasNot',
          [],
          'русский',
        ),
      ];
      for (final message in messages) {
        expect(
          renderMessage(context, deserializeMessage(serializeMessage(message))),
          isNot(contains('русский')),
        );
      }
      final dateMessage = AppMessage('cannotEditALogAlreadyIncludedInThe', [
        AppMessage.date('2026-09-30'),
      ], 'русский');
      expect(
        renderMessage(
          context,
          deserializeMessage(serializeMessage(dateMessage)),
        ),
        contains('30.09.2026'),
      );
      expect(formatCalendarDate('2026-09-30'), '30.09.2026');
    },
  );

  for (final locale in [
    const Locale('ru', 'RU'),
    const Locale('en', 'US'),
    const Locale('hu', 'HU'),
  ]) {
    testWidgets('new installation resolves ${locale.toLanguageTag()}', (
      tester,
    ) async {
      tester.binding.platformDispatcher.localesTestValue = [locale];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      final store = LocalStore(sqlite3.openInMemory())..init();
      addTearDown(store.close);
      final state = createState(store);
      await tester.pumpWidget(JiraTimeTrackerApp(appState: state));
      await tester.pumpAndSettle();
      expect(
        find.text(locale.languageCode == 'ru' ? 'Работа' : 'Work'),
        findsWidgets,
      );
    });
  }

  testWidgets(
    'existing empty installation stays Russian and manual choice survives reopening the database',
    (tester) async {
      tester.binding.platformDispatcher.localesTestValue = [const Locale('en')];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      final directory = Directory.systemTemp.createTempSync('jtt-language-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final path = '${directory.path}/state.db';
      final oldStore = LocalStore(sqlite3.open(path))..init();
      oldStore.close();
      final store = LocalStore(sqlite3.open(path))..init();
      final state = createState(store);
      await tester.pumpWidget(JiraTimeTrackerApp(appState: state));
      await tester.pumpAndSettle();
      expect(find.text('Работа'), findsWidgets);
      await tester.tap(find.text('Настройки'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();
      expect(find.text('Work'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      store.close();
      final reopened = LocalStore(sqlite3.open(path))..init();
      final nextState = createState(reopened);
      await tester.pumpWidget(JiraTimeTrackerApp(appState: nextState));
      await tester.pumpAndSettle();
      expect(find.text('Work'), findsWidgets);
      reopened.close();
    },
  );

  testWidgets(
    'system changes preserve an open form and localise its validation message',
    (tester) async {
      tester.binding.platformDispatcher.localesTestValue = [const Locale('ru')];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      final store = LocalStore(sqlite3.openInMemory())..init();
      addTearDown(store.close);
      store.upsertIssue(
        Issue(
          scope: 'default',
          issueId: '1001',
          key: 'PROJ-1',
          summary: 'Название из Jira',
          lastUsedAtUtc: DateTime.utc(2026, 9, 30),
        ),
      );
      final state = createState(store);
      await tester.pumpWidget(JiraTimeTrackerApp(appState: state));
      await tester.pumpAndSettle();
      final context = tester.element(find.text('Jira Time Tracker'));
      showDialog<void>(
        context: context,
        builder: (_) =>
            AddTimeDialog(appState: state, initialIssue: state.issues.first),
      );
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(AddTimeDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), '0');
      await tester.enterText(fields.at(1), '0');
      await tester.enterText(fields.at(2), 'Мой текст без перевода');
      await tester.tap(find.text('Сохранить запись'));
      await tester.pumpAndSettle();
      expect(
        find.text('Длительность времени должна быть больше нуля'),
        findsOneWidget,
      );
      tester.binding.platformDispatcher.localesTestValue = [
        const Locale('en', 'GB'),
      ];
      await tester.pumpAndSettle();
      expect(find.text('Save entry'), findsOneWidget);
      expect(find.text('Duration must be greater than zero'), findsOneWidget);
      expect(find.text('Мой текст без перевода'), findsOneWidget);
      expect(find.textContaining('Название из Jira'), findsWidgets);
      expect(state.logs, isEmpty);
    },
  );

  testWidgets('English calendar uses day-first dates and 24-hour time', (
    tester,
  ) async {
    final store = LocalStore(sqlite3.openInMemory())..init();
    addTearDown(store.close);
    final state = createState(store)..selectLanguage(UiLanguage.en);
    await tester.pumpWidget(JiraTimeTrackerApp(appState: state));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Jira Time Tracker'));
    final material = MaterialLocalizations.of(context);
    expect(material.formatCompactDate(DateTime(2026, 9, 30)), '30.09.2026');
    expect(material.parseCompactDate('30.09.2026'), DateTime(2026, 9, 30));
    expect(material.parseCompactDate('99.09.2026'), isNull);
    expect(material.dateHelpText, 'DD.MM.YYYY');
    expect(MediaQuery.of(context).alwaysUse24HourFormat, isTrue);
    expect(
      material.formatTimeOfDay(
        const TimeOfDay(hour: 14, minute: 5),
        alwaysUse24HourFormat: true,
      ),
      '14:05',
    );
  });

  testWidgets('language cannot be changed in read-only mode', (tester) async {
    final store = LocalStore(sqlite3.openInMemory())..init();
    store.setSetting('ui_language', 'en');
    addTearDown(store.close);
    final state = createState(store, readOnly: true);
    await tester.pumpWidget(JiraTimeTrackerApp(appState: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButton<UiLanguage>>(
            find.byKey(const ValueKey('language-selector')),
          )
          .onChanged,
      isNull,
    );
    expect(
      find.text('The language cannot be changed in read-only mode.'),
      findsOneWidget,
    );
    expect(
      () => state.selectLanguage(UiLanguage.ru),
      throwsA(isA<ReadOnlyException>()),
    );
    expect(state.language.value, UiLanguage.en);
  });

  testWidgets('a failed save leaves the previous language selected', (
    tester,
  ) async {
    final store = LocalStore(sqlite3.openInMemory())..init();
    final state = createState(store)..selectLanguage(UiLanguage.ru);
    await tester.pumpWidget(JiraTimeTrackerApp(appState: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    store.close();
    await tester.tap(find.byKey(const ValueKey('language-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(find.text('Работа'), findsWidgets);
    expect(find.textContaining('Не удалось сохранить язык:'), findsOneWidget);
  });

  for (final language in [UiLanguage.ru, UiLanguage.en]) {
    for (final size in [
      const Size(1152, 800),
      const Size(640, 720),
      const Size(390, 460),
    ]) {
      testWidgets('${language.name} screens fit at $size in both themes', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final store = LocalStore(sqlite3.openInMemory())..init();
        addTearDown(store.close);
        final state = createState(store)..selectLanguage(language);
        await tester.pumpWidget(JiraTimeTrackerApp(appState: state));
        await tester.pumpAndSettle();
        for (final theme in [UiThemeMode.light, UiThemeMode.dark]) {
          state.selectThemeMode(theme);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          state.selectTab(1);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(
            find.text(language == UiLanguage.ru ? 'Настройки' : 'Settings'),
          );
          await tester.pumpAndSettle();
          for (final section in SettingsSection.values) {
            await tester.pumpWidget(
              MaterialApp(
                locale: Locale(language.name),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: theme == UiThemeMode.dark
                    ? AppTheme.darkTheme
                    : AppTheme.lightTheme,
                home: Scaffold(
                  body: SettingsPage(
                    appState: state,
                    initialSection: section,
                    key: ValueKey('$section-$theme'),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$section/$theme/$size',
            );
          }
          await tester.pumpWidget(JiraTimeTrackerApp(appState: state));
          await tester.pumpAndSettle();
        }
      });
    }
  }
  testWidgets(
    'new installation follows Windows and switches the shell immediately',
    (tester) async {
      tester.binding.platformDispatcher.localeTestValue = const Locale(
        'en',
        'GB',
      );
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
      final store = LocalStore(sqlite3.openInMemory())..init();
      final jira = JiraClient();
      final state = AppState(
        store: store,
        connectionStore: ConnectionStore(
          secureStorage: InMemorySecureStorage(),
          environment: {},
        ),
        jiraClient: jira,
        isReadOnly: false,
      );
      addTearDown(() {
        state.dispose();
        jira.close();
        store.close();
      });
      await tester.pumpWidget(JiraTimeTrackerApp(appState: state));
      await tester.pumpAndSettle();
      expect(find.text('Work'), findsWidgets);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Русский').last);
      await tester.pumpAndSettle();
      expect(find.text('Работа'), findsWidgets);
      expect(find.text('Язык / Language'), findsOneWidget);
    },
  );

  testWidgets('switching languages preserves timers, draft and selection', (
    tester,
  ) async {
    final store = LocalStore(sqlite3.openInMemory())..init();
    addTearDown(store.close);
    store.upsertIssue(
      Issue(
        scope: 'default',
        issueId: '1001',
        key: 'PROJ-1',
        summary: 'Исходная задача',
        lastUsedAtUtc: DateTime.utc(2026, 9, 30),
      ),
    );
    final state = createState(store)..selectLanguage(UiLanguage.ru);
    final source = await state.addManualLog(
      issueId: '1001',
      durationSeconds: 3600,
      description: 'Без перевода',
    );
    state.toggleLogSelection(source.id);
    await state.buildDay(customSeed: 42);
    final draft = state.currentDraft!;
    final intervals = state.currentSegments
        .map((value) => value.toMap())
        .toList();
    final free = await state.addManualLog(
      issueId: '1001',
      durationSeconds: 1800,
    );
    state.toggleLogSelection(free.id);
    final selected = Set<String>.from(state.selectedLogIds);
    final timer = await state.playTimer('1001');
    await tester.pumpWidget(JiraTimeTrackerApp(appState: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('language-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsWidgets);
    expect(state.currentDraft!.toMap(), draft.toMap());
    expect(
      state.currentSegments.map((value) => value.toMap()).toList(),
      intervals,
    );
    expect(state.selectedLogIds, selected);
    expect(
      state.logs.singleWhere((value) => value.id == timer.id).isRunning,
      isTrue,
    );
    expect(
      state.logs.singleWhere((value) => value.id == source.id).description,
      'Без перевода',
    );
    expect(
      store.getDayDraft(scope: 'default', date: '2026-09-30')!.toMap(),
      draft.toMap(),
    );
    await state.pauseAllTimers();
  });

  testWidgets('selected log counts use the correct forms in both languages', (
    tester,
  ) async {
    final store = LocalStore(sqlite3.openInMemory())..init();
    addTearDown(store.close);
    store.upsertIssue(
      Issue(
        scope: 'default',
        issueId: '1001',
        key: 'PROJ-1',
        summary: 'Task',
        lastUsedAtUtc: DateTime.utc(2026, 9, 30),
      ),
    );
    final state = createState(store)..selectLanguage(UiLanguage.en);
    await tester.pumpWidget(JiraTimeTrackerApp(appState: state));
    await tester.pumpAndSettle();
    for (var count = 1; count <= 5; count++) {
      final log = await state.addManualLog(
        issueId: '1001',
        durationSeconds: 900,
      );
      state.toggleLogSelection(log.id);
      await tester.pumpAndSettle();
      expect(
        find.text('Selected $count ${count == 1 ? 'entry' : 'entries'}'),
        findsOneWidget,
      );
    }
    state.selectLanguage(UiLanguage.ru);
    await tester.pumpAndSettle();
    expect(find.text('Выбрано 5 записей'), findsOneWidget);
    state.toggleLogSelection(state.logs.last.id);
    state.toggleLogSelection(state.logs[state.logs.length - 2].id);
    state.toggleLogSelection(state.logs[state.logs.length - 3].id);
    await tester.pumpAndSettle();
    expect(find.text('Выбрано 2 записи'), findsOneWidget);
  });

  testWidgets(
    'live application errors switch language while a Jira error stays raw',
    (tester) async {
      final store = LocalStore(sqlite3.openInMemory())..init();
      addTearDown(store.close);
      final state = createState(store)..selectLanguage(UiLanguage.en);
      try {
        await state.addManualLog(issueId: 'missing', durationSeconds: 0);
      } catch (error) {
        state.setStatusMessage(error);
      }
      await tester.pumpWidget(JiraTimeTrackerApp(appState: state));
      await tester.pumpAndSettle();
      expect(find.text('Duration must be greater than zero'), findsOneWidget);
      state.selectLanguage(UiLanguage.ru);
      await tester.pumpAndSettle();
      expect(
        find.text('Длительность времени должна быть больше нуля'),
        findsOneWidget,
      );
      state.setStatusMessage(
        const JiraApiException('Ошибка от Jira без перевода'),
      );
      state.selectLanguage(UiLanguage.en);
      await tester.pumpAndSettle();
      expect(find.text('Ошибка от Jira без перевода'), findsOneWidget);
    },
  );

  testWidgets(
    'saved new errors localise after restart and legacy errors stay unchanged',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync(
        'jtt-error-language-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final path = '${directory.path}/state.db';
      final initial = LocalStore(sqlite3.open(path))..init();
      final now = DateTime.utc(2026, 9, 30, 9);
      final issue = Issue(
        scope: 'default',
        issueId: '1001',
        key: 'PROJ-1',
        summary: 'Исходное название',
        lastUsedAtUtc: now,
      );
      final logs = List.generate(
        2,
        (index) => LocalLog(
          id: 'source-$index',
          scope: 'default',
          issueId: '1001',
          titleSnapshot: issue.summary,
          description: 'Исходное описание',
          accumulatedSeconds: 3600,
          createdAtUtc: now,
        ),
      );
      initial.saveLogsAndIssue(logs: logs, issue: issue);
      initial.saveDayDraft(
        draft: DayDraft(
          id: 'draft',
          scope: 'default',
          date: '2026-09-30',
          startUtc: now,
          endUtc: now.add(const Duration(hours: 3)),
          seed: 42,
          settingsSnapshot: const DaySettings().toJson(),
          status: DraftStatus.draft,
        ),
        draftLogs: logs
            .map(
              (log) => DraftLog(
                draftId: 'draft',
                sourceLogId: log.id,
                sourceDurationSeconds: 3600,
                descriptionSnapshot: log.description,
              ),
            )
            .toList(),
        segments: List.generate(
          2,
          (index) => Segment(
            id: 'segment-$index',
            draftId: 'draft',
            sourceLogId: logs[index].id,
            issueId: issue.issueId,
            startUtc: now.add(Duration(hours: index)),
            durationSeconds: 3600,
            description: logs[index].description,
            sendState: SendState.failed,
            lastError: index == 0
                ? serializeMessage(
                    const AppMessage('jiraServerErrorCode', [
                      503,
                    ], 'Серверная ошибка Jira (код 503)'),
                  )
                : 'Старая сохранённая ошибка',
          ),
        ),
        breaks: const [],
      );
      initial.close();
      final store = LocalStore(sqlite3.open(path))..init();
      addTearDown(store.close);
      final state = createState(store)
        ..selectLanguage(UiLanguage.en)
        ..selectTab(1);
      await tester.pumpWidget(JiraTimeTrackerApp(appState: state));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submission results').first);
      await tester.pumpAndSettle();
      expect(find.text('Jira server error (code 503)'), findsWidgets);
      expect(find.text('Старая сохранённая ошибка'), findsWidgets);
      expect(find.textContaining('Исходное описание'), findsWidgets);
    },
  );
}
