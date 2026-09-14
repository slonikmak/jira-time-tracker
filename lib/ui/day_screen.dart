import 'package:flutter/material.dart';
import '../app_state.dart';
import '../log_clock.dart';
import '../models.dart';
import '../worklog_sender.dart';
import 'app_theme.dart';
import 'edit_segment_dialog.dart';
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
        return Scaffold(
          body: Column(
            children: [
              _buildHeader(context),
              _buildSummaryStats(context),
              if (appState.currentDraft != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: TimelineTrackBar(
                    draft: appState.currentDraft!,
                    segments: appState.currentSegments,
                    breaks: appState.currentBreaks,
                    issueKeys: {
                      for (final i in appState.issues) i.issueId: i.key,
                    },
                    onEditSegment: (seg) {
                      final key =
                          appState.issues
                              .where((i) => i.issueId == seg.issueId)
                              .firstOrNull
                              ?.key ??
                          'Задача';
                      _openEditSegmentDialog(context, seg, key);
                    },
                  ),
                ),
              if (appState.validationErrors.isNotEmpty)
                _buildValidationErrors(context),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Левая колонка: источники времени (логи)
                    SizedBox(width: 320, child: _buildSourcesPanel(context)),
                    const VerticalDivider(width: 1),
                    // Правая колонка: расписание дня
                    Expanded(child: _buildSchedulePanel(context)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date = appState.selectedDate;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        border: Border(
          bottom: BorderSide(color: AppColors.line(isDark), width: 1),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Предыдущий день',
                onPressed: () => appState.previousDay(),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month, size: 18),
                label: Text(
                  dateStr,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: appState.selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                    helpText: 'Выберите дату',
                    cancelText: 'Отмена',
                    confirmText: 'Выбрать',
                  );
                  if (picked != null) {
                    appState.setSelectedDate(picked);
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Следующий день',
                onPressed: () => appState.nextDay(),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: () => appState.today(),
                child: const Text('Сегодня'),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: appState.isFetchingJiraWorklogs
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync, size: 18),
                tooltip: 'Обновить записи из Jira',
                onPressed: appState.isFetchingJiraWorklogs
                    ? null
                    : () => appState.fetchJiraWorklogsForDate(),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (appState.currentDraft != null) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Пересобрать'),
                  onPressed: appState.isDraftLockedFromRebuild
                      ? null
                      : () => _confirmRebuild(context),
                ),
                const SizedBox(width: 8),
              ] else ...[
                FilledButton.icon(
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Собрать день'),
                  onPressed: appState.isReadOnly
                      ? null
                      : () => _handleBuildDay(context),
                ),
                const SizedBox(width: 8),
              ],
              if (appState.currentDraft?.status == DraftStatus.completed) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade400),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green.shade800,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Отправлен в Jira',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                FilledButton.icon(
                  icon: appState.isSubmittingDay
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: Text(
                    appState.currentSegments.any(
                          (s) => s.sendState == SendState.failed,
                        )
                        ? 'Повторить отправку'
                        : 'Отправить в Jira',
                  ),
                  onPressed:
                      (appState.currentDraft == null ||
                          appState.validationErrors.isNotEmpty ||
                          appState.isBuildingDay ||
                          appState.isSubmittingDay ||
                          appState.isReadOnly ||
                          appState.currentSegments.isEmpty)
                      ? null
                      : () => _handleSendDraft(context),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStats(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.surface,
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          _StatChip(
            label: 'Полный день',
            value: LogClock.formatHoursMinutes(
              appState.totalDayDurationSeconds,
            ),
            icon: Icons.access_time,
          ),
          _StatChip(
            label: 'Паузы',
            value: LogClock.formatHoursMinutes(
              appState.totalBreaksDurationSeconds,
            ),
            icon: Icons.coffee,
          ),
          _StatChip(
            label: 'Новое время',
            value: LogClock.formatHoursMinutes(
              appState.totalSegmentsDurationSeconds,
            ),
            icon: Icons.timelapse,
            color: Theme.of(context).colorScheme.primary,
          ),
          _StatChip(
            label: 'Уже в Jira',
            value: LogClock.formatHoursMinutes(
              appState.totalExistingDurationSeconds,
            ),
            icon: Icons.cloud_done_outlined,
            color: Colors.purple.shade700,
          ),
          _StatChip(
            label: 'Всего в Jira',
            value: LogClock.formatHoursMinutes(
              appState.totalJiraDurationSeconds,
            ),
            icon: Icons.check_circle_outline,
            color: Colors.teal.shade700,
          ),
        ],
      ),
    );
  }

  Widget _buildValidationErrors(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.errorContainer,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 20,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Text(
                'Ошибки валидации расписания (отправка заблокирована):',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...appState.validationErrors.map(
            (err) => Padding(
              padding: const EdgeInsets.only(left: 28, bottom: 2),
              child: Text(
                '• $err',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourcesPanel(BuildContext context) {
    final hasDraft = appState.currentDraft != null;
    final draftLogs = appState.currentDraftLogs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          child: Row(
            children: [
              const Icon(Icons.list_alt, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasDraft ? 'Источники черновика' : 'Логи для включения',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasDraft)
                Text(
                  '${draftLogs.length} шт.',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
        ),
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

        final originalTime = LogClock.formatHoursMinutes(
          dl.sourceDurationSeconds,
        );
        final allocatedTime = LogClock.formatHoursMinutes(allocatedSec);

        return ListTile(
          dense: true,
          title: Text(
            srcLog.titleSnapshot,
            style: const TextStyle(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$originalTime → $allocatedTime',
                style: TextStyle(
                  color: isLocked
                      ? Colors.amber.shade900
                      : Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (dl.descriptionSnapshot.isNotEmpty)
                Text(
                  dl.descriptionSnapshot,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
          trailing: IconButton(
            icon: Icon(
              isLocked ? Icons.lock : Icons.lock_open_outlined,
              size: 18,
              color: isLocked ? Colors.amber.shade800 : Colors.grey,
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
    if (appState.currentDraft == null) {
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

    items.sort((a, b) => a.startUtc.compareTo(b.startUtc));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.isSegment) {
          return _buildSegmentCard(context, item.segment!);
        } else if (item.isBreak) {
          return _buildBreakCard(context, item.breakItem!);
        } else {
          return _buildExistingWorklogCard(context, item.existingWorklog!);
        }
      },
    );
  }

  Widget _buildSegmentCard(BuildContext context, Segment segment) {
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

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Колонка времени
            SizedBox(
              width: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$startStr — $endStr',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    durationStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Описание и задача
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          issue.key,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          issue.summary,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildSendStateBadge(context, segment.sendState),
                      if (segment.jiraWorklogId != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '#${segment.jiraWorklogId}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    segment.description.isNotEmpty
                        ? segment.description
                        : '(без описания)',
                    style: TextStyle(
                      fontSize: 12,
                      color: segment.description.isNotEmpty
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.grey,
                    ),
                  ),
                  if (segment.lastError != null &&
                      segment.lastError!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      segment.lastError!,
                      style: TextStyle(
                        fontSize: 11,
                        color: segment.sendState == SendState.unknown
                            ? Colors.amber.shade900
                            : Colors.red.shade800,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (segment.sendState == SendState.unknown) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.sync, size: 14),
                          label: const Text(
                            'Сверить результат (A15)',
                            style: TextStyle(fontSize: 11),
                          ),
                          onPressed: () =>
                              _handleReconcileSegment(context, segment),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.help_outline, size: 14),
                          label: const Text(
                            'Разрешить вручную (A15)',
                            style: TextStyle(fontSize: 11),
                          ),
                          onPressed: () =>
                              _openManualResolveDialog(context, segment),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Кнопки действий: редактировать, удалить
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: segment.sendState == SendState.sent
                      ? 'Уже отправлено в Jira'
                      : 'Редактировать интервал (A13)',
                  onPressed: segment.sendState == SendState.sent
                      ? null
                      : () =>
                            _openEditSegmentDialog(context, segment, issue.key),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: segment.sendState == SendState.sent
                      ? 'Уже отправлено в Jira'
                      : 'Удалить интервал (A13)',
                  onPressed: segment.sendState == SendState.sent
                      ? null
                      : () => _confirmDeleteSegment(context, segment),
                ),
              ],
            ),
          ],
        ),
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
    final isLunch = breakItem.kind == BreakKind.lunch;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isLunch ? Colors.amber.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isLunch ? Colors.amber.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isLunch ? Icons.restaurant : Icons.coffee,
            size: 16,
            color: isLunch ? Colors.amber.shade800 : Colors.brown.shade400,
          ),
          const SizedBox(width: 8),
          Text(
            isLunch ? 'Обед' : 'Перерыв',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isLunch ? Colors.amber.shade900 : Colors.brown.shade700,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '$startStr — $endStr ($durationStr)',
            style: TextStyle(
              fontSize: 12,
              color: isLunch ? Colors.amber.shade900 : Colors.brown.shade600,
            ),
          ),
        ],
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

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.purple.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.purple.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$startStr — $endStr',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.purple.shade900,
                    ),
                  ),
                  Text(
                    durationStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple.shade700,
                      fontWeight: FontWeight.w600,
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
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ew.issueKey ?? ew.issueId,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Уже в Jira (только чтение)',
                        style: TextStyle(fontSize: 11, color: Colors.purple),
                      ),
                    ],
                  ),
                  if (ew.comment != null && ew.comment!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      ew.comment!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.purple.shade900,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendStateBadge(BuildContext context, SendState state) {
    Color bg;
    Color fg;
    String text;

    switch (state) {
      case SendState.pending:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
        text = 'Ожидает';
        break;
      case SendState.sending:
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade900;
        text = 'Отправка...';
        break;
      case SendState.sent:
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        text = 'Отправлено';
        break;
      case SendState.failed:
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        text = 'Ошибка';
        break;
      case SendState.unknown:
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
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

  void _confirmRebuild(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Пересобрать расписание?'),
        content: const Text(
          'Все ручные правки интервалов этого дня будут заменены новым автоматически сгенерированным расписанием.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handleBuildDay(context);
            },
            child: const Text('Пересобрать'),
          ),
        ],
      ),
    );
  }

  void _openEditSegmentDialog(
    BuildContext context,
    Segment segment,
    String taskTitle,
  ) {
    showDialog(
      context: context,
      builder: (context) => EditSegmentDialog(
        segment: segment,
        taskTitle: taskTitle,
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

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipColor = color ?? AppColors.text(isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.line(isDark)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: AppColors.muted(isDark)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: chipColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
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
