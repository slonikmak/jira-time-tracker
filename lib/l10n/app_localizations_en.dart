// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get work => 'Work';

  @override
  String get day => 'Day';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Язык / Language';

  @override
  String get systemDefault => 'System default';

  @override
  String languageSaveFailed(String error) {
    return 'Could not save the language: $error';
  }

  @override
  String get days => '7 days';

  @override
  String get days9 => '30 days';

  @override
  String get all => 'All';

  @override
  String get invalidInputEnterAKeyProjNumericId =>
      'Invalid input: enter a key (PROJ-123), numeric ID or /browse/... link';

  @override
  String get firstCheckAndSaveTheJiraConnectionIn =>
      'First check and save the Jira connection in Settings';

  @override
  String get jiraApiTokenWasNotFoundInSecure =>
      'Jira API token was not found in secure storage';

  @override
  String get firstConnectJiraInSettings => 'First connect Jira in Settings.';

  @override
  String get jiraApiTokenWasNotFoundInSecure16 =>
      'Jira API token was not found in secure storage.';

  @override
  String get theApplicationIsReadOnly => 'The application is read-only.';

  @override
  String get issueKeyOrIdCannotBeEmpty => 'Issue key or ID cannot be empty';

  @override
  String issueIsNotInTheLocalCatalogueAnd(String p0) {
    return 'Issue \"$p0\" is not in the local catalogue and Jira is unavailable.';
  }

  @override
  String get durationMustBeGreaterThanZero =>
      'Duration must be greater than zero';

  @override
  String issueWithIdWasNotFoundInThe(String p0) {
    return 'Issue with ID $p0 was not found in the local catalogue';
  }

  @override
  String logWithIdWasNotFound(String p0) {
    return 'Log with ID $p0 was not found';
  }

  @override
  String get cannotEditARunningLogPauseItFirst =>
      'Cannot edit a running log. Pause it first.';

  @override
  String get cannotEditALogThatHasAlreadyBeen =>
      'Cannot edit a log that has already been used.';

  @override
  String cannotEditALogAlreadyIncludedInThe(String p0) {
    return 'Cannot edit a log already included in the day draft ($p0).';
  }

  @override
  String get cannotSplitARunningLogStopItFirst =>
      'Cannot split a running log. Stop it first.';

  @override
  String get cannotSplitALogThatHasAlreadyBeen =>
      'Cannot split a log that has already been used.';

  @override
  String get cannotSplitALogAlreadyIncludedInA =>
      'Cannot split a log already included in a day draft.';

  @override
  String theFirstPartMustBeGreaterThanAnd(String p0) {
    return 'The first part must be greater than 0 and less than the total duration ($p0 s)';
  }

  @override
  String get atLeastTwoLogsAreRequiredToMerge =>
      'At least two logs are required to merge';

  @override
  String get someOfTheSpecifiedLogsWereNotFound =>
      'Some of the specified logs were not found';

  @override
  String get cannotMergeRunningLogs => 'Cannot merge running logs.';

  @override
  String get cannotMergeLogsAlreadyIncludedInADay =>
      'Cannot merge logs already included in a day draft.';

  @override
  String get cannotDeleteARunningLogPauseItFirst =>
      'Cannot delete a running log. Pause it first.';

  @override
  String cannotDeleteALogAlreadyIncludedInThe(String p0) {
    return 'Cannot delete a log already included in the day draft ($p0).';
  }

  @override
  String get errorLoadingJiraEntries => 'Error loading Jira entries:';

  @override
  String errorLoadingJiraEntries37(String p0) {
    return 'Error loading Jira entries: $p0';
  }

  @override
  String get noActiveJiraConnectionToLoadWorklogs =>
      'No active Jira connection to load worklogs.';

  @override
  String get expectedAJiraIssueKeyOrNumericId =>
      'Expected a Jira issue key or numeric ID.';

  @override
  String get noActiveJiraConnection => 'No active Jira connection.';

  @override
  String get expectedAJiraIssueKeyAndANumeric =>
      'Expected a Jira issue key and a numeric attachment ID.';

  @override
  String get theAgentRuleCannotBeEmpty => 'The agent rule cannot be empty.';

  @override
  String get cannotClearADayAfterSubmissionHasStarted =>
      'Cannot clear a day after submission has started or in read-only mode.';

  @override
  String get cannotRebuildAPartiallyOrFullySubmittedDay =>
      'Cannot rebuild a partially or fully submitted day.';

  @override
  String get noLogsSelectedToBuildTheDay =>
      'No logs selected to build the day.';

  @override
  String get aRunningLogCannotBeIncludedInA =>
      'A running log cannot be included in a day draft.';

  @override
  String logIsAlreadyIncludedInADraftFor(String p0, String p1) {
    return 'Log $p0 is already included in a draft for $p1.';
  }

  @override
  String get daySuccessfullyRebuiltSmartRebuild =>
      'Day successfully rebuilt (smart rebuild).';

  @override
  String get daySuccessfullyBuilt => 'Day successfully built.';

  @override
  String get theSegmentListCannotBeEmpty => 'The segment list cannot be empty.';

  @override
  String get cannotReplaceTheDraftAfterDaySubmissionHas =>
      'Cannot replace the draft after day submission has started.';

  @override
  String get theDayDraftHasChangedSinceItWas =>
      'The day draft has changed since it was read. Get a fresh snapshot and try again.';

  @override
  String get theDayDraftHasBeenDeletedSinceIt =>
      'The day draft has been deleted since it was read. Get a fresh snapshot and try again.';

  @override
  String sourceWasNotFound(String p0) {
    return 'Source \"$p0\" was not found.';
  }

  @override
  String runningSourceCannotBeIncludedInADay(String p0) {
    return 'Running source \"$p0\" cannot be included in a day.';
  }

  @override
  String submittedSourceCannotBeIncludedAgain(String p0) {
    return 'Submitted source \"$p0\" cannot be included again.';
  }

  @override
  String sourceHasNoRecordedTime(String p0) {
    return 'Source \"$p0\" has no recorded time.';
  }

  @override
  String sourceIsAlreadyIncludedInADraftFor(String p0, String p1) {
    return 'Source \"$p0\" is already included in a draft for $p1.';
  }

  @override
  String theIssueForSourceWasNotFoundIn(String p0) {
    return 'The issue for source $p0 was not found in the local catalogue.';
  }

  @override
  String issueDoesNotMatchSource(String p0, String p1, String p2) {
    return 'Issue \"$p0\" does not match source $p1 ($p2).';
  }

  @override
  String get segmentDurationMustBeGreaterThanZero =>
      'Segment duration must be greater than zero.';

  @override
  String theSegmentMustStartOnTheTargetDate(String p0) {
    return 'The segment must start on the target date $p0.';
  }

  @override
  String theEntireSegmentMustFitWithinTheTarget(String p0) {
    return 'The entire segment must fit within the target date $p0.';
  }

  @override
  String get theDayDraftChangedWhileTheSnapshotWas =>
      'The day draft changed while the snapshot was being prepared. Get a fresh snapshot and try again.';

  @override
  String get thisIntervalHasAlreadyBeenSubmittedOrNeeds =>
      'This interval has already been submitted or needs reconciliation with Jira.';

  @override
  String get durationMustBeGreaterThanMinutes =>
      'Duration must be greater than 0 minutes.';

  @override
  String get theNextIntervalIsPinnedOrHasAlready =>
      'The next interval is pinned or has already been submitted. It cannot be moved.';

  @override
  String theSplitPointMustBeGreaterThanAnd(String p0) {
    return 'The split point must be greater than 0 and less than the segment duration ($p0 s)';
  }

  @override
  String get onlySegmentsFromTheSameSourceLogCan =>
      'Only segments from the same source log can be merged.';

  @override
  String get theSourceLogForTheSegmentsWasNot =>
      'The source log for the segments was not found.';

  @override
  String get cannotRebuildADayAfterSubmissionHasStarted =>
      'Cannot rebuild a day after submission has started or in read-only mode.';

  @override
  String get daySuccessfullyRebuiltWithTheOrderPreserved =>
      'Day successfully rebuilt with the order preserved.';

  @override
  String get endTimeMustBeAfterStartTime =>
      'End time must be after start time.';

  @override
  String cannotChangeTheBoundaryThereIsAJira(String p0) {
    return 'Cannot change the boundary: there is a Jira entry on the left ($p0).';
  }

  @override
  String get thePreviousTaskMustBeAtLeastMinute =>
      'The previous task must be at least 1 minute long.';

  @override
  String cannotChangeTheBoundaryThereIsAJira76(String p0) {
    return 'Cannot change the boundary: there is a Jira entry on the right ($p0).';
  }

  @override
  String get theNextTaskMustBeAtLeastMinute =>
      'The next task must be at least 1 minute long.';

  @override
  String notEnoughFreeTimeBeforeJiraEntryRequires(
    String p0,
    String p1,
    String p2,
  ) {
    return 'Not enough free time before Jira entry $p0: requires $p1 min, available $p2 min.';
  }

  @override
  String get jiraTokenWasNotFoundInSecureStorage =>
      'Jira token was not found in secure storage';

  @override
  String get submittingEntriesToJira => 'Submitting entries to Jira...';

  @override
  String allEntriesWereSuccessfullySubmittedToJira(String p0) {
    return 'All entries ($p0) were successfully submitted to Jira!';
  }

  @override
  String submissionError(String p0) {
    return 'Submission error: $p0';
  }

  @override
  String submissionFinishedSentFailedUnknown(String p0, String p1, String p2) {
    return 'Submission finished: $p0 sent, $p1 failed, $p2 unknown.';
  }

  @override
  String errorSubmittingToJira(String p0) {
    return 'Error submitting to Jira: $p0';
  }

  @override
  String reconciliationError(String p0) {
    return 'Reconciliation error: $p0';
  }

  @override
  String get worklogSuccessfullyLinked => 'Worklog successfully linked!';

  @override
  String get errorLinkingTheWorklog => 'Error linking the worklog';

  @override
  String get segmentResetToPendingSubmissionIsAllowedAgain =>
      'Segment reset to Pending. Submission is allowed again.';

  @override
  String conflictPinnedTaskOverlapsTask(String p0, String p1) {
    return 'Conflict: pinned task \"$p0\" overlaps task \"$p1\".';
  }

  @override
  String conflictPinnedTaskOverlapsExistingJiraEntry(String p0, String p1) {
    return 'Conflict: pinned task \"$p0\" overlaps existing Jira entry \"$p1\".';
  }

  @override
  String get theLogHasAZeroOrNegativeDuration =>
      'The log has a zero or negative duration.';

  @override
  String get conflictExistingJiraEntriesOverlapEachOther =>
      'Conflict: existing Jira entries overlap each other.';

  @override
  String get existingWorklog => 'Existing worklog';

  @override
  String get segment => 'Segment';

  @override
  String get tasksDoNotFitIntoTheSelectedDate =>
      'Tasks do not fit into the selected date (before 23:59:59). Reduce the duration or move some tasks to another day.';

  @override
  String existingJiraEntriesAlreadyOccupyOrMoreHours(String p0) {
    return 'Existing Jira entries already occupy $p0 or more hours.';
  }

  @override
  String get existingJiraEntriesOrPinnedTasksFallOutside =>
      'Existing Jira entries or pinned tasks fall outside the permitted 24-hour day window.';

  @override
  String get withExistingEntriesAndPinnedTasksTheDay =>
      'With existing entries and pinned tasks, the day exceeds the 24-hour limit.';

  @override
  String get pinnedTask => 'Pinned task';

  @override
  String get existingEntriesBreaksAndPinnedTasksHaveExhausted =>
      'Existing entries, breaks and pinned tasks have exhausted the work time budget.';

  @override
  String get aDurationLockedLogIsShorterThanThe =>
      'A duration-locked log is shorter than the minimum work interval of 15 minutes.';

  @override
  String lockedLogsRequireHMinButOnlyH(
    String p0,
    String p1,
    String p2,
    String p3,
  ) {
    return 'Locked logs require $p0 h $p1 min, but only $p2 h $p3 min is available.';
  }

  @override
  String allLogsAreLockedHMinButThe(
    String p0,
    String p1,
    String p2,
    String p3,
  ) {
    return 'All logs are locked ($p0 h $p1 min), but the budget is $p2 h $p3 min. Unlock at least one log.';
  }

  @override
  String get notEnoughTimeEachSelectedLogRequiresAt =>
      'Not enough time: each selected log requires at least 15 minutes.';

  @override
  String get cannotFitWorkIntervalsOfAtLeastMinutes =>
      'Cannot fit work intervals of at least 15 minutes with the required breaks. Change the selected logs or day settings.';

  @override
  String theTotalDayDurationSExceedsHours(String p0) {
    return 'The total day duration ($p0 s) exceeds 24 hours.';
  }

  @override
  String get totalWorkTimeExceedsHours => 'Total work time exceeds 24 hours.';

  @override
  String segmentHasANonPositiveDuration(String p0) {
    return 'Segment $p0 has a non-positive duration.';
  }

  @override
  String segmentIsShorterThanTheMinimumOfMinutes(String p0) {
    return 'Segment $p0 is shorter than the minimum of 10 minutes.';
  }

  @override
  String segmentFallsOutsideTheWorkDay(String p0) {
    return 'Segment $p0 falls outside the work day.';
  }

  @override
  String breakHasANonPositiveDuration(String p0) {
    return 'Break $p0 has a non-positive duration.';
  }

  @override
  String breakFallsOutsideTheWorkDay(String p0) {
    return 'Break $p0 falls outside the work day.';
  }

  @override
  String existingEntryHasANonPositiveDuration(String p0) {
    return 'Existing entry $p0 has a non-positive duration.';
  }

  @override
  String existingEntryFallsOutsideTheWorkDay(String p0) {
    return 'Existing entry $p0 falls outside the work day.';
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
    return 'Overlap detected: $p0 ($p1 - $p2) and $p3 ($p4 - $p5).';
  }

  @override
  String get breaksMustHaveAWorkIntervalBetweenThem =>
      'Breaks must have a work interval between them.';

  @override
  String theRequiredBreakBetweenWorkIntervalsAndIs(String p0, String p1) {
    return 'The required break between work intervals $p0 and $p1 is missing.';
  }

  @override
  String get cannotPlaceTheLongBreakWithinTheStart =>
      'Cannot place the long break within the start range. Change the day settings.';

  @override
  String get cannotPlaceTheLongBreakWithinTheStart120 =>
      'Cannot place the long break within the start range: the time is occupied. Change the day settings.';

  @override
  String get cannotPlaceTheRequiredNumberOfShortBreaks =>
      'Cannot place the required number of short breaks: the free gap is too short. Change the day settings.';

  @override
  String get cannotPlaceTheRequiredNumberOfShortBreaks122 =>
      'Cannot place the required number of short breaks in the free time. Change the day settings.';

  @override
  String get candidate => 'Candidate';

  @override
  String couldNotGetTheJiraSiteSCloudid(String p0) {
    return 'Could not get the Jira site\'s cloudId (code: $p0)';
  }

  @override
  String networkErrorRequestingCloudid(String p0) {
    return 'Network error requesting cloudId: $p0';
  }

  @override
  String get invalidEmailOrApiTokenUnauthorized =>
      'Invalid email or API token (401 Unauthorized)';

  @override
  String get accessDeniedForbidden => 'Access denied (403 Forbidden)';

  @override
  String rateLimitExceededTooManyRequests(String p0) {
    return 'Rate limit exceeded (429 Too Many Requests)$p0';
  }

  @override
  String jiraApiError(String p0, String p1) {
    return 'Jira API error: $p0 $p1';
  }

  @override
  String get jiraUrlIsMissing => 'Jira URL is missing';

  @override
  String get atlassianAccountEmailIsMissing =>
      'Atlassian account email is missing';

  @override
  String get atlassianApiTokenIsMissing => 'Atlassian API token is missing';

  @override
  String couldNotConnectViaEitherTheDirectOr(String p0) {
    return 'Could not connect via either the direct or scoped route: $p0';
  }

  @override
  String errorCheckingTheScopedRoute(String p0) {
    return 'Error checking the scoped route: $p0';
  }

  @override
  String issueWasNotFoundInJiraNotFound(String p0) {
    return 'Issue \"$p0\" was not found in Jira (404 Not Found)';
  }

  @override
  String get jiraAuthenticationErrorUnauthorized =>
      'Jira authentication error (401 Unauthorized)';

  @override
  String get accessToTheJiraIssueIsDeniedForbidden =>
      'Access to the Jira issue is denied (403 Forbidden)';

  @override
  String errorLoadingIssue(String p0, String p1, String p2) {
    return 'Error loading issue \"$p0\": $p1 $p2';
  }

  @override
  String get jiraReturnedAnIncompleteCommentList =>
      'Jira returned an incomplete comment list';

  @override
  String get attachmentWasNotFoundInTheSpecifiedJira =>
      'Attachment was not found in the specified Jira issue';

  @override
  String errorLoadingJiraAttachmentCode(String p0) {
    return 'Error loading Jira attachment (code: $p0)';
  }

  @override
  String errorLoadingJiraDataCode(String p0) {
    return 'Error loading Jira data (code: $p0)';
  }

  @override
  String errorSearchingJiraForIssuesWithWorklogsCode(String p0) {
    return 'Error searching Jira for issues with worklogs (code: $p0)';
  }

  @override
  String errorLoadingWorklogsForIssueCode(String p0, String p1) {
    return 'Error loading worklogs for issue \"$p0\" (code: $p1)';
  }

  @override
  String get jiraSResponseDoesNotContainTheCreated =>
      'Jira\'s 201 response does not contain the created worklog ID';

  @override
  String invalidJsonInJiraSResponse(String p0) {
    return 'Invalid JSON in Jira\'s 201 response: $p0';
  }

  @override
  String jiraRejectedTheRequestCode(String p0) {
    return 'Jira rejected the request (code $p0)';
  }

  @override
  String jiraServerErrorCode(String p0) {
    return 'Jira server error (code $p0)';
  }

  @override
  String connectionLostOrTimedOut(String p0) {
    return 'Connection lost or timed out: $p0';
  }

  @override
  String get storageIsReadOnlyAnotherApplicationInstanceHolds =>
      'Storage is read-only: another application instance holds the write lock.';

  @override
  String logIsAlreadyIncludedInADraftFor152(String p0, String p1) {
    return 'Log $p0 is already included in a draft for $p1.';
  }

  @override
  String get cannotRemoveALogAfterDaySubmissionTo =>
      'Cannot remove a log after day submission to Jira has started.';

  @override
  String negativeTimeDifferenceSTheSystemClockMoved(String p0) {
    return 'Negative time difference ($p0 s): the system clock moved backwards. Check the log.';
  }

  @override
  String hM(String p0, String p1) {
    return '${p0}h ${p1}m';
  }

  @override
  String m(String p0) {
    return '${p0}m';
  }

  @override
  String get dayStartEnterATimeFromToFrom =>
      'Day start: enter a time from 00:00 to 23:59, from ≤ to.';

  @override
  String get dayDurationEnterAPositiveDurationUpTo =>
      'Day duration: enter a positive duration up to 24 hours, from ≤ to.';

  @override
  String get longBreakStartEnterATimeFromTo =>
      'Long break start: enter a time from 00:00 to 23:59, from ≤ to.';

  @override
  String get longBreakDurationEnterToDisableItOr =>
      'Long break duration: enter 0–0 to disable it or a positive duration, from ≤ to.';

  @override
  String shortBreaksEnterAnIntegerFromToFrom(String p0) {
    return 'Short breaks: enter an integer from 0 to $p0, from ≤ to.';
  }

  @override
  String get shortBreakDurationEnterAPositiveDurationFrom =>
      'Short break duration: enter a positive duration, from ≤ to.';

  @override
  String get scheduleSegment => 'Schedule segment';

  @override
  String get dayStart => 'Day start';

  @override
  String get dayEnd => 'Day end';

  @override
  String get couldNotSaveCredentialsInWindowsCredentialManager =>
      'Could not save credentials in Windows Credential Manager';

  @override
  String get selectAnIssueFromTheList => 'Select an issue from the list';

  @override
  String get selectedIssueWasNotFound => 'Selected issue was not found';

  @override
  String addedTo(String p0, String p1) {
    return 'Added $p0 to $p1';
  }

  @override
  String get addTime => 'Add time';

  @override
  String get close => 'Close';

  @override
  String get theEntryWillAppearInTheQueueNo =>
      'The entry will appear in the queue. No timer is needed.';

  @override
  String get issue => 'Issue';

  @override
  String get noIssuesAvailableAddAnIssueFirst =>
      'No issues available. Add an issue first.';

  @override
  String get quickIssues => 'QUICK ISSUES';

  @override
  String get recentIssues => 'RECENT ISSUES';

  @override
  String get hours => 'Hours';

  @override
  String get minutes => 'Minutes';

  @override
  String get workDone => 'Work done';

  @override
  String get optional => 'Optional';

  @override
  String get forExampleTheLoginFormAndErrorHandling =>
      'For example, the login form and error handling';

  @override
  String get setStartTime => 'Set start time';

  @override
  String newEntry(String p0) {
    return 'New entry · $p0';
  }

  @override
  String start(String p0) {
    return '· start $p0';
  }

  @override
  String get clearFixedStartTime => 'Clear fixed start time';

  @override
  String get cancel => 'Cancel';

  @override
  String get saveEntry => 'Save entry';

  @override
  String get dayTimeline => 'Day timeline';

  @override
  String get submissionResultNeedsChecking =>
      'Submission result needs checking';

  @override
  String get dayPartiallySubmitted => 'Day partially submitted';

  @override
  String get couldNotSubmitEntries => 'Could not submit entries';

  @override
  String sentFailedWithAnUnknownResultResubmissionOf(
    String p0,
    String p1,
    String p2,
  ) {
    return '$p0 sent, $p1 failed, $p2 with an unknown result. Resubmission of unknown entries is blocked.';
  }

  @override
  String sentNotSentFailedEntriesCanBeResubmitted(String p0, String p1) {
    return '$p0 sent, $p1 not sent. Failed entries can be resubmitted.';
  }

  @override
  String get loadingJiraEntries => 'Loading Jira entries...';

  @override
  String get jiraEntriesForTheSelectedDay =>
      'Jira entries for the selected day';

  @override
  String get noJiraEntriesForTheSelectedDay =>
      'No Jira entries for the selected day';

  @override
  String get buildAScheduleFromTheSelectedLogs =>
      'Build a schedule from the selected logs';

  @override
  String get allEntriesSubmitted => 'All entries submitted';

  @override
  String get submissionResult => 'Submission result';

  @override
  String draftSavedOnThisDevice(String p0) {
    return '$p0 · Draft saved on this device';
  }

  @override
  String get selectADate => 'Select a date';

  @override
  String get select => 'Select';

  @override
  String get moreScheduleActions => 'More schedule actions';

  @override
  String selectDate(String p0) {
    return 'Select date ($p0)';
  }

  @override
  String get previousDay => 'Previous day';

  @override
  String get nextDay => 'Next day';

  @override
  String get today => 'Today';

  @override
  String get refreshJiraEntries => 'Refresh Jira entries';

  @override
  String get rebuildDay => 'Rebuild day';

  @override
  String get submissionResults => 'Submission results';

  @override
  String get clear => 'Clear';

  @override
  String get smartRebuild => 'Smart rebuild';

  @override
  String get dayBoundaries => 'Day boundaries';

  @override
  String wholeDayIncludingBreaks(String p0) {
    return 'Whole day: $p0 including breaks';
  }

  @override
  String get sent => 'Sent';

  @override
  String get newTime => 'New time';

  @override
  String ofEntries(String p0, int p1) {
    String _temp0 = intl.Intl.pluralLogic(
      p1,
      locale: localeName,
      other: '$p1 entries',
      one: '$p1 entry',
    );
    return '$p0 of $_temp0';
  }

  @override
  String entriesInTheSchedule(String p0) {
    return '$p0 entries in the schedule';
  }

  @override
  String entriesToSubmit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '$count entry',
    );
    return '$_temp0 to submit';
  }

  @override
  String get alreadyInJira => 'Already in Jira';

  @override
  String get willNotBeSubmittedAgain => 'Will not be submitted again';

  @override
  String get breaks => 'Breaks';

  @override
  String get excludedFromWorkTime => 'Excluded from work time';

  @override
  String get rebuildIsUnavailableAfterSubmissionHasStartedResolve =>
      'Rebuild is unavailable after submission has started. Resolve all results first.';

  @override
  String get reconcileUnknownResultsBeforeResubmitting =>
      'Reconcile unknown results before resubmitting.';

  @override
  String get resubmissionAffectsOnlyEntriesThatHaveNotBeen =>
      'Resubmission affects only entries that have not been sent.';

  @override
  String get successfulEntriesAreNeverSubmittedAgain =>
      'Successful entries are never submitted again.';

  @override
  String get entriesForThisDay => 'Entries for this day';

  @override
  String get successfulEntriesAreNeverSubmittedAgain229 =>
      'Successful entries are never submitted again';

  @override
  String get pendingSubmission => 'Pending submission';

  @override
  String get sending => 'Sending...';

  @override
  String get notSent => 'Not sent';

  @override
  String get checkingTheResult => 'Checking the result';

  @override
  String get noDescription => '(no description)';

  @override
  String get actionsForAnUnknownResult => 'Actions for an unknown result';

  @override
  String get reconcileResultA => 'Reconcile result (A15)';

  @override
  String get resolveManuallyA => 'Resolve manually (A15)';

  @override
  String get couldNotLoadJiraEntries => 'Could not load Jira entries';

  @override
  String get noJiraEntriesForThisDay => 'No Jira entries for this day';

  @override
  String get buildADayFromYourLogs => 'Build a day from your logs';

  @override
  String get retryLoadingUsingTheDateMenu =>
      'Retry loading using the date menu.';

  @override
  String get selectEntriesAndTheDateOnTheWork =>
      'Select entries and the date on the Work tab.';

  @override
  String get selectLogs => 'Select logs';

  @override
  String get theScheduleNeedsChecking => 'The schedule needs checking';

  @override
  String submissionToJiraIsBlocked(String p0, String p1) {
    return '$p0 $p1 · submission to Jira is blocked';
  }

  @override
  String get scheduleErrors => 'Schedule errors';

  @override
  String get showErrors => 'Show errors';

  @override
  String get sources => 'Sources';

  @override
  String get logsToInclude => 'Logs to include';

  @override
  String get recordedTimeScheduledTime => 'Recorded time → scheduled time';

  @override
  String get selectLogsForTheDay => 'Select logs for the day';

  @override
  String get noSources => 'No sources';

  @override
  String get durationLockedClickToUnlock => 'Duration locked (click to unlock)';

  @override
  String get lockDurationWhenRebuilding => 'Lock duration when rebuilding';

  @override
  String get theQueueHasNoFreeStoppedLogsAdd =>
      'The queue has no free stopped logs. Add time on the Work tab.';

  @override
  String inTheDraftFor(String p0) {
    return 'In the draft for $p0';
  }

  @override
  String get durationLocked => 'Duration locked';

  @override
  String get lockDuration => 'Lock duration';

  @override
  String get noPlanBuiltForThisDayYet => 'No plan built for this day yet';

  @override
  String get selectLogsOnTheLeftAndClickBuild =>
      'Select logs on the left and click Build day';

  @override
  String get buildDay => 'Build day';

  @override
  String get schedule => 'Schedule';

  @override
  String get clickAnIntervalToEditIt => 'Click an interval to edit it';

  @override
  String get jiraEntriesAreReadOnly => 'Jira entries are read-only';

  @override
  String get dragToReorder => 'Drag to reorder';

  @override
  String get timePinned => 'Time pinned';

  @override
  String get alreadySubmittedToJira => 'Already submitted to Jira';

  @override
  String get editIntervalA => 'Edit interval (A13)';

  @override
  String get moreActions => 'More actions';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get unpinTime => 'Unpin time';

  @override
  String get pinTime => 'Pin time';

  @override
  String get unlock => 'Unlock';

  @override
  String get splitInterval => 'Split interval';

  @override
  String get mergeIntervals => 'Merge intervals';

  @override
  String get deleteInterval => 'Delete interval';

  @override
  String get break278 => 'Break';

  @override
  String get editInterval => 'Edit interval';

  @override
  String get alreadyInJiraReadOnly => 'Already in Jira (read-only)';

  @override
  String get pending => 'Pending';

  @override
  String get error => 'Error';

  @override
  String get unknown => 'Unknown';

  @override
  String get planReadyToSubmit => 'Plan ready to submit';

  @override
  String get theScheduleHasErrors => 'The schedule has errors';

  @override
  String entriesSent(String p0, int p1) {
    String _temp0 = intl.Intl.pluralLogic(
      p1,
      locale: localeName,
      other: '$p1 entries',
      one: '$p1 entry',
    );
    return '$p0 · $_temp0 sent';
  }

  @override
  String get checkTheUnknownResultInJiraFirst =>
      'Check the unknown result in Jira first';

  @override
  String entriesSomeSubmissionsFailed(String p0, int p1) {
    String _temp0 = intl.Intl.pluralLogic(
      p1,
      locale: localeName,
      other: '$p1 entries',
      one: '$p1 entry',
    );
    return '$p0 · $_temp0, some submissions failed';
  }

  @override
  String entriesWillBeAddedToJira(String p0, int p1) {
    String _temp0 = intl.Intl.pluralLogic(
      p1,
      locale: localeName,
      other: '$p1 entries',
      one: '$p1 entry',
    );
    return '$p0 · $_temp0 will be added to Jira';
  }

  @override
  String get backToWork => 'Back to work';

  @override
  String get checkInJira => 'Check in Jira';

  @override
  String get retrySubmission => 'Retry submission';

  @override
  String get submitToJira => 'Submit to Jira';

  @override
  String get monday => 'Monday';

  @override
  String get tuesday => 'Tuesday';

  @override
  String get wednesday => 'Wednesday';

  @override
  String get thursday => 'Thursday';

  @override
  String get friday => 'Friday';

  @override
  String get saturday => 'Saturday';

  @override
  String get sunday => 'Sunday';

  @override
  String get january => 'January';

  @override
  String get february => 'February';

  @override
  String get march => 'March';

  @override
  String get april => 'April';

  @override
  String get may => 'May';

  @override
  String get june => 'June';

  @override
  String get july => 'July';

  @override
  String get august => 'August';

  @override
  String get september => 'September';

  @override
  String get october => 'October';

  @override
  String get november => 'November';

  @override
  String get december => 'December';

  @override
  String get smartRebuildTheDay => 'Smart rebuild the day?';

  @override
  String get theCurrentDraftWillBeReplacedAndManual =>
      'The current draft will be replaced and manual time edits will be lost. The schedule will be optimised with breaks and split long tasks.';

  @override
  String get rebuild => 'Rebuild';

  @override
  String get clearTheDay => 'Clear the day?';

  @override
  String get allDraftIntervalsAndBreaksWillBeRemoved =>
      'All draft intervals and breaks will be removed. Source logs will return to the queue. Jira entries will remain on screen.';

  @override
  String get rebuildTheDay => 'Rebuild the day?';

  @override
  String get theScheduleWillBeRebuiltWithOrderAnd =>
      'The schedule will be rebuilt with order and pinned intervals preserved. Manual time edits will be replaced.';

  @override
  String get dayRebuiltWithOrderAndPinnedIntervalsPreserved =>
      'Day rebuilt with order and pinned intervals preserved.';

  @override
  String get breakCollapsedAndTasksMovedTogether =>
      'Break collapsed and tasks moved together.';

  @override
  String get previousTaskExtendedToFillTheBreak =>
      'Previous task extended to fill the break.';

  @override
  String get breakDurationUpdated => 'Break duration updated.';

  @override
  String get deleteInterval324 => 'Delete interval?';

  @override
  String get theIntervalWillBeRemovedFromTheSchedule =>
      'The interval will be removed from the schedule. If it is the last interval for its source in this day, the source log will return to the queue.';

  @override
  String get delete => 'Delete';

  @override
  String successfullySubmittedEntriesToJira(int p0) {
    String _temp0 = intl.Intl.pluralLogic(
      p0,
      locale: localeName,
      other: '$p0 entries',
      one: '$p0 entry',
    );
    return 'Successfully submitted $_temp0 to Jira!';
  }

  @override
  String sentFailedUnknown(String p0, String p1, String p2) {
    return 'Sent: $p0, Failed: $p1, Unknown: $p2';
  }

  @override
  String get resolveUnknownStatusA => 'Resolve unknown status (A15)';

  @override
  String get theSegmentHasAnUnknownResultTheJira =>
      'The segment has an unknown result (the Jira response was lost or interrupted). Blind retry is prohibited.';

  @override
  String get optionEnterTheIdOfTheCreatedJira =>
      'Option 1: Enter the ID of the created Jira entry';

  @override
  String get theApplicationWillCheckTheEntrySAuthor =>
      'The application will check the entry\'s author, date and duration before confirming:';

  @override
  String get worklogIdForExample => 'Worklog ID (for example: 10042)';

  @override
  String get entrySuccessfullyConfirmedAndLinked =>
      'Entry successfully confirmed and linked!';

  @override
  String get linkingError => 'Linking error';

  @override
  String get link => 'Link';

  @override
  String get optionConfirmThatTheEntryDoesNotExist =>
      'Option 2: Confirm that the entry does not exist';

  @override
  String get ifYouHaveOpenedJiraInABrowser =>
      'If you have opened Jira in a browser and verified that the issue does not contain this entry, you can reset the interval to Pending for resubmission.';

  @override
  String get noEntryInJiraAllowRetry => 'No entry in Jira, allow retry';

  @override
  String get intervalResetToPendingForResubmission =>
      'Interval reset to Pending for resubmission.';

  @override
  String get editTimeEntry => 'Edit time entry';

  @override
  String get workDoneDescription => 'Work done (description)';

  @override
  String get briefDescriptionOfTheWork => 'Brief description of the work...';

  @override
  String get fixedStart => 'Fixed start';

  @override
  String get save => 'Save';

  @override
  String get selectStartTime => 'Select start time';

  @override
  String get done => 'Done';

  @override
  String get editInterval348 => 'Edit interval';

  @override
  String get start349 => 'Start';

  @override
  String get duration => 'Duration';

  @override
  String end(String p0) {
    return 'End: $p0';
  }

  @override
  String get workDoneDuringThisInterval => 'Work done during this interval...';

  @override
  String get breakDurationMustBeGreaterThanMinutes =>
      'Break duration must be greater than 0 minutes.';

  @override
  String break354(String p0) {
    return 'Break ($p0)';
  }

  @override
  String get quickActions => 'Quick actions:';

  @override
  String get collapseBreak => 'Collapse break';

  @override
  String get moveFollowingTasksTogetherRemoveTheGap =>
      'Move following tasks together (remove the gap)';

  @override
  String get extendPreviousTask => 'Extend previous task';

  @override
  String extendTaskBy(String p0) {
    return 'Extend task by $p0';
  }

  @override
  String get thePreviousEntryIsFixedInJira =>
      'The previous entry is fixed in Jira';

  @override
  String get thisIsTheStartOfTheDayNo =>
      'This is the start of the day (no previous task)';

  @override
  String get setBreakDuration => 'Set break duration:';

  @override
  String get followingTasksWillShiftTogetherPreservingTheirDurations =>
      'Following tasks will shift together, preserving their durations.';

  @override
  String min(String p0) {
    return '$p0 min';
  }

  @override
  String get apply => 'Apply';

  @override
  String logsSuccessfullyMergedTotalDuration(String p0) {
    return 'Logs successfully merged. Total duration: $p0';
  }

  @override
  String get mergeWithAnotherLog => 'Merge with another log';

  @override
  String currentLog(String p0) {
    return 'Current log: $p0';
  }

  @override
  String duration369(String p0) {
    return 'Duration: $p0';
  }

  @override
  String get selectALogToMerge => 'Select a log to merge:';

  @override
  String get noFreeLogsAvailableToMerge => 'No free logs available to merge.';

  @override
  String get theLogsBelongToDifferentIssuesSelectThe =>
      'The logs belong to different issues. Select the issue for the result:';

  @override
  String get merge => 'Merge';

  @override
  String get intervalsSuccessfullyMerged => 'Intervals successfully merged.';

  @override
  String currentInterval(String p0, String p1) {
    return 'Current interval: $p0 ($p1)';
  }

  @override
  String duration376(String p0) {
    return 'Duration: $p0';
  }

  @override
  String get selectAnIntervalToMerge => 'Select an interval to merge:';

  @override
  String get noOtherIntervalsAvailableToMerge =>
      'No other intervals available to merge.';

  @override
  String get enterAJiraIssueKeyIdOrLink => 'Enter a Jira issue key, ID or link';

  @override
  String get editQuickIssue => 'Edit quick issue';

  @override
  String get addQuickIssue => 'Add quick issue';

  @override
  String get findAnExistingIssueInTheConnectedJira =>
      'Find an existing issue in the connected Jira.';

  @override
  String get keyIdOrLink => 'Key, ID or link';

  @override
  String get forExampleProj => 'for example, PROJ-123';

  @override
  String get find => 'Find';

  @override
  String get note => 'Note';

  @override
  String get optionalWhenToUseThisIssue => 'Optional: when to use this issue';

  @override
  String get theNoteIsLocalAndIsNotSubmitted =>
      'The note is local and is not submitted to Jira.';

  @override
  String get add => 'Add';

  @override
  String m390(String p0) {
    return '$p0 m';
  }

  @override
  String h(String p0) {
    return '$p0 h';
  }

  @override
  String hM392(String p0, String p1) {
    return '$p0 h $p1 m';
  }

  @override
  String get enterTimeInHhMmFormat => 'Enter time in HH:MM format.';

  @override
  String get enterADurationForExampleHM =>
      'Enter a duration, for example 7 h 30 m.';

  @override
  String get enterADurationForExampleH => 'Enter a duration, for example 8 h.';

  @override
  String get enterADurationForExampleM => 'Enter a duration, for example 30 m.';

  @override
  String get enterADurationForExampleM398 =>
      'Enter a duration, for example 45 m.';

  @override
  String get enterAnIntegerFrom => 'Enter an integer from 0.';

  @override
  String get enterADurationForExampleM400 =>
      'Enter a duration, for example 5 m.';

  @override
  String get enterADurationForExampleM401 =>
      'Enter a duration, for example 10 m.';

  @override
  String get dayBuildSettingsSaved => 'Day build settings saved.';

  @override
  String couldNotSaveSettings(String p0) {
    return 'Could not save settings: $p0';
  }

  @override
  String connectionError(String p0) {
    return 'Connection error: $p0';
  }

  @override
  String get jiraConnectionSuccessfullySaved =>
      'Jira connection successfully saved';

  @override
  String get quickIssues406 => 'Quick issues';

  @override
  String get savedIssuesForQuicklyAddingTime =>
      'Saved issues for quickly adding time.';

  @override
  String get addIssue => 'Add issue';

  @override
  String get connectJiraFirst => 'Connect Jira first';

  @override
  String get quickIssuesAreStoredSeparatelyForEachSite =>
      'Quick issues are stored separately for each site and account.';

  @override
  String get goToConnection => 'Go to connection';

  @override
  String get inReadOnlyModeYouCanViewThe =>
      'In read-only mode you can view the list but cannot change it.';

  @override
  String get noQuickIssuesYet => 'No quick issues yet';

  @override
  String get addAFrequentlyUsedJiraIssueToShow =>
      'Add a frequently used Jira issue to show it here and on the Work screen.';

  @override
  String get jiraConnection => 'Jira connection';

  @override
  String get dayBuild => 'Day build';

  @override
  String get localApi => 'Local API';

  @override
  String get settings418 => 'Settings';

  @override
  String get jiraConnectionDayBuildQuickIssuesAndLocal =>
      'Jira connection, day build, quick issues and local API.';

  @override
  String get theme => 'Theme';

  @override
  String get systemDefault422 => 'System default';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String couldNotSaveTheTheme(String p0) {
    return 'Could not save the theme: $p0';
  }

  @override
  String get theThemeCannotBeChangedInReadOnly =>
      'The theme cannot be changed in read-only mode.';

  @override
  String get smartRebuildChoosesValuesWithinTheseRanges =>
      'Smart rebuild chooses values within these ranges.';

  @override
  String get parameter => 'PARAMETER';

  @override
  String get from => 'FROM';

  @override
  String get to => 'TO';

  @override
  String get dayDuration => 'Day duration';

  @override
  String get longBreakStart => 'Long break start';

  @override
  String get longBreakDuration => 'Long break duration';

  @override
  String get shortBreaksPerDay => 'Short breaks per day';

  @override
  String get shortBreakDuration => 'Short break duration';

  @override
  String get minimumWorkIntervalMinutes => 'Minimum work interval: 15 minutes.';

  @override
  String get agentDayBuildRule => 'Agent day build rule';

  @override
  String get theAgentReceivesThisTextTogetherWithThe =>
      'The agent receives this text together with the ranges via the local API. The built-in builder uses only the ranges.';

  @override
  String get describeHowTheAgentShouldUseTheDay =>
      'Describe how the agent should use the day build settings';

  @override
  String get couldNot => 'Could not';

  @override
  String get settingsCannotBeChangedInReadOnlyMode =>
      'Settings cannot be changed in read-only mode.';

  @override
  String get reset => 'Reset';

  @override
  String get saveSettings => 'Save settings';

  @override
  String get usedToLoadIssuesAndSubmitTime =>
      'Used to load issues and submit time.';

  @override
  String get jiraAddress => 'Jira address';

  @override
  String get apiToken => 'API token';

  @override
  String get showToken => 'Show token';

  @override
  String get hideToken => 'Hide token';

  @override
  String accountIdRoute(String p0, String p1) {
    return 'Account ID: $p0\nRoute: $p1';
  }

  @override
  String connected(String p0, String p1) {
    return 'Connected · $p0\n$p1';
  }

  @override
  String get checkConnection => 'Check connection';

  @override
  String get localApiForAiAgents => 'Local API for AI agents';

  @override
  String get theBuiltInHttpServerAllowsAiAgents =>
      'The built-in HTTP server allows AI agents to log time and provide a complete day schedule.';

  @override
  String get localServerAddress => 'Local server address';

  @override
  String get copyAddress => 'Copy address';

  @override
  String get serverAddressCopiedToClipboard =>
      'Server address copied to clipboard';

  @override
  String get agentSkillInstructions => 'Agent skill instructions';

  @override
  String get copyInstructions => 'Copy instructions';

  @override
  String get agentInstructionsCopiedToClipboard =>
      'Agent instructions copied to clipboard';

  @override
  String get editNote => 'Edit note';

  @override
  String get actions => 'Actions';

  @override
  String couldNotDeleteTheQuickIssue(String p0) {
    return 'Could not delete the quick issue: $p0';
  }

  @override
  String get removeFromQuickIssues => 'Remove from quick issues';

  @override
  String get jiraConnected => 'Jira connected';

  @override
  String get readOnlyModeAnotherApplicationInstanceHoldsThe =>
      'Read-only mode: another application instance holds the write lock (A19).';

  @override
  String theFirstPartMustBeGreaterThanAnd466(String p0) {
    return 'The first part must be greater than 0 and less than $p0';
  }

  @override
  String logSplitIntoTwoPartsAnd(String p0, String p1) {
    return 'Log split into two parts: $p0 and $p1';
  }

  @override
  String get splitTimeEntry => 'Split time entry';

  @override
  String totalTime(String p0) {
    return 'Total time: $p0';
  }

  @override
  String get part => 'Part 1';

  @override
  String get h471 => 'h';

  @override
  String get m472 => 'm';

  @override
  String get partDescription => 'Part 1 description';

  @override
  String get partRemainder => 'Part 2 (remainder)';

  @override
  String get min475 => '0 min';

  @override
  String get partDescription476 => 'Part 2 description';

  @override
  String get split => 'Split';

  @override
  String theFirstPartMustBeGreaterThanAnd478(String p0) {
    return 'The first part must be greater than 0 and less than $p0';
  }

  @override
  String intervalSplitAnd(String p0, String p1) {
    return 'Interval split: $p0 and $p1';
  }

  @override
  String issue480(String p0) {
    return 'Issue: $p0';
  }

  @override
  String totalDuration(String p0) {
    return 'Total duration: $p0';
  }

  @override
  String get firstPartDescription => 'First part description';

  @override
  String get workDoneInTheFirstPart => 'Work done in the first part...';

  @override
  String get secondPartDescription => 'Second part description';

  @override
  String get workDoneInTheSecondPart => 'Work done in the second part...';

  @override
  String h486(String p0) {
    return '$p0 h';
  }

  @override
  String hMin(String p0, String p1) {
    return '$p0 h $p1 min';
  }

  @override
  String break488(String p0, String p1, String p2) {
    return 'Break · $p0–$p1 ($p2)';
  }

  @override
  String alreadyInJira489(String p0, String p1, String p2) {
    return '$p0 · already in Jira · $p1–$p2';
  }

  @override
  String get selectedLogs => 'Selected logs';

  @override
  String issueAdded(String p0, String p1) {
    return 'Issue added: $p0 — $p1';
  }

  @override
  String get couldNotAddTheIssue => 'Could not add the issue';

  @override
  String get work493 => 'Work';

  @override
  String get pasteAJiraIssueIdOrLink => 'Paste a Jira issue ID or link';

  @override
  String get frequentlyUsedIssuesHaveNotBeenConfiguredYet =>
      'Frequently used issues have not been configured yet.';

  @override
  String get configureQuickIssues => 'Configure quick issues';

  @override
  String get recentIssues497 => 'Recent issues';

  @override
  String start498(String p0) {
    return 'Start ($p0)';
  }

  @override
  String get selectMultiple => 'Select multiple';

  @override
  String get searchIssues => 'Search issues';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get activityFilter => 'Activity filter';

  @override
  String get lastDays => 'Last 7 days';

  @override
  String get lastDays504 => 'Last 30 days';

  @override
  String get allTime => 'All time';

  @override
  String get noIssuesAddedEnterAKeyIdOr =>
      'No issues added.\nEnter a key, ID or link above.';

  @override
  String get noIssuesMatchTheFilter => 'No issues match the filter.';

  @override
  String activity(String p0) {
    return 'Activity: $p0';
  }

  @override
  String get stop => 'Stop';

  @override
  String get start510 => 'Start';

  @override
  String get queue => 'Queue';

  @override
  String get history => 'History';

  @override
  String total(String p0) {
    return 'Total $p0';
  }

  @override
  String get pauseAllTimers => 'Pause all timers';

  @override
  String get theLogQueueIsEmpty => 'The log queue is empty';

  @override
  String get startAnIssueTimerOrAddTimeManually =>
      'Start an issue timer or add time manually.';

  @override
  String removeLogFromDraftFor(String p0) {
    return 'Remove log from draft for $p0';
  }

  @override
  String get dayContentsCannotBeChangedAfterSubmissionHas =>
      'Day contents cannot be changed after submission has started';

  @override
  String entryIsAlreadyIncludedInTheDayFor(String p0) {
    return 'Entry is already included in the day for $p0';
  }

  @override
  String get selectForDayBuild => 'Select for day build';

  @override
  String get pauseTheTimerBeforeSelectingItForDay =>
      'Pause the timer before selecting it for day build';

  @override
  String get pauseTimer => 'Pause timer';

  @override
  String get stopTheTimerToAddThisEntryTo =>
      'Stop the timer to add this entry to a day.';

  @override
  String get systemClockMovedBackwards => 'System clock moved backwards!';

  @override
  String created(String p0) {
    return 'Created: $p0';
  }

  @override
  String inDayOpen(String p0) {
    return 'In day $p0 · Open';
  }

  @override
  String get actionsForAnEntryInAnotherDay =>
      'Actions for an entry in another day';

  @override
  String removeFromDay(String p0) {
    return 'Remove from day $p0';
  }

  @override
  String get logActions => 'Log actions';

  @override
  String get edit => 'Edit';

  @override
  String get mergeWith => 'Merge with…';

  @override
  String get noSubmittedLogsInHistoryYet => 'No submitted logs in history yet.';

  @override
  String get submissionHistoryIsStoredOnThisDevice =>
      'Submission history is stored on this device';

  @override
  String noEntriesSelectedFor(String p0) {
    return 'No entries selected for $p0';
  }

  @override
  String selected(String p0, String p1) {
    return 'Selected $p0 $p1';
  }

  @override
  String get recordedTime => ' recorded time';

  @override
  String get buildFor => 'Build for';

  @override
  String get dayBuildDate => 'Day build date';

  @override
  String get monday539 => 'Monday';

  @override
  String get tuesday540 => 'Tuesday';

  @override
  String get wednesday541 => 'Wednesday';

  @override
  String get thursday542 => 'Thursday';

  @override
  String get friday543 => 'Friday';

  @override
  String get saturday544 => 'Saturday';

  @override
  String get sunday545 => 'Sunday';

  @override
  String get entries => 'entries';

  @override
  String get entry => 'entry';

  @override
  String get entries548 => 'entries';

  @override
  String get deleteTimeEntry => 'Delete time entry?';

  @override
  String entryWillBePermanentlyDeleted(String p0, String p1) {
    return 'Entry \"$p0\" ($p1) will be permanently deleted.';
  }

  @override
  String entrySuccessfullyFoundAndConfirmedInJiraId(String p0) {
    return 'Entry successfully found and confirmed in Jira (ID: $p0).';
  }

  @override
  String get theJiraTimeTrackerSegmentPropertyWasNot =>
      'The jira-time-tracker.segment property was not found among the issue\'s Jira entries. Blind resubmission is prohibited.';

  @override
  String connectionMismatchTheDraftBelongsToSiteAccount(String p0, String p1) {
    return 'Connection mismatch: the draft belongs to site/account \"$p0\" but the current connection is \"$p1\". Submission is blocked.';
  }

  @override
  String get theDraftIsEmptyThereAreNoIntervals =>
      'The draft is empty, there are no intervals to submit.';

  @override
  String get jiraRejectedTheRequest => 'Jira rejected the request';

  @override
  String get unknownSubmissionResultTheConnectionMayHaveBeen =>
      'Unknown submission result (the connection may have been lost)';

  @override
  String conflictMultipleEntriesFoundWithSegmentIdManual(String p0, String p1) {
    return 'Conflict: multiple ($p0) entries found with segment id \"$p1\". Manual checking is required.';
  }

  @override
  String conflictAnEntryWithTheSameSegmentId(String p0, String p1, String p2) {
    return 'Conflict: an entry with the same segment id was found, but its parameters differ (author: $p0, duration: $p1, time: $p2).';
  }

  @override
  String networkErrorDuringReconciliation(String p0) {
    return 'Network error during reconciliation: $p0';
  }

  @override
  String entryWithIdWasNotFoundInIssue(String p0, String p1) {
    return 'Entry with ID \"$p0\" was not found in issue \"$p1\".';
  }

  @override
  String theEntryBelongsToAnotherJiraUserAccountid(String p0) {
    return 'The entry belongs to another Jira user (accountId: $p0).';
  }

  @override
  String jiraEntryDurationSDoesNotMatchThe(String p0, String p1) {
    return 'Jira entry duration ($p0 s) does not match the segment ($p1 s).';
  }

  @override
  String errorCheckingTheJiraEntry(String p0) {
    return 'Error checking the Jira entry: $p0';
  }

  @override
  String get resetByUserConfirmedTheEntryDoesNot =>
      'Reset by user: confirmed the entry does not exist in Jira; retry is allowed';

  @override
  String get breakLabel => 'Break';

  @override
  String get submissionInterruptedAtStartup =>
      'Interrupted before confirmation (recovered at startup)';

  @override
  String get directApi => 'Direct API';

  @override
  String retryAfterSeconds(String seconds) {
    return '. Retry after $seconds s.';
  }

  @override
  String get mismatch => 'does not match';

  @override
  String scheduleEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '$count entry',
    );
    return '$_temp0 in the schedule';
  }

  @override
  String scheduleErrorCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count errors',
      one: '$count error',
    );
    return '$_temp0 · submission to Jira is blocked';
  }

  @override
  String get readOnlyLanguage =>
      'The language cannot be changed in read-only mode.';

  @override
  String selectedLogCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '$count entry',
    );
    return 'Selected $_temp0';
  }
}
