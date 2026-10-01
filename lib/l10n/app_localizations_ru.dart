// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get work => 'Работа';

  @override
  String get day => 'День';

  @override
  String get settings => 'Настройки';

  @override
  String get language => 'Язык / Language';

  @override
  String get systemDefault => 'Как в системе';

  @override
  String languageSaveFailed(String error) {
    return 'Не удалось сохранить язык: $error';
  }

  @override
  String get days => '7 дней';

  @override
  String get days9 => '30 дней';

  @override
  String get all => 'Все';

  @override
  String get invalidInputEnterAKeyProjNumericId =>
      'Некорректный ввод: укажите ключ (PROJ-123), числовой ID или ссылку /browse/...';

  @override
  String get firstCheckAndSaveTheJiraConnectionIn =>
      'Сначала проверьте и сохраните подключение к Jira в Настройках';

  @override
  String get jiraApiTokenWasNotFoundInSecure =>
      'API токен Jira не найден в защищённом хранилище';

  @override
  String get firstConnectJiraInSettings =>
      'Сначала подключите Jira в Настройках.';

  @override
  String get jiraApiTokenWasNotFoundInSecure16 =>
      'API токен Jira не найден в защищённом хранилище.';

  @override
  String get theApplicationIsReadOnly =>
      'Приложение открыто только для чтения.';

  @override
  String get issueKeyOrIdCannotBeEmpty =>
      'Ключ или ID задачи не может быть пустым';

  @override
  String issueIsNotInTheLocalCatalogueAnd(String p0) {
    return 'Задача \"$p0\" отсутствует в локальном каталоге, подключение к Jira недоступно.';
  }

  @override
  String get durationMustBeGreaterThanZero =>
      'Длительность времени должна быть больше нуля';

  @override
  String issueWithIdWasNotFoundInThe(String p0) {
    return 'Задача с ID $p0 не найдена в локальном каталоге';
  }

  @override
  String logWithIdWasNotFound(String p0) {
    return 'Лог с ID $p0 не найден';
  }

  @override
  String get cannotEditARunningLogPauseItFirst =>
      'Нельзя редактировать работающий лог. Сначала поставьте его на паузу.';

  @override
  String get cannotEditALogThatHasAlreadyBeen =>
      'Нельзя редактировать уже использованный лог.';

  @override
  String cannotEditALogAlreadyIncludedInThe(String p0) {
    return 'Нельзя редактировать лог, уже включенный в черновик дня ($p0).';
  }

  @override
  String get cannotSplitARunningLogStopItFirst =>
      'Нельзя разбить работающий лог. Сначала остановите его.';

  @override
  String get cannotSplitALogThatHasAlreadyBeen =>
      'Нельзя разбить уже использованный лог.';

  @override
  String get cannotSplitALogAlreadyIncludedInA =>
      'Нельзя разбить лог, уже включенный в черновик дня.';

  @override
  String theFirstPartMustBeGreaterThanAnd(String p0) {
    return 'Длительность первой части должна быть больше 0 и меньше общей длительности ($p0 с)';
  }

  @override
  String get atLeastTwoLogsAreRequiredToMerge =>
      'Для объединения требуется минимум два лога';

  @override
  String get someOfTheSpecifiedLogsWereNotFound =>
      'Некоторые из указанных логов не найдены';

  @override
  String get cannotMergeRunningLogs => 'Нельзя объединять работающие логи.';

  @override
  String get cannotMergeLogsAlreadyIncludedInADay =>
      'Нельзя объединять логи, уже включенные в черновик дня.';

  @override
  String get cannotDeleteARunningLogPauseItFirst =>
      'Нельзя удалить работающий лог. Сначала поставьте его на паузу.';

  @override
  String cannotDeleteALogAlreadyIncludedInThe(String p0) {
    return 'Нельзя удалить лог, уже включенный в черновик дня ($p0).';
  }

  @override
  String get errorLoadingJiraEntries => 'Ошибка загрузки записей Jira:';

  @override
  String errorLoadingJiraEntries37(String p0) {
    return 'Ошибка загрузки записей Jira: $p0';
  }

  @override
  String get noActiveJiraConnectionToLoadWorklogs =>
      'Нет активного подключения к Jira для загрузки worklogs.';

  @override
  String get expectedAJiraIssueKeyOrNumericId =>
      'Ожидается ключ или числовой ID задачи Jira.';

  @override
  String get noActiveJiraConnection => 'Нет активного подключения к Jira.';

  @override
  String get expectedAJiraIssueKeyAndANumeric =>
      'Ожидается ключ задачи Jira и числовой ID вложения.';

  @override
  String get theAgentRuleCannotBeEmpty =>
      'Правило для агента не может быть пустым.';

  @override
  String get cannotClearADayAfterSubmissionHasStarted =>
      'Нельзя очистить день после начала отправки или в режиме только чтения.';

  @override
  String get cannotRebuildAPartiallyOrFullySubmittedDay =>
      'Нельзя пересобрать частично или полностью отправленный день.';

  @override
  String get noLogsSelectedToBuildTheDay =>
      'Не выбрано ни одного лога для сборки дня.';

  @override
  String get aRunningLogCannotBeIncludedInA =>
      'Работающий лог нельзя включить в черновик дня.';

  @override
  String logIsAlreadyIncludedInADraftFor(String p0, String p1) {
    return 'Лог $p0 уже включен в черновик на дату $p1.';
  }

  @override
  String get daySuccessfullyRebuiltSmartRebuild =>
      'День успешно пересобран (умная пересборка).';

  @override
  String get daySuccessfullyBuilt => 'День успешно собран.';

  @override
  String get theSegmentListCannotBeEmpty =>
      'Список сегментов не может быть пустым.';

  @override
  String get cannotReplaceTheDraftAfterDaySubmissionHas =>
      'Нельзя заменить черновик после начала отправки дня.';

  @override
  String get theDayDraftHasChangedSinceItWas =>
      'Черновик дня изменился после чтения. Получите актуальный snapshot и повторите запись.';

  @override
  String get theDayDraftHasBeenDeletedSinceIt =>
      'Черновик дня был удалён после чтения. Получите актуальный snapshot и повторите запись.';

  @override
  String sourceWasNotFound(String p0) {
    return 'Источник \"$p0\" не найден.';
  }

  @override
  String runningSourceCannotBeIncludedInADay(String p0) {
    return 'Работающий источник \"$p0\" нельзя включить в день.';
  }

  @override
  String submittedSourceCannotBeIncludedAgain(String p0) {
    return 'Отправленный источник \"$p0\" нельзя включить повторно.';
  }

  @override
  String sourceHasNoRecordedTime(String p0) {
    return 'Источник \"$p0\" не содержит записанного времени.';
  }

  @override
  String sourceIsAlreadyIncludedInADraftFor(String p0, String p1) {
    return 'Источник \"$p0\" уже включён в черновик на дату $p1.';
  }

  @override
  String theIssueForSourceWasNotFoundIn(String p0) {
    return 'В локальном каталоге не найдена задача источника $p0.';
  }

  @override
  String issueDoesNotMatchSource(String p0, String p1, String p2) {
    return 'Задача \"$p0\" не соответствует источнику $p1 ($p2).';
  }

  @override
  String get segmentDurationMustBeGreaterThanZero =>
      'Длительность сегмента должна быть больше нуля.';

  @override
  String theSegmentMustStartOnTheTargetDate(String p0) {
    return 'Начало сегмента должно попадать в целевую дату $p0.';
  }

  @override
  String theEntireSegmentMustFitWithinTheTarget(String p0) {
    return 'Сегмент должен полностью помещаться в целевую дату $p0.';
  }

  @override
  String get theDayDraftChangedWhileTheSnapshotWas =>
      'Черновик дня изменился во время подготовки snapshot. Получите актуальный snapshot и повторите запись.';

  @override
  String get thisIntervalHasAlreadyBeenSubmittedOrNeeds =>
      'Этот интервал уже отправлен или ожидает сверки с Jira.';

  @override
  String get durationMustBeGreaterThanMinutes =>
      'Длительность должна быть больше 0 минут.';

  @override
  String get theNextIntervalIsPinnedOrHasAlready =>
      'Следующий интервал закреплён или уже отправлялся. Сдвиг невозможен.';

  @override
  String theSplitPointMustBeGreaterThanAnd(String p0) {
    return 'Смещение точки разделения должно быть больше 0 и меньше длительности сегмента ($p0 с)';
  }

  @override
  String get onlySegmentsFromTheSameSourceLogCan =>
      'Можно объединить только сегменты одного исходного лога.';

  @override
  String get theSourceLogForTheSegmentsWasNot =>
      'Исходный лог сегментов не найден.';

  @override
  String get cannotRebuildADayAfterSubmissionHasStarted =>
      'Нельзя пересобрать день после начала отправки или в режиме только чтения.';

  @override
  String get daySuccessfullyRebuiltWithTheOrderPreserved =>
      'День успешно пересобран с сохранением порядка.';

  @override
  String get endTimeMustBeAfterStartTime =>
      'Время окончания должно быть позже времени начала.';

  @override
  String cannotChangeTheBoundaryThereIsAJira(String p0) {
    return 'Нельзя изменять границу: слева находится запись из Jira ($p0).';
  }

  @override
  String get thePreviousTaskMustBeAtLeastMinute =>
      'Длительность предыдущей задачи не может быть меньше 1 минуты.';

  @override
  String cannotChangeTheBoundaryThereIsAJira76(String p0) {
    return 'Нельзя изменять границу: справа находится запись из Jira ($p0).';
  }

  @override
  String get theNextTaskMustBeAtLeastMinute =>
      'Длительность следующей задачи не может быть меньше 1 минуты.';

  @override
  String notEnoughFreeTimeBeforeJiraEntryRequires(
    String p0,
    String p1,
    String p2,
  ) {
    return 'Недостаточно свободного времени перед записью Jira $p0: требуется $p1 мин, доступно $p2 мин.';
  }

  @override
  String get jiraTokenWasNotFoundInSecureStorage =>
      'Токен Jira не найден в защищённом хранилище';

  @override
  String get submittingEntriesToJira => 'Отправка записей в Jira...';

  @override
  String allEntriesWereSuccessfullySubmittedToJira(String p0) {
    return 'Все записи ($p0) успешно отправлены в Jira!';
  }

  @override
  String submissionError(String p0) {
    return 'Ошибка отправки: $p0';
  }

  @override
  String submissionFinishedSentFailedUnknown(String p0, String p1, String p2) {
    return 'Отправка завершена: отправлено $p0, ошибок $p1, неизвестно $p2.';
  }

  @override
  String errorSubmittingToJira(String p0) {
    return 'Ошибка отправки в Jira: $p0';
  }

  @override
  String reconciliationError(String p0) {
    return 'Ошибка сверки: $p0';
  }

  @override
  String get worklogSuccessfullyLinked => 'Worklog успешно привязан!';

  @override
  String get errorLinkingTheWorklog => 'Ошибка привязки worklog';

  @override
  String get segmentResetToPendingSubmissionIsAllowedAgain =>
      'Статус сегмента сброшен на «В очереди». Разрешена повторная отправка.';

  @override
  String conflictPinnedTaskOverlapsTask(String p0, String p1) {
    return 'Обнаружен конфликт: фиксированная задача \"$p0\" пересекается с задачей \"$p1\".';
  }

  @override
  String conflictPinnedTaskOverlapsExistingJiraEntry(String p0, String p1) {
    return 'Обнаружен конфликт: фиксированная задача \"$p0\" пересекается с существующей записью в Jira \"$p1\".';
  }

  @override
  String get theLogHasAZeroOrNegativeDuration =>
      'Лог содержит нулевую или отрицательную длительность.';

  @override
  String get conflictExistingJiraEntriesOverlapEachOther =>
      'Обнаружен конфликт: существующие записи в Jira пересекаются друг с другом.';

  @override
  String get existingWorklog => 'Существующий worklog';

  @override
  String get segment => 'Сегмент';

  @override
  String get tasksDoNotFitIntoTheSelectedDate =>
      'Задачи не помещаются в выбранные сутки (до 23:59:59). Уменьшите длительность или перенесите часть задач на другой день.';

  @override
  String existingJiraEntriesAlreadyOccupyOrMoreHours(String p0) {
    return 'Существующие записи в Jira уже занимают $p0 или более часов.';
  }

  @override
  String get existingJiraEntriesOrPinnedTasksFallOutside =>
      'Существующие записи в Jira или фиксированные задачи выходят за допустимое 24-часовое окно рабочего дня.';

  @override
  String get withExistingEntriesAndPinnedTasksTheDay =>
      'С учётом существующих записей и фиксированных задач день превышает лимит в 24 часа.';

  @override
  String get pinnedTask => 'Фиксированная задача';

  @override
  String get existingEntriesBreaksAndPinnedTasksHaveExhausted =>
      'Бюджет рабочего времени исчерпан существующими записями, перерывами и фиксированными задачами.';

  @override
  String get aDurationLockedLogIsShorterThanThe =>
      'Зафиксированный лог короче минимального рабочего интервала 15 минут.';

  @override
  String lockedLogsRequireHMinButOnlyH(
    String p0,
    String p1,
    String p2,
    String p3,
  ) {
    return 'Фиксированные логи требуют $p0 ч $p1 мин, а доступно только $p2 ч $p3 мин.';
  }

  @override
  String allLogsAreLockedHMinButThe(
    String p0,
    String p1,
    String p2,
    String p3,
  ) {
    return 'Все логи зафиксированы ($p0 ч $p1 мин), но бюджет составляет $p2 ч $p3 мин. Разблокируйте хотя бы один лог.';
  }

  @override
  String get notEnoughTimeEachSelectedLogRequiresAt =>
      'Недостаточно времени: каждому выбранному логу требуется минимум 15 минут.';

  @override
  String get cannotFitWorkIntervalsOfAtLeastMinutes =>
      'Невозможно разместить рабочие интервалы от 15 минут с обязательными паузами. Измените выбор логов или настройки дня.';

  @override
  String theTotalDayDurationSExceedsHours(String p0) {
    return 'Общая продолжительность дня ($p0 сек) превышает 24 часа.';
  }

  @override
  String get totalWorkTimeExceedsHours =>
      'Суммарное рабочее время превышает 24 часа.';

  @override
  String segmentHasANonPositiveDuration(String p0) {
    return 'Сегмент $p0 имеет неположительную длительность.';
  }

  @override
  String segmentIsShorterThanTheMinimumOfMinutes(String p0) {
    return 'Сегмент $p0 короче минимальных 10 минут.';
  }

  @override
  String segmentFallsOutsideTheWorkDay(String p0) {
    return 'Сегмент $p0 выходит за границы рабочего дня.';
  }

  @override
  String breakHasANonPositiveDuration(String p0) {
    return 'Перерыв $p0 имеет неположительную длительность.';
  }

  @override
  String breakFallsOutsideTheWorkDay(String p0) {
    return 'Перерыв $p0 выходит за границы рабочего дня.';
  }

  @override
  String existingEntryHasANonPositiveDuration(String p0) {
    return 'Существующая запись $p0 имеет неположительную длительность.';
  }

  @override
  String existingEntryFallsOutsideTheWorkDay(String p0) {
    return 'Существующая запись $p0 выходит за границы рабочего дня.';
  }

  @override
  String overlapDetectedAnd(
    String p0,
    String p1,
    String p2,
    String p3,
    String p4,
    String p5,
  ) {
    return 'Обнаружено пересечение: $p0 ($p1 - $p2) и $p3 ($p4 - $p5).';
  }

  @override
  String get breaksMustHaveAWorkIntervalBetweenThem =>
      'Перерывы не должны следовать подряд без рабочего интервала между ними.';

  @override
  String theRequiredBreakBetweenWorkIntervalsAndIs(String p0, String p1) {
    return 'Между рабочими интервалами $p0 и $p1 отсутствует обязательная пауза.';
  }

  @override
  String get cannotPlaceTheLongBreakWithinTheStart =>
      'Невозможно разместить длинную паузу в заданном диапазоне начала. Измените настройки дня.';

  @override
  String get cannotPlaceTheLongBreakWithinTheStart120 =>
      'Невозможно разместить длинную паузу в заданном диапазоне начала: время занято. Измените настройки дня.';

  @override
  String get cannotPlaceTheRequiredNumberOfShortBreaks =>
      'Невозможно разместить заданное число коротких пауз: слишком короткий свободный промежуток. Измените настройки дня.';

  @override
  String get cannotPlaceTheRequiredNumberOfShortBreaks122 =>
      'Невозможно разместить заданное число коротких пауз в свободном времени. Измените настройки дня.';

  @override
  String get candidate => 'Кандидат';

  @override
  String couldNotGetTheJiraSiteSCloudid(String p0) {
    return 'Не удалось получить cloudId Jira-сайта (код: $p0)';
  }

  @override
  String networkErrorRequestingCloudid(String p0) {
    return 'Сетевая ошибка при запросе cloudId: $p0';
  }

  @override
  String get invalidEmailOrApiTokenUnauthorized =>
      'Неверный email или API токен (401 Unauthorized)';

  @override
  String get accessDeniedForbidden => 'Доступ запрещён (403 Forbidden)';

  @override
  String rateLimitExceededTooManyRequests(String p0) {
    return 'Превышен лимит запросов (429 Too Many Requests)$p0';
  }

  @override
  String jiraApiError(String p0, String p1) {
    return 'Ошибка Jira API: $p0 $p1';
  }

  @override
  String get jiraUrlIsMissing => 'Не указан URL Jira';

  @override
  String get atlassianAccountEmailIsMissing =>
      'Не указан Email аккаунта Atlassian';

  @override
  String get atlassianApiTokenIsMissing => 'Не указан API токен Atlassian';

  @override
  String couldNotConnectViaEitherTheDirectOr(String p0) {
    return 'Не удалось подключиться ни прямым, ни scoped-маршрутом: $p0';
  }

  @override
  String errorCheckingTheScopedRoute(String p0) {
    return 'Ошибка при проверке scoped-маршрута: $p0';
  }

  @override
  String issueWasNotFoundInJiraNotFound(String p0) {
    return 'Задача \"$p0\" не найдена в Jira (404 Not Found)';
  }

  @override
  String get jiraAuthenticationErrorUnauthorized =>
      'Ошибка авторизации Jira (401 Unauthorized)';

  @override
  String get accessToTheJiraIssueIsDeniedForbidden =>
      'Нет доступа к задаче в Jira (403 Forbidden)';

  @override
  String errorLoadingIssue(String p0, String p1, String p2) {
    return 'Ошибка загрузки задачи \"$p0\": $p1 $p2';
  }

  @override
  String get jiraReturnedAnIncompleteCommentList =>
      'Jira вернула неполный список комментариев';

  @override
  String get attachmentWasNotFoundInTheSpecifiedJira =>
      'Вложение не найдено в указанной задаче Jira';

  @override
  String errorLoadingJiraAttachmentCode(String p0) {
    return 'Ошибка загрузки вложения Jira (код: $p0)';
  }

  @override
  String errorLoadingJiraDataCode(String p0) {
    return 'Ошибка загрузки данных Jira (код: $p0)';
  }

  @override
  String errorSearchingJiraForIssuesWithWorklogsCode(String p0) {
    return 'Ошибка поиска задач с worklogs в Jira (код: $p0)';
  }

  @override
  String errorLoadingWorklogsForIssueCode(String p0, String p1) {
    return 'Ошибка загрузки worklogs для задачи \"$p0\" (код: $p1)';
  }

  @override
  String get jiraSResponseDoesNotContainTheCreated =>
      'Ответ Jira 201 не содержит ID созданного worklog';

  @override
  String invalidJsonInJiraSResponse(String p0) {
    return 'Некорректный JSON в ответе Jira 201: $p0';
  }

  @override
  String jiraRejectedTheRequestCode(String p0) {
    return 'Отказ Jira (код $p0)';
  }

  @override
  String jiraServerErrorCode(String p0) {
    return 'Серверная ошибка Jira (код $p0)';
  }

  @override
  String connectionLostOrTimedOut(String p0) {
    return 'Обрыв связи или таймаут: $p0';
  }

  @override
  String get storageIsReadOnlyAnotherApplicationInstanceHolds =>
      'Хранилище работает в режиме только чтения: другой экземпляр приложения удерживает блокировку записи.';

  @override
  String logIsAlreadyIncludedInADraftFor152(String p0, String p1) {
    return 'Лог $p0 уже включен в черновик на дату $p1.';
  }

  @override
  String get cannotRemoveALogAfterDaySubmissionTo =>
      'Нельзя исключить лог после начала отправки дня в Jira.';

  @override
  String negativeTimeDifferenceSTheSystemClockMoved(String p0) {
    return 'Отрицательная разница времени ($p0 с): системные часы были переведены назад. Проверьте лог.';
  }

  @override
  String hM(String p0, String p1) {
    return '$p0ч $p1м';
  }

  @override
  String m(String p0) {
    return '$p0м';
  }

  @override
  String get dayStartEnterATimeFromToFrom =>
      'Начало дня: укажите время от 00:00 до 23:59, от ≤ до.';

  @override
  String get dayDurationEnterAPositiveDurationUpTo =>
      'Длительность дня: укажите положительное время до 24 часов, от ≤ до.';

  @override
  String get longBreakStartEnterATimeFromTo =>
      'Начало длинной паузы: укажите время от 00:00 до 23:59, от ≤ до.';

  @override
  String get longBreakDurationEnterToDisableItOr =>
      'Длительность длинной паузы: укажите 0–0 для отключения или положительное время, от ≤ до.';

  @override
  String shortBreaksEnterAnIntegerFromToFrom(String p0) {
    return 'Короткие паузы: укажите целое число от 0 до $p0, от ≤ до.';
  }

  @override
  String get shortBreakDurationEnterAPositiveDurationFrom =>
      'Длительность короткой паузы: укажите положительное время, от ≤ до.';

  @override
  String get scheduleSegment => 'Сегмент расписания';

  @override
  String get dayStart => 'Начало дня';

  @override
  String get dayEnd => 'Конец дня';

  @override
  String get couldNotSaveCredentialsInWindowsCredentialManager =>
      'Не удалось сохранить учетные данные в Windows Credential Manager';

  @override
  String get selectAnIssueFromTheList => 'Выберите задачу из списка';

  @override
  String get selectedIssueWasNotFound => 'Выбранная задача не найдена';

  @override
  String addedTo(String p0, String p1) {
    return 'Добавлено $p0 к $p1';
  }

  @override
  String get addTime => 'Добавить время';

  @override
  String get close => 'Закрыть';

  @override
  String get theEntryWillAppearInTheQueueNo =>
      'Запись появится в очереди. Таймер запускать не нужно.';

  @override
  String get issue => 'Задача';

  @override
  String get noIssuesAvailableAddAnIssueFirst =>
      'Нет доступных задач. Сначала добавьте задачу.';

  @override
  String get quickIssues => 'БЫСТРЫЕ ЗАДАЧИ';

  @override
  String get recentIssues => 'НЕДАВНИЕ ЗАДАЧИ';

  @override
  String get hours => 'Часы';

  @override
  String get minutes => 'Минуты';

  @override
  String get workDone => 'Что сделано';

  @override
  String get optional => 'Необязательно';

  @override
  String get forExampleTheLoginFormAndErrorHandling =>
      'Например, форма входа и обработка ошибок';

  @override
  String get setStartTime => 'Указать время начала';

  @override
  String newEntry(String p0) {
    return 'Новая запись · $p0';
  }

  @override
  String start(String p0) {
    return '· начало $p0';
  }

  @override
  String get clearFixedStartTime => 'Очистить фиксированное время';

  @override
  String get cancel => 'Отмена';

  @override
  String get saveEntry => 'Сохранить запись';

  @override
  String get dayTimeline => 'Шкала дня';

  @override
  String get submissionResultNeedsChecking =>
      'Нужно проверить результат отправки';

  @override
  String get dayPartiallySubmitted => 'День отправлен частично';

  @override
  String get couldNotSubmitEntries => 'Не удалось отправить записи';

  @override
  String sentFailedWithAnUnknownResultResubmissionOf(
    String p0,
    String p1,
    String p2,
  ) {
    return '$p0 отправлено, $p1 с ошибкой, $p2 с неизвестным результатом. Повторная отправка неизвестных записей заблокирована.';
  }

  @override
  String sentNotSentFailedEntriesCanBeResubmitted(String p0, String p1) {
    return '$p0 отправлено, $p1 не отправлено. Можно повторить отправку неуспешных записей.';
  }

  @override
  String get loadingJiraEntries => 'Загружаем записи из Jira...';

  @override
  String get jiraEntriesForTheSelectedDay => 'Записи Jira за выбранный день';

  @override
  String get noJiraEntriesForTheSelectedDay =>
      'Записей Jira за выбранный день нет';

  @override
  String get buildAScheduleFromTheSelectedLogs =>
      'Соберите расписание из выбранных логов';

  @override
  String get allEntriesSubmitted => 'Все записи отправлены';

  @override
  String get submissionResult => 'Результат отправки';

  @override
  String draftSavedOnThisDevice(String p0) {
    return '$p0 · Черновик сохранён на устройстве';
  }

  @override
  String get selectADate => 'Выберите дату';

  @override
  String get select => 'Выбрать';

  @override
  String get moreScheduleActions => 'Другие действия с расписанием';

  @override
  String selectDate(String p0) {
    return 'Выбрать дату ($p0)';
  }

  @override
  String get previousDay => 'Предыдущий день';

  @override
  String get nextDay => 'Следующий день';

  @override
  String get today => 'Сегодня';

  @override
  String get refreshJiraEntries => 'Обновить записи из Jira';

  @override
  String get rebuildDay => 'Пересобрать день';

  @override
  String get submissionResults => 'Результаты отправки';

  @override
  String get clear => 'Очистить';

  @override
  String get smartRebuild => 'Умная пересборка';

  @override
  String get dayBoundaries => 'Границы дня';

  @override
  String wholeDayIncludingBreaks(String p0) {
    return 'Весь день: $p0 с паузами';
  }

  @override
  String get sent => 'Отправлено';

  @override
  String get newTime => 'Новое время';

  @override
  String ofEntries(String p0, int p1) {
    String _temp0 = intl.Intl.pluralLogic(
      p1,
      locale: localeName,
      other: '$p1 записи',
      many: '$p1 записей',
      few: '$p1 записи',
      one: '$p1 запись',
    );
    return '$p0 из $_temp0';
  }

  @override
  String entriesInTheSchedule(String p0) {
    return '$p0 записей в расписании';
  }

  @override
  String entriesToSubmit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    return '$_temp0 к отправке';
  }

  @override
  String get alreadyInJira => 'Уже в Jira';

  @override
  String get willNotBeSubmittedAgain => 'Не отправляется повторно';

  @override
  String get breaks => 'Паузы';

  @override
  String get excludedFromWorkTime => 'Не входят в рабочее время';

  @override
  String get rebuildIsUnavailableAfterSubmissionHasStartedResolve =>
      'Пересборка недоступна после начала отправки. Сначала нужно разрешить все результаты.';

  @override
  String get reconcileUnknownResultsBeforeResubmitting =>
      'Сверьте неизвестные результаты перед повторной отправкой.';

  @override
  String get resubmissionAffectsOnlyEntriesThatHaveNotBeen =>
      'Повторная отправка затронет только неотправленные записи.';

  @override
  String get successfulEntriesAreNeverSubmittedAgain =>
      'Успешные записи не отправляются повторно.';

  @override
  String get entriesForThisDay => 'Записи этого дня';

  @override
  String get successfulEntriesAreNeverSubmittedAgain229 =>
      'Успешные записи не отправляются повторно';

  @override
  String get pendingSubmission => 'Ожидает отправки';

  @override
  String get sending => 'Отправка...';

  @override
  String get notSent => 'Не отправлено';

  @override
  String get checkingTheResult => 'Проверяем результат';

  @override
  String get noDescription => '(без описания)';

  @override
  String get actionsForAnUnknownResult =>
      'Действия для неопределённого результата';

  @override
  String get reconcileResultA => 'Сверить результат (A15)';

  @override
  String get resolveManuallyA => 'Разрешить вручную (A15)';

  @override
  String get couldNotLoadJiraEntries => 'Не удалось загрузить записи Jira';

  @override
  String get noJiraEntriesForThisDay => 'Записей Jira за этот день нет';

  @override
  String get buildADayFromYourLogs => 'Соберите день из своих логов';

  @override
  String get retryLoadingUsingTheDateMenu =>
      'Повторите загрузку через меню у даты.';

  @override
  String get selectEntriesAndTheDateOnTheWork =>
      'На «Работе» выберите записи и нужную дату.';

  @override
  String get selectLogs => 'Выбрать логи';

  @override
  String get theScheduleNeedsChecking => 'Расписание требует проверки';

  @override
  String submissionToJiraIsBlocked(String p0, String p1) {
    return '$p0 $p1 · отправка в Jira заблокирована';
  }

  @override
  String get scheduleErrors => 'Ошибки в расписании';

  @override
  String get showErrors => 'Показать ошибки';

  @override
  String get sources => 'Источники';

  @override
  String get logsToInclude => 'Логи для включения';

  @override
  String get recordedTimeScheduledTime => 'Исходное время → в расписании';

  @override
  String get selectLogsForTheDay => 'Выберите логи для дня';

  @override
  String get noSources => 'Нет источников';

  @override
  String get durationLockedClickToUnlock =>
      'Длительность зафиксирована (нажмите чтобы разблокировать)';

  @override
  String get lockDurationWhenRebuilding =>
      'Зафиксировать длительность при пересборке';

  @override
  String get theQueueHasNoFreeStoppedLogsAdd =>
      'В очереди нет свободных остановленных логов. Добавьте время на вкладке «Работа».';

  @override
  String inTheDraftFor(String p0) {
    return 'В черновике на $p0';
  }

  @override
  String get durationLocked => 'Длительность зафиксирована';

  @override
  String get lockDuration => 'Зафиксировать длительность';

  @override
  String get noPlanBuiltForThisDayYet => 'План на этот день ещё не собран';

  @override
  String get selectLogsOnTheLeftAndClickBuild =>
      'Выберите логи слева и нажмите «Собрать день»';

  @override
  String get buildDay => 'Собрать день';

  @override
  String get schedule => 'Расписание';

  @override
  String get clickAnIntervalToEditIt => 'Нажмите на интервал, чтобы изменить';

  @override
  String get jiraEntriesAreReadOnly => 'Записи Jira доступны только для чтения';

  @override
  String get dragToReorder => 'Перетащить для изменения порядка';

  @override
  String get timePinned => 'Время зафиксировано';

  @override
  String get alreadySubmittedToJira => 'Уже отправлено в Jira';

  @override
  String get editIntervalA => 'Редактировать интервал (A13)';

  @override
  String get moreActions => 'Другие действия';

  @override
  String get moveUp => 'Переместить вверх';

  @override
  String get moveDown => 'Переместить вниз';

  @override
  String get unpinTime => 'Снять фиксацию времени';

  @override
  String get pinTime => 'Зафиксировать время';

  @override
  String get unlock => 'Снять фиксацию';

  @override
  String get splitInterval => 'Разбить интервал';

  @override
  String get mergeIntervals => 'Объединить интервалы';

  @override
  String get deleteInterval => 'Удалить интервал';

  @override
  String get break278 => 'Пауза';

  @override
  String get editInterval => 'Редактировать интервал';

  @override
  String get alreadyInJiraReadOnly => 'Уже в Jira (только чтение)';

  @override
  String get pending => 'Ожидает';

  @override
  String get error => 'Ошибка';

  @override
  String get unknown => 'Не определено';

  @override
  String get planReadyToSubmit => 'План готов к отправке';

  @override
  String get theScheduleHasErrors => 'В расписании есть ошибки';

  @override
  String entriesSent(String p0, int p1) {
    String _temp0 = intl.Intl.pluralLogic(
      p1,
      locale: localeName,
      other: '$p1 записи',
      many: '$p1 записей',
      few: '$p1 записи',
      one: '$p1 запись',
    );
    return '$p0 · $_temp0 отправлено';
  }

  @override
  String get checkTheUnknownResultInJiraFirst =>
      'Сначала проверьте неизвестный результат в Jira';

  @override
  String entriesSomeSubmissionsFailed(String p0, int p1) {
    String _temp0 = intl.Intl.pluralLogic(
      p1,
      locale: localeName,
      other: '$p1 записи',
      many: '$p1 записей',
      few: '$p1 записи',
      one: '$p1 запись',
    );
    return '$p0 · $_temp0, часть отправок не удалась';
  }

  @override
  String entriesWillBeAddedToJira(String p0, int p1) {
    String _temp0 = intl.Intl.pluralLogic(
      p1,
      locale: localeName,
      other: '$p1 записи',
      many: '$p1 записей',
      few: '$p1 записи',
      one: '$p1 запись',
    );
    return '$p0 · $_temp0 будут добавлены в Jira';
  }

  @override
  String get backToWork => 'Вернуться к работе';

  @override
  String get checkInJira => 'Проверить в Jira';

  @override
  String get retrySubmission => 'Повторить отправку';

  @override
  String get submitToJira => 'Отправить в Jira';

  @override
  String get monday => 'Понедельник';

  @override
  String get tuesday => 'Вторник';

  @override
  String get wednesday => 'Среда';

  @override
  String get thursday => 'Четверг';

  @override
  String get friday => 'Пятница';

  @override
  String get saturday => 'Суббота';

  @override
  String get sunday => 'Воскресенье';

  @override
  String get january => 'января';

  @override
  String get february => 'февраля';

  @override
  String get march => 'марта';

  @override
  String get april => 'апреля';

  @override
  String get may => 'мая';

  @override
  String get june => 'июня';

  @override
  String get july => 'июля';

  @override
  String get august => 'августа';

  @override
  String get september => 'сентября';

  @override
  String get october => 'октября';

  @override
  String get november => 'ноября';

  @override
  String get december => 'декабря';

  @override
  String get smartRebuildTheDay => 'Умная пересборка дня?';

  @override
  String get theCurrentDraftWillBeReplacedAndManual =>
      'Текущий черновик будет заменён, а ручные правки времени исчезнут. Расписание будет оптимизировано с перерывами и разделением длинных задач.';

  @override
  String get rebuild => 'Пересобрать';

  @override
  String get clearTheDay => 'Очистить день?';

  @override
  String get allDraftIntervalsAndBreaksWillBeRemoved =>
      'Все интервалы и паузы черновика будут удалены. Исходные логи вернутся в очередь. Записи Jira останутся на экране.';

  @override
  String get rebuildTheDay => 'Пересобрать день?';

  @override
  String get theScheduleWillBeRebuiltWithOrderAnd =>
      'Расписание будет построено заново с сохранением порядка и закреплённых интервалов. Ручные правки времени будут заменены.';

  @override
  String get dayRebuiltWithOrderAndPinnedIntervalsPreserved =>
      'День пересобран с сохранением порядка и якорей.';

  @override
  String get breakCollapsedAndTasksMovedTogether =>
      'Пауза схлопнута, задачи подтянуты вплотную.';

  @override
  String get previousTaskExtendedToFillTheBreak =>
      'Предыдущая задача продлена на время паузы.';

  @override
  String get breakDurationUpdated => 'Длительность паузы обновлена.';

  @override
  String get deleteInterval324 => 'Удалить интервал?';

  @override
  String get theIntervalWillBeRemovedFromTheSchedule =>
      'Интервал будет удален из расписания. Если это последний интервал задачи в данном дне, исходный лог будет возвращён обратно в очередь.';

  @override
  String get delete => 'Удалить';

  @override
  String successfullySubmittedEntriesToJira(int p0) {
    String _temp0 = intl.Intl.pluralLogic(
      p0,
      locale: localeName,
      other: '$p0 записи',
      many: '$p0 записей',
      few: '$p0 записи',
      one: '$p0 запись',
    );
    return 'Успешно отправлено: $_temp0 в Jira!';
  }

  @override
  String sentFailedUnknown(String p0, String p1, String p2) {
    return 'Отправлено: $p0, Ошибок: $p1, Не определено: $p2';
  }

  @override
  String get resolveUnknownStatusA => 'Разрешение неизвестного статуса (A15)';

  @override
  String get theSegmentHasAnUnknownResultTheJira =>
      'Сегмент находится в состоянии «Не определено» (ответ Jira был потерян или прерван). Слепой повтор запрещён.';

  @override
  String get optionEnterTheIdOfTheCreatedJira =>
      'Вариант 1: Указать ID созданной записи в Jira';

  @override
  String get theApplicationWillCheckTheEntrySAuthor =>
      'Приложение проверит автора, дату и длительность записи перед подтверждением:';

  @override
  String get worklogIdForExample => 'Worklog ID (например: 10042)';

  @override
  String get entrySuccessfullyConfirmedAndLinked =>
      'Запись успешно подтверждена и связана!';

  @override
  String get linkingError => 'Ошибка привязки';

  @override
  String get link => 'Связать';

  @override
  String get optionConfirmThatTheEntryDoesNotExist =>
      'Вариант 2: Подтвердить отсутствие записи';

  @override
  String get ifYouHaveOpenedJiraInABrowser =>
      'Если вы открыли Jira в браузере и точно убедились, что в задаче нет этой записи, вы можете вернуть интервал в статус ожидания для повторной отправки.';

  @override
  String get noEntryInJiraAllowRetry => 'Записи нет в Jira, разрешить повтор';

  @override
  String get intervalResetToPendingForResubmission =>
      'Интервал переведён в статус ожидания для повторной отправки.';

  @override
  String get editTimeEntry => 'Редактировать запись времени';

  @override
  String get workDoneDescription => 'Что сделано (описание)';

  @override
  String get briefDescriptionOfTheWork => 'Краткое описание работы...';

  @override
  String get fixedStart => 'Фиксированное начало';

  @override
  String get save => 'Сохранить';

  @override
  String get selectStartTime => 'Выберите время начала';

  @override
  String get done => 'Готово';

  @override
  String get editInterval348 => 'Изменить интервал';

  @override
  String get start349 => 'Начало';

  @override
  String get duration => 'Длительность';

  @override
  String end(String p0) {
    return 'Окончание: $p0';
  }

  @override
  String get workDoneDuringThisInterval =>
      'Что было сделано за этот интервал...';

  @override
  String get breakDurationMustBeGreaterThanMinutes =>
      'Длительность перерыва должна быть больше 0 минут.';

  @override
  String break354(String p0) {
    return 'Перерыв ($p0)';
  }

  @override
  String get quickActions => 'Быстрые действия:';

  @override
  String get collapseBreak => 'Схлопнуть паузу';

  @override
  String get moveFollowingTasksTogetherRemoveTheGap =>
      'Придвинуть следующие задачи встык (убрать зазор)';

  @override
  String get extendPreviousTask => 'Растянуть предыдущую задачу';

  @override
  String extendTaskBy(String p0) {
    return 'Продлить работу над задачей на $p0';
  }

  @override
  String get thePreviousEntryIsFixedInJira =>
      'Предыдущая запись зафиксирована в Jira';

  @override
  String get thisIsTheStartOfTheDayNo =>
      'Это начало рабочего дня (нет предыдущей задачи)';

  @override
  String get setBreakDuration => 'Задать длительность перерыва:';

  @override
  String get followingTasksWillShiftTogetherPreservingTheirDurations =>
      'Последующие задачи сдвинутся волной, сохранив свою длительность.';

  @override
  String min(String p0) {
    return '$p0 мин';
  }

  @override
  String get apply => 'Применить';

  @override
  String logsSuccessfullyMergedTotalDuration(String p0) {
    return 'Логи успешно объединены. Общая длительность: $p0';
  }

  @override
  String get mergeWithAnotherLog => 'Объединить с другим логом';

  @override
  String currentLog(String p0) {
    return 'Текущий лог: $p0';
  }

  @override
  String duration369(String p0) {
    return 'Длительность: $p0';
  }

  @override
  String get selectALogToMerge => 'Выберите лог для объединения:';

  @override
  String get noFreeLogsAvailableToMerge =>
      'Нет доступных свободных логов для объединения.';

  @override
  String get theLogsBelongToDifferentIssuesSelectThe =>
      'Логи принадлежат разным задачам. Выберите задачу для результата:';

  @override
  String get merge => 'Объединить';

  @override
  String get intervalsSuccessfullyMerged => 'Интервалы успешно объединены.';

  @override
  String currentInterval(String p0, String p1) {
    return 'Текущий интервал: $p0 ($p1)';
  }

  @override
  String duration376(String p0) {
    return 'Длительность: $p0';
  }

  @override
  String get selectAnIntervalToMerge => 'Выберите интервал для объединения:';

  @override
  String get noOtherIntervalsAvailableToMerge =>
      'Нет других интервалов для объединения.';

  @override
  String get enterAJiraIssueKeyIdOrLink =>
      'Введите ключ, ID или ссылку на задачу Jira';

  @override
  String get editQuickIssue => 'Изменить быструю задачу';

  @override
  String get addQuickIssue => 'Добавить быструю задачу';

  @override
  String get findAnExistingIssueInTheConnectedJira =>
      'Найдите существующую задачу в подключённой Jira.';

  @override
  String get keyIdOrLink => 'Ключ, ID или ссылка';

  @override
  String get forExampleProj => 'например, PROJ-123';

  @override
  String get find => 'Найти';

  @override
  String get note => 'Подсказка';

  @override
  String get optionalWhenToUseThisIssue =>
      'Необязательно: когда использовать эту задачу';

  @override
  String get theNoteIsLocalAndIsNotSubmitted =>
      'Подсказка видна только локально и не отправляется в Jira.';

  @override
  String get add => 'Добавить';

  @override
  String m390(String p0) {
    return '$p0 м';
  }

  @override
  String h(String p0) {
    return '$p0 ч';
  }

  @override
  String hM392(String p0, String p1) {
    return '$p0 ч $p1 м';
  }

  @override
  String get enterTimeInHhMmFormat => 'Введите время в формате ЧЧ:ММ.';

  @override
  String get enterADurationForExampleHM =>
      'Введите длительность, например 7 ч 30 м.';

  @override
  String get enterADurationForExampleH => 'Введите длительность, например 8 ч.';

  @override
  String get enterADurationForExampleM =>
      'Введите длительность, например 30 м.';

  @override
  String get enterADurationForExampleM398 =>
      'Введите длительность, например 45 м.';

  @override
  String get enterAnIntegerFrom => 'Введите целое число от 0.';

  @override
  String get enterADurationForExampleM400 =>
      'Введите длительность, например 5 м.';

  @override
  String get enterADurationForExampleM401 =>
      'Введите длительность, например 10 м.';

  @override
  String get dayBuildSettingsSaved => 'Параметры сборки дня сохранены.';

  @override
  String couldNotSaveSettings(String p0) {
    return 'Не удалось сохранить параметры: $p0';
  }

  @override
  String connectionError(String p0) {
    return 'Ошибка подключения: $p0';
  }

  @override
  String get jiraConnectionSuccessfullySaved =>
      'Подключение к Jira успешно сохранено';

  @override
  String get quickIssues406 => 'Быстрые задачи';

  @override
  String get savedIssuesForQuicklyAddingTime =>
      'Сохранённые задачи для быстрого добавления времени.';

  @override
  String get addIssue => 'Добавить задачу';

  @override
  String get connectJiraFirst => 'Сначала подключите Jira';

  @override
  String get quickIssuesAreStoredSeparatelyForEachSite =>
      'Быстрые задачи хранятся отдельно для каждого сайта и аккаунта.';

  @override
  String get goToConnection => 'Перейти к подключению';

  @override
  String get inReadOnlyModeYouCanViewThe =>
      'В режиме только чтения список можно просматривать, но нельзя изменять.';

  @override
  String get noQuickIssuesYet => 'Быстрых задач пока нет';

  @override
  String get addAFrequentlyUsedJiraIssueToShow =>
      'Добавьте часто используемую Jira-задачу — она появится здесь и на экране «Работа».';

  @override
  String get jiraConnection => 'Подключение к Jira';

  @override
  String get dayBuild => 'Сборка дня';

  @override
  String get localApi => 'Локальный API';

  @override
  String get settings418 => 'Настройки';

  @override
  String get jiraConnectionDayBuildQuickIssuesAndLocal =>
      'Подключение к Jira, сборка дня, быстрые задачи и локальный API.';

  @override
  String get theme => 'Тема оформления';

  @override
  String get systemDefault422 => 'Как в системе';

  @override
  String get light => 'Светлая';

  @override
  String get dark => 'Тёмная';

  @override
  String couldNotSaveTheTheme(String p0) {
    return 'Не удалось сохранить тему: $p0';
  }

  @override
  String get theThemeCannotBeChangedInReadOnly =>
      'В режиме только чтения изменить тему нельзя.';

  @override
  String get smartRebuildChoosesValuesWithinTheseRanges =>
      'Умная пересборка выбирает значения внутри этих диапазонов.';

  @override
  String get parameter => 'ПАРАМЕТР';

  @override
  String get from => 'ОТ';

  @override
  String get to => 'ДО';

  @override
  String get dayDuration => 'Длительность дня';

  @override
  String get longBreakStart => 'Начало длинной паузы';

  @override
  String get longBreakDuration => 'Длительность длинной паузы';

  @override
  String get shortBreaksPerDay => 'Короткие паузы за день';

  @override
  String get shortBreakDuration => 'Длительность короткой паузы';

  @override
  String get minimumWorkIntervalMinutes =>
      'Минимальный рабочий интервал — 15 минут.';

  @override
  String get agentDayBuildRule => 'Правило сборки для агента';

  @override
  String get theAgentReceivesThisTextTogetherWithThe =>
      'Агент получает этот текст вместе с диапазонами через локальный API. Встроенный сборщик использует только диапазоны.';

  @override
  String get describeHowTheAgentShouldUseTheDay =>
      'Опишите, как агенту использовать параметры сборки дня';

  @override
  String get couldNot => 'Не удалось';

  @override
  String get settingsCannotBeChangedInReadOnlyMode =>
      'В режиме только чтения изменить параметры нельзя.';

  @override
  String get reset => 'Сбросить';

  @override
  String get saveSettings => 'Сохранить параметры';

  @override
  String get usedToLoadIssuesAndSubmitTime =>
      'Используется для загрузки задач и отправки времени.';

  @override
  String get jiraAddress => 'Адрес Jira';

  @override
  String get apiToken => 'API-токен';

  @override
  String get showToken => 'Показать токен';

  @override
  String get hideToken => 'Скрыть токен';

  @override
  String accountIdRoute(String p0, String p1) {
    return 'Account ID: $p0\nМаршрут: $p1';
  }

  @override
  String connected(String p0, String p1) {
    return 'Подключено · $p0\n$p1';
  }

  @override
  String get checkConnection => 'Проверить подключение';

  @override
  String get localApiForAiAgents => 'Локальный API для AI-агентов';

  @override
  String get theBuiltInHttpServerAllowsAiAgents =>
      'Встроенный HTTP-сервер позволяет AI-агентам логировать время и передавать готовое расписание дня.';

  @override
  String get localServerAddress => 'Адрес локального сервера';

  @override
  String get copyAddress => 'Скопировать адрес';

  @override
  String get serverAddressCopiedToClipboard =>
      'Адрес сервера скопирован в буфер обмена';

  @override
  String get agentSkillInstructions => 'Инструкция для скилла агента';

  @override
  String get copyInstructions => 'Скопировать инструкцию';

  @override
  String get agentInstructionsCopiedToClipboard =>
      'Инструкция для агента скопирована в буфер обмена';

  @override
  String get editNote => 'Изменить подсказку';

  @override
  String get actions => 'Действия';

  @override
  String couldNotDeleteTheQuickIssue(String p0) {
    return 'Не удалось удалить быструю задачу: $p0';
  }

  @override
  String get removeFromQuickIssues => 'Удалить из быстрых';

  @override
  String get jiraConnected => 'Jira подключена';

  @override
  String get readOnlyModeAnotherApplicationInstanceHoldsThe =>
      'Режим только чтения: другой экземпляр приложения удерживает блокировку записи (A19).';

  @override
  String theFirstPartMustBeGreaterThanAnd466(String p0) {
    return 'Длительность первой части должна быть больше 0 и меньше $p0';
  }

  @override
  String logSplitIntoTwoPartsAnd(String p0, String p1) {
    return 'Лог разделен на две части: $p0 и $p1';
  }

  @override
  String get splitTimeEntry => 'Разбить запись времени';

  @override
  String totalTime(String p0) {
    return 'Общее время: $p0';
  }

  @override
  String get part => 'Часть 1';

  @override
  String get h471 => 'ч';

  @override
  String get m472 => 'м';

  @override
  String get partDescription => 'Описание части 1';

  @override
  String get partRemainder => 'Часть 2 (остаток)';

  @override
  String get min475 => '0 мин';

  @override
  String get partDescription476 => 'Описание части 2';

  @override
  String get split => 'Разбить';

  @override
  String theFirstPartMustBeGreaterThanAnd478(String p0) {
    return 'Длительность первой части должна быть больше 0 и меньше $p0';
  }

  @override
  String intervalSplitAnd(String p0, String p1) {
    return 'Интервал разделен: $p0 и $p1';
  }

  @override
  String issue480(String p0) {
    return 'Задача: $p0';
  }

  @override
  String totalDuration(String p0) {
    return 'Общая длительность: $p0';
  }

  @override
  String get firstPartDescription => 'Описание первой части';

  @override
  String get workDoneInTheFirstPart => 'Что сделано в первой части...';

  @override
  String get secondPartDescription => 'Описание второй части';

  @override
  String get workDoneInTheSecondPart => 'Что сделано во второй части...';

  @override
  String h486(String p0) {
    return '$p0 ч';
  }

  @override
  String hMin(String p0, String p1) {
    return '$p0 ч $p1 мин';
  }

  @override
  String break488(String p0, String p1, String p2) {
    return 'Перерыв · $p0–$p1 ($p2)';
  }

  @override
  String alreadyInJira489(String p0, String p1, String p2) {
    return '$p0 · уже в Jira · $p1–$p2';
  }

  @override
  String get selectedLogs => 'Выбранные логи';

  @override
  String issueAdded(String p0, String p1) {
    return 'Задача добавлена: $p0 — $p1';
  }

  @override
  String get couldNotAddTheIssue => 'Не удалось добавить задачу';

  @override
  String get work493 => 'Работа';

  @override
  String get pasteAJiraIssueIdOrLink => 'Вставьте ID или ссылку на задачу Jira';

  @override
  String get frequentlyUsedIssuesHaveNotBeenConfiguredYet =>
      'Часто используемые задачи ещё не настроены.';

  @override
  String get configureQuickIssues => 'Настроить быстрые задачи';

  @override
  String get recentIssues497 => 'Недавние задачи';

  @override
  String start498(String p0) {
    return 'Запустить ($p0)';
  }

  @override
  String get selectMultiple => 'Выбрать несколько';

  @override
  String get searchIssues => 'Поиск по задачам';

  @override
  String get clearSearch => 'Очистить поиск';

  @override
  String get activityFilter => 'Фильтр активности';

  @override
  String get lastDays => 'За 7 дней';

  @override
  String get lastDays504 => 'За 30 дней';

  @override
  String get allTime => 'За всё время';

  @override
  String get noIssuesAddedEnterAKeyIdOr =>
      'Нет добавленных задач.\nВведите ключ, ID или ссылку выше.';

  @override
  String get noIssuesMatchTheFilter => 'Нет задач, соответствующих фильтру.';

  @override
  String activity(String p0) {
    return 'Активность: $p0';
  }

  @override
  String get stop => 'Остановить';

  @override
  String get start510 => 'Начать';

  @override
  String get queue => 'Очередь';

  @override
  String get history => 'История';

  @override
  String total(String p0) {
    return 'Всего $p0';
  }

  @override
  String get pauseAllTimers => 'Поставить все таймеры на паузу';

  @override
  String get theLogQueueIsEmpty => 'Очередь логов пуста';

  @override
  String get startAnIssueTimerOrAddTimeManually =>
      'Запустите таймер на задаче или добавьте время вручную.';

  @override
  String removeLogFromDraftFor(String p0) {
    return 'Убрать лог из черновика на $p0';
  }

  @override
  String get dayContentsCannotBeChangedAfterSubmissionHas =>
      'После начала отправки состав дня изменить нельзя';

  @override
  String entryIsAlreadyIncludedInTheDayFor(String p0) {
    return 'Запись уже включена в день $p0';
  }

  @override
  String get selectForDayBuild => 'Выбрать для сборки дня';

  @override
  String get pauseTheTimerBeforeSelectingItForDay =>
      'Поставьте таймер на паузу перед выбором для сборки дня';

  @override
  String get pauseTimer => 'Поставить таймер на паузу';

  @override
  String get stopTheTimerToAddThisEntryTo =>
      'Остановите таймер, чтобы добавить запись в день.';

  @override
  String get systemClockMovedBackwards => 'Обнаружен откат системного времени!';

  @override
  String created(String p0) {
    return 'Создан: $p0';
  }

  @override
  String inDayOpen(String p0) {
    return 'В дне $p0 · Открыть';
  }

  @override
  String get actionsForAnEntryInAnotherDay => 'Действия с записью в другом дне';

  @override
  String removeFromDay(String p0) {
    return 'Убрать из дня $p0';
  }

  @override
  String get logActions => 'Действия с логом';

  @override
  String get edit => 'Редактировать';

  @override
  String get mergeWith => 'Объединить с…';

  @override
  String get noSubmittedLogsInHistoryYet =>
      'История отправленных логов пока пуста.';

  @override
  String get submissionHistoryIsStoredOnThisDevice =>
      'История отправок хранится на этом устройстве';

  @override
  String noEntriesSelectedFor(String p0) {
    return 'Для $p0 записи не выбраны';
  }

  @override
  String selected(String p0, String p1) {
    return 'Выбрано $p0 $p1';
  }

  @override
  String get recordedTime => ' исходного времени';

  @override
  String get buildFor => 'Собрать на';

  @override
  String get dayBuildDate => 'Дата для сборки дня';

  @override
  String get monday539 => 'понедельник';

  @override
  String get tuesday540 => 'вторник';

  @override
  String get wednesday541 => 'среда';

  @override
  String get thursday542 => 'четверг';

  @override
  String get friday543 => 'пятница';

  @override
  String get saturday544 => 'суббота';

  @override
  String get sunday545 => 'воскресенье';

  @override
  String get entries => 'записей';

  @override
  String get entry => 'запись';

  @override
  String get entries548 => 'записи';

  @override
  String get deleteTimeEntry => 'Удалить запись времени?';

  @override
  String entryWillBePermanentlyDeleted(String p0, String p1) {
    return 'Запись «$p0» ($p1) будет удалена безвозвратно.';
  }

  @override
  String entrySuccessfullyFoundAndConfirmedInJiraId(String p0) {
    return 'Запись успешно найдена в Jira и подтверждена (ID: $p0).';
  }

  @override
  String get theJiraTimeTrackerSegmentPropertyWasNot =>
      'Свойство jira-time-tracker.segment не найдено среди записей задачи в Jira. Слепая повторная отправка запрещена.';

  @override
  String connectionMismatchTheDraftBelongsToSiteAccount(String p0, String p1) {
    return 'Несоответствие подключения: черновик принадлежит сайту/аккаунту \"$p0\", а текущее подключение — \"$p1\". Отправка заблокирована.';
  }

  @override
  String get theDraftIsEmptyThereAreNoIntervals =>
      'Черновик пуст, нет интервалов для отправки.';

  @override
  String get jiraRejectedTheRequest => 'Отказ Jira';

  @override
  String get unknownSubmissionResultTheConnectionMayHaveBeen =>
      'Неопределённый статус отправки (возможен обрыв связи)';

  @override
  String conflictMultipleEntriesFoundWithSegmentIdManual(String p0, String p1) {
    return 'Конфликт: найдено несколько ($p0) записей с свойством segment id \"$p1\". Требуется ручная проверка.';
  }

  @override
  String conflictAnEntryWithTheSameSegmentId(String p0, String p1, String p2) {
    return 'Конфликт: найдена запись с совпадающим segment id, но параметры не совпадают (автор: $p0, длительность: $p1, время: $p2).';
  }

  @override
  String networkErrorDuringReconciliation(String p0) {
    return 'Сетевая ошибка при сверке: $p0';
  }

  @override
  String entryWithIdWasNotFoundInIssue(String p0, String p1) {
    return 'Запись с ID \"$p0\" не найдена в задаче \"$p1\".';
  }

  @override
  String theEntryBelongsToAnotherJiraUserAccountid(String p0) {
    return 'Запись принадлежит другому пользователю Jira (accountId: $p0).';
  }

  @override
  String jiraEntryDurationSDoesNotMatchThe(String p0, String p1) {
    return 'Длительность записи в Jira ($p0 с) не совпадает с сегментом ($p1 с).';
  }

  @override
  String errorCheckingTheJiraEntry(String p0) {
    return 'Ошибка проверки записи в Jira: $p0';
  }

  @override
  String get resetByUserConfirmedTheEntryDoesNot =>
      'Сброшено пользователем: подтверждено отсутствие записи в Jira, разрешён повтор';

  @override
  String get breakLabel => 'Перерыв';

  @override
  String get submissionInterruptedAtStartup =>
      'Прервано до получения подтверждения (восстановлено при запуске)';

  @override
  String get directApi => 'Прямой API';

  @override
  String retryAfterSeconds(String seconds) {
    return '. Повторите через $seconds сек.';
  }

  @override
  String get mismatch => 'не совпадает';

  @override
  String scheduleEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    return '$_temp0 в расписании';
  }

  @override
  String scheduleErrorCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ошибки',
      many: '$count ошибок',
      few: '$count ошибки',
      one: '$count ошибка',
    );
    return '$_temp0 · отправка в Jira заблокирована';
  }

  @override
  String get readOnlyLanguage => 'В режиме только чтения изменить язык нельзя.';

  @override
  String selectedLogCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    return 'Выбрано $_temp0';
  }
}
