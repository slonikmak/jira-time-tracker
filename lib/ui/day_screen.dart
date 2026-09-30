import 'package:flutter/material.dart';
import '../app_state.dart';
import '../log_clock.dart';
import '../models.dart';
import '../worklog_sender.dart';
import 'app_theme.dart';
import 'gap_actions_dialog.dart';
import 'edit_segment_dialog.dart';
import 'merge_segments_dialog.dart';
import 'split_segment_dialog.dart';
import 'timeline_track_bar.dart';

/// Экран «День»: календарь, сборщик расписания, инспекция пауз и редактирование сегментов.
class DayScreen extends StatelessWidget {
  final AppState appState;

  const DayScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final hasDraft = appState.currentDraft != null;
        final hasExistingWorklogs = appState.importedWorklogs.isNotEmpty;
        final hasDayData = hasDraft || hasExistingWorklogs;
        return Scaffold(
          body: Column(
            children: [
              _buildHeader(context),
              if (hasDraft) _buildSummaryStats(context),
              if (hasDraft) _buildTimeline(context),
              if (hasDraft) _buildSubmissionNotice(context),

              if (hasDraft && appState.validationErrors.isNotEmpty)
                _buildValidationErrors(context),
              Expanded(
                child: hasDayData
                    ? _buildDayGrid(context)
                    : _buildEmptyDay(context),
              ),
              if (hasDraft) _buildSubmissionFooter(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeline(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Шкала дня', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          TimelineTrackBar(
            draft: appState.currentDraft!,
            segments: appState.currentSegments,
            breaks: appState.currentBreaks,
            existingWorklogs: appState.importedWorklogs,
            issueKeys: {for (final i in appState.issues) i.issueId: i.key},
            onEditSegment: (seg) {
              final issue = appState.issues
                  .where((i) => i.issueId == seg.issueId)
                  .firstOrNull;
              _openEditSegmentDialog(
                context,
                seg,
                issue == null ? 'Задача' : '${issue.key} · ${issue.summary}',
              );
            },
            onEditBreak: (breakItem) =>
                _openGapActionsDialog(context, breakItem),
            isReadOnly:
                appState.isReadOnly || appState.isDraftLockedFromRebuild,
            onResizeSegmentRight: (seg, newDuration) {
              try {
                appState.resizeSegmentRight(seg, newDuration);
              } catch (error) {
                _showEditError(context, error);
              }
            },
            onResizeSegmentLeft: (seg, newStart) {
              try {
                appState.resizeSegmentLeft(seg, newStart);
              } catch (error) {
                _showEditError(context, error);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showEditError(BuildContext context, Object error) {
    final message = error is ArgumentError
        ? (error.message?.toString() ?? error.toString())
        : error.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Widget _buildSubmissionNotice(BuildContext context) {
    final segments = appState.currentSegments;
    final sent = segments.where((s) => s.sendState == SendState.sent).length;
    final failed = segments
        .where((s) => s.sendState == SendState.failed)
        .length;
    final unknown = segments
        .where((s) => s.sendState == SendState.unknown)
        .length;
    if (failed == 0 && unknown == 0) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = unknown > 0
        ? 'Нужно проверить результат отправки'
        : sent > 0
        ? 'День отправлен частично'
        : 'Не удалось отправить записи';
    final detail = unknown > 0
        ? '$sent отправлено, $failed с ошибкой, $unknown с неизвестным результатом. Повторная отправка неизвестных записей заблокирована.'
        : '$sent отправлено, $failed не отправлено. Можно повторить отправку неуспешных записей.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.warnBg(isDark),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.warn(isDark)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted(isDark),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date = appState.selectedDate;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

    final draft = appState.currentDraft;
    final subtitle = draft == null
        ? appState.isFetchingJiraWorklogs
              ? 'Загружаем записи из Jira...'
              : appState.importedWorklogs.isNotEmpty
              ? 'Записи Jira за выбранный день'
              : appState.hasLoadedJiraWorklogs
              ? 'Записей Jira за выбранный день нет'
              : 'Соберите расписание из выбранных логов'
        : draft.status == DraftStatus.completed
        ? 'Все записи отправлены'
        : appState.isDraftLockedFromRebuild
        ? 'Результат отправки'
        : '${_weekdayName(date.weekday)} · Черновик сохранён на устройстве';

    Future<void> pickDate() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: appState.selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
        helpText: 'Выберите дату',
        cancelText: 'Отмена',
        confirmText: 'Выбрать',
      );
      if (picked != null) appState.setSelectedDate(picked);
    }

    final dateMenu = PopupMenuButton<String>(
      tooltip: 'Другие действия с расписанием',
      onSelected: (action) {
        switch (action) {
          case 'date':
            pickDate();
          case 'previous':
            appState.previousDay();
          case 'next':
            appState.nextDay();
          case 'today':
            appState.today();
          case 'refresh':
            appState.fetchJiraWorklogsForDate();
          case 'rebuild':
            _confirmRebuildCurrentDay(context);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'date', child: Text('Выбрать дату ($dateStr)')),
        const PopupMenuItem(value: 'previous', child: Text('Предыдущий день')),
        const PopupMenuItem(value: 'next', child: Text('Следующий день')),
        const PopupMenuItem(value: 'today', child: Text('Сегодня')),
        PopupMenuItem(
          value: 'refresh',
          enabled: !appState.isFetchingJiraWorklogs,
          child: const Text('Обновить записи из Jira'),
        ),
        if (draft != null) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'rebuild',
            enabled: !appState.isReadOnly && !appState.isDraftLockedFromRebuild,
            child: const Text('Пересобрать день'),
          ),
        ],
      ],
      child: const Padding(
        padding: EdgeInsets.only(left: 12),
        child: Icon(Icons.keyboard_arrow_down, size: 20),
      ),
    );

    final hasSendResults = appState.currentSegments.any(
      (segment) => segment.sendState != SendState.pending,
    );
    final controls = <Widget>[
      if (hasSendResults)
        TextButton.icon(
          onPressed: () => _showSubmissionResults(context),
          icon: const Icon(Icons.receipt_long_outlined, size: 16),
          label: const Text('Результаты отправки'),
        ),
      if (draft != null)
        OutlinedButton.icon(
          icon: const Icon(Icons.delete_sweep_outlined, size: 16),
          label: const Text('Очистить'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            textStyle: const TextStyle(fontSize: 13),
          ),
          onPressed: appState.canClearCurrentDay
              ? () => _confirmClearCurrentDay(context)
              : null,
        ),
      if (draft != null)
        OutlinedButton.icon(
          icon: const Icon(Icons.auto_awesome, size: 16),
          label: const Text('Умная пересборка'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 36),
            visualDensity: VisualDensity.standard,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            textStyle: const TextStyle(fontSize: 13),
          ),
          onPressed: appState.isReadOnly || appState.isDraftLockedFromRebuild
              ? null
              : () => _confirmSmartRebuild(context),
        ),
    ];

    final dateTitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: pickDate,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                alignment: Alignment.centerLeft,
              ),
              child: Text(
                '${date.day} ${_monthName(date.month)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 29,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            dateMenu,
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: AppColors.muted(isDark)),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 32, 40, 28),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 1040) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                dateTitle,
                const SizedBox(height: 6),
                Wrap(spacing: 2, runSpacing: 2, children: controls),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: dateTitle),
              Row(mainAxisSize: MainAxisSize.min, children: controls),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryStats(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final draft = appState.currentDraft!;
    final start = _formatTime(draft.startUtc.toLocal());
    final end = _formatTime(draft.endUtc.toLocal());
    final sentSegments = appState.currentSegments
        .where((segment) => segment.sendState == SendState.sent)
        .toList();
    final hasSent = sentSegments.isNotEmpty;
    final sentDuration = sentSegments.fold<int>(
      0,
      (sum, segment) => sum + segment.durationSeconds,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(40, 0, 40, 18),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        border: Border.symmetric(
          horizontal: BorderSide(color: AppColors.line(isDark)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final metrics = [
            _DayMetric(
              label: 'Границы дня',
              value: '$start — $end',
              detail:
                  'Весь день: ${LogClock.formatHoursMinutes(appState.totalDayDurationSeconds)} с паузами',
            ),
            _DayMetric(
              label: hasSent ? 'Отправлено' : 'Новое время',
              value: LogClock.formatHoursMinutes(
                hasSent ? sentDuration : appState.totalSegmentsDurationSeconds,
              ),
              detail: hasSent
                  ? '${sentSegments.length} из ${appState.currentSegments.length} записей'
                  : appState.currentSegments.any(
                      (segment) =>
                          segment.sendState == SendState.failed ||
                          segment.sendState == SendState.unknown,
                    )
                  ? '${appState.currentSegments.length} записей в расписании'
                  : '${appState.currentSegments.length} записей к отправке',
              color: hasSent
                  ? AppColors.green(isDark)
                  : AppColors.primary(isDark),
            ),
            _DayMetric(
              label: 'Уже в Jira',
              value: LogClock.formatHoursMinutes(
                appState.totalExistingDurationSeconds,
              ),
              detail: 'Не отправляется повторно',
              color: AppColors.text(isDark),
            ),
            _DayMetric(
              label: 'Паузы',
              value: LogClock.formatHoursMinutes(
                appState.totalBreaksDurationSeconds,
              ),
              detail: 'Не входят в рабочее время',
            ),
          ];
          if (constraints.maxWidth < 760) {
            return Wrap(
              children: metrics
                  .map(
                    (metric) => SizedBox(
                      width: constraints.maxWidth / 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: metric,
                      ),
                    ),
                  )
                  .toList(),
            );
          }
          return Row(
            children: [
              for (var i = 0; i < metrics.length; i++) ...[
                if (i > 0)
                  Container(
                    width: 1,
                    height: 80,
                    color: AppColors.line(isDark),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: metrics[i],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildDayGrid(BuildContext context) {
    final now = appState.nowProvider().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final showSources =
        appState.currentDraft != null || !appState.selectedDate.isBefore(today);

    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 5, 40, 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!showSources) return _buildSchedulePanel(context);
          if (constraints.maxWidth < 930) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 420, child: _buildSchedulePanel(context)),
                  const SizedBox(height: 20),
                  SizedBox(height: 280, child: _buildSourcesPanel(context)),
                ],
              ),
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildSchedulePanel(context)),
              const SizedBox(width: 36),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.line(
                  Theme.of(context).brightness == Brightness.dark,
                ),
              ),
              const SizedBox(width: 27),
              SizedBox(width: 302, child: _buildSourcesPanel(context)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSubmissionResults(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final segments = [...appState.currentSegments]
      ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
    final hasUnknown = segments.any((s) => s.sendState == SendState.unknown);
    final hasFailed = segments.any((s) => s.sendState == SendState.failed);
    final note = appState.isDraftLockedFromRebuild
        ? 'Пересборка недоступна после начала отправки. Сначала нужно разрешить все результаты.'
        : hasUnknown
        ? 'Сверьте неизвестные результаты перед повторной отправкой.'
        : hasFailed
        ? 'Повторная отправка затронет только неотправленные записи.'
        : 'Успешные записи не отправляются повторно.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 5, 40, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Записи этого дня',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Text(
                'Успешные записи не отправляются повторно',
                style: TextStyle(fontSize: 11, color: AppColors.muted(isDark)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.line(isDark)),
          Expanded(
            child: ListView.separated(
              itemCount: segments.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, color: AppColors.line(isDark)),
              itemBuilder: (context, index) =>
                  _buildSubmissionResultRow(context, segments[index]),
            ),
          ),
          Divider(height: 1, color: AppColors.line(isDark)),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              note,
              style: TextStyle(fontSize: 11, color: AppColors.muted(isDark)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSubmissionResults(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 1000,
          height: MediaQuery.sizeOf(dialogContext).height * .72,
          child: ListenableBuilder(
            listenable: appState,
            builder: (context, _) => _buildSubmissionResults(context),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmissionResultRow(BuildContext context, Segment segment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final start = segment.startUtc.toLocal();
    final end = segment.endUtc.toLocal();
    final timeRange = '${_formatTime(start)} — ${_formatTime(end)}';
    final issue = appState.issues
        .where((item) => item.issueId == segment.issueId)
        .firstOrNull;
    final issueKey = issue?.key ?? segment.issueId;
    final title = issue?.summary ?? issueKey;
    final status = switch (segment.sendState) {
      SendState.pending => (
        'Ожидает отправки',
        Icons.hourglass_empty,
        AppColors.muted(isDark),
      ),
      SendState.sending => (
        'Отправка...',
        Icons.sync,
        AppColors.primary(isDark),
      ),
      SendState.sent => (
        'Отправлено',
        Icons.check_circle_outline,
        AppColors.green(isDark),
      ),
      SendState.failed => (
        'Не отправлено',
        Icons.error_outline,
        AppColors.error(isDark),
      ),
      SendState.unknown => (
        'Проверяем результат',
        Icons.sync,
        AppColors.warn(isDark),
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 138,
            child: Text(
              timeRange,
              style: TextStyle(
                fontFamily: 'IBM Plex Mono',
                fontSize: 11,
                color: AppColors.muted(isDark),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      issueKey,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary(isDark),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  segment.description.isNotEmpty
                      ? segment.description
                      : '(без описания)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.muted(isDark),
                  ),
                ),
                if (segment.jiraWorklogId != null)
                  Text(
                    'Jira #${segment.jiraWorklogId}',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.muted(isDark),
                    ),
                  ),
                if (segment.lastError?.isNotEmpty == true)
                  Text(
                    segment.lastError!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.warn(isDark),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 54,
            child: Text(
              LogClock.formatHoursMinutes(segment.durationSeconds),
              textAlign: TextAlign.right,
              style: const TextStyle(fontFamily: 'IBM Plex Mono', fontSize: 11),
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 164,
            child: Row(
              children: [
                Icon(status.$2, size: 16, color: status.$3),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    status.$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: status.$3),
                  ),
                ),
              ],
            ),
          ),
          if (segment.sendState == SendState.unknown)
            PopupMenuButton<String>(
              tooltip: 'Действия для неопределённого результата',
              enabled: !appState.isReadOnly,
              onSelected: (action) {
                if (action == 'reconcile') {
                  _handleReconcileSegment(context, segment);
                } else {
                  _openManualResolveDialog(context, segment);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'reconcile',
                  child: Text('Сверить результат (A15)'),
                ),
                PopupMenuItem(
                  value: 'resolve',
                  child: Text('Разрешить вручную (A15)'),
                ),
              ],
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildEmptyDay(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final jiraLoadFailed = appState.jiraWorklogsLoadFailed;
    if (appState.isFetchingJiraWorklogs) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Загружаем записи из Jira...'),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 30,
            color: AppColors.muted(isDark),
          ),
          const SizedBox(height: 14),
          Text(
            jiraLoadFailed
                ? 'Не удалось загрузить записи Jira'
                : appState.hasLoadedJiraWorklogs
                ? 'Записей Jira за этот день нет'
                : 'Соберите день из своих логов',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            jiraLoadFailed
                ? 'Повторите загрузку через меню у даты.'
                : 'На «Работе» выберите записи и нужную дату.',
            style: TextStyle(fontSize: 12, color: AppColors.muted(isDark)),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => appState.selectTab(0),
            child: const Text('Выбрать логи'),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationErrors(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final errors = appState.validationErrors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.warnBg(isDark),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.warn(isDark), size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Расписание требует проверки',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.warn(isDark),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${errors.length} ${errors.length == 1 ? 'ошибка' : 'ошибок'} · отправка в Jira заблокирована',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted(isDark),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Ошибки в расписании'),
                  content: SizedBox(
                    width: 560,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final error in errors)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                '• $error',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Закрыть'),
                    ),
                  ],
                ),
              ),
              child: const Text('Показать ошибки'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourcesPanel(BuildContext context) {
    final hasDraft = appState.currentDraft != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                hasDraft ? 'Источники' : 'Логи для включения',
                style: Theme.of(context).textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          hasDraft ? 'Исходное время → в расписании' : 'Выберите логи для дня',
          style: TextStyle(fontSize: 11, color: AppColors.muted(isDark)),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: hasDraft
              ? _buildDraftSourcesList(context)
              : _buildQueueSelectionList(context),
        ),
      ],
    );
  }

  Widget _buildDraftSourcesList(BuildContext context) {
    final draftLogs = appState.currentDraftLogs;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (draftLogs.isEmpty) {
      return const Center(child: Text('Нет источников'));
    }

    return ListView.separated(
      itemCount: draftLogs.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final dl = draftLogs[index];
        final isLocked = appState.lockedSourceLogIds.contains(dl.sourceLogId);

        // Считаем сумму выделенного времени по сегментам этого лога
        final allocatedSec = appState.currentSegments
            .where((s) => s.sourceLogId == dl.sourceLogId)
            .fold<int>(0, (sum, s) => sum + s.durationSeconds);

        final srcLog = appState.logs.firstWhere(
          (l) => l.id == dl.sourceLogId,
          orElse: () => LocalLog(
            id: dl.sourceLogId,
            scope: appState.activeScope,
            issueId: '',
            titleSnapshot: dl.sourceLogId,
            accumulatedSeconds: dl.sourceDurationSeconds,
            createdAtUtc: DateTime.now().toUtc(),
          ),
        );
        final sourceIssue = appState.issues
            .where((issue) => issue.issueId == srcLog.issueId)
            .firstOrNull;

        final originalTime = LogClock.formatHoursMinutes(
          dl.sourceDurationSeconds,
        );
        final allocatedTime = LogClock.formatHoursMinutes(allocatedSec);

        return ListTile(
          dense: false,
          contentPadding: EdgeInsets.zero,
          minVerticalPadding: 12,
          title: Row(
            children: [
              if (sourceIssue != null) ...[
                Text(
                  sourceIssue.key,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.primary(isDark),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  srcLog.titleSnapshot,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '$originalTime → $allocatedTime',
                style: TextStyle(
                  color: isLocked
                      ? AppColors.warn(isDark)
                      : AppColors.primary(isDark),
                  fontWeight: FontWeight.w600,
                  fontFamily: 'IBM Plex Mono',
                  fontSize: 13,
                ),
              ),
              if (dl.descriptionSnapshot.isNotEmpty)
                Text(
                  dl.descriptionSnapshot,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.muted(isDark),
                  ),
                ),
            ],
          ),
          trailing: IconButton(
            icon: Icon(
              isLocked ? Icons.lock : Icons.lock_open_outlined,
              size: 18,
              color: isLocked
                  ? AppColors.primary(isDark)
                  : AppColors.muted(isDark),
            ),
            tooltip: isLocked
                ? 'Длительность зафиксирована (нажмите чтобы разблокировать)'
                : 'Зафиксировать длительность при пересборке',
            onPressed: () => appState.toggleLogLock(dl.sourceLogId),
          ),
        );
      },
    );
  }

  Widget _buildQueueSelectionList(BuildContext context) {
    final queue = appState.unconsumedLogs.where((l) => !l.isRunning).toList();

    if (queue.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'В очереди нет свободных остановленных логов. Добавьте время на вкладке «Работа».',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: queue.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final log = queue[index];
        final isSelected = appState.selectedLogIds.contains(log.id);
        final isInOtherDraft = appState.isLogInDraft(log.id);
        final draftDate = appState.getDraftDateForLog(log.id);
        final isLocked = appState.lockedSourceLogIds.contains(log.id);

        return CheckboxListTile(
          dense: true,
          value: isSelected,
          enabled: !isInOtherDraft,
          onChanged: isInOtherDraft
              ? null
              : (_) => appState.toggleLogSelection(log.id),
          title: Text(
            log.titleSnapshot,
            style: const TextStyle(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LogClock.formatHoursMinutes(log.accumulatedSeconds),
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
              if (isInOtherDraft)
                Text(
                  'В черновике на $draftDate',
                  style: const TextStyle(color: Colors.red, fontSize: 11),
                ),
            ],
          ),
          secondary: IconButton(
            icon: Icon(
              isLocked ? Icons.lock : Icons.lock_open_outlined,
              size: 18,
              color: isLocked ? Colors.amber.shade800 : Colors.grey,
            ),
            tooltip: isLocked
                ? 'Длительность зафиксирована'
                : 'Зафиксировать длительность',
            onPressed: () => appState.toggleLogLock(log.id),
          ),
        );
      },
    );
  }

  Widget _buildSchedulePanel(BuildContext context) {
    final hasDraft = appState.currentDraft != null;
    if (!hasDraft && appState.importedWorklogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_view_day, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'План на этот день ещё не собран',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Выберите логи слева и нажмите «Собрать день»',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Собрать день'),
              onPressed: appState.isReadOnly
                  ? null
                  : () => _handleBuildDay(context),
            ),
          ],
        ),
      );
    }

    // Собираем элементы расписания в хронологическом порядке
    final items = <_ScheduleItem>[];

    for (final s in appState.currentSegments) {
      items.add(_ScheduleItem.segment(s));
    }
    for (final b in appState.currentBreaks) {
      items.add(_ScheduleItem.breakItem(b));
    }
    for (final ew in appState.importedWorklogs) {
      items.add(_ScheduleItem.existingWorklog(ew));
    }

    final segOrder = {
      for (var i = 0; i < appState.currentSegments.length; i++)
        appState.currentSegments[i].id: i,
    };

    items.sort((a, b) {
      if (a.isSegment && b.isSegment) {
        return segOrder[a.segment!.id]!.compareTo(segOrder[b.segment!.id]!);
      }
      return a.startUtc.compareTo(b.startUtc);
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Расписание', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            Text(
              hasDraft
                  ? 'Нажмите на интервал, чтобы изменить'
                  : 'Записи Jira доступны только для чтения',
              style: TextStyle(fontSize: 12, color: AppColors.muted(isDark)),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: items.length,
            onReorder: (oldIndex, newIndex) {
              if (oldIndex < 0 || oldIndex >= items.length) return;
              final draggedItem = items[oldIndex];
              if (!draggedItem.isSegment) return;
              final draggedSegment = draggedItem.segment!;
              final oldSegIndex = appState.currentSegments.indexWhere(
                (s) => s.id == draggedSegment.id,
              );
              if (oldSegIndex == -1) return;
              final targetSegIndex = items
                  .take(newIndex)
                  .where((it) => it.isSegment)
                  .length;
              appState.reorderSegments(oldSegIndex, targetSegIndex);
            },
            itemBuilder: (context, index) {
              final item = items[index];
              final key = ValueKey(
                item.isSegment
                    ? 'seg_${item.segment!.id}'
                    : (item.isBreak
                          ? 'break_${item.breakItem!.id}'
                          : 'ew_${item.existingWorklog!.id}'),
              );

              if (item.isSegment) {
                return KeyedSubtree(
                  key: key,
                  child: _buildSegmentCard(
                    context,
                    item.segment!,
                    itemIndex: index,
                  ),
                );
              } else if (item.isBreak) {
                return KeyedSubtree(
                  key: key,
                  child: _buildBreakCard(context, item.breakItem!),
                );
              } else {
                return KeyedSubtree(
                  key: key,
                  child: _buildExistingWorklogCard(
                    context,
                    item.existingWorklog!,
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentCard(
    BuildContext context,
    Segment segment, {
    int? itemIndex,
  }) {
    final startLocal = segment.startUtc.toLocal();
    final endLocal = segment.endUtc.toLocal();
    final startStr =
        '${startLocal.hour.toString().padLeft(2, '0')}:${startLocal.minute.toString().padLeft(2, '0')}';
    final endStr =
        '${endLocal.hour.toString().padLeft(2, '0')}:${endLocal.minute.toString().padLeft(2, '0')}';
    final durationStr = LogClock.formatHoursMinutes(segment.durationSeconds);

    final issue = appState.issues.firstWhere(
      (i) => i.issueId == segment.issueId,
      orElse: () => Issue(
        scope: appState.activeScope,
        issueId: segment.issueId,
        key: segment.issueId,
        summary: '',
        lastUsedAtUtc: DateTime.now().toUtc(),
      ),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSent = segment.sendState == SendState.sent;
    final isLocked = appState.isReadOnly || appState.isDraftLockedFromRebuild;
    final segIndex = appState.currentSegments.indexWhere(
      (s) => s.id == segment.id,
    );
    final canMoveUp = !isSent && !isLocked && segIndex > 0;
    final canMoveDown =
        !isSent &&
        !isLocked &&
        segIndex != -1 &&
        segIndex < appState.currentSegments.length - 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      decoration: BoxDecoration(
        color: isSent ? AppColors.hover(isDark) : AppColors.selected(isDark),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          if (itemIndex != null && !isSent && !isLocked)
            ReorderableDragStartListener(
              index: itemIndex,
              child: Tooltip(
                message: 'Перетащить для изменения порядка',
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.drag_indicator,
                    size: 16,
                    color: AppColors.muted(isDark),
                  ),
                ),
              ),
            ),
          SizedBox(
            width: 116,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$startStr — $endStr',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Mono',
                      fontSize: 11,
                    ),
                  ),
                ),
                if (segment.isFixed)
                  Tooltip(
                    message: 'Время зафиксировано',
                    child: Icon(
                      Icons.lock,
                      size: 12,
                      color: AppColors.primary(isDark),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      issue.key,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary(isDark),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        issue.summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSendStateBadge(context, segment.sendState),
                    if (segment.jiraWorklogId != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '#${segment.jiraWorklogId}',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          fontSize: 10,
                          color: AppColors.muted(isDark),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  segment.description.isNotEmpty
                      ? segment.description
                      : '(без описания)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.muted(isDark),
                  ),
                ),
                if (segment.lastError?.isNotEmpty == true)
                  Text(
                    segment.lastError!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.warn(isDark),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 54,
            child: Text(
              durationStr,
              textAlign: TextAlign.right,
              style: const TextStyle(fontFamily: 'IBM Plex Mono', fontSize: 11),
            ),
          ),
          IconButton(
            key: ValueKey('edit-segment-$segIndex'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.edit_outlined, size: 16),
            tooltip: isSent
                ? 'Уже отправлено в Jira'
                : 'Редактировать интервал (A13)',
            onPressed:
                isSent ||
                    appState.isReadOnly ||
                    segment.sendState == SendState.unknown ||
                    segment.sendState == SendState.sending
                ? null
                : () => _openEditSegmentDialog(
                    context,
                    segment,
                    '${issue.key} · ${issue.summary}',
                  ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Другие действия',
            onSelected: (action) {
              switch (action) {
                case 'up':
                  appState.moveSegmentUp(segment.id);
                case 'down':
                  appState.moveSegmentDown(segment.id);
                case 'fixed':
                  appState.toggleSegmentFixed(segment.id);
                case 'split':
                  SplitSegmentDialog.show(
                    context,
                    appState: appState,
                    segment: segment,
                    issueKey: issue.key,
                  );
                case 'merge':
                  MergeSegmentsDialog.show(
                    context,
                    appState: appState,
                    segment: segment,
                  );
                case 'delete':
                  _confirmDeleteSegment(context, segment);
                case 'reconcile':
                  _handleReconcileSegment(context, segment);
                case 'resolve':
                  _openManualResolveDialog(context, segment);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'up',
                enabled: canMoveUp,
                child: const Text('Переместить вверх'),
              ),
              PopupMenuItem(
                value: 'down',
                enabled: canMoveDown,
                child: const Text('Переместить вниз'),
              ),
              PopupMenuItem(
                value: 'fixed',
                enabled: !isSent && !isLocked,
                child: Tooltip(
                  message: segment.isFixed
                      ? 'Снять фиксацию времени'
                      : 'Зафиксировать время',
                  child: Text(
                    segment.isFixed ? 'Снять фиксацию' : 'Зафиксировать время',
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'split',
                enabled: !isSent && !isLocked,
                child: const Tooltip(
                  message: 'Разбить интервал',
                  child: Text('Разбить интервал'),
                ),
              ),
              PopupMenuItem(
                value: 'merge',
                enabled:
                    !isSent && !isLocked && appState.currentSegments.length > 1,
                child: const Tooltip(
                  message: 'Объединить интервалы',
                  child: Text('Объединить интервалы'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                enabled: !isSent && !isLocked,
                child: const Text('Удалить интервал'),
              ),
              if (segment.sendState == SendState.unknown) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'reconcile',
                  enabled: !appState.isReadOnly,
                  child: Text('Сверить результат (A15)'),
                ),
                PopupMenuItem(
                  value: 'resolve',
                  enabled: !appState.isReadOnly,
                  child: Text('Разрешить вручную (A15)'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakCard(BuildContext context, Break breakItem) {
    final startLocal = breakItem.startUtc.toLocal();
    final endLocal = breakItem.endUtc.toLocal();
    final startStr =
        '${startLocal.hour.toString().padLeft(2, '0')}:${startLocal.minute.toString().padLeft(2, '0')}';
    final endStr =
        '${endLocal.hour.toString().padLeft(2, '0')}:${endLocal.minute.toString().padLeft(2, '0')}';
    final durationStr = LogClock.formatHoursMinutes(breakItem.durationSeconds);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = AppColors.muted(isDark);
    final isLocked = appState.isReadOnly || appState.isDraftLockedFromRebuild;

    return InkWell(
      onTap: isLocked ? null : () => _openGapActionsDialog(context, breakItem),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 116,
              child: Text(
                '$startStr — $endStr',
                style: TextStyle(
                  fontFamily: 'IBM Plex Mono',
                  fontSize: 11,
                  color: foreground,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.coffee_outlined, size: 15, color: foreground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Пауза',
                style: TextStyle(fontSize: 12, color: foreground),
              ),
            ),
            Text(
              durationStr,
              style: TextStyle(
                fontFamily: 'IBM Plex Mono',
                fontSize: 11,
                color: foreground,
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined, size: 16),
              tooltip: 'Редактировать интервал',
              onPressed: isLocked
                  ? null
                  : () => _openGapActionsDialog(context, breakItem),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingWorklogCard(BuildContext context, ImportedWorklog ew) {
    final startLocal = ew.startUtc.toLocal();
    final endLocal = ew.endUtc.toLocal();
    final startStr =
        '${startLocal.hour.toString().padLeft(2, '0')}:${startLocal.minute.toString().padLeft(2, '0')}';
    final endStr =
        '${endLocal.hour.toString().padLeft(2, '0')}:${endLocal.minute.toString().padLeft(2, '0')}';
    final durationStr = LogClock.formatHoursMinutes(ew.durationSeconds);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.hover(isDark),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 116,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$startStr — $endStr',
                    style: TextStyle(
                      fontFamily: 'IBM Plex Mono',
                      fontSize: 11,
                      color: AppColors.text(isDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.hover(isDark),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.line(isDark)),
                        ),
                        child: Text(
                          ew.issueKey ?? ew.issueId,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.muted(isDark),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Уже в Jira (только чтение)',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.muted(isDark),
                        ),
                      ),
                    ],
                  ),
                  if (ew.comment != null && ew.comment!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      ew.comment!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.text(isDark),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 54,
              child: Text(
                durationStr,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: 'IBM Plex Mono',
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendStateBadge(BuildContext context, SendState state) {
    if (state == SendState.pending) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color bg;
    Color fg;
    String text;

    switch (state) {
      case SendState.pending:
        bg = AppColors.hover(isDark);
        fg = AppColors.muted(isDark);
        text = 'Ожидает';
        break;
      case SendState.sending:
        bg = AppColors.selected(isDark);
        fg = AppColors.primary(isDark);
        text = 'Отправка...';
        break;
      case SendState.sent:
        bg = AppColors.greenBg(isDark);
        fg = AppColors.green(isDark);
        text = 'Отправлено';
        break;
      case SendState.failed:
        bg = AppColors.warnBg(isDark);
        fg = AppColors.error(isDark);
        text = 'Ошибка';
        break;
      case SendState.unknown:
        bg = AppColors.warnBg(isDark);
        fg = AppColors.warn(isDark);
        text = 'Не определено';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildSubmissionFooter(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final segments = appState.currentSegments;
    final isCompleted = appState.currentDraft?.status == DraftStatus.completed;
    final hasUnknown = segments.any((s) => s.sendState == SendState.unknown);
    final hasFailed = segments.any((s) => s.sendState == SendState.failed);
    final firstUnknown = segments
        .where((s) => s.sendState == SendState.unknown)
        .firstOrNull;
    final total = LogClock.formatHoursMinutes(
      appState.totalSegmentsDurationSeconds,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 27),
      decoration: BoxDecoration(
        color: AppColors.inset(isDark),
        border: Border(top: BorderSide(color: AppColors.line(isDark))),
      ),
      child: Row(
        children: [
          Icon(
            appState.validationErrors.isEmpty
                ? Icons.check_circle_outline
                : Icons.error_outline,
            size: 18,
            color: appState.validationErrors.isEmpty
                ? AppColors.green(isDark)
                : AppColors.error(isDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appState.validationErrors.isEmpty
                      ? 'План готов к отправке'
                      : 'В расписании есть ошибки',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  isCompleted
                      ? '$total · ${segments.length} записей отправлено'
                      : hasUnknown
                      ? 'Сначала проверьте неизвестный результат в Jira'
                      : hasFailed
                      ? '$total · ${segments.length} записей, есть ошибки отправки'
                      : 'В Jira будет добавлено $total · ${segments.length} записей',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.muted(isDark),
                  ),
                ),
              ],
            ),
          ),
          if (isCompleted)
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 36),
                visualDensity: VisualDensity.standard,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle: const TextStyle(fontSize: 13),
              ),
              onPressed: () => appState.selectTab(0),
              child: const Text('Вернуться к работе'),
            )
          else
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 36),
                visualDensity: VisualDensity.standard,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle: const TextStyle(fontSize: 13),
              ),
              icon: hasUnknown
                  ? const Icon(Icons.sync, size: 18)
                  : appState.isSubmittingDay
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined, size: 18),
              label: Text(
                hasUnknown
                    ? 'Проверить в Jira'
                    : hasFailed
                    ? 'Повторить отправку'
                    : 'Отправить в Jira',
              ),
              onPressed:
                  (appState.isBuildingDay ||
                      appState.isSubmittingDay ||
                      segments.isEmpty ||
                      appState.isReadOnly ||
                      (!hasUnknown && appState.validationErrors.isNotEmpty))
                  ? null
                  : hasUnknown
                  ? () => _handleReconcileSegment(context, firstUnknown!)
                  : () => _handleSendDraft(context),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  String _weekdayName(int weekday) => const [
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
    'Воскресенье',
  ][weekday - 1];

  String _monthName(int month) => const [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ][month - 1];

  void _handleBuildDay(BuildContext context) async {
    try {
      await appState.buildDay();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _confirmSmartRebuild(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Умная пересборка дня?'),
        content: const Text(
          'Текущий черновик будет заменён, а ручные правки времени исчезнут. Расписание будет оптимизировано с перерывами и разделением длинных задач.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handleSmartRebuildDay(context);
            },
            child: const Text('Пересобрать'),
          ),
        ],
      ),
    );
  }

  void _confirmClearCurrentDay(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Очистить день?'),
        content: const Text(
          'Все интервалы и паузы черновика будут удалены. Исходные логи вернутся в очередь. Записи Jira останутся на экране.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              try {
                appState.clearCurrentDay();
              } catch (error) {
                _showEditError(context, error);
              }
            },
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
  }

  void _confirmRebuildCurrentDay(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Пересобрать день?'),
        content: const Text(
          'Расписание будет построено заново с сохранением порядка и закреплённых интервалов. Ручные правки времени будут заменены.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _handleRebuildCurrentDay(context);
            },
            child: const Text('Пересобрать'),
          ),
        ],
      ),
    );
  }

  void _handleRebuildCurrentDay(BuildContext context) async {
    try {
      await appState.rebuildCurrentDay();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('День пересобран с сохранением порядка и якорей.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _handleSmartRebuildDay(BuildContext context) async {
    try {
      await appState.smartRebuildDay();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _openEditSegmentDialog(
    BuildContext context,
    Segment segment,
    String taskTitle,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => EditSegmentDialog(
        segment: segment,
        taskTitle: taskTitle,
        onDelete: appState.isReadOnly || appState.isDraftLockedFromRebuild
            ? null
            : () {
                Navigator.of(dialogContext).pop();
                _confirmDeleteSegment(context, segment);
              },
        onSave:
            ({
              required DateTime startUtc,
              required int durationSeconds,
              required String description,
            }) {
              appState.updateSegment(
                segmentId: segment.id,
                startUtc: startUtc,
                durationSeconds: durationSeconds,
                description: description,
              );
            },
      ),
    );
  }

  void _openGapActionsDialog(BuildContext context, Break breakItem) {
    if (appState.isReadOnly || appState.isDraftLockedFromRebuild) return;
    final neighbors = appState.findGapNeighbors(breakItem);

    showDialog(
      context: context,
      builder: (dialogCtx) => GapActionsDialog(
        breakItem: breakItem,
        neighbors: neighbors,
        onSnap: () {
          appState.snapGap(breakItem);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Пауза схлопнута, задачи подтянуты вплотную.'),
            ),
          );
        },
        onFillLeft: () {
          appState.fillGapWithLeftSegment(breakItem);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Предыдущая задача продлена на время паузы.'),
            ),
          );
        },
        onSetDuration: (newDurationSeconds) {
          appState.setGapDuration(
            gap: breakItem,
            newDurationSeconds: newDurationSeconds,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Длительность паузы обновлена.')),
          );
        },
        onValidateDuration: (newDurationSeconds) {
          final delta = newDurationSeconds - breakItem.durationSeconds;
          if (delta > 0) {
            return appState.canShiftSegmentsRight(
              afterUtc: breakItem.endUtc,
              deltaSeconds: delta,
            );
          }
          return null;
        },
      ),
    );
  }

  void _confirmDeleteSegment(BuildContext context, Segment segment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить интервал?'),
        content: const Text(
          'Интервал будет удален из расписания. Если это последний интервал задачи в данном дне, исходный лог будет возвращён обратно в очередь.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              appState.deleteSegment(segment.id);
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _handleSendDraft(BuildContext context) async {
    final result = await appState.submitCurrentDraft();
    if (!context.mounted) return;
    if (result != null) {
      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Успешно отправлено ${result.sent} записей в Jira!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (result.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Отправлено: ${result.sent}, Ошибок: ${result.failed}, Не определено: ${result.unknown}',
            ),
            backgroundColor: Colors.amber.shade800,
          ),
        );
      }
    }
  }

  void _handleReconcileSegment(BuildContext context, Segment segment) async {
    final res = await appState.reconcileSegment(segment);
    if (!context.mounted) return;
    if (res != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.status == ReconcileStatus.recovered
              ? Colors.green
              : (res.status == ReconcileStatus.conflict
                    ? Colors.red
                    : Colors.amber.shade800),
        ),
      );
    }
  }

  void _openManualResolveDialog(BuildContext context, Segment segment) {
    final idController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Разрешение неизвестного статуса (A15)'),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Сегмент находится в состоянии «Не определено» (ответ Jira был потерян или прерван). Слепой повтор запрещён.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Вариант 1: Указать ID созданной записи в Jira',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Приложение проверит автора, дату и длительность записи перед подтверждением:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: idController,
                          decoration: const InputDecoration(
                            labelText: 'Worklog ID (например: 10042)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          final text = idController.text.trim();
                          if (text.isEmpty) return;
                          Navigator.of(dialogCtx).pop();
                          final res = await appState.manuallyLinkWorklog(
                            segment,
                            text,
                          );
                          if (!context.mounted) return;
                          if (res != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  res.isSuccess
                                      ? 'Запись успешно подтверждена и связана!'
                                      : (res.errorMessage ?? 'Ошибка привязки'),
                                ),
                                backgroundColor: res.isSuccess
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.error,
                              ),
                            );
                          }
                        },
                        child: const Text('Связать'),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  const Text(
                    'Вариант 2: Подтвердить отсутствие записи',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Если вы открыли Jira в браузере и точно убедились, что в задаче нет этой записи, вы можете вернуть интервал в статус ожидания для повторной отправки.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.replay, size: 16),
                    label: const Text('Записи нет в Jira, разрешить повтор'),
                    onPressed: () {
                      Navigator.of(dialogCtx).pop();
                      appState.manuallyConfirmAbsenceAndAllowRetry(segment);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Интервал переведён в статус ожидания для повторной отправки.',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Отмена'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DayMetric extends StatelessWidget {
  final String label;
  final String value;
  final String? detail;
  final Color? color;

  const _DayMetric({
    required this.label,
    required this.value,
    this.detail,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.muted(isDark)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'IBM Plex Mono',
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: color ?? AppColors.text(isDark),
          ),
        ),
        if (detail != null) ...[
          const SizedBox(height: 5),
          Text(
            detail!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: AppColors.muted(isDark)),
          ),
        ],
      ],
    );
  }
}

class _ScheduleItem {
  final Segment? segment;
  final Break? breakItem;
  final ImportedWorklog? existingWorklog;

  const _ScheduleItem._({this.segment, this.breakItem, this.existingWorklog});

  factory _ScheduleItem.segment(Segment s) => _ScheduleItem._(segment: s);
  factory _ScheduleItem.breakItem(Break b) => _ScheduleItem._(breakItem: b);
  factory _ScheduleItem.existingWorklog(ImportedWorklog ew) =>
      _ScheduleItem._(existingWorklog: ew);

  bool get isSegment => segment != null;
  bool get isBreak => breakItem != null;
  bool get isExistingWorklog => existingWorklog != null;

  DateTime get startUtc {
    if (isSegment) return segment!.startUtc;
    if (isBreak) return breakItem!.startUtc;
    return existingWorklog!.startUtc;
  }
}
