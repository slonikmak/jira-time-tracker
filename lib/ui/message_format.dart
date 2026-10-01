import 'package:flutter/material.dart';
import '../app_message.dart';
import '../l10n/app_localizations.dart';

String formatCalendarDate(String? isoDate) {
  final date = isoDate == null ? null : DateTime.tryParse(isoDate);
  if (date == null) return isoDate ?? '';
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year.toString().padLeft(4, '0')}';
}

String formatHoursMinutes(BuildContext context, int totalSeconds) {
  final seconds = totalSeconds < 0 ? 0 : totalSeconds;
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final l = AppLocalizations.of(context);
  return hours > 0
      ? l.hM(hours.toString(), minutes.toString().padLeft(2, '0'))
      : l.m(minutes.toString());
}

String renderMessage(BuildContext context, Object? value) {
  if (value is MessageException) {
    return renderMessage(context, value.messageText);
  }
  if (value is ArgumentError) return renderMessage(context, value.message);
  if (value is! AppMessage) return value?.toString() ?? '';
  final message = value;
  if (message.id == 'calendarDate') {
    return formatCalendarDate(message.arguments.first as String?);
  }
  if (message.id == 'duration') {
    return formatHoursMinutes(
      context,
      int.parse(message.arguments.first.toString()),
    );
  }
  if (message.id == 'joinedMessages') {
    return message.arguments
        .skip(1)
        .map((part) => renderMessage(context, part))
        .join(message.arguments.first.toString());
  }
  final l = AppLocalizations.of(context);
  return switch (message.id) {
    'aDurationLockedLogIsShorterThanThe' =>
      l.aDurationLockedLogIsShorterThanThe,
    'aRunningLogCannotBeIncludedInA' => l.aRunningLogCannotBeIncludedInA,
    'accessDeniedForbidden' => l.accessDeniedForbidden,
    'accessToTheJiraIssueIsDeniedForbidden' =>
      l.accessToTheJiraIssueIsDeniedForbidden,
    'all' => l.all,
    'allEntriesWereSuccessfullySubmittedToJira' =>
      l.allEntriesWereSuccessfullySubmittedToJira(
        renderMessage(context, message.arguments[0]),
      ),
    'allLogsAreLockedHMinButThe' => l.allLogsAreLockedHMinButThe(
      renderMessage(context, message.arguments[0]),
      renderMessage(context, message.arguments[1]),
      renderMessage(context, message.arguments[2]),
      renderMessage(context, message.arguments[3]),
    ),
    'atLeastTwoLogsAreRequiredToMerge' => l.atLeastTwoLogsAreRequiredToMerge,
    'atlassianAccountEmailIsMissing' => l.atlassianAccountEmailIsMissing,
    'atlassianApiTokenIsMissing' => l.atlassianApiTokenIsMissing,
    'attachmentWasNotFoundInTheSpecifiedJira' =>
      l.attachmentWasNotFoundInTheSpecifiedJira,
    'break' => l.breakLabel,
    'breakDurationMustBeGreaterThanMinutes' =>
      l.breakDurationMustBeGreaterThanMinutes,
    'breakFallsOutsideTheWorkDay' => l.breakFallsOutsideTheWorkDay(
      renderMessage(context, message.arguments[0]),
    ),
    'breakHasANonPositiveDuration' => l.breakHasANonPositiveDuration(
      renderMessage(context, message.arguments[0]),
    ),
    'breaksMustHaveAWorkIntervalBetweenThem' =>
      l.breaksMustHaveAWorkIntervalBetweenThem,
    'candidate' => l.candidate,
    'cannotChangeTheBoundaryThereIsAJira' =>
      l.cannotChangeTheBoundaryThereIsAJira(
        renderMessage(context, message.arguments[0]),
      ),
    'cannotChangeTheBoundaryThereIsAJira76' =>
      l.cannotChangeTheBoundaryThereIsAJira76(
        renderMessage(context, message.arguments[0]),
      ),
    'cannotClearADayAfterSubmissionHasStarted' =>
      l.cannotClearADayAfterSubmissionHasStarted,
    'cannotDeleteALogAlreadyIncludedInThe' =>
      l.cannotDeleteALogAlreadyIncludedInThe(
        renderMessage(context, message.arguments[0]),
      ),
    'cannotDeleteARunningLogPauseItFirst' =>
      l.cannotDeleteARunningLogPauseItFirst,
    'cannotEditALogAlreadyIncludedInThe' =>
      l.cannotEditALogAlreadyIncludedInThe(
        renderMessage(context, message.arguments[0]),
      ),
    'cannotEditALogThatHasAlreadyBeen' => l.cannotEditALogThatHasAlreadyBeen,
    'cannotEditARunningLogPauseItFirst' => l.cannotEditARunningLogPauseItFirst,
    'cannotFitWorkIntervalsOfAtLeastMinutes' =>
      l.cannotFitWorkIntervalsOfAtLeastMinutes,
    'cannotMergeLogsAlreadyIncludedInADay' =>
      l.cannotMergeLogsAlreadyIncludedInADay,
    'cannotMergeRunningLogs' => l.cannotMergeRunningLogs,
    'cannotPlaceTheLongBreakWithinTheStart' =>
      l.cannotPlaceTheLongBreakWithinTheStart,
    'cannotPlaceTheLongBreakWithinTheStart120' =>
      l.cannotPlaceTheLongBreakWithinTheStart120,
    'cannotPlaceTheRequiredNumberOfShortBreaks' =>
      l.cannotPlaceTheRequiredNumberOfShortBreaks,
    'cannotPlaceTheRequiredNumberOfShortBreaks122' =>
      l.cannotPlaceTheRequiredNumberOfShortBreaks122,
    'cannotRebuildADayAfterSubmissionHasStarted' =>
      l.cannotRebuildADayAfterSubmissionHasStarted,
    'cannotRebuildAPartiallyOrFullySubmittedDay' =>
      l.cannotRebuildAPartiallyOrFullySubmittedDay,
    'cannotRemoveALogAfterDaySubmissionTo' =>
      l.cannotRemoveALogAfterDaySubmissionTo,
    'cannotReplaceTheDraftAfterDaySubmissionHas' =>
      l.cannotReplaceTheDraftAfterDaySubmissionHas,
    'cannotSplitALogAlreadyIncludedInA' => l.cannotSplitALogAlreadyIncludedInA,
    'cannotSplitALogThatHasAlreadyBeen' => l.cannotSplitALogThatHasAlreadyBeen,
    'cannotSplitARunningLogStopItFirst' => l.cannotSplitARunningLogStopItFirst,
    'conflictAnEntryWithTheSameSegmentId' =>
      l.conflictAnEntryWithTheSameSegmentId(
        renderMessage(context, message.arguments[0]),
        renderMessage(context, message.arguments[1]),
        renderMessage(context, message.arguments[2]),
      ),
    'conflictExistingJiraEntriesOverlapEachOther' =>
      l.conflictExistingJiraEntriesOverlapEachOther,
    'conflictMultipleEntriesFoundWithSegmentIdManual' =>
      l.conflictMultipleEntriesFoundWithSegmentIdManual(
        renderMessage(context, message.arguments[0]),
        renderMessage(context, message.arguments[1]),
      ),
    'conflictPinnedTaskOverlapsExistingJiraEntry' =>
      l.conflictPinnedTaskOverlapsExistingJiraEntry(
        renderMessage(context, message.arguments[0]),
        renderMessage(context, message.arguments[1]),
      ),
    'conflictPinnedTaskOverlapsTask' => l.conflictPinnedTaskOverlapsTask(
      renderMessage(context, message.arguments[0]),
      renderMessage(context, message.arguments[1]),
    ),
    'connectionError' => l.connectionError(
      renderMessage(context, message.arguments[0]),
    ),
    'connectionLostOrTimedOut' => l.connectionLostOrTimedOut(
      renderMessage(context, message.arguments[0]),
    ),
    'connectionMismatchTheDraftBelongsToSiteAccount' =>
      l.connectionMismatchTheDraftBelongsToSiteAccount(
        renderMessage(context, message.arguments[0]),
        renderMessage(context, message.arguments[1]),
      ),
    'couldNotConnectViaEitherTheDirectOr' =>
      l.couldNotConnectViaEitherTheDirectOr(
        renderMessage(context, message.arguments[0]),
      ),
    'couldNotGetTheJiraSiteSCloudid' => l.couldNotGetTheJiraSiteSCloudid(
      renderMessage(context, message.arguments[0]),
    ),
    'couldNotSaveCredentialsInWindowsCredentialManager' =>
      l.couldNotSaveCredentialsInWindowsCredentialManager,
    'couldNotSaveSettings' => l.couldNotSaveSettings(
      renderMessage(context, message.arguments[0]),
    ),
    'dayBuildSettingsSaved' => l.dayBuildSettingsSaved,
    'dayDurationEnterAPositiveDurationUpTo' =>
      l.dayDurationEnterAPositiveDurationUpTo,
    'dayEnd' => l.dayEnd,
    'dayStart' => l.dayStart,
    'dayStartEnterATimeFromToFrom' => l.dayStartEnterATimeFromToFrom,
    'daySuccessfullyBuilt' => l.daySuccessfullyBuilt,
    'daySuccessfullyRebuiltSmartRebuild' =>
      l.daySuccessfullyRebuiltSmartRebuild,
    'daySuccessfullyRebuiltWithTheOrderPreserved' =>
      l.daySuccessfullyRebuiltWithTheOrderPreserved,
    'days' => l.days,
    'days9' => l.days9,
    'durationMustBeGreaterThanMinutes' => l.durationMustBeGreaterThanMinutes,
    'durationMustBeGreaterThanZero' => l.durationMustBeGreaterThanZero,
    'endTimeMustBeAfterStartTime' => l.endTimeMustBeAfterStartTime,
    'enterADurationForExampleH' => l.enterADurationForExampleH,
    'enterADurationForExampleHM' => l.enterADurationForExampleHM,
    'enterADurationForExampleM' => l.enterADurationForExampleM,
    'enterADurationForExampleM398' => l.enterADurationForExampleM398,
    'enterADurationForExampleM400' => l.enterADurationForExampleM400,
    'enterADurationForExampleM401' => l.enterADurationForExampleM401,
    'enterAJiraIssueKeyIdOrLink' => l.enterAJiraIssueKeyIdOrLink,
    'enterAnIntegerFrom' => l.enterAnIntegerFrom,
    'enterTimeInHhMmFormat' => l.enterTimeInHhMmFormat,
    'entrySuccessfullyFoundAndConfirmedInJiraId' =>
      l.entrySuccessfullyFoundAndConfirmedInJiraId(
        renderMessage(context, message.arguments[0]),
      ),
    'entryWithIdWasNotFoundInIssue' => l.entryWithIdWasNotFoundInIssue(
      renderMessage(context, message.arguments[0]),
      renderMessage(context, message.arguments[1]),
    ),
    'errorCheckingTheJiraEntry' => l.errorCheckingTheJiraEntry(
      renderMessage(context, message.arguments[0]),
    ),
    'errorCheckingTheScopedRoute' => l.errorCheckingTheScopedRoute(
      renderMessage(context, message.arguments[0]),
    ),
    'errorLinkingTheWorklog' => l.errorLinkingTheWorklog,
    'errorLoadingIssue' => l.errorLoadingIssue(
      renderMessage(context, message.arguments[0]),
      renderMessage(context, message.arguments[1]),
      renderMessage(context, message.arguments[2]),
    ),
    'errorLoadingJiraAttachmentCode' => l.errorLoadingJiraAttachmentCode(
      renderMessage(context, message.arguments[0]),
    ),
    'errorLoadingJiraDataCode' => l.errorLoadingJiraDataCode(
      renderMessage(context, message.arguments[0]),
    ),
    'errorLoadingJiraEntries37' => l.errorLoadingJiraEntries37(
      renderMessage(context, message.arguments[0]),
    ),
    'errorLoadingWorklogsForIssueCode' => l.errorLoadingWorklogsForIssueCode(
      renderMessage(context, message.arguments[0]),
      renderMessage(context, message.arguments[1]),
    ),
    'errorSearchingJiraForIssuesWithWorklogsCode' =>
      l.errorSearchingJiraForIssuesWithWorklogsCode(
        renderMessage(context, message.arguments[0]),
      ),
    'errorSubmittingToJira' => l.errorSubmittingToJira(
      renderMessage(context, message.arguments[0]),
    ),
    'existingEntriesBreaksAndPinnedTasksHaveExhausted' =>
      l.existingEntriesBreaksAndPinnedTasksHaveExhausted,
    'existingEntryFallsOutsideTheWorkDay' =>
      l.existingEntryFallsOutsideTheWorkDay(
        renderMessage(context, message.arguments[0]),
      ),
    'existingEntryHasANonPositiveDuration' =>
      l.existingEntryHasANonPositiveDuration(
        renderMessage(context, message.arguments[0]),
      ),
    'existingJiraEntriesAlreadyOccupyOrMoreHours' =>
      l.existingJiraEntriesAlreadyOccupyOrMoreHours(
        renderMessage(context, message.arguments[0]),
      ),
    'existingJiraEntriesOrPinnedTasksFallOutside' =>
      l.existingJiraEntriesOrPinnedTasksFallOutside,
    'existingWorklog' => l.existingWorklog,
    'expectedAJiraIssueKeyAndANumeric' => l.expectedAJiraIssueKeyAndANumeric,
    'expectedAJiraIssueKeyOrNumericId' => l.expectedAJiraIssueKeyOrNumericId,
    'firstCheckAndSaveTheJiraConnectionIn' =>
      l.firstCheckAndSaveTheJiraConnectionIn,
    'firstConnectJiraInSettings' => l.firstConnectJiraInSettings,
    'invalidEmailOrApiTokenUnauthorized' =>
      l.invalidEmailOrApiTokenUnauthorized,
    'invalidInputEnterAKeyProjNumericId' =>
      l.invalidInputEnterAKeyProjNumericId,
    'invalidJsonInJiraSResponse' => l.invalidJsonInJiraSResponse(
      renderMessage(context, message.arguments[0]),
    ),
    'issueDoesNotMatchSource' => l.issueDoesNotMatchSource(
      renderMessage(context, message.arguments[0]),
      renderMessage(context, message.arguments[1]),
      renderMessage(context, message.arguments[2]),
    ),
    'issueIsNotInTheLocalCatalogueAnd' => l.issueIsNotInTheLocalCatalogueAnd(
      renderMessage(context, message.arguments[0]),
    ),
    'issueKeyOrIdCannotBeEmpty' => l.issueKeyOrIdCannotBeEmpty,
    'issueWasNotFoundInJiraNotFound' => l.issueWasNotFoundInJiraNotFound(
      renderMessage(context, message.arguments[0]),
    ),
    'issueWithIdWasNotFoundInThe' => l.issueWithIdWasNotFoundInThe(
      renderMessage(context, message.arguments[0]),
    ),
    'jiraApiError' => l.jiraApiError(
      renderMessage(context, message.arguments[0]),
      renderMessage(context, message.arguments[1]),
    ),
    'jiraApiTokenWasNotFoundInSecure' => l.jiraApiTokenWasNotFoundInSecure,
    'jiraApiTokenWasNotFoundInSecure16' => l.jiraApiTokenWasNotFoundInSecure16,
    'jiraAuthenticationErrorUnauthorized' =>
      l.jiraAuthenticationErrorUnauthorized,
    'jiraEntryDurationSDoesNotMatchThe' => l.jiraEntryDurationSDoesNotMatchThe(
      renderMessage(context, message.arguments[0]),
      renderMessage(context, message.arguments[1]),
    ),
    'jiraRejectedTheRequest' => l.jiraRejectedTheRequest,
    'jiraRejectedTheRequestCode' => l.jiraRejectedTheRequestCode(
      renderMessage(context, message.arguments[0]),
    ),
    'jiraReturnedAnIncompleteCommentList' =>
      l.jiraReturnedAnIncompleteCommentList,
    'jiraSResponseDoesNotContainTheCreated' =>
      l.jiraSResponseDoesNotContainTheCreated,
    'jiraServerErrorCode' => l.jiraServerErrorCode(
      renderMessage(context, message.arguments[0]),
    ),
    'jiraTokenWasNotFoundInSecureStorage' =>
      l.jiraTokenWasNotFoundInSecureStorage,
    'jiraUrlIsMissing' => l.jiraUrlIsMissing,
    'lockedLogsRequireHMinButOnlyH' => l.lockedLogsRequireHMinButOnlyH(
      renderMessage(context, message.arguments[0]),
      renderMessage(context, message.arguments[1]),
      renderMessage(context, message.arguments[2]),
      renderMessage(context, message.arguments[3]),
    ),
    'logIsAlreadyIncludedInADraftFor' => l.logIsAlreadyIncludedInADraftFor(
      renderMessage(context, message.arguments[0]),
      renderMessage(context, message.arguments[1]),
    ),
    'logIsAlreadyIncludedInADraftFor152' =>
      l.logIsAlreadyIncludedInADraftFor152(
        renderMessage(context, message.arguments[0]),
        renderMessage(context, message.arguments[1]),
      ),
    'logWithIdWasNotFound' => l.logWithIdWasNotFound(
      renderMessage(context, message.arguments[0]),
    ),
    'longBreakDurationEnterToDisableItOr' =>
      l.longBreakDurationEnterToDisableItOr,
    'longBreakStartEnterATimeFromTo' => l.longBreakStartEnterATimeFromTo,
    'mismatch' => l.mismatch,
    'negativeTimeDifferenceSTheSystemClockMoved' =>
      l.negativeTimeDifferenceSTheSystemClockMoved(
        renderMessage(context, message.arguments[0]),
      ),
    'networkErrorDuringReconciliation' => l.networkErrorDuringReconciliation(
      renderMessage(context, message.arguments[0]),
    ),
    'networkErrorRequestingCloudid' => l.networkErrorRequestingCloudid(
      renderMessage(context, message.arguments[0]),
    ),
    'noActiveJiraConnection' => l.noActiveJiraConnection,
    'noActiveJiraConnectionToLoadWorklogs' =>
      l.noActiveJiraConnectionToLoadWorklogs,
    'noLogsSelectedToBuildTheDay' => l.noLogsSelectedToBuildTheDay,
    'notEnoughFreeTimeBeforeJiraEntryRequires' =>
      l.notEnoughFreeTimeBeforeJiraEntryRequires(
        renderMessage(context, message.arguments[0]),
        renderMessage(context, message.arguments[1]),
        renderMessage(context, message.arguments[2]),
      ),
    'notEnoughTimeEachSelectedLogRequiresAt' =>
      l.notEnoughTimeEachSelectedLogRequiresAt,
    'onlySegmentsFromTheSameSourceLogCan' =>
      l.onlySegmentsFromTheSameSourceLogCan,
    'overlapDetectedAnd' => l.overlapDetectedAnd(
      renderMessage(context, message.arguments[0]),
      renderMessage(context, message.arguments[1]),
      renderMessage(context, message.arguments[2]),
      renderMessage(context, message.arguments[3]),
      renderMessage(context, message.arguments[4]),
      renderMessage(context, message.arguments[5]),
    ),
    'pinnedTask' => l.pinnedTask,
    'rateLimitExceededTooManyRequests' => l.rateLimitExceededTooManyRequests(
      renderMessage(context, message.arguments[0]),
    ),
    'reconciliationError' => l.reconciliationError(
      renderMessage(context, message.arguments[0]),
    ),
    'resetByUserConfirmedTheEntryDoesNot' =>
      l.resetByUserConfirmedTheEntryDoesNot,
    'retryAfterSeconds' => l.retryAfterSeconds(
      renderMessage(context, message.arguments[0]),
    ),
    'runningSourceCannotBeIncludedInADay' =>
      l.runningSourceCannotBeIncludedInADay(
        renderMessage(context, message.arguments[0]),
      ),
    'scheduleSegment' => l.scheduleSegment,
    'segment' => l.segment,
    'segmentDurationMustBeGreaterThanZero' =>
      l.segmentDurationMustBeGreaterThanZero,
    'segmentFallsOutsideTheWorkDay' => l.segmentFallsOutsideTheWorkDay(
      renderMessage(context, message.arguments[0]),
    ),
    'segmentHasANonPositiveDuration' => l.segmentHasANonPositiveDuration(
      renderMessage(context, message.arguments[0]),
    ),
    'segmentIsShorterThanTheMinimumOfMinutes' =>
      l.segmentIsShorterThanTheMinimumOfMinutes(
        renderMessage(context, message.arguments[0]),
      ),
    'segmentResetToPendingSubmissionIsAllowedAgain' =>
      l.segmentResetToPendingSubmissionIsAllowedAgain,
    'selectAnIssueFromTheList' => l.selectAnIssueFromTheList,
    'selectedIssueWasNotFound' => l.selectedIssueWasNotFound,
    'shortBreakDurationEnterAPositiveDurationFrom' =>
      l.shortBreakDurationEnterAPositiveDurationFrom,
    'shortBreaksEnterAnIntegerFromToFrom' =>
      l.shortBreaksEnterAnIntegerFromToFrom(
        renderMessage(context, message.arguments[0]),
      ),
    'someOfTheSpecifiedLogsWereNotFound' =>
      l.someOfTheSpecifiedLogsWereNotFound,
    'sourceHasNoRecordedTime' => l.sourceHasNoRecordedTime(
      renderMessage(context, message.arguments[0]),
    ),
    'sourceIsAlreadyIncludedInADraftFor' =>
      l.sourceIsAlreadyIncludedInADraftFor(
        renderMessage(context, message.arguments[0]),
        renderMessage(context, message.arguments[1]),
      ),
    'sourceWasNotFound' => l.sourceWasNotFound(
      renderMessage(context, message.arguments[0]),
    ),
    'storageIsReadOnlyAnotherApplicationInstanceHolds' =>
      l.storageIsReadOnlyAnotherApplicationInstanceHolds,
    'submissionError' => l.submissionError(
      renderMessage(context, message.arguments[0]),
    ),
    'submissionFinishedSentFailedUnknown' =>
      l.submissionFinishedSentFailedUnknown(
        renderMessage(context, message.arguments[0]),
        renderMessage(context, message.arguments[1]),
        renderMessage(context, message.arguments[2]),
      ),
    'submissionInterruptedAtStartup' => l.submissionInterruptedAtStartup,
    'submittedSourceCannotBeIncludedAgain' =>
      l.submittedSourceCannotBeIncludedAgain(
        renderMessage(context, message.arguments[0]),
      ),
    'submittingEntriesToJira' => l.submittingEntriesToJira,
    'tasksDoNotFitIntoTheSelectedDate' => l.tasksDoNotFitIntoTheSelectedDate,
    'theAgentRuleCannotBeEmpty' => l.theAgentRuleCannotBeEmpty,
    'theApplicationIsReadOnly' => l.theApplicationIsReadOnly,
    'theDayDraftChangedWhileTheSnapshotWas' =>
      l.theDayDraftChangedWhileTheSnapshotWas,
    'theDayDraftHasBeenDeletedSinceIt' => l.theDayDraftHasBeenDeletedSinceIt,
    'theDayDraftHasChangedSinceItWas' => l.theDayDraftHasChangedSinceItWas,
    'theDraftIsEmptyThereAreNoIntervals' =>
      l.theDraftIsEmptyThereAreNoIntervals,
    'theEntireSegmentMustFitWithinTheTarget' =>
      l.theEntireSegmentMustFitWithinTheTarget(
        renderMessage(context, message.arguments[0]),
      ),
    'theEntryBelongsToAnotherJiraUserAccountid' =>
      l.theEntryBelongsToAnotherJiraUserAccountid(
        renderMessage(context, message.arguments[0]),
      ),
    'theFirstPartMustBeGreaterThanAnd' => l.theFirstPartMustBeGreaterThanAnd(
      renderMessage(context, message.arguments[0]),
    ),
    'theFirstPartMustBeGreaterThanAnd466' =>
      l.theFirstPartMustBeGreaterThanAnd466(
        renderMessage(context, message.arguments[0]),
      ),
    'theFirstPartMustBeGreaterThanAnd478' =>
      l.theFirstPartMustBeGreaterThanAnd478(
        renderMessage(context, message.arguments[0]),
      ),
    'theIssueForSourceWasNotFoundIn' => l.theIssueForSourceWasNotFoundIn(
      renderMessage(context, message.arguments[0]),
    ),
    'theJiraTimeTrackerSegmentPropertyWasNot' =>
      l.theJiraTimeTrackerSegmentPropertyWasNot,
    'theLogHasAZeroOrNegativeDuration' => l.theLogHasAZeroOrNegativeDuration,
    'theNextIntervalIsPinnedOrHasAlready' =>
      l.theNextIntervalIsPinnedOrHasAlready,
    'theNextTaskMustBeAtLeastMinute' => l.theNextTaskMustBeAtLeastMinute,
    'thePreviousTaskMustBeAtLeastMinute' =>
      l.thePreviousTaskMustBeAtLeastMinute,
    'theRequiredBreakBetweenWorkIntervalsAndIs' =>
      l.theRequiredBreakBetweenWorkIntervalsAndIs(
        renderMessage(context, message.arguments[0]),
        renderMessage(context, message.arguments[1]),
      ),
    'theSegmentListCannotBeEmpty' => l.theSegmentListCannotBeEmpty,
    'theSegmentMustStartOnTheTargetDate' =>
      l.theSegmentMustStartOnTheTargetDate(
        renderMessage(context, message.arguments[0]),
      ),
    'theSourceLogForTheSegmentsWasNot' => l.theSourceLogForTheSegmentsWasNot,
    'theSplitPointMustBeGreaterThanAnd' => l.theSplitPointMustBeGreaterThanAnd(
      renderMessage(context, message.arguments[0]),
    ),
    'theTotalDayDurationSExceedsHours' => l.theTotalDayDurationSExceedsHours(
      renderMessage(context, message.arguments[0]),
    ),
    'thisIntervalHasAlreadyBeenSubmittedOrNeeds' =>
      l.thisIntervalHasAlreadyBeenSubmittedOrNeeds,
    'totalWorkTimeExceedsHours' => l.totalWorkTimeExceedsHours,
    'unknownSubmissionResultTheConnectionMayHaveBeen' =>
      l.unknownSubmissionResultTheConnectionMayHaveBeen,
    'withExistingEntriesAndPinnedTasksTheDay' =>
      l.withExistingEntriesAndPinnedTasksTheDay,
    'worklogSuccessfullyLinked' => l.worklogSuccessfullyLinked,
    _ => message.fallback,
  };
}
