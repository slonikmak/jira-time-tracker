import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @work.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get work;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Язык / Language'**
  String get language;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// No description provided for @languageSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the language: {error}'**
  String languageSaveFailed(String error);

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get days;

  /// No description provided for @days9.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get days9;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @invalidInputEnterAKeyProjNumericId.
  ///
  /// In en, this message translates to:
  /// **'Invalid input: enter a key (PROJ-123), numeric ID or /browse/... link'**
  String get invalidInputEnterAKeyProjNumericId;

  /// No description provided for @firstCheckAndSaveTheJiraConnectionIn.
  ///
  /// In en, this message translates to:
  /// **'First check and save the Jira connection in Settings'**
  String get firstCheckAndSaveTheJiraConnectionIn;

  /// No description provided for @jiraApiTokenWasNotFoundInSecure.
  ///
  /// In en, this message translates to:
  /// **'Jira API token was not found in secure storage'**
  String get jiraApiTokenWasNotFoundInSecure;

  /// No description provided for @firstConnectJiraInSettings.
  ///
  /// In en, this message translates to:
  /// **'First connect Jira in Settings.'**
  String get firstConnectJiraInSettings;

  /// No description provided for @jiraApiTokenWasNotFoundInSecure16.
  ///
  /// In en, this message translates to:
  /// **'Jira API token was not found in secure storage.'**
  String get jiraApiTokenWasNotFoundInSecure16;

  /// No description provided for @theApplicationIsReadOnly.
  ///
  /// In en, this message translates to:
  /// **'The application is read-only.'**
  String get theApplicationIsReadOnly;

  /// No description provided for @issueKeyOrIdCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Issue key or ID cannot be empty'**
  String get issueKeyOrIdCannotBeEmpty;

  /// No description provided for @issueIsNotInTheLocalCatalogueAnd.
  ///
  /// In en, this message translates to:
  /// **'Issue \"{p0}\" is not in the local catalogue and Jira is unavailable.'**
  String issueIsNotInTheLocalCatalogueAnd(String p0);

  /// No description provided for @durationMustBeGreaterThanZero.
  ///
  /// In en, this message translates to:
  /// **'Duration must be greater than zero'**
  String get durationMustBeGreaterThanZero;

  /// No description provided for @issueWithIdWasNotFoundInThe.
  ///
  /// In en, this message translates to:
  /// **'Issue with ID {p0} was not found in the local catalogue'**
  String issueWithIdWasNotFoundInThe(String p0);

  /// No description provided for @logWithIdWasNotFound.
  ///
  /// In en, this message translates to:
  /// **'Log with ID {p0} was not found'**
  String logWithIdWasNotFound(String p0);

  /// No description provided for @cannotEditARunningLogPauseItFirst.
  ///
  /// In en, this message translates to:
  /// **'Cannot edit a running log. Pause it first.'**
  String get cannotEditARunningLogPauseItFirst;

  /// No description provided for @cannotEditALogThatHasAlreadyBeen.
  ///
  /// In en, this message translates to:
  /// **'Cannot edit a log that has already been used.'**
  String get cannotEditALogThatHasAlreadyBeen;

  /// No description provided for @cannotEditALogAlreadyIncludedInThe.
  ///
  /// In en, this message translates to:
  /// **'Cannot edit a log already included in the day draft ({p0}).'**
  String cannotEditALogAlreadyIncludedInThe(String p0);

  /// No description provided for @cannotSplitARunningLogStopItFirst.
  ///
  /// In en, this message translates to:
  /// **'Cannot split a running log. Stop it first.'**
  String get cannotSplitARunningLogStopItFirst;

  /// No description provided for @cannotSplitALogThatHasAlreadyBeen.
  ///
  /// In en, this message translates to:
  /// **'Cannot split a log that has already been used.'**
  String get cannotSplitALogThatHasAlreadyBeen;

  /// No description provided for @cannotSplitALogAlreadyIncludedInA.
  ///
  /// In en, this message translates to:
  /// **'Cannot split a log already included in a day draft.'**
  String get cannotSplitALogAlreadyIncludedInA;

  /// No description provided for @theFirstPartMustBeGreaterThanAnd.
  ///
  /// In en, this message translates to:
  /// **'The first part must be greater than 0 and less than the total duration ({p0} s)'**
  String theFirstPartMustBeGreaterThanAnd(String p0);

  /// No description provided for @atLeastTwoLogsAreRequiredToMerge.
  ///
  /// In en, this message translates to:
  /// **'At least two logs are required to merge'**
  String get atLeastTwoLogsAreRequiredToMerge;

  /// No description provided for @someOfTheSpecifiedLogsWereNotFound.
  ///
  /// In en, this message translates to:
  /// **'Some of the specified logs were not found'**
  String get someOfTheSpecifiedLogsWereNotFound;

  /// No description provided for @cannotMergeRunningLogs.
  ///
  /// In en, this message translates to:
  /// **'Cannot merge running logs.'**
  String get cannotMergeRunningLogs;

  /// No description provided for @cannotMergeLogsAlreadyIncludedInADay.
  ///
  /// In en, this message translates to:
  /// **'Cannot merge logs already included in a day draft.'**
  String get cannotMergeLogsAlreadyIncludedInADay;

  /// No description provided for @cannotDeleteARunningLogPauseItFirst.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete a running log. Pause it first.'**
  String get cannotDeleteARunningLogPauseItFirst;

  /// No description provided for @cannotDeleteALogAlreadyIncludedInThe.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete a log already included in the day draft ({p0}).'**
  String cannotDeleteALogAlreadyIncludedInThe(String p0);

  /// No description provided for @errorLoadingJiraEntries.
  ///
  /// In en, this message translates to:
  /// **'Error loading Jira entries:'**
  String get errorLoadingJiraEntries;

  /// No description provided for @errorLoadingJiraEntries37.
  ///
  /// In en, this message translates to:
  /// **'Error loading Jira entries: {p0}'**
  String errorLoadingJiraEntries37(String p0);

  /// No description provided for @noActiveJiraConnectionToLoadWorklogs.
  ///
  /// In en, this message translates to:
  /// **'No active Jira connection to load worklogs.'**
  String get noActiveJiraConnectionToLoadWorklogs;

  /// No description provided for @expectedAJiraIssueKeyOrNumericId.
  ///
  /// In en, this message translates to:
  /// **'Expected a Jira issue key or numeric ID.'**
  String get expectedAJiraIssueKeyOrNumericId;

  /// No description provided for @noActiveJiraConnection.
  ///
  /// In en, this message translates to:
  /// **'No active Jira connection.'**
  String get noActiveJiraConnection;

  /// No description provided for @expectedAJiraIssueKeyAndANumeric.
  ///
  /// In en, this message translates to:
  /// **'Expected a Jira issue key and a numeric attachment ID.'**
  String get expectedAJiraIssueKeyAndANumeric;

  /// No description provided for @theAgentRuleCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'The agent rule cannot be empty.'**
  String get theAgentRuleCannotBeEmpty;

  /// No description provided for @cannotClearADayAfterSubmissionHasStarted.
  ///
  /// In en, this message translates to:
  /// **'Cannot clear a day after submission has started or in read-only mode.'**
  String get cannotClearADayAfterSubmissionHasStarted;

  /// No description provided for @cannotRebuildAPartiallyOrFullySubmittedDay.
  ///
  /// In en, this message translates to:
  /// **'Cannot rebuild a partially or fully submitted day.'**
  String get cannotRebuildAPartiallyOrFullySubmittedDay;

  /// No description provided for @noLogsSelectedToBuildTheDay.
  ///
  /// In en, this message translates to:
  /// **'No logs selected to build the day.'**
  String get noLogsSelectedToBuildTheDay;

  /// No description provided for @aRunningLogCannotBeIncludedInA.
  ///
  /// In en, this message translates to:
  /// **'A running log cannot be included in a day draft.'**
  String get aRunningLogCannotBeIncludedInA;

  /// No description provided for @logIsAlreadyIncludedInADraftFor.
  ///
  /// In en, this message translates to:
  /// **'Log {p0} is already included in a draft for {p1}.'**
  String logIsAlreadyIncludedInADraftFor(String p0, String p1);

  /// No description provided for @daySuccessfullyRebuiltSmartRebuild.
  ///
  /// In en, this message translates to:
  /// **'Day successfully rebuilt (smart rebuild).'**
  String get daySuccessfullyRebuiltSmartRebuild;

  /// No description provided for @daySuccessfullyBuilt.
  ///
  /// In en, this message translates to:
  /// **'Day successfully built.'**
  String get daySuccessfullyBuilt;

  /// No description provided for @theSegmentListCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'The segment list cannot be empty.'**
  String get theSegmentListCannotBeEmpty;

  /// No description provided for @cannotReplaceTheDraftAfterDaySubmissionHas.
  ///
  /// In en, this message translates to:
  /// **'Cannot replace the draft after day submission has started.'**
  String get cannotReplaceTheDraftAfterDaySubmissionHas;

  /// No description provided for @theDayDraftHasChangedSinceItWas.
  ///
  /// In en, this message translates to:
  /// **'The day draft has changed since it was read. Get a fresh snapshot and try again.'**
  String get theDayDraftHasChangedSinceItWas;

  /// No description provided for @theDayDraftHasBeenDeletedSinceIt.
  ///
  /// In en, this message translates to:
  /// **'The day draft has been deleted since it was read. Get a fresh snapshot and try again.'**
  String get theDayDraftHasBeenDeletedSinceIt;

  /// No description provided for @sourceWasNotFound.
  ///
  /// In en, this message translates to:
  /// **'Source \"{p0}\" was not found.'**
  String sourceWasNotFound(String p0);

  /// No description provided for @runningSourceCannotBeIncludedInADay.
  ///
  /// In en, this message translates to:
  /// **'Running source \"{p0}\" cannot be included in a day.'**
  String runningSourceCannotBeIncludedInADay(String p0);

  /// No description provided for @submittedSourceCannotBeIncludedAgain.
  ///
  /// In en, this message translates to:
  /// **'Submitted source \"{p0}\" cannot be included again.'**
  String submittedSourceCannotBeIncludedAgain(String p0);

  /// No description provided for @sourceHasNoRecordedTime.
  ///
  /// In en, this message translates to:
  /// **'Source \"{p0}\" has no recorded time.'**
  String sourceHasNoRecordedTime(String p0);

  /// No description provided for @sourceIsAlreadyIncludedInADraftFor.
  ///
  /// In en, this message translates to:
  /// **'Source \"{p0}\" is already included in a draft for {p1}.'**
  String sourceIsAlreadyIncludedInADraftFor(String p0, String p1);

  /// No description provided for @theIssueForSourceWasNotFoundIn.
  ///
  /// In en, this message translates to:
  /// **'The issue for source {p0} was not found in the local catalogue.'**
  String theIssueForSourceWasNotFoundIn(String p0);

  /// No description provided for @issueDoesNotMatchSource.
  ///
  /// In en, this message translates to:
  /// **'Issue \"{p0}\" does not match source {p1} ({p2}).'**
  String issueDoesNotMatchSource(String p0, String p1, String p2);

  /// No description provided for @segmentDurationMustBeGreaterThanZero.
  ///
  /// In en, this message translates to:
  /// **'Segment duration must be greater than zero.'**
  String get segmentDurationMustBeGreaterThanZero;

  /// No description provided for @theSegmentMustStartOnTheTargetDate.
  ///
  /// In en, this message translates to:
  /// **'The segment must start on the target date {p0}.'**
  String theSegmentMustStartOnTheTargetDate(String p0);

  /// No description provided for @theEntireSegmentMustFitWithinTheTarget.
  ///
  /// In en, this message translates to:
  /// **'The entire segment must fit within the target date {p0}.'**
  String theEntireSegmentMustFitWithinTheTarget(String p0);

  /// No description provided for @theDayDraftChangedWhileTheSnapshotWas.
  ///
  /// In en, this message translates to:
  /// **'The day draft changed while the snapshot was being prepared. Get a fresh snapshot and try again.'**
  String get theDayDraftChangedWhileTheSnapshotWas;

  /// No description provided for @thisIntervalHasAlreadyBeenSubmittedOrNeeds.
  ///
  /// In en, this message translates to:
  /// **'This interval has already been submitted or needs reconciliation with Jira.'**
  String get thisIntervalHasAlreadyBeenSubmittedOrNeeds;

  /// No description provided for @durationMustBeGreaterThanMinutes.
  ///
  /// In en, this message translates to:
  /// **'Duration must be greater than 0 minutes.'**
  String get durationMustBeGreaterThanMinutes;

  /// No description provided for @theNextIntervalIsPinnedOrHasAlready.
  ///
  /// In en, this message translates to:
  /// **'The next interval is pinned or has already been submitted. It cannot be moved.'**
  String get theNextIntervalIsPinnedOrHasAlready;

  /// No description provided for @theSplitPointMustBeGreaterThanAnd.
  ///
  /// In en, this message translates to:
  /// **'The split point must be greater than 0 and less than the segment duration ({p0} s)'**
  String theSplitPointMustBeGreaterThanAnd(String p0);

  /// No description provided for @onlySegmentsFromTheSameSourceLogCan.
  ///
  /// In en, this message translates to:
  /// **'Only segments from the same source log can be merged.'**
  String get onlySegmentsFromTheSameSourceLogCan;

  /// No description provided for @theSourceLogForTheSegmentsWasNot.
  ///
  /// In en, this message translates to:
  /// **'The source log for the segments was not found.'**
  String get theSourceLogForTheSegmentsWasNot;

  /// No description provided for @cannotRebuildADayAfterSubmissionHasStarted.
  ///
  /// In en, this message translates to:
  /// **'Cannot rebuild a day after submission has started or in read-only mode.'**
  String get cannotRebuildADayAfterSubmissionHasStarted;

  /// No description provided for @daySuccessfullyRebuiltWithTheOrderPreserved.
  ///
  /// In en, this message translates to:
  /// **'Day successfully rebuilt with the order preserved.'**
  String get daySuccessfullyRebuiltWithTheOrderPreserved;

  /// No description provided for @endTimeMustBeAfterStartTime.
  ///
  /// In en, this message translates to:
  /// **'End time must be after start time.'**
  String get endTimeMustBeAfterStartTime;

  /// No description provided for @cannotChangeTheBoundaryThereIsAJira.
  ///
  /// In en, this message translates to:
  /// **'Cannot change the boundary: there is a Jira entry on the left ({p0}).'**
  String cannotChangeTheBoundaryThereIsAJira(String p0);

  /// No description provided for @thePreviousTaskMustBeAtLeastMinute.
  ///
  /// In en, this message translates to:
  /// **'The previous task must be at least 1 minute long.'**
  String get thePreviousTaskMustBeAtLeastMinute;

  /// No description provided for @cannotChangeTheBoundaryThereIsAJira76.
  ///
  /// In en, this message translates to:
  /// **'Cannot change the boundary: there is a Jira entry on the right ({p0}).'**
  String cannotChangeTheBoundaryThereIsAJira76(String p0);

  /// No description provided for @theNextTaskMustBeAtLeastMinute.
  ///
  /// In en, this message translates to:
  /// **'The next task must be at least 1 minute long.'**
  String get theNextTaskMustBeAtLeastMinute;

  /// No description provided for @notEnoughFreeTimeBeforeJiraEntryRequires.
  ///
  /// In en, this message translates to:
  /// **'Not enough free time before Jira entry {p0}: requires {p1} min, available {p2} min.'**
  String notEnoughFreeTimeBeforeJiraEntryRequires(
    String p0,
    String p1,
    String p2,
  );

  /// No description provided for @jiraTokenWasNotFoundInSecureStorage.
  ///
  /// In en, this message translates to:
  /// **'Jira token was not found in secure storage'**
  String get jiraTokenWasNotFoundInSecureStorage;

  /// No description provided for @submittingEntriesToJira.
  ///
  /// In en, this message translates to:
  /// **'Submitting entries to Jira...'**
  String get submittingEntriesToJira;

  /// No description provided for @allEntriesWereSuccessfullySubmittedToJira.
  ///
  /// In en, this message translates to:
  /// **'All entries ({p0}) were successfully submitted to Jira!'**
  String allEntriesWereSuccessfullySubmittedToJira(String p0);

  /// No description provided for @submissionError.
  ///
  /// In en, this message translates to:
  /// **'Submission error: {p0}'**
  String submissionError(String p0);

  /// No description provided for @submissionFinishedSentFailedUnknown.
  ///
  /// In en, this message translates to:
  /// **'Submission finished: {p0} sent, {p1} failed, {p2} unknown.'**
  String submissionFinishedSentFailedUnknown(String p0, String p1, String p2);

  /// No description provided for @errorSubmittingToJira.
  ///
  /// In en, this message translates to:
  /// **'Error submitting to Jira: {p0}'**
  String errorSubmittingToJira(String p0);

  /// No description provided for @reconciliationError.
  ///
  /// In en, this message translates to:
  /// **'Reconciliation error: {p0}'**
  String reconciliationError(String p0);

  /// No description provided for @worklogSuccessfullyLinked.
  ///
  /// In en, this message translates to:
  /// **'Worklog successfully linked!'**
  String get worklogSuccessfullyLinked;

  /// No description provided for @errorLinkingTheWorklog.
  ///
  /// In en, this message translates to:
  /// **'Error linking the worklog'**
  String get errorLinkingTheWorklog;

  /// No description provided for @segmentResetToPendingSubmissionIsAllowedAgain.
  ///
  /// In en, this message translates to:
  /// **'Segment reset to Pending. Submission is allowed again.'**
  String get segmentResetToPendingSubmissionIsAllowedAgain;

  /// No description provided for @conflictPinnedTaskOverlapsTask.
  ///
  /// In en, this message translates to:
  /// **'Conflict: pinned task \"{p0}\" overlaps task \"{p1}\".'**
  String conflictPinnedTaskOverlapsTask(String p0, String p1);

  /// No description provided for @conflictPinnedTaskOverlapsExistingJiraEntry.
  ///
  /// In en, this message translates to:
  /// **'Conflict: pinned task \"{p0}\" overlaps existing Jira entry \"{p1}\".'**
  String conflictPinnedTaskOverlapsExistingJiraEntry(String p0, String p1);

  /// No description provided for @theLogHasAZeroOrNegativeDuration.
  ///
  /// In en, this message translates to:
  /// **'The log has a zero or negative duration.'**
  String get theLogHasAZeroOrNegativeDuration;

  /// No description provided for @conflictExistingJiraEntriesOverlapEachOther.
  ///
  /// In en, this message translates to:
  /// **'Conflict: existing Jira entries overlap each other.'**
  String get conflictExistingJiraEntriesOverlapEachOther;

  /// No description provided for @existingWorklog.
  ///
  /// In en, this message translates to:
  /// **'Existing worklog'**
  String get existingWorklog;

  /// No description provided for @segment.
  ///
  /// In en, this message translates to:
  /// **'Segment'**
  String get segment;

  /// No description provided for @tasksDoNotFitIntoTheSelectedDate.
  ///
  /// In en, this message translates to:
  /// **'Tasks do not fit into the selected date (before 23:59:59). Reduce the duration or move some tasks to another day.'**
  String get tasksDoNotFitIntoTheSelectedDate;

  /// No description provided for @existingJiraEntriesAlreadyOccupyOrMoreHours.
  ///
  /// In en, this message translates to:
  /// **'Existing Jira entries already occupy {p0} or more hours.'**
  String existingJiraEntriesAlreadyOccupyOrMoreHours(String p0);

  /// No description provided for @existingJiraEntriesOrPinnedTasksFallOutside.
  ///
  /// In en, this message translates to:
  /// **'Existing Jira entries or pinned tasks fall outside the permitted 24-hour day window.'**
  String get existingJiraEntriesOrPinnedTasksFallOutside;

  /// No description provided for @withExistingEntriesAndPinnedTasksTheDay.
  ///
  /// In en, this message translates to:
  /// **'With existing entries and pinned tasks, the day exceeds the 24-hour limit.'**
  String get withExistingEntriesAndPinnedTasksTheDay;

  /// No description provided for @pinnedTask.
  ///
  /// In en, this message translates to:
  /// **'Pinned task'**
  String get pinnedTask;

  /// No description provided for @existingEntriesBreaksAndPinnedTasksHaveExhausted.
  ///
  /// In en, this message translates to:
  /// **'Existing entries, breaks and pinned tasks have exhausted the work time budget.'**
  String get existingEntriesBreaksAndPinnedTasksHaveExhausted;

  /// No description provided for @aDurationLockedLogIsShorterThanThe.
  ///
  /// In en, this message translates to:
  /// **'A duration-locked log is shorter than the minimum work interval of 15 minutes.'**
  String get aDurationLockedLogIsShorterThanThe;

  /// No description provided for @lockedLogsRequireHMinButOnlyH.
  ///
  /// In en, this message translates to:
  /// **'Locked logs require {p0} h {p1} min, but only {p2} h {p3} min is available.'**
  String lockedLogsRequireHMinButOnlyH(
    String p0,
    String p1,
    String p2,
    String p3,
  );

  /// No description provided for @allLogsAreLockedHMinButThe.
  ///
  /// In en, this message translates to:
  /// **'All logs are locked ({p0} h {p1} min), but the budget is {p2} h {p3} min. Unlock at least one log.'**
  String allLogsAreLockedHMinButThe(String p0, String p1, String p2, String p3);

  /// No description provided for @notEnoughTimeEachSelectedLogRequiresAt.
  ///
  /// In en, this message translates to:
  /// **'Not enough time: each selected log requires at least 15 minutes.'**
  String get notEnoughTimeEachSelectedLogRequiresAt;

  /// No description provided for @cannotFitWorkIntervalsOfAtLeastMinutes.
  ///
  /// In en, this message translates to:
  /// **'Cannot fit work intervals of at least 15 minutes with the required breaks. Change the selected logs or day settings.'**
  String get cannotFitWorkIntervalsOfAtLeastMinutes;

  /// No description provided for @theTotalDayDurationSExceedsHours.
  ///
  /// In en, this message translates to:
  /// **'The total day duration ({p0} s) exceeds 24 hours.'**
  String theTotalDayDurationSExceedsHours(String p0);

  /// No description provided for @totalWorkTimeExceedsHours.
  ///
  /// In en, this message translates to:
  /// **'Total work time exceeds 24 hours.'**
  String get totalWorkTimeExceedsHours;

  /// No description provided for @segmentHasANonPositiveDuration.
  ///
  /// In en, this message translates to:
  /// **'Segment {p0} has a non-positive duration.'**
  String segmentHasANonPositiveDuration(String p0);

  /// No description provided for @segmentIsShorterThanTheMinimumOfMinutes.
  ///
  /// In en, this message translates to:
  /// **'Segment {p0} is shorter than the minimum of 10 minutes.'**
  String segmentIsShorterThanTheMinimumOfMinutes(String p0);

  /// No description provided for @segmentFallsOutsideTheWorkDay.
  ///
  /// In en, this message translates to:
  /// **'Segment {p0} falls outside the work day.'**
  String segmentFallsOutsideTheWorkDay(String p0);

  /// No description provided for @breakHasANonPositiveDuration.
  ///
  /// In en, this message translates to:
  /// **'Break {p0} has a non-positive duration.'**
  String breakHasANonPositiveDuration(String p0);

  /// No description provided for @breakFallsOutsideTheWorkDay.
  ///
  /// In en, this message translates to:
  /// **'Break {p0} falls outside the work day.'**
  String breakFallsOutsideTheWorkDay(String p0);

  /// No description provided for @existingEntryHasANonPositiveDuration.
  ///
  /// In en, this message translates to:
  /// **'Existing entry {p0} has a non-positive duration.'**
  String existingEntryHasANonPositiveDuration(String p0);

  /// No description provided for @existingEntryFallsOutsideTheWorkDay.
  ///
  /// In en, this message translates to:
  /// **'Existing entry {p0} falls outside the work day.'**
  String existingEntryFallsOutsideTheWorkDay(String p0);

  /// No description provided for @overlapDetectedAnd.
  ///
  /// In en, this message translates to:
  /// **'Overlap detected: {p0} ({p1} - {p2}) and {p3} ({p4} - {p5}).'**
  String overlapDetectedAnd(
    String p0,
    String p1,
    String p2,
    String p3,
    String p4,
    String p5,
  );

  /// No description provided for @breaksMustHaveAWorkIntervalBetweenThem.
  ///
  /// In en, this message translates to:
  /// **'Breaks must have a work interval between them.'**
  String get breaksMustHaveAWorkIntervalBetweenThem;

  /// No description provided for @theRequiredBreakBetweenWorkIntervalsAndIs.
  ///
  /// In en, this message translates to:
  /// **'The required break between work intervals {p0} and {p1} is missing.'**
  String theRequiredBreakBetweenWorkIntervalsAndIs(String p0, String p1);

  /// No description provided for @cannotPlaceTheLongBreakWithinTheStart.
  ///
  /// In en, this message translates to:
  /// **'Cannot place the long break within the start range. Change the day settings.'**
  String get cannotPlaceTheLongBreakWithinTheStart;

  /// No description provided for @cannotPlaceTheLongBreakWithinTheStart120.
  ///
  /// In en, this message translates to:
  /// **'Cannot place the long break within the start range: the time is occupied. Change the day settings.'**
  String get cannotPlaceTheLongBreakWithinTheStart120;

  /// No description provided for @cannotPlaceTheRequiredNumberOfShortBreaks.
  ///
  /// In en, this message translates to:
  /// **'Cannot place the required number of short breaks: the free gap is too short. Change the day settings.'**
  String get cannotPlaceTheRequiredNumberOfShortBreaks;

  /// No description provided for @cannotPlaceTheRequiredNumberOfShortBreaks122.
  ///
  /// In en, this message translates to:
  /// **'Cannot place the required number of short breaks in the free time. Change the day settings.'**
  String get cannotPlaceTheRequiredNumberOfShortBreaks122;

  /// No description provided for @candidate.
  ///
  /// In en, this message translates to:
  /// **'Candidate'**
  String get candidate;

  /// No description provided for @couldNotGetTheJiraSiteSCloudid.
  ///
  /// In en, this message translates to:
  /// **'Could not get the Jira site\'s cloudId (code: {p0})'**
  String couldNotGetTheJiraSiteSCloudid(String p0);

  /// No description provided for @networkErrorRequestingCloudid.
  ///
  /// In en, this message translates to:
  /// **'Network error requesting cloudId: {p0}'**
  String networkErrorRequestingCloudid(String p0);

  /// No description provided for @invalidEmailOrApiTokenUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or API token (401 Unauthorized)'**
  String get invalidEmailOrApiTokenUnauthorized;

  /// No description provided for @accessDeniedForbidden.
  ///
  /// In en, this message translates to:
  /// **'Access denied (403 Forbidden)'**
  String get accessDeniedForbidden;

  /// No description provided for @rateLimitExceededTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Rate limit exceeded (429 Too Many Requests){p0}'**
  String rateLimitExceededTooManyRequests(String p0);

  /// No description provided for @jiraApiError.
  ///
  /// In en, this message translates to:
  /// **'Jira API error: {p0} {p1}'**
  String jiraApiError(String p0, String p1);

  /// No description provided for @jiraUrlIsMissing.
  ///
  /// In en, this message translates to:
  /// **'Jira URL is missing'**
  String get jiraUrlIsMissing;

  /// No description provided for @atlassianAccountEmailIsMissing.
  ///
  /// In en, this message translates to:
  /// **'Atlassian account email is missing'**
  String get atlassianAccountEmailIsMissing;

  /// No description provided for @atlassianApiTokenIsMissing.
  ///
  /// In en, this message translates to:
  /// **'Atlassian API token is missing'**
  String get atlassianApiTokenIsMissing;

  /// No description provided for @couldNotConnectViaEitherTheDirectOr.
  ///
  /// In en, this message translates to:
  /// **'Could not connect via either the direct or scoped route: {p0}'**
  String couldNotConnectViaEitherTheDirectOr(String p0);

  /// No description provided for @errorCheckingTheScopedRoute.
  ///
  /// In en, this message translates to:
  /// **'Error checking the scoped route: {p0}'**
  String errorCheckingTheScopedRoute(String p0);

  /// No description provided for @issueWasNotFoundInJiraNotFound.
  ///
  /// In en, this message translates to:
  /// **'Issue \"{p0}\" was not found in Jira (404 Not Found)'**
  String issueWasNotFoundInJiraNotFound(String p0);

  /// No description provided for @jiraAuthenticationErrorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Jira authentication error (401 Unauthorized)'**
  String get jiraAuthenticationErrorUnauthorized;

  /// No description provided for @accessToTheJiraIssueIsDeniedForbidden.
  ///
  /// In en, this message translates to:
  /// **'Access to the Jira issue is denied (403 Forbidden)'**
  String get accessToTheJiraIssueIsDeniedForbidden;

  /// No description provided for @errorLoadingIssue.
  ///
  /// In en, this message translates to:
  /// **'Error loading issue \"{p0}\": {p1} {p2}'**
  String errorLoadingIssue(String p0, String p1, String p2);

  /// No description provided for @jiraReturnedAnIncompleteCommentList.
  ///
  /// In en, this message translates to:
  /// **'Jira returned an incomplete comment list'**
  String get jiraReturnedAnIncompleteCommentList;

  /// No description provided for @attachmentWasNotFoundInTheSpecifiedJira.
  ///
  /// In en, this message translates to:
  /// **'Attachment was not found in the specified Jira issue'**
  String get attachmentWasNotFoundInTheSpecifiedJira;

  /// No description provided for @errorLoadingJiraAttachmentCode.
  ///
  /// In en, this message translates to:
  /// **'Error loading Jira attachment (code: {p0})'**
  String errorLoadingJiraAttachmentCode(String p0);

  /// No description provided for @errorLoadingJiraDataCode.
  ///
  /// In en, this message translates to:
  /// **'Error loading Jira data (code: {p0})'**
  String errorLoadingJiraDataCode(String p0);

  /// No description provided for @errorSearchingJiraForIssuesWithWorklogsCode.
  ///
  /// In en, this message translates to:
  /// **'Error searching Jira for issues with worklogs (code: {p0})'**
  String errorSearchingJiraForIssuesWithWorklogsCode(String p0);

  /// No description provided for @errorLoadingWorklogsForIssueCode.
  ///
  /// In en, this message translates to:
  /// **'Error loading worklogs for issue \"{p0}\" (code: {p1})'**
  String errorLoadingWorklogsForIssueCode(String p0, String p1);

  /// No description provided for @jiraSResponseDoesNotContainTheCreated.
  ///
  /// In en, this message translates to:
  /// **'Jira\'s 201 response does not contain the created worklog ID'**
  String get jiraSResponseDoesNotContainTheCreated;

  /// No description provided for @invalidJsonInJiraSResponse.
  ///
  /// In en, this message translates to:
  /// **'Invalid JSON in Jira\'s 201 response: {p0}'**
  String invalidJsonInJiraSResponse(String p0);

  /// No description provided for @jiraRejectedTheRequestCode.
  ///
  /// In en, this message translates to:
  /// **'Jira rejected the request (code {p0})'**
  String jiraRejectedTheRequestCode(String p0);

  /// No description provided for @jiraServerErrorCode.
  ///
  /// In en, this message translates to:
  /// **'Jira server error (code {p0})'**
  String jiraServerErrorCode(String p0);

  /// No description provided for @connectionLostOrTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Connection lost or timed out: {p0}'**
  String connectionLostOrTimedOut(String p0);

  /// No description provided for @storageIsReadOnlyAnotherApplicationInstanceHolds.
  ///
  /// In en, this message translates to:
  /// **'Storage is read-only: another application instance holds the write lock.'**
  String get storageIsReadOnlyAnotherApplicationInstanceHolds;

  /// No description provided for @logIsAlreadyIncludedInADraftFor152.
  ///
  /// In en, this message translates to:
  /// **'Log {p0} is already included in a draft for {p1}.'**
  String logIsAlreadyIncludedInADraftFor152(String p0, String p1);

  /// No description provided for @cannotRemoveALogAfterDaySubmissionTo.
  ///
  /// In en, this message translates to:
  /// **'Cannot remove a log after day submission to Jira has started.'**
  String get cannotRemoveALogAfterDaySubmissionTo;

  /// No description provided for @negativeTimeDifferenceSTheSystemClockMoved.
  ///
  /// In en, this message translates to:
  /// **'Negative time difference ({p0} s): the system clock moved backwards. Check the log.'**
  String negativeTimeDifferenceSTheSystemClockMoved(String p0);

  /// No description provided for @hM.
  ///
  /// In en, this message translates to:
  /// **'{p0}h {p1}m'**
  String hM(String p0, String p1);

  /// No description provided for @m.
  ///
  /// In en, this message translates to:
  /// **'{p0}m'**
  String m(String p0);

  /// No description provided for @dayStartEnterATimeFromToFrom.
  ///
  /// In en, this message translates to:
  /// **'Day start: enter a time from 00:00 to 23:59, from ≤ to.'**
  String get dayStartEnterATimeFromToFrom;

  /// No description provided for @dayDurationEnterAPositiveDurationUpTo.
  ///
  /// In en, this message translates to:
  /// **'Day duration: enter a positive duration up to 24 hours, from ≤ to.'**
  String get dayDurationEnterAPositiveDurationUpTo;

  /// No description provided for @longBreakStartEnterATimeFromTo.
  ///
  /// In en, this message translates to:
  /// **'Long break start: enter a time from 00:00 to 23:59, from ≤ to.'**
  String get longBreakStartEnterATimeFromTo;

  /// No description provided for @longBreakDurationEnterToDisableItOr.
  ///
  /// In en, this message translates to:
  /// **'Long break duration: enter 0–0 to disable it or a positive duration, from ≤ to.'**
  String get longBreakDurationEnterToDisableItOr;

  /// No description provided for @shortBreaksEnterAnIntegerFromToFrom.
  ///
  /// In en, this message translates to:
  /// **'Short breaks: enter an integer from 0 to {p0}, from ≤ to.'**
  String shortBreaksEnterAnIntegerFromToFrom(String p0);

  /// No description provided for @shortBreakDurationEnterAPositiveDurationFrom.
  ///
  /// In en, this message translates to:
  /// **'Short break duration: enter a positive duration, from ≤ to.'**
  String get shortBreakDurationEnterAPositiveDurationFrom;

  /// No description provided for @scheduleSegment.
  ///
  /// In en, this message translates to:
  /// **'Schedule segment'**
  String get scheduleSegment;

  /// No description provided for @dayStart.
  ///
  /// In en, this message translates to:
  /// **'Day start'**
  String get dayStart;

  /// No description provided for @dayEnd.
  ///
  /// In en, this message translates to:
  /// **'Day end'**
  String get dayEnd;

  /// No description provided for @couldNotSaveCredentialsInWindowsCredentialManager.
  ///
  /// In en, this message translates to:
  /// **'Could not save credentials in Windows Credential Manager'**
  String get couldNotSaveCredentialsInWindowsCredentialManager;

  /// No description provided for @selectAnIssueFromTheList.
  ///
  /// In en, this message translates to:
  /// **'Select an issue from the list'**
  String get selectAnIssueFromTheList;

  /// No description provided for @selectedIssueWasNotFound.
  ///
  /// In en, this message translates to:
  /// **'Selected issue was not found'**
  String get selectedIssueWasNotFound;

  /// No description provided for @addedTo.
  ///
  /// In en, this message translates to:
  /// **'Added {p0} to {p1}'**
  String addedTo(String p0, String p1);

  /// No description provided for @addTime.
  ///
  /// In en, this message translates to:
  /// **'Add time'**
  String get addTime;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @theEntryWillAppearInTheQueueNo.
  ///
  /// In en, this message translates to:
  /// **'The entry will appear in the queue. No timer is needed.'**
  String get theEntryWillAppearInTheQueueNo;

  /// No description provided for @issue.
  ///
  /// In en, this message translates to:
  /// **'Issue'**
  String get issue;

  /// No description provided for @noIssuesAvailableAddAnIssueFirst.
  ///
  /// In en, this message translates to:
  /// **'No issues available. Add an issue first.'**
  String get noIssuesAvailableAddAnIssueFirst;

  /// No description provided for @quickIssues.
  ///
  /// In en, this message translates to:
  /// **'QUICK ISSUES'**
  String get quickIssues;

  /// No description provided for @recentIssues.
  ///
  /// In en, this message translates to:
  /// **'RECENT ISSUES'**
  String get recentIssues;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get hours;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get minutes;

  /// No description provided for @workDone.
  ///
  /// In en, this message translates to:
  /// **'Work done'**
  String get workDone;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @forExampleTheLoginFormAndErrorHandling.
  ///
  /// In en, this message translates to:
  /// **'For example, the login form and error handling'**
  String get forExampleTheLoginFormAndErrorHandling;

  /// No description provided for @setStartTime.
  ///
  /// In en, this message translates to:
  /// **'Set start time'**
  String get setStartTime;

  /// No description provided for @newEntry.
  ///
  /// In en, this message translates to:
  /// **'New entry · {p0}'**
  String newEntry(String p0);

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'· start {p0}'**
  String start(String p0);

  /// No description provided for @clearFixedStartTime.
  ///
  /// In en, this message translates to:
  /// **'Clear fixed start time'**
  String get clearFixedStartTime;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @saveEntry.
  ///
  /// In en, this message translates to:
  /// **'Save entry'**
  String get saveEntry;

  /// No description provided for @dayTimeline.
  ///
  /// In en, this message translates to:
  /// **'Day timeline'**
  String get dayTimeline;

  /// No description provided for @submissionResultNeedsChecking.
  ///
  /// In en, this message translates to:
  /// **'Submission result needs checking'**
  String get submissionResultNeedsChecking;

  /// No description provided for @dayPartiallySubmitted.
  ///
  /// In en, this message translates to:
  /// **'Day partially submitted'**
  String get dayPartiallySubmitted;

  /// No description provided for @couldNotSubmitEntries.
  ///
  /// In en, this message translates to:
  /// **'Could not submit entries'**
  String get couldNotSubmitEntries;

  /// No description provided for @sentFailedWithAnUnknownResultResubmissionOf.
  ///
  /// In en, this message translates to:
  /// **'{p0} sent, {p1} failed, {p2} with an unknown result. Resubmission of unknown entries is blocked.'**
  String sentFailedWithAnUnknownResultResubmissionOf(
    String p0,
    String p1,
    String p2,
  );

  /// No description provided for @sentNotSentFailedEntriesCanBeResubmitted.
  ///
  /// In en, this message translates to:
  /// **'{p0} sent, {p1} not sent. Failed entries can be resubmitted.'**
  String sentNotSentFailedEntriesCanBeResubmitted(String p0, String p1);

  /// No description provided for @loadingJiraEntries.
  ///
  /// In en, this message translates to:
  /// **'Loading Jira entries...'**
  String get loadingJiraEntries;

  /// No description provided for @jiraEntriesForTheSelectedDay.
  ///
  /// In en, this message translates to:
  /// **'Jira entries for the selected day'**
  String get jiraEntriesForTheSelectedDay;

  /// No description provided for @noJiraEntriesForTheSelectedDay.
  ///
  /// In en, this message translates to:
  /// **'No Jira entries for the selected day'**
  String get noJiraEntriesForTheSelectedDay;

  /// No description provided for @buildAScheduleFromTheSelectedLogs.
  ///
  /// In en, this message translates to:
  /// **'Build a schedule from the selected logs'**
  String get buildAScheduleFromTheSelectedLogs;

  /// No description provided for @allEntriesSubmitted.
  ///
  /// In en, this message translates to:
  /// **'All entries submitted'**
  String get allEntriesSubmitted;

  /// No description provided for @submissionResult.
  ///
  /// In en, this message translates to:
  /// **'Submission result'**
  String get submissionResult;

  /// No description provided for @draftSavedOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'{p0} · Draft saved on this device'**
  String draftSavedOnThisDevice(String p0);

  /// No description provided for @selectADate.
  ///
  /// In en, this message translates to:
  /// **'Select a date'**
  String get selectADate;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @moreScheduleActions.
  ///
  /// In en, this message translates to:
  /// **'More schedule actions'**
  String get moreScheduleActions;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date ({p0})'**
  String selectDate(String p0);

  /// No description provided for @previousDay.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get previousDay;

  /// No description provided for @nextDay.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get nextDay;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @refreshJiraEntries.
  ///
  /// In en, this message translates to:
  /// **'Refresh Jira entries'**
  String get refreshJiraEntries;

  /// No description provided for @rebuildDay.
  ///
  /// In en, this message translates to:
  /// **'Rebuild day'**
  String get rebuildDay;

  /// No description provided for @submissionResults.
  ///
  /// In en, this message translates to:
  /// **'Submission results'**
  String get submissionResults;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @smartRebuild.
  ///
  /// In en, this message translates to:
  /// **'Smart rebuild'**
  String get smartRebuild;

  /// No description provided for @dayBoundaries.
  ///
  /// In en, this message translates to:
  /// **'Day boundaries'**
  String get dayBoundaries;

  /// No description provided for @wholeDayIncludingBreaks.
  ///
  /// In en, this message translates to:
  /// **'Whole day: {p0} including breaks'**
  String wholeDayIncludingBreaks(String p0);

  /// No description provided for @sent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get sent;

  /// No description provided for @newTime.
  ///
  /// In en, this message translates to:
  /// **'New time'**
  String get newTime;

  /// No description provided for @ofEntries.
  ///
  /// In en, this message translates to:
  /// **'{p0} of {p1, plural, one {{p1} entry} other {{p1} entries}}'**
  String ofEntries(String p0, int p1);

  /// No description provided for @entriesInTheSchedule.
  ///
  /// In en, this message translates to:
  /// **'{p0} entries in the schedule'**
  String entriesInTheSchedule(String p0);

  /// No description provided for @entriesToSubmit.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {{count} entry} other {{count} entries}} to submit'**
  String entriesToSubmit(int count);

  /// No description provided for @alreadyInJira.
  ///
  /// In en, this message translates to:
  /// **'Already in Jira'**
  String get alreadyInJira;

  /// No description provided for @willNotBeSubmittedAgain.
  ///
  /// In en, this message translates to:
  /// **'Will not be submitted again'**
  String get willNotBeSubmittedAgain;

  /// No description provided for @breaks.
  ///
  /// In en, this message translates to:
  /// **'Breaks'**
  String get breaks;

  /// No description provided for @excludedFromWorkTime.
  ///
  /// In en, this message translates to:
  /// **'Excluded from work time'**
  String get excludedFromWorkTime;

  /// No description provided for @rebuildIsUnavailableAfterSubmissionHasStartedResolve.
  ///
  /// In en, this message translates to:
  /// **'Rebuild is unavailable after submission has started. Resolve all results first.'**
  String get rebuildIsUnavailableAfterSubmissionHasStartedResolve;

  /// No description provided for @reconcileUnknownResultsBeforeResubmitting.
  ///
  /// In en, this message translates to:
  /// **'Reconcile unknown results before resubmitting.'**
  String get reconcileUnknownResultsBeforeResubmitting;

  /// No description provided for @resubmissionAffectsOnlyEntriesThatHaveNotBeen.
  ///
  /// In en, this message translates to:
  /// **'Resubmission affects only entries that have not been sent.'**
  String get resubmissionAffectsOnlyEntriesThatHaveNotBeen;

  /// No description provided for @successfulEntriesAreNeverSubmittedAgain.
  ///
  /// In en, this message translates to:
  /// **'Successful entries are never submitted again.'**
  String get successfulEntriesAreNeverSubmittedAgain;

  /// No description provided for @entriesForThisDay.
  ///
  /// In en, this message translates to:
  /// **'Entries for this day'**
  String get entriesForThisDay;

  /// No description provided for @successfulEntriesAreNeverSubmittedAgain229.
  ///
  /// In en, this message translates to:
  /// **'Successful entries are never submitted again'**
  String get successfulEntriesAreNeverSubmittedAgain229;

  /// No description provided for @pendingSubmission.
  ///
  /// In en, this message translates to:
  /// **'Pending submission'**
  String get pendingSubmission;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get sending;

  /// No description provided for @notSent.
  ///
  /// In en, this message translates to:
  /// **'Not sent'**
  String get notSent;

  /// No description provided for @checkingTheResult.
  ///
  /// In en, this message translates to:
  /// **'Checking the result'**
  String get checkingTheResult;

  /// No description provided for @noDescription.
  ///
  /// In en, this message translates to:
  /// **'(no description)'**
  String get noDescription;

  /// No description provided for @actionsForAnUnknownResult.
  ///
  /// In en, this message translates to:
  /// **'Actions for an unknown result'**
  String get actionsForAnUnknownResult;

  /// No description provided for @reconcileResultA.
  ///
  /// In en, this message translates to:
  /// **'Reconcile result (A15)'**
  String get reconcileResultA;

  /// No description provided for @resolveManuallyA.
  ///
  /// In en, this message translates to:
  /// **'Resolve manually (A15)'**
  String get resolveManuallyA;

  /// No description provided for @couldNotLoadJiraEntries.
  ///
  /// In en, this message translates to:
  /// **'Could not load Jira entries'**
  String get couldNotLoadJiraEntries;

  /// No description provided for @noJiraEntriesForThisDay.
  ///
  /// In en, this message translates to:
  /// **'No Jira entries for this day'**
  String get noJiraEntriesForThisDay;

  /// No description provided for @buildADayFromYourLogs.
  ///
  /// In en, this message translates to:
  /// **'Build a day from your logs'**
  String get buildADayFromYourLogs;

  /// No description provided for @retryLoadingUsingTheDateMenu.
  ///
  /// In en, this message translates to:
  /// **'Retry loading using the date menu.'**
  String get retryLoadingUsingTheDateMenu;

  /// No description provided for @selectEntriesAndTheDateOnTheWork.
  ///
  /// In en, this message translates to:
  /// **'Select entries and the date on the Work tab.'**
  String get selectEntriesAndTheDateOnTheWork;

  /// No description provided for @selectLogs.
  ///
  /// In en, this message translates to:
  /// **'Select logs'**
  String get selectLogs;

  /// No description provided for @theScheduleNeedsChecking.
  ///
  /// In en, this message translates to:
  /// **'The schedule needs checking'**
  String get theScheduleNeedsChecking;

  /// No description provided for @submissionToJiraIsBlocked.
  ///
  /// In en, this message translates to:
  /// **'{p0} {p1} · submission to Jira is blocked'**
  String submissionToJiraIsBlocked(String p0, String p1);

  /// No description provided for @scheduleErrors.
  ///
  /// In en, this message translates to:
  /// **'Schedule errors'**
  String get scheduleErrors;

  /// No description provided for @showErrors.
  ///
  /// In en, this message translates to:
  /// **'Show errors'**
  String get showErrors;

  /// No description provided for @sources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get sources;

  /// No description provided for @logsToInclude.
  ///
  /// In en, this message translates to:
  /// **'Logs to include'**
  String get logsToInclude;

  /// No description provided for @recordedTimeScheduledTime.
  ///
  /// In en, this message translates to:
  /// **'Recorded time → scheduled time'**
  String get recordedTimeScheduledTime;

  /// No description provided for @selectLogsForTheDay.
  ///
  /// In en, this message translates to:
  /// **'Select logs for the day'**
  String get selectLogsForTheDay;

  /// No description provided for @noSources.
  ///
  /// In en, this message translates to:
  /// **'No sources'**
  String get noSources;

  /// No description provided for @durationLockedClickToUnlock.
  ///
  /// In en, this message translates to:
  /// **'Duration locked (click to unlock)'**
  String get durationLockedClickToUnlock;

  /// No description provided for @lockDurationWhenRebuilding.
  ///
  /// In en, this message translates to:
  /// **'Lock duration when rebuilding'**
  String get lockDurationWhenRebuilding;

  /// No description provided for @theQueueHasNoFreeStoppedLogsAdd.
  ///
  /// In en, this message translates to:
  /// **'The queue has no free stopped logs. Add time on the Work tab.'**
  String get theQueueHasNoFreeStoppedLogsAdd;

  /// No description provided for @inTheDraftFor.
  ///
  /// In en, this message translates to:
  /// **'In the draft for {p0}'**
  String inTheDraftFor(String p0);

  /// No description provided for @durationLocked.
  ///
  /// In en, this message translates to:
  /// **'Duration locked'**
  String get durationLocked;

  /// No description provided for @lockDuration.
  ///
  /// In en, this message translates to:
  /// **'Lock duration'**
  String get lockDuration;

  /// No description provided for @noPlanBuiltForThisDayYet.
  ///
  /// In en, this message translates to:
  /// **'No plan built for this day yet'**
  String get noPlanBuiltForThisDayYet;

  /// No description provided for @selectLogsOnTheLeftAndClickBuild.
  ///
  /// In en, this message translates to:
  /// **'Select logs on the left and click Build day'**
  String get selectLogsOnTheLeftAndClickBuild;

  /// No description provided for @buildDay.
  ///
  /// In en, this message translates to:
  /// **'Build day'**
  String get buildDay;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @clickAnIntervalToEditIt.
  ///
  /// In en, this message translates to:
  /// **'Click an interval to edit it'**
  String get clickAnIntervalToEditIt;

  /// No description provided for @jiraEntriesAreReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Jira entries are read-only'**
  String get jiraEntriesAreReadOnly;

  /// No description provided for @dragToReorder.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get dragToReorder;

  /// No description provided for @timePinned.
  ///
  /// In en, this message translates to:
  /// **'Time pinned'**
  String get timePinned;

  /// No description provided for @alreadySubmittedToJira.
  ///
  /// In en, this message translates to:
  /// **'Already submitted to Jira'**
  String get alreadySubmittedToJira;

  /// No description provided for @editIntervalA.
  ///
  /// In en, this message translates to:
  /// **'Edit interval (A13)'**
  String get editIntervalA;

  /// No description provided for @moreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get moreActions;

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDown;

  /// No description provided for @unpinTime.
  ///
  /// In en, this message translates to:
  /// **'Unpin time'**
  String get unpinTime;

  /// No description provided for @pinTime.
  ///
  /// In en, this message translates to:
  /// **'Pin time'**
  String get pinTime;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @splitInterval.
  ///
  /// In en, this message translates to:
  /// **'Split interval'**
  String get splitInterval;

  /// No description provided for @mergeIntervals.
  ///
  /// In en, this message translates to:
  /// **'Merge intervals'**
  String get mergeIntervals;

  /// No description provided for @deleteInterval.
  ///
  /// In en, this message translates to:
  /// **'Delete interval'**
  String get deleteInterval;

  /// No description provided for @break278.
  ///
  /// In en, this message translates to:
  /// **'Break'**
  String get break278;

  /// No description provided for @editInterval.
  ///
  /// In en, this message translates to:
  /// **'Edit interval'**
  String get editInterval;

  /// No description provided for @alreadyInJiraReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Already in Jira (read-only)'**
  String get alreadyInJiraReadOnly;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @planReadyToSubmit.
  ///
  /// In en, this message translates to:
  /// **'Plan ready to submit'**
  String get planReadyToSubmit;

  /// No description provided for @theScheduleHasErrors.
  ///
  /// In en, this message translates to:
  /// **'The schedule has errors'**
  String get theScheduleHasErrors;

  /// No description provided for @entriesSent.
  ///
  /// In en, this message translates to:
  /// **'{p0} · {p1, plural, one {{p1} entry} other {{p1} entries}} sent'**
  String entriesSent(String p0, int p1);

  /// No description provided for @checkTheUnknownResultInJiraFirst.
  ///
  /// In en, this message translates to:
  /// **'Check the unknown result in Jira first'**
  String get checkTheUnknownResultInJiraFirst;

  /// No description provided for @entriesSomeSubmissionsFailed.
  ///
  /// In en, this message translates to:
  /// **'{p0} · {p1, plural, one {{p1} entry} other {{p1} entries}}, some submissions failed'**
  String entriesSomeSubmissionsFailed(String p0, int p1);

  /// No description provided for @entriesWillBeAddedToJira.
  ///
  /// In en, this message translates to:
  /// **'{p0} · {p1, plural, one {{p1} entry} other {{p1} entries}} will be added to Jira'**
  String entriesWillBeAddedToJira(String p0, int p1);

  /// No description provided for @backToWork.
  ///
  /// In en, this message translates to:
  /// **'Back to work'**
  String get backToWork;

  /// No description provided for @checkInJira.
  ///
  /// In en, this message translates to:
  /// **'Check in Jira'**
  String get checkInJira;

  /// No description provided for @retrySubmission.
  ///
  /// In en, this message translates to:
  /// **'Retry submission'**
  String get retrySubmission;

  /// No description provided for @submitToJira.
  ///
  /// In en, this message translates to:
  /// **'Submit to Jira'**
  String get submitToJira;

  /// No description provided for @monday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday;

  /// No description provided for @tuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get tuesday;

  /// No description provided for @wednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get wednesday;

  /// No description provided for @thursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get thursday;

  /// No description provided for @friday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get friday;

  /// No description provided for @saturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get saturday;

  /// No description provided for @sunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday;

  /// No description provided for @january.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get january;

  /// No description provided for @february.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get february;

  /// No description provided for @march.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get march;

  /// No description provided for @april.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get april;

  /// No description provided for @may.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get may;

  /// No description provided for @june.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get june;

  /// No description provided for @july.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get july;

  /// No description provided for @august.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get august;

  /// No description provided for @september.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get september;

  /// No description provided for @october.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get october;

  /// No description provided for @november.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get november;

  /// No description provided for @december.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get december;

  /// No description provided for @smartRebuildTheDay.
  ///
  /// In en, this message translates to:
  /// **'Smart rebuild the day?'**
  String get smartRebuildTheDay;

  /// No description provided for @theCurrentDraftWillBeReplacedAndManual.
  ///
  /// In en, this message translates to:
  /// **'The current draft will be replaced and manual time edits will be lost. The schedule will be optimised with breaks and split long tasks.'**
  String get theCurrentDraftWillBeReplacedAndManual;

  /// No description provided for @rebuild.
  ///
  /// In en, this message translates to:
  /// **'Rebuild'**
  String get rebuild;

  /// No description provided for @clearTheDay.
  ///
  /// In en, this message translates to:
  /// **'Clear the day?'**
  String get clearTheDay;

  /// No description provided for @allDraftIntervalsAndBreaksWillBeRemoved.
  ///
  /// In en, this message translates to:
  /// **'All draft intervals and breaks will be removed. Source logs will return to the queue. Jira entries will remain on screen.'**
  String get allDraftIntervalsAndBreaksWillBeRemoved;

  /// No description provided for @rebuildTheDay.
  ///
  /// In en, this message translates to:
  /// **'Rebuild the day?'**
  String get rebuildTheDay;

  /// No description provided for @theScheduleWillBeRebuiltWithOrderAnd.
  ///
  /// In en, this message translates to:
  /// **'The schedule will be rebuilt with order and pinned intervals preserved. Manual time edits will be replaced.'**
  String get theScheduleWillBeRebuiltWithOrderAnd;

  /// No description provided for @dayRebuiltWithOrderAndPinnedIntervalsPreserved.
  ///
  /// In en, this message translates to:
  /// **'Day rebuilt with order and pinned intervals preserved.'**
  String get dayRebuiltWithOrderAndPinnedIntervalsPreserved;

  /// No description provided for @breakCollapsedAndTasksMovedTogether.
  ///
  /// In en, this message translates to:
  /// **'Break collapsed and tasks moved together.'**
  String get breakCollapsedAndTasksMovedTogether;

  /// No description provided for @previousTaskExtendedToFillTheBreak.
  ///
  /// In en, this message translates to:
  /// **'Previous task extended to fill the break.'**
  String get previousTaskExtendedToFillTheBreak;

  /// No description provided for @breakDurationUpdated.
  ///
  /// In en, this message translates to:
  /// **'Break duration updated.'**
  String get breakDurationUpdated;

  /// No description provided for @deleteInterval324.
  ///
  /// In en, this message translates to:
  /// **'Delete interval?'**
  String get deleteInterval324;

  /// No description provided for @theIntervalWillBeRemovedFromTheSchedule.
  ///
  /// In en, this message translates to:
  /// **'The interval will be removed from the schedule. If it is the last interval for its source in this day, the source log will return to the queue.'**
  String get theIntervalWillBeRemovedFromTheSchedule;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @successfullySubmittedEntriesToJira.
  ///
  /// In en, this message translates to:
  /// **'Successfully submitted {p0, plural, one {{p0} entry} other {{p0} entries}} to Jira!'**
  String successfullySubmittedEntriesToJira(int p0);

  /// No description provided for @sentFailedUnknown.
  ///
  /// In en, this message translates to:
  /// **'Sent: {p0}, Failed: {p1}, Unknown: {p2}'**
  String sentFailedUnknown(String p0, String p1, String p2);

  /// No description provided for @resolveUnknownStatusA.
  ///
  /// In en, this message translates to:
  /// **'Resolve unknown status (A15)'**
  String get resolveUnknownStatusA;

  /// No description provided for @theSegmentHasAnUnknownResultTheJira.
  ///
  /// In en, this message translates to:
  /// **'The segment has an unknown result (the Jira response was lost or interrupted). Blind retry is prohibited.'**
  String get theSegmentHasAnUnknownResultTheJira;

  /// No description provided for @optionEnterTheIdOfTheCreatedJira.
  ///
  /// In en, this message translates to:
  /// **'Option 1: Enter the ID of the created Jira entry'**
  String get optionEnterTheIdOfTheCreatedJira;

  /// No description provided for @theApplicationWillCheckTheEntrySAuthor.
  ///
  /// In en, this message translates to:
  /// **'The application will check the entry\'s author, date and duration before confirming:'**
  String get theApplicationWillCheckTheEntrySAuthor;

  /// No description provided for @worklogIdForExample.
  ///
  /// In en, this message translates to:
  /// **'Worklog ID (for example: 10042)'**
  String get worklogIdForExample;

  /// No description provided for @entrySuccessfullyConfirmedAndLinked.
  ///
  /// In en, this message translates to:
  /// **'Entry successfully confirmed and linked!'**
  String get entrySuccessfullyConfirmedAndLinked;

  /// No description provided for @linkingError.
  ///
  /// In en, this message translates to:
  /// **'Linking error'**
  String get linkingError;

  /// No description provided for @link.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get link;

  /// No description provided for @optionConfirmThatTheEntryDoesNotExist.
  ///
  /// In en, this message translates to:
  /// **'Option 2: Confirm that the entry does not exist'**
  String get optionConfirmThatTheEntryDoesNotExist;

  /// No description provided for @ifYouHaveOpenedJiraInABrowser.
  ///
  /// In en, this message translates to:
  /// **'If you have opened Jira in a browser and verified that the issue does not contain this entry, you can reset the interval to Pending for resubmission.'**
  String get ifYouHaveOpenedJiraInABrowser;

  /// No description provided for @noEntryInJiraAllowRetry.
  ///
  /// In en, this message translates to:
  /// **'No entry in Jira, allow retry'**
  String get noEntryInJiraAllowRetry;

  /// No description provided for @intervalResetToPendingForResubmission.
  ///
  /// In en, this message translates to:
  /// **'Interval reset to Pending for resubmission.'**
  String get intervalResetToPendingForResubmission;

  /// No description provided for @editTimeEntry.
  ///
  /// In en, this message translates to:
  /// **'Edit time entry'**
  String get editTimeEntry;

  /// No description provided for @workDoneDescription.
  ///
  /// In en, this message translates to:
  /// **'Work done (description)'**
  String get workDoneDescription;

  /// No description provided for @briefDescriptionOfTheWork.
  ///
  /// In en, this message translates to:
  /// **'Brief description of the work...'**
  String get briefDescriptionOfTheWork;

  /// No description provided for @fixedStart.
  ///
  /// In en, this message translates to:
  /// **'Fixed start'**
  String get fixedStart;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @selectStartTime.
  ///
  /// In en, this message translates to:
  /// **'Select start time'**
  String get selectStartTime;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @editInterval348.
  ///
  /// In en, this message translates to:
  /// **'Edit interval'**
  String get editInterval348;

  /// No description provided for @start349.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start349;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @end.
  ///
  /// In en, this message translates to:
  /// **'End: {p0}'**
  String end(String p0);

  /// No description provided for @workDoneDuringThisInterval.
  ///
  /// In en, this message translates to:
  /// **'Work done during this interval...'**
  String get workDoneDuringThisInterval;

  /// No description provided for @breakDurationMustBeGreaterThanMinutes.
  ///
  /// In en, this message translates to:
  /// **'Break duration must be greater than 0 minutes.'**
  String get breakDurationMustBeGreaterThanMinutes;

  /// No description provided for @break354.
  ///
  /// In en, this message translates to:
  /// **'Break ({p0})'**
  String break354(String p0);

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions:'**
  String get quickActions;

  /// No description provided for @collapseBreak.
  ///
  /// In en, this message translates to:
  /// **'Collapse break'**
  String get collapseBreak;

  /// No description provided for @moveFollowingTasksTogetherRemoveTheGap.
  ///
  /// In en, this message translates to:
  /// **'Move following tasks together (remove the gap)'**
  String get moveFollowingTasksTogetherRemoveTheGap;

  /// No description provided for @extendPreviousTask.
  ///
  /// In en, this message translates to:
  /// **'Extend previous task'**
  String get extendPreviousTask;

  /// No description provided for @extendTaskBy.
  ///
  /// In en, this message translates to:
  /// **'Extend task by {p0}'**
  String extendTaskBy(String p0);

  /// No description provided for @thePreviousEntryIsFixedInJira.
  ///
  /// In en, this message translates to:
  /// **'The previous entry is fixed in Jira'**
  String get thePreviousEntryIsFixedInJira;

  /// No description provided for @thisIsTheStartOfTheDayNo.
  ///
  /// In en, this message translates to:
  /// **'This is the start of the day (no previous task)'**
  String get thisIsTheStartOfTheDayNo;

  /// No description provided for @setBreakDuration.
  ///
  /// In en, this message translates to:
  /// **'Set break duration:'**
  String get setBreakDuration;

  /// No description provided for @followingTasksWillShiftTogetherPreservingTheirDurations.
  ///
  /// In en, this message translates to:
  /// **'Following tasks will shift together, preserving their durations.'**
  String get followingTasksWillShiftTogetherPreservingTheirDurations;

  /// No description provided for @min.
  ///
  /// In en, this message translates to:
  /// **'{p0} min'**
  String min(String p0);

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @logsSuccessfullyMergedTotalDuration.
  ///
  /// In en, this message translates to:
  /// **'Logs successfully merged. Total duration: {p0}'**
  String logsSuccessfullyMergedTotalDuration(String p0);

  /// No description provided for @mergeWithAnotherLog.
  ///
  /// In en, this message translates to:
  /// **'Merge with another log'**
  String get mergeWithAnotherLog;

  /// No description provided for @currentLog.
  ///
  /// In en, this message translates to:
  /// **'Current log: {p0}'**
  String currentLog(String p0);

  /// No description provided for @duration369.
  ///
  /// In en, this message translates to:
  /// **'Duration: {p0}'**
  String duration369(String p0);

  /// No description provided for @selectALogToMerge.
  ///
  /// In en, this message translates to:
  /// **'Select a log to merge:'**
  String get selectALogToMerge;

  /// No description provided for @noFreeLogsAvailableToMerge.
  ///
  /// In en, this message translates to:
  /// **'No free logs available to merge.'**
  String get noFreeLogsAvailableToMerge;

  /// No description provided for @theLogsBelongToDifferentIssuesSelectThe.
  ///
  /// In en, this message translates to:
  /// **'The logs belong to different issues. Select the issue for the result:'**
  String get theLogsBelongToDifferentIssuesSelectThe;

  /// No description provided for @merge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get merge;

  /// No description provided for @intervalsSuccessfullyMerged.
  ///
  /// In en, this message translates to:
  /// **'Intervals successfully merged.'**
  String get intervalsSuccessfullyMerged;

  /// No description provided for @currentInterval.
  ///
  /// In en, this message translates to:
  /// **'Current interval: {p0} ({p1})'**
  String currentInterval(String p0, String p1);

  /// No description provided for @duration376.
  ///
  /// In en, this message translates to:
  /// **'Duration: {p0}'**
  String duration376(String p0);

  /// No description provided for @selectAnIntervalToMerge.
  ///
  /// In en, this message translates to:
  /// **'Select an interval to merge:'**
  String get selectAnIntervalToMerge;

  /// No description provided for @noOtherIntervalsAvailableToMerge.
  ///
  /// In en, this message translates to:
  /// **'No other intervals available to merge.'**
  String get noOtherIntervalsAvailableToMerge;

  /// No description provided for @enterAJiraIssueKeyIdOrLink.
  ///
  /// In en, this message translates to:
  /// **'Enter a Jira issue key, ID or link'**
  String get enterAJiraIssueKeyIdOrLink;

  /// No description provided for @editQuickIssue.
  ///
  /// In en, this message translates to:
  /// **'Edit quick issue'**
  String get editQuickIssue;

  /// No description provided for @addQuickIssue.
  ///
  /// In en, this message translates to:
  /// **'Add quick issue'**
  String get addQuickIssue;

  /// No description provided for @findAnExistingIssueInTheConnectedJira.
  ///
  /// In en, this message translates to:
  /// **'Find an existing issue in the connected Jira.'**
  String get findAnExistingIssueInTheConnectedJira;

  /// No description provided for @keyIdOrLink.
  ///
  /// In en, this message translates to:
  /// **'Key, ID or link'**
  String get keyIdOrLink;

  /// No description provided for @forExampleProj.
  ///
  /// In en, this message translates to:
  /// **'for example, PROJ-123'**
  String get forExampleProj;

  /// No description provided for @find.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get find;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @optionalWhenToUseThisIssue.
  ///
  /// In en, this message translates to:
  /// **'Optional: when to use this issue'**
  String get optionalWhenToUseThisIssue;

  /// No description provided for @theNoteIsLocalAndIsNotSubmitted.
  ///
  /// In en, this message translates to:
  /// **'The note is local and is not submitted to Jira.'**
  String get theNoteIsLocalAndIsNotSubmitted;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @m390.
  ///
  /// In en, this message translates to:
  /// **'{p0} m'**
  String m390(String p0);

  /// No description provided for @h.
  ///
  /// In en, this message translates to:
  /// **'{p0} h'**
  String h(String p0);

  /// No description provided for @hM392.
  ///
  /// In en, this message translates to:
  /// **'{p0} h {p1} m'**
  String hM392(String p0, String p1);

  /// No description provided for @enterTimeInHhMmFormat.
  ///
  /// In en, this message translates to:
  /// **'Enter time in HH:MM format.'**
  String get enterTimeInHhMmFormat;

  /// No description provided for @enterADurationForExampleHM.
  ///
  /// In en, this message translates to:
  /// **'Enter a duration, for example 7 h 30 m.'**
  String get enterADurationForExampleHM;

  /// No description provided for @enterADurationForExampleH.
  ///
  /// In en, this message translates to:
  /// **'Enter a duration, for example 8 h.'**
  String get enterADurationForExampleH;

  /// No description provided for @enterADurationForExampleM.
  ///
  /// In en, this message translates to:
  /// **'Enter a duration, for example 30 m.'**
  String get enterADurationForExampleM;

  /// No description provided for @enterADurationForExampleM398.
  ///
  /// In en, this message translates to:
  /// **'Enter a duration, for example 45 m.'**
  String get enterADurationForExampleM398;

  /// No description provided for @enterAnIntegerFrom.
  ///
  /// In en, this message translates to:
  /// **'Enter an integer from 0.'**
  String get enterAnIntegerFrom;

  /// No description provided for @enterADurationForExampleM400.
  ///
  /// In en, this message translates to:
  /// **'Enter a duration, for example 5 m.'**
  String get enterADurationForExampleM400;

  /// No description provided for @enterADurationForExampleM401.
  ///
  /// In en, this message translates to:
  /// **'Enter a duration, for example 10 m.'**
  String get enterADurationForExampleM401;

  /// No description provided for @dayBuildSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Day build settings saved.'**
  String get dayBuildSettingsSaved;

  /// No description provided for @couldNotSaveSettings.
  ///
  /// In en, this message translates to:
  /// **'Could not save settings: {p0}'**
  String couldNotSaveSettings(String p0);

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection error: {p0}'**
  String connectionError(String p0);

  /// No description provided for @jiraConnectionSuccessfullySaved.
  ///
  /// In en, this message translates to:
  /// **'Jira connection successfully saved'**
  String get jiraConnectionSuccessfullySaved;

  /// No description provided for @quickIssues406.
  ///
  /// In en, this message translates to:
  /// **'Quick issues'**
  String get quickIssues406;

  /// No description provided for @savedIssuesForQuicklyAddingTime.
  ///
  /// In en, this message translates to:
  /// **'Saved issues for quickly adding time.'**
  String get savedIssuesForQuicklyAddingTime;

  /// No description provided for @addIssue.
  ///
  /// In en, this message translates to:
  /// **'Add issue'**
  String get addIssue;

  /// No description provided for @connectJiraFirst.
  ///
  /// In en, this message translates to:
  /// **'Connect Jira first'**
  String get connectJiraFirst;

  /// No description provided for @quickIssuesAreStoredSeparatelyForEachSite.
  ///
  /// In en, this message translates to:
  /// **'Quick issues are stored separately for each site and account.'**
  String get quickIssuesAreStoredSeparatelyForEachSite;

  /// No description provided for @goToConnection.
  ///
  /// In en, this message translates to:
  /// **'Go to connection'**
  String get goToConnection;

  /// No description provided for @inReadOnlyModeYouCanViewThe.
  ///
  /// In en, this message translates to:
  /// **'In read-only mode you can view the list but cannot change it.'**
  String get inReadOnlyModeYouCanViewThe;

  /// No description provided for @noQuickIssuesYet.
  ///
  /// In en, this message translates to:
  /// **'No quick issues yet'**
  String get noQuickIssuesYet;

  /// No description provided for @addAFrequentlyUsedJiraIssueToShow.
  ///
  /// In en, this message translates to:
  /// **'Add a frequently used Jira issue to show it here and on the Work screen.'**
  String get addAFrequentlyUsedJiraIssueToShow;

  /// No description provided for @jiraConnection.
  ///
  /// In en, this message translates to:
  /// **'Jira connection'**
  String get jiraConnection;

  /// No description provided for @dayBuild.
  ///
  /// In en, this message translates to:
  /// **'Day build'**
  String get dayBuild;

  /// No description provided for @localApi.
  ///
  /// In en, this message translates to:
  /// **'Local API'**
  String get localApi;

  /// No description provided for @settings418.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings418;

  /// No description provided for @jiraConnectionDayBuildQuickIssuesAndLocal.
  ///
  /// In en, this message translates to:
  /// **'Jira connection, day build, quick issues and local API.'**
  String get jiraConnectionDayBuildQuickIssuesAndLocal;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @systemDefault422.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault422;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @couldNotSaveTheTheme.
  ///
  /// In en, this message translates to:
  /// **'Could not save the theme: {p0}'**
  String couldNotSaveTheTheme(String p0);

  /// No description provided for @theThemeCannotBeChangedInReadOnly.
  ///
  /// In en, this message translates to:
  /// **'The theme cannot be changed in read-only mode.'**
  String get theThemeCannotBeChangedInReadOnly;

  /// No description provided for @smartRebuildChoosesValuesWithinTheseRanges.
  ///
  /// In en, this message translates to:
  /// **'Smart rebuild chooses values within these ranges.'**
  String get smartRebuildChoosesValuesWithinTheseRanges;

  /// No description provided for @parameter.
  ///
  /// In en, this message translates to:
  /// **'PARAMETER'**
  String get parameter;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'FROM'**
  String get from;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'TO'**
  String get to;

  /// No description provided for @dayDuration.
  ///
  /// In en, this message translates to:
  /// **'Day duration'**
  String get dayDuration;

  /// No description provided for @longBreakStart.
  ///
  /// In en, this message translates to:
  /// **'Long break start'**
  String get longBreakStart;

  /// No description provided for @longBreakDuration.
  ///
  /// In en, this message translates to:
  /// **'Long break duration'**
  String get longBreakDuration;

  /// No description provided for @shortBreaksPerDay.
  ///
  /// In en, this message translates to:
  /// **'Short breaks per day'**
  String get shortBreaksPerDay;

  /// No description provided for @shortBreakDuration.
  ///
  /// In en, this message translates to:
  /// **'Short break duration'**
  String get shortBreakDuration;

  /// No description provided for @minimumWorkIntervalMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minimum work interval: 15 minutes.'**
  String get minimumWorkIntervalMinutes;

  /// No description provided for @agentDayBuildRule.
  ///
  /// In en, this message translates to:
  /// **'Agent day build rule'**
  String get agentDayBuildRule;

  /// No description provided for @theAgentReceivesThisTextTogetherWithThe.
  ///
  /// In en, this message translates to:
  /// **'The agent receives this text together with the ranges via the local API. The built-in builder uses only the ranges.'**
  String get theAgentReceivesThisTextTogetherWithThe;

  /// No description provided for @describeHowTheAgentShouldUseTheDay.
  ///
  /// In en, this message translates to:
  /// **'Describe how the agent should use the day build settings'**
  String get describeHowTheAgentShouldUseTheDay;

  /// No description provided for @couldNot.
  ///
  /// In en, this message translates to:
  /// **'Could not'**
  String get couldNot;

  /// No description provided for @settingsCannotBeChangedInReadOnlyMode.
  ///
  /// In en, this message translates to:
  /// **'Settings cannot be changed in read-only mode.'**
  String get settingsCannotBeChangedInReadOnlyMode;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save settings'**
  String get saveSettings;

  /// No description provided for @usedToLoadIssuesAndSubmitTime.
  ///
  /// In en, this message translates to:
  /// **'Used to load issues and submit time.'**
  String get usedToLoadIssuesAndSubmitTime;

  /// No description provided for @jiraAddress.
  ///
  /// In en, this message translates to:
  /// **'Jira address'**
  String get jiraAddress;

  /// No description provided for @apiToken.
  ///
  /// In en, this message translates to:
  /// **'API token'**
  String get apiToken;

  /// No description provided for @showToken.
  ///
  /// In en, this message translates to:
  /// **'Show token'**
  String get showToken;

  /// No description provided for @hideToken.
  ///
  /// In en, this message translates to:
  /// **'Hide token'**
  String get hideToken;

  /// No description provided for @accountIdRoute.
  ///
  /// In en, this message translates to:
  /// **'Account ID: {p0}\nRoute: {p1}'**
  String accountIdRoute(String p0, String p1);

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected · {p0}\n{p1}'**
  String connected(String p0, String p1);

  /// No description provided for @checkConnection.
  ///
  /// In en, this message translates to:
  /// **'Check connection'**
  String get checkConnection;

  /// No description provided for @localApiForAiAgents.
  ///
  /// In en, this message translates to:
  /// **'Local API for AI agents'**
  String get localApiForAiAgents;

  /// No description provided for @theBuiltInHttpServerAllowsAiAgents.
  ///
  /// In en, this message translates to:
  /// **'The built-in HTTP server allows AI agents to log time and provide a complete day schedule.'**
  String get theBuiltInHttpServerAllowsAiAgents;

  /// No description provided for @localServerAddress.
  ///
  /// In en, this message translates to:
  /// **'Local server address'**
  String get localServerAddress;

  /// No description provided for @copyAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get copyAddress;

  /// No description provided for @serverAddressCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Server address copied to clipboard'**
  String get serverAddressCopiedToClipboard;

  /// No description provided for @agentSkillInstructions.
  ///
  /// In en, this message translates to:
  /// **'Agent skill instructions'**
  String get agentSkillInstructions;

  /// No description provided for @copyInstructions.
  ///
  /// In en, this message translates to:
  /// **'Copy instructions'**
  String get copyInstructions;

  /// No description provided for @agentInstructionsCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Agent instructions copied to clipboard'**
  String get agentInstructionsCopiedToClipboard;

  /// No description provided for @editNote.
  ///
  /// In en, this message translates to:
  /// **'Edit note'**
  String get editNote;

  /// No description provided for @actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actions;

  /// No description provided for @couldNotDeleteTheQuickIssue.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the quick issue: {p0}'**
  String couldNotDeleteTheQuickIssue(String p0);

  /// No description provided for @removeFromQuickIssues.
  ///
  /// In en, this message translates to:
  /// **'Remove from quick issues'**
  String get removeFromQuickIssues;

  /// No description provided for @jiraConnected.
  ///
  /// In en, this message translates to:
  /// **'Jira connected'**
  String get jiraConnected;

  /// No description provided for @readOnlyModeAnotherApplicationInstanceHoldsThe.
  ///
  /// In en, this message translates to:
  /// **'Read-only mode: another application instance holds the write lock (A19).'**
  String get readOnlyModeAnotherApplicationInstanceHoldsThe;

  /// No description provided for @theFirstPartMustBeGreaterThanAnd466.
  ///
  /// In en, this message translates to:
  /// **'The first part must be greater than 0 and less than {p0}'**
  String theFirstPartMustBeGreaterThanAnd466(String p0);

  /// No description provided for @logSplitIntoTwoPartsAnd.
  ///
  /// In en, this message translates to:
  /// **'Log split into two parts: {p0} and {p1}'**
  String logSplitIntoTwoPartsAnd(String p0, String p1);

  /// No description provided for @splitTimeEntry.
  ///
  /// In en, this message translates to:
  /// **'Split time entry'**
  String get splitTimeEntry;

  /// No description provided for @totalTime.
  ///
  /// In en, this message translates to:
  /// **'Total time: {p0}'**
  String totalTime(String p0);

  /// No description provided for @part.
  ///
  /// In en, this message translates to:
  /// **'Part 1'**
  String get part;

  /// No description provided for @h471.
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get h471;

  /// No description provided for @m472.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get m472;

  /// No description provided for @partDescription.
  ///
  /// In en, this message translates to:
  /// **'Part 1 description'**
  String get partDescription;

  /// No description provided for @partRemainder.
  ///
  /// In en, this message translates to:
  /// **'Part 2 (remainder)'**
  String get partRemainder;

  /// No description provided for @min475.
  ///
  /// In en, this message translates to:
  /// **'0 min'**
  String get min475;

  /// No description provided for @partDescription476.
  ///
  /// In en, this message translates to:
  /// **'Part 2 description'**
  String get partDescription476;

  /// No description provided for @split.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get split;

  /// No description provided for @theFirstPartMustBeGreaterThanAnd478.
  ///
  /// In en, this message translates to:
  /// **'The first part must be greater than 0 and less than {p0}'**
  String theFirstPartMustBeGreaterThanAnd478(String p0);

  /// No description provided for @intervalSplitAnd.
  ///
  /// In en, this message translates to:
  /// **'Interval split: {p0} and {p1}'**
  String intervalSplitAnd(String p0, String p1);

  /// No description provided for @issue480.
  ///
  /// In en, this message translates to:
  /// **'Issue: {p0}'**
  String issue480(String p0);

  /// No description provided for @totalDuration.
  ///
  /// In en, this message translates to:
  /// **'Total duration: {p0}'**
  String totalDuration(String p0);

  /// No description provided for @firstPartDescription.
  ///
  /// In en, this message translates to:
  /// **'First part description'**
  String get firstPartDescription;

  /// No description provided for @workDoneInTheFirstPart.
  ///
  /// In en, this message translates to:
  /// **'Work done in the first part...'**
  String get workDoneInTheFirstPart;

  /// No description provided for @secondPartDescription.
  ///
  /// In en, this message translates to:
  /// **'Second part description'**
  String get secondPartDescription;

  /// No description provided for @workDoneInTheSecondPart.
  ///
  /// In en, this message translates to:
  /// **'Work done in the second part...'**
  String get workDoneInTheSecondPart;

  /// No description provided for @h486.
  ///
  /// In en, this message translates to:
  /// **'{p0} h'**
  String h486(String p0);

  /// No description provided for @hMin.
  ///
  /// In en, this message translates to:
  /// **'{p0} h {p1} min'**
  String hMin(String p0, String p1);

  /// No description provided for @break488.
  ///
  /// In en, this message translates to:
  /// **'Break · {p0}–{p1} ({p2})'**
  String break488(String p0, String p1, String p2);

  /// No description provided for @alreadyInJira489.
  ///
  /// In en, this message translates to:
  /// **'{p0} · already in Jira · {p1}–{p2}'**
  String alreadyInJira489(String p0, String p1, String p2);

  /// No description provided for @selectedLogs.
  ///
  /// In en, this message translates to:
  /// **'Selected logs'**
  String get selectedLogs;

  /// No description provided for @issueAdded.
  ///
  /// In en, this message translates to:
  /// **'Issue added: {p0} — {p1}'**
  String issueAdded(String p0, String p1);

  /// No description provided for @couldNotAddTheIssue.
  ///
  /// In en, this message translates to:
  /// **'Could not add the issue'**
  String get couldNotAddTheIssue;

  /// No description provided for @work493.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get work493;

  /// No description provided for @pasteAJiraIssueIdOrLink.
  ///
  /// In en, this message translates to:
  /// **'Paste a Jira issue ID or link'**
  String get pasteAJiraIssueIdOrLink;

  /// No description provided for @frequentlyUsedIssuesHaveNotBeenConfiguredYet.
  ///
  /// In en, this message translates to:
  /// **'Frequently used issues have not been configured yet.'**
  String get frequentlyUsedIssuesHaveNotBeenConfiguredYet;

  /// No description provided for @configureQuickIssues.
  ///
  /// In en, this message translates to:
  /// **'Configure quick issues'**
  String get configureQuickIssues;

  /// No description provided for @recentIssues497.
  ///
  /// In en, this message translates to:
  /// **'Recent issues'**
  String get recentIssues497;

  /// No description provided for @start498.
  ///
  /// In en, this message translates to:
  /// **'Start ({p0})'**
  String start498(String p0);

  /// No description provided for @selectMultiple.
  ///
  /// In en, this message translates to:
  /// **'Select multiple'**
  String get selectMultiple;

  /// No description provided for @searchIssues.
  ///
  /// In en, this message translates to:
  /// **'Search issues'**
  String get searchIssues;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @activityFilter.
  ///
  /// In en, this message translates to:
  /// **'Activity filter'**
  String get activityFilter;

  /// No description provided for @lastDays.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get lastDays;

  /// No description provided for @lastDays504.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get lastDays504;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get allTime;

  /// No description provided for @noIssuesAddedEnterAKeyIdOr.
  ///
  /// In en, this message translates to:
  /// **'No issues added.\nEnter a key, ID or link above.'**
  String get noIssuesAddedEnterAKeyIdOr;

  /// No description provided for @noIssuesMatchTheFilter.
  ///
  /// In en, this message translates to:
  /// **'No issues match the filter.'**
  String get noIssuesMatchTheFilter;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity: {p0}'**
  String activity(String p0);

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @start510.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start510;

  /// No description provided for @queue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get queue;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total {p0}'**
  String total(String p0);

  /// No description provided for @pauseAllTimers.
  ///
  /// In en, this message translates to:
  /// **'Pause all timers'**
  String get pauseAllTimers;

  /// No description provided for @theLogQueueIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'The log queue is empty'**
  String get theLogQueueIsEmpty;

  /// No description provided for @startAnIssueTimerOrAddTimeManually.
  ///
  /// In en, this message translates to:
  /// **'Start an issue timer or add time manually.'**
  String get startAnIssueTimerOrAddTimeManually;

  /// No description provided for @removeLogFromDraftFor.
  ///
  /// In en, this message translates to:
  /// **'Remove log from draft for {p0}'**
  String removeLogFromDraftFor(String p0);

  /// No description provided for @dayContentsCannotBeChangedAfterSubmissionHas.
  ///
  /// In en, this message translates to:
  /// **'Day contents cannot be changed after submission has started'**
  String get dayContentsCannotBeChangedAfterSubmissionHas;

  /// No description provided for @entryIsAlreadyIncludedInTheDayFor.
  ///
  /// In en, this message translates to:
  /// **'Entry is already included in the day for {p0}'**
  String entryIsAlreadyIncludedInTheDayFor(String p0);

  /// No description provided for @selectForDayBuild.
  ///
  /// In en, this message translates to:
  /// **'Select for day build'**
  String get selectForDayBuild;

  /// No description provided for @pauseTheTimerBeforeSelectingItForDay.
  ///
  /// In en, this message translates to:
  /// **'Pause the timer before selecting it for day build'**
  String get pauseTheTimerBeforeSelectingItForDay;

  /// No description provided for @pauseTimer.
  ///
  /// In en, this message translates to:
  /// **'Pause timer'**
  String get pauseTimer;

  /// No description provided for @stopTheTimerToAddThisEntryTo.
  ///
  /// In en, this message translates to:
  /// **'Stop the timer to add this entry to a day.'**
  String get stopTheTimerToAddThisEntryTo;

  /// No description provided for @systemClockMovedBackwards.
  ///
  /// In en, this message translates to:
  /// **'System clock moved backwards!'**
  String get systemClockMovedBackwards;

  /// No description provided for @created.
  ///
  /// In en, this message translates to:
  /// **'Created: {p0}'**
  String created(String p0);

  /// No description provided for @inDayOpen.
  ///
  /// In en, this message translates to:
  /// **'In day {p0} · Open'**
  String inDayOpen(String p0);

  /// No description provided for @actionsForAnEntryInAnotherDay.
  ///
  /// In en, this message translates to:
  /// **'Actions for an entry in another day'**
  String get actionsForAnEntryInAnotherDay;

  /// No description provided for @removeFromDay.
  ///
  /// In en, this message translates to:
  /// **'Remove from day {p0}'**
  String removeFromDay(String p0);

  /// No description provided for @logActions.
  ///
  /// In en, this message translates to:
  /// **'Log actions'**
  String get logActions;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @mergeWith.
  ///
  /// In en, this message translates to:
  /// **'Merge with…'**
  String get mergeWith;

  /// No description provided for @noSubmittedLogsInHistoryYet.
  ///
  /// In en, this message translates to:
  /// **'No submitted logs in history yet.'**
  String get noSubmittedLogsInHistoryYet;

  /// No description provided for @submissionHistoryIsStoredOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Submission history is stored on this device'**
  String get submissionHistoryIsStoredOnThisDevice;

  /// No description provided for @noEntriesSelectedFor.
  ///
  /// In en, this message translates to:
  /// **'No entries selected for {p0}'**
  String noEntriesSelectedFor(String p0);

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'Selected {p0} {p1}'**
  String selected(String p0, String p1);

  /// No description provided for @recordedTime.
  ///
  /// In en, this message translates to:
  /// **' recorded time'**
  String get recordedTime;

  /// No description provided for @buildFor.
  ///
  /// In en, this message translates to:
  /// **'Build for'**
  String get buildFor;

  /// No description provided for @dayBuildDate.
  ///
  /// In en, this message translates to:
  /// **'Day build date'**
  String get dayBuildDate;

  /// No description provided for @monday539.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday539;

  /// No description provided for @tuesday540.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get tuesday540;

  /// No description provided for @wednesday541.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get wednesday541;

  /// No description provided for @thursday542.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get thursday542;

  /// No description provided for @friday543.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get friday543;

  /// No description provided for @saturday544.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get saturday544;

  /// No description provided for @sunday545.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday545;

  /// No description provided for @entries.
  ///
  /// In en, this message translates to:
  /// **'entries'**
  String get entries;

  /// No description provided for @entry.
  ///
  /// In en, this message translates to:
  /// **'entry'**
  String get entry;

  /// No description provided for @entries548.
  ///
  /// In en, this message translates to:
  /// **'entries'**
  String get entries548;

  /// No description provided for @deleteTimeEntry.
  ///
  /// In en, this message translates to:
  /// **'Delete time entry?'**
  String get deleteTimeEntry;

  /// No description provided for @entryWillBePermanentlyDeleted.
  ///
  /// In en, this message translates to:
  /// **'Entry \"{p0}\" ({p1}) will be permanently deleted.'**
  String entryWillBePermanentlyDeleted(String p0, String p1);

  /// No description provided for @entrySuccessfullyFoundAndConfirmedInJiraId.
  ///
  /// In en, this message translates to:
  /// **'Entry successfully found and confirmed in Jira (ID: {p0}).'**
  String entrySuccessfullyFoundAndConfirmedInJiraId(String p0);

  /// No description provided for @theJiraTimeTrackerSegmentPropertyWasNot.
  ///
  /// In en, this message translates to:
  /// **'The jira-time-tracker.segment property was not found among the issue\'s Jira entries. Blind resubmission is prohibited.'**
  String get theJiraTimeTrackerSegmentPropertyWasNot;

  /// No description provided for @connectionMismatchTheDraftBelongsToSiteAccount.
  ///
  /// In en, this message translates to:
  /// **'Connection mismatch: the draft belongs to site/account \"{p0}\" but the current connection is \"{p1}\". Submission is blocked.'**
  String connectionMismatchTheDraftBelongsToSiteAccount(String p0, String p1);

  /// No description provided for @theDraftIsEmptyThereAreNoIntervals.
  ///
  /// In en, this message translates to:
  /// **'The draft is empty, there are no intervals to submit.'**
  String get theDraftIsEmptyThereAreNoIntervals;

  /// No description provided for @jiraRejectedTheRequest.
  ///
  /// In en, this message translates to:
  /// **'Jira rejected the request'**
  String get jiraRejectedTheRequest;

  /// No description provided for @unknownSubmissionResultTheConnectionMayHaveBeen.
  ///
  /// In en, this message translates to:
  /// **'Unknown submission result (the connection may have been lost)'**
  String get unknownSubmissionResultTheConnectionMayHaveBeen;

  /// No description provided for @conflictMultipleEntriesFoundWithSegmentIdManual.
  ///
  /// In en, this message translates to:
  /// **'Conflict: multiple ({p0}) entries found with segment id \"{p1}\". Manual checking is required.'**
  String conflictMultipleEntriesFoundWithSegmentIdManual(String p0, String p1);

  /// No description provided for @conflictAnEntryWithTheSameSegmentId.
  ///
  /// In en, this message translates to:
  /// **'Conflict: an entry with the same segment id was found, but its parameters differ (author: {p0}, duration: {p1}, time: {p2}).'**
  String conflictAnEntryWithTheSameSegmentId(String p0, String p1, String p2);

  /// No description provided for @networkErrorDuringReconciliation.
  ///
  /// In en, this message translates to:
  /// **'Network error during reconciliation: {p0}'**
  String networkErrorDuringReconciliation(String p0);

  /// No description provided for @entryWithIdWasNotFoundInIssue.
  ///
  /// In en, this message translates to:
  /// **'Entry with ID \"{p0}\" was not found in issue \"{p1}\".'**
  String entryWithIdWasNotFoundInIssue(String p0, String p1);

  /// No description provided for @theEntryBelongsToAnotherJiraUserAccountid.
  ///
  /// In en, this message translates to:
  /// **'The entry belongs to another Jira user (accountId: {p0}).'**
  String theEntryBelongsToAnotherJiraUserAccountid(String p0);

  /// No description provided for @jiraEntryDurationSDoesNotMatchThe.
  ///
  /// In en, this message translates to:
  /// **'Jira entry duration ({p0} s) does not match the segment ({p1} s).'**
  String jiraEntryDurationSDoesNotMatchThe(String p0, String p1);

  /// No description provided for @errorCheckingTheJiraEntry.
  ///
  /// In en, this message translates to:
  /// **'Error checking the Jira entry: {p0}'**
  String errorCheckingTheJiraEntry(String p0);

  /// No description provided for @resetByUserConfirmedTheEntryDoesNot.
  ///
  /// In en, this message translates to:
  /// **'Reset by user: confirmed the entry does not exist in Jira; retry is allowed'**
  String get resetByUserConfirmedTheEntryDoesNot;

  /// No description provided for @breakLabel.
  ///
  /// In en, this message translates to:
  /// **'Break'**
  String get breakLabel;

  /// No description provided for @submissionInterruptedAtStartup.
  ///
  /// In en, this message translates to:
  /// **'Interrupted before confirmation (recovered at startup)'**
  String get submissionInterruptedAtStartup;

  /// No description provided for @directApi.
  ///
  /// In en, this message translates to:
  /// **'Direct API'**
  String get directApi;

  /// No description provided for @retryAfterSeconds.
  ///
  /// In en, this message translates to:
  /// **'. Retry after {seconds} s.'**
  String retryAfterSeconds(String seconds);

  /// No description provided for @mismatch.
  ///
  /// In en, this message translates to:
  /// **'does not match'**
  String get mismatch;

  /// No description provided for @scheduleEntryCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {{count} entry} other {{count} entries}} in the schedule'**
  String scheduleEntryCount(int count);

  /// No description provided for @scheduleErrorCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {{count} error} other {{count} errors}} · submission to Jira is blocked'**
  String scheduleErrorCount(int count);

  /// No description provided for @readOnlyLanguage.
  ///
  /// In en, this message translates to:
  /// **'The language cannot be changed in read-only mode.'**
  String get readOnlyLanguage;

  /// No description provided for @selectedLogCount.
  ///
  /// In en, this message translates to:
  /// **'Selected {count, plural, one {{count} entry} other {{count} entries}}'**
  String selectedLogCount(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
