import 'package:flutter_test/flutter_test.dart';
import 'package:jira_time_tracker/app_state.dart';
import 'package:jira_time_tracker/agent_instructions.dart';
import 'package:jira_time_tracker/connection_store.dart';
import 'package:jira_time_tracker/jira_client.dart';
import 'package:jira_time_tracker/local_store.dart';
import 'package:jira_time_tracker/models.dart';
import 'package:jira_time_tracker/secure_storage.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late LocalStore store;
  late JiraClient jiraClient;
  late ConnectionStore connectionStore;

  setUp(() {
    store = LocalStore(sqlite3.openInMemory())..init();
    jiraClient = JiraClient();
    connectionStore = ConnectionStore(
      secureStorage: InMemorySecureStorage(),
      environment: {},
    );
  });

  tearDown(() {
    jiraClient.close();
    store.close();
  });

  AppState createState() => AppState(
    store: store,
    connectionStore: connectionStore,
    jiraClient: jiraClient,
    isReadOnly: false,
    nowProvider: () => DateTime.utc(2026, 9, 24),
  );

  test('Сохранённые настройки сборки дня переживают перезапуск', () {
    final first = createState();
    const changed = DaySettings(
      startMinutesMin: 9 * 60,
      startMinutesMax: 10 * 60,
    );

    first.updateDaySettings(changed);
    first.dispose();

    final restored = createState();
    expect(restored.daySettings.toMap(), changed.toMap());
    restored.dispose();
  });

  test('Правило агента сохраняется с диапазонами и переживает перезапуск', () {
    final first = createState();
    expect(first.agentDayRule, AppState.defaultAgentDayRule);
    const settings = DaySettings(startMinutesMin: 9 * 60);
    first.updateDaySettings(
      settings,
      agentRule: '  Сначала поставь сложные задачи.  ',
    );
    expect(first.agentDayRule, 'Сначала поставь сложные задачи.');
    expect(
      () => first.updateDaySettings(const DaySettings(), agentRule: '  '),
      throwsArgumentError,
    );
    first.dispose();

    final restored = createState();
    expect(restored.daySettings.toMap(), settings.toMap());
    expect(restored.agentDayRule, 'Сначала поставь сложные задачи.');
    restored.dispose();
  });

  test(
    'Старое стандартное правило переводится, пользовательское сохраняется',
    () {
      for (final previousDefault in [
        defaultAgentDayRuleRu,
        defaultAgentDayRuleEn,
      ]) {
        store.setSetting('agent_day_rule', previousDefault);
        final state = createState();
        expect(state.agentDayRuleForLanguage('ru'), defaultAgentDayRuleRu);
        expect(state.agentDayRuleForLanguage('en'), defaultAgentDayRuleEn);
        state.updateDaySettings(
          const DaySettings(),
          agentRule: defaultAgentDayRuleEn,
        );
        state.dispose();
        final restored = createState();
        expect(restored.agentDayRuleForLanguage('ru'), defaultAgentDayRuleRu);
        restored.updateDaySettings(
          const DaySettings(),
          agentRule: 'My own rule.',
        );
        restored.dispose();
        final custom = createState();
        expect(custom.agentDayRuleForLanguage('ru'), 'My own rule.');
        expect(custom.agentDayRuleForLanguage('en'), 'My own rule.');
        custom.dispose();
      }
    },
  );

  test('Очистка дня освобождает источник и не меняет его время', () {
    final start = DateTime.utc(2026, 9, 24, 9);
    final source = LocalLog(
      id: 'source-1',
      scope: 'default',
      issueId: '1001',
      titleSnapshot: 'PROJ-1',
      accumulatedSeconds: 3600,
      createdAtUtc: start,
    );
    store.saveLogAndIssue(
      log: source,
      issue: Issue(
        scope: 'default',
        issueId: '1001',
        key: 'PROJ-1',
        summary: 'Работа',
        lastUsedAtUtc: start,
      ),
    );
    store.saveDayDraft(
      draft: DayDraft(
        id: 'draft-1',
        scope: 'default',
        date: '2026-09-24',
        startUtc: start,
        endUtc: start.add(const Duration(hours: 1)),
        seed: 1,
        settingsSnapshot: const DaySettings().toJson(),
      ),
      draftLogs: const [
        DraftLog(
          draftId: 'draft-1',
          sourceLogId: 'source-1',
          sourceDurationSeconds: 3600,
          descriptionSnapshot: '',
        ),
      ],
      segments: [
        Segment(
          id: 'segment-1',
          draftId: 'draft-1',
          sourceLogId: 'source-1',
          issueId: '1001',
          startUtc: start,
          durationSeconds: 3600,
        ),
      ],
      breaks: const [],
    );
    final state = createState();
    state.loadDraftForSelectedDate();
    expect(state.isLogInDraft(source.id), isTrue);
    state.setImportedWorklogs([
      ImportedWorklog(
        id: 'jira-1',
        issueId: '1001',
        startUtc: start,
        durationSeconds: 600,
        authorAccountId: 'account-1',
      ),
    ]);

    state.clearCurrentDay();

    expect(state.currentDraft, isNull);
    expect(state.importedWorklogs.single.id, 'jira-1');
    expect(state.isLogInDraft(source.id), isFalse);
    expect(store.getLocalLog(source.id)!.accumulatedSeconds, 3600);
    expect(
      store.getDayDraft(
        scope: state.activeScope,
        date: state.selectedDateString,
      ),
      isNull,
    );

    store.saveDayDraft(
      draft: DayDraft(
        id: 'draft-sending',
        scope: state.activeScope,
        date: state.selectedDateString,
        startUtc: start,
        endUtc: start.add(const Duration(hours: 1)),
        seed: 2,
        settingsSnapshot: const DaySettings().toJson(),
        status: DraftStatus.sending,
      ),
      draftLogs: const [],
      segments: const [],
      breaks: const [],
    );
    state.loadDraftForSelectedDate();
    expect(state.canClearCurrentDay, isFalse);
    expect(state.clearCurrentDay, throwsStateError);
    expect(
      store.getDayDraft(
        scope: state.activeScope,
        date: state.selectedDateString,
      ),
      isNotNull,
    );
    state.dispose();
  });

  test('Повреждённые сохранённые настройки не становятся активными', () {
    store.setSetting(
      'day_settings',
      const DaySettings(startMinutesMin: -1).toJson(),
    );
    final state = createState();
    expect(state.daySettings.toMap(), const DaySettings().toMap());
    state.dispose();
  });

  test('Открытие черновика не подменяет общие настройки его снимком', () {
    final state = createState();
    const changed = DaySettings(startMinutesMin: 9 * 60);
    state.updateDaySettings(changed);
    store.saveDayDraft(
      draft: DayDraft(
        id: 'draft-1',
        scope: state.activeScope,
        date: state.selectedDateString,
        startUtc: DateTime.utc(2026, 9, 24, 8),
        endUtc: DateTime.utc(2026, 9, 24, 16),
        seed: 42,
        settingsSnapshot: const DaySettings().toJson(),
      ),
      draftLogs: const [],
      segments: const [],
      breaks: const [],
    );

    state.loadDraftForSelectedDate();
    expect(state.daySettings.toMap(), changed.toMap());
    state.dispose();

    final restored = createState();
    expect(restored.daySettings.toMap(), changed.toMap());
    restored.dispose();
  });

  test(
    'Некорректные диапазоны не сохраняются, ноль коротких пауз допустим',
    () {
      final state = createState();
      final invalid = <DaySettings>[
        const DaySettings(startMinutesMin: 10 * 60, startMinutesMax: 9 * 60),
        const DaySettings(startMinutesMin: -1),
        const DaySettings(totalDurationSecondsMin: 0),
        const DaySettings(lunchStartMinutesMax: 24 * 60),
        const DaySettings(lunchDurationSecondsMin: -60),
        const DaySettings(lunchDurationSecondsMin: 0),
        const DaySettings(shortBreakCountMin: -1),
        const DaySettings(
          shortBreakCountMax: DaySettings.maxShortBreakCount + 1,
        ),
        const DaySettings(shortBreakDurationSecondsMax: 0),
      ];

      for (final settings in invalid) {
        expect(() => state.updateDaySettings(settings), throwsArgumentError);
      }
      expect(store.getSetting('day_settings'), isNull);
      expect(state.daySettings.toMap(), const DaySettings().toMap());

      const withoutExtraBreaks = DaySettings(
        shortBreakCountMin: 0,
        shortBreakCountMax: 0,
      );
      state.updateDaySettings(withoutExtraBreaks);
      expect(state.daySettings.toMap(), withoutExtraBreaks.toMap());
      const withoutLongBreak = DaySettings(
        lunchDurationSecondsMin: 0,
        lunchDurationSecondsMax: 0,
      );
      state.updateDaySettings(withoutLongBreak);
      expect(state.daySettings.toMap(), withoutLongBreak.toMap());
      state.dispose();
    },
  );

  test(
    'Явная пересборка сохраняет снимок новых настроек в черновике',
    () async {
      final createdAt = DateTime.utc(2026, 9, 24, 10);
      store.saveLogAndIssue(
        log: LocalLog(
          id: 'log-1',
          scope: 'default',
          issueId: '1001',
          titleSnapshot: 'PROJ-1',
          accumulatedSeconds: 2 * 3600,
          createdAtUtc: createdAt,
        ),
        issue: Issue(
          scope: 'default',
          issueId: '1001',
          key: 'PROJ-1',
          summary: 'Работа',
          lastUsedAtUtc: createdAt,
        ),
      );
      final state = createState();
      state.toggleLogSelection('log-1');
      await state.buildDay(customSeed: 42);
      final originalSnapshot = state.currentDraft!.settingsSnapshot;

      const changed = DaySettings(startMinutesMin: 9 * 60);
      state.updateDaySettings(changed);
      expect(state.currentDraft!.settingsSnapshot, originalSnapshot);

      await state.rebuildCurrentDay(customSeed: 43);
      expect(
        DaySettings.fromJson(state.currentDraft!.settingsSnapshot).toMap(),
        changed.toMap(),
      );

      const next = DaySettings(
        startMinutesMin: 8 * 60,
        startMinutesMax: 8 * 60,
        shortBreakCountMin: 0,
        shortBreakCountMax: 0,
      );
      state.updateDaySettings(next);
      expect(
        DaySettings.fromJson(state.currentDraft!.settingsSnapshot).toMap(),
        changed.toMap(),
      );
      await state.smartRebuildDay(customSeed: 44);
      expect(
        DaySettings.fromJson(state.currentDraft!.settingsSnapshot).toMap(),
        next.toMap(),
      );

      final unchangedDraft = state.currentDraft!.toMap();
      final unchangedSegments = [
        for (final segment in state.currentSegments) segment.toMap(),
      ];
      state.updateDaySettings(
        const DaySettings(
          startMinutesMin: 8 * 60,
          startMinutesMax: 8 * 60,
          totalDurationSecondsMin: 8 * 3600,
          totalDurationSecondsMax: 8 * 3600,
          lunchStartMinutesMin: 23 * 60,
          lunchStartMinutesMax: 23 * 60,
          shortBreakCountMin: 0,
          shortBreakCountMax: 0,
        ),
      );
      await expectLater(state.smartRebuildDay(customSeed: 45), throwsException);
      expect(state.currentDraft!.toMap(), unchangedDraft);
      expect([
        for (final segment in state.currentSegments) segment.toMap(),
      ], unchangedSegments);
      expect(
        store
            .getDayDraft(
              scope: state.activeScope,
              date: state.selectedDateString,
            )!
            .toMap(),
        unchangedDraft,
      );
      state.dispose();
    },
  );
}
