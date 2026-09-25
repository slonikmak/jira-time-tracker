import 'package:flutter/material.dart';
import '../app_state.dart';
import '../log_clock.dart';
import '../models.dart';
import 'add_time_dialog.dart';
import 'app_theme.dart';
import 'edit_log_dialog.dart';
import 'merge_logs_dialog.dart';
import 'split_log_dialog.dart';

/// Режим отображения правой колонки экрана «Работа».
enum WorkScreenQueueTab { queue, history }

/// Экран «Работа»:
/// - левая колонка: каталог задач Jira, таймеры, добавление времени
/// - правая колонка: очередь логов и история
class WorkScreen extends StatefulWidget {
  final AppState appState;
  final VoidCallback? onOpenQuickIssueSettings;

  const WorkScreen({
    super.key,
    required this.appState,
    this.onOpenQuickIssueSettings,
  });

  @override
  State<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends State<WorkScreen> {
  final TextEditingController _addController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _isAdding = false;
  bool _isSelectionMode = false;
  WorkScreenQueueTab _currentQueueTab = WorkScreenQueueTab.queue;

  @override
  void dispose() {
    _addController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Issue? _issueById(String issueId) {
    for (final issue in widget.appState.issues) {
      if (issue.issueId == issueId) return issue;
    }
    return null;
  }

  QuickIssue? _quickIssueFor(String issueId) {
    for (final quickIssue in widget.appState.quickIssues) {
      if (quickIssue.issueId == issueId) return quickIssue;
    }
    return null;
  }

  Future<void> _handleAddIssue() async {
    final text = _addController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isAdding = true;
    });

    try {
      final issue = await widget.appState.addIssue(text);
      _addController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Задача добавлена: ${issue.key} — ${issue.summary}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Не удалось добавить задачу'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 1125;
            final contentWidth = constraints.maxWidth - 80;
            final taskWidth = (contentWidth - 65) * .46;
            final dateLabel = _formatHeaderDate(widget.appState.selectedDate);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 32, 40, 0),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Работа',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        fontSize: 29,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.7,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dateLabel,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.muted(isDark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: OutlinedButton.icon(
                              key: const ValueKey('add-time-global'),
                              onPressed: () => AddTimeDialog.show(
                                context,
                                appState: widget.appState,
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 36),
                                visualDensity: VisualDensity.standard,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                textStyle: const TextStyle(fontSize: 14),
                              ),
                              icon: const Icon(Icons.add, size: 17),
                              label: const Text('Добавить время'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildAddIssueRow(context),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                Expanded(
                  child: isNarrow
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 310,
                                child: _buildTasksColumn(context),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 360,
                                child: _buildQueueColumn(context),
                              ),
                            ],
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: taskWidth,
                                child: _buildTasksColumn(context),
                              ),
                              const SizedBox(width: 31),
                              VerticalDivider(
                                width: 1,
                                thickness: 1,
                                color: AppColors.line(isDark),
                              ),
                              const SizedBox(width: 32),
                              Expanded(child: _buildQueueColumn(context)),
                            ],
                          ),
                        ),
                ),
                _buildBottomAssemblyBar(context),
              ],
            );
          },
        );
      },
    );
  }

  // --- Левая колонка: задачи ---

  Widget _buildAddIssueRow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: TextField(
              controller: _addController,
              decoration: InputDecoration(
                hintText: 'Вставьте ID или ссылку на задачу Jira',
                prefixIcon: const Icon(Icons.search, size: 18),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 44,
                ),
                isDense: true,
                filled: true,
                fillColor: isDark
                    ? AppColors.insetDark
                    : AppColors.hover(false),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _handleAddIssue(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: _isAdding ? null : _handleAddIssue,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            visualDensity: VisualDensity.standard,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            textStyle: const TextStyle(fontSize: 14),
          ),
          icon: _isAdding
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_forward, size: 16),
          label: const Text('Добавить задачу'),
        ),
        const SizedBox(width: 10),
        PopupMenuButton<String>(
          key: const ValueKey('quick-issues-menu'),
          tooltip: 'Быстрые задачи',
          offset: const Offset(0, 36),
          constraints: const BoxConstraints(minWidth: 300, maxWidth: 340),
          onSelected: (value) async {
            if (value == '__settings__') {
              widget.onOpenQuickIssueSettings?.call();
              return;
            }
            for (final issue in widget.appState.issues) {
              if (issue.issueId == value && context.mounted) {
                await AddTimeDialog.show(
                  context,
                  appState: widget.appState,
                  issue: issue,
                );
                return;
              }
            }
          },
          itemBuilder: (context) {
            final rows = <PopupMenuEntry<String>>[];
            for (final quickIssue in widget.appState.quickIssues) {
              final issue = _issueById(quickIssue.issueId);
              if (issue == null) continue;
              rows.add(
                PopupMenuItem<String>(
                  value: issue.issueId,
                  enabled: !widget.appState.isReadOnly,
                  child: SizedBox(
                    width: 304,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.selected(isDark),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                issue.key,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: AppColors.primary(isDark),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                issue.summary,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (quickIssue.note?.isNotEmpty == true) ...[
                          const SizedBox(height: 3),
                          Text(
                            quickIssue.note!,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.muted(isDark),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }
            if (rows.isNotEmpty) return rows;
            return [
              PopupMenuItem<String>(
                enabled: false,
                child: SizedBox(
                  width: 248,
                  child: Text(
                    'Часто используемые задачи ещё не настроены.',
                    style: TextStyle(
                      color: AppColors.muted(isDark),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                key: ValueKey('configure-quick-issues'),
                value: '__settings__',
                child: Row(
                  children: [
                    Icon(Icons.tune, size: 17),
                    SizedBox(width: 8),
                    Expanded(child: Text('Настроить быстрые задачи')),
                  ],
                ),
              ),
            ];
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.line(isDark)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_outlined, size: 16),
                const SizedBox(width: 6),
                const Text('Быстрые задачи', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTasksColumn(BuildContext context) {
    final filteredIssues = widget.appState.filteredIssues;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Недавние задачи',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            if (_isSelectionMode && widget.appState.selectedIssueIds.isNotEmpty)
              TextButton.icon(
                onPressed: () => widget.appState.startSelectedIssues(),
                icon: const Icon(Icons.play_arrow, size: 17),
                label: Text(
                  'Запустить (${widget.appState.selectedIssueIds.length})',
                ),
              ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isSelectionMode = !_isSelectionMode;
                  if (!_isSelectionMode) widget.appState.clearIssueSelection();
                });
              },
              child: Text(_isSelectionMode ? 'Отмена' : 'Выбрать несколько'),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(Icons.search, size: 17, color: AppColors.muted(isDark)),
            const SizedBox(width: 7),
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Поиск по задачам',
                  isDense: true,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          tooltip: 'Очистить поиск',
                          onPressed: () {
                            _searchController.clear();
                            widget.appState.setIssueSearchQuery('');
                          },
                        )
                      : null,
                ),
                onChanged: widget.appState.setIssueSearchQuery,
              ),
            ),
            PopupMenuButton<IssueFilterPeriod>(
              tooltip: 'Фильтр активности',
              onSelected: widget.appState.setIssueFilterPeriod,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: IssueFilterPeriod.days7,
                  child: Text('За 7 дней'),
                ),
                PopupMenuItem(
                  value: IssueFilterPeriod.days30,
                  child: Text('За 30 дней'),
                ),
                PopupMenuItem(
                  value: IssueFilterPeriod.all,
                  child: Text('За всё время'),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Row(
                  children: [
                    Text(_filterPeriodLabel(widget.appState.filterPeriod)),
                    const SizedBox(width: 3),
                    const Icon(Icons.expand_more, size: 17),
                  ],
                ),
              ),
            ),
          ],
        ),
        Divider(height: 1, color: AppColors.line(isDark)),
        Expanded(
          child: filteredIssues.isEmpty
              ? Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 36,
                          color: AppColors.muted(isDark),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.appState.issues.isEmpty
                              ? 'Нет добавленных задач.\nВведите ключ, ID или ссылку выше.'
                              : 'Нет задач, соответствующих фильтру.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted(isDark)),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: filteredIssues.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: AppColors.line(isDark)),
                  itemBuilder: (context, index) {
                    final issue = filteredIssues[index];
                    final isSelected = widget.appState.selectedIssueIds
                        .contains(issue.issueId);
                    final currentLog = widget.appState.getCurrentLogForIssue(
                      issue.issueId,
                    );
                    final isRunning = currentLog?.isRunning ?? false;
                    final elapsedSeconds = currentLog == null
                        ? 0
                        : LogClock.calculateElapsed(
                            log: currentLog,
                            nowUtc: widget.appState.nowProvider(),
                          ).elapsedSeconds;
                    final quickIssue = _quickIssueFor(issue.issueId);

                    return Container(
                      key: ValueKey('issue-${issue.issueId}'),
                      color: isSelected || isRunning
                          ? AppColors.selected(isDark)
                          : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 13,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (_isSelectionMode)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: SizedBox(
                                    width: 20,
                                    height: 24,
                                    child: Checkbox(
                                      value: isSelected,
                                      onChanged: (_) => widget.appState
                                          .toggleIssueSelection(issue.issueId),
                                    ),
                                  ),
                                ),
                              Text(
                                issue.key,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isRunning
                                      ? AppColors.primary(isDark)
                                      : AppColors.muted(isDark),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              if (issue.status != null &&
                                  issue.status!.isNotEmpty)
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      issue.status!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.muted(isDark),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            issue.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            quickIssue?.note ??
                                'Активность: ${_formatDateTime(issue.lastUsedAtUtc)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.muted(isDark),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                isRunning
                                    ? Icons.stop_circle_outlined
                                    : Icons.play_arrow,
                                size: 17,
                                color: isRunning
                                    ? AppColors.primary(isDark)
                                    : AppColors.muted(isDark),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                LogClock.formatDigital(elapsedSeconds),
                                style: TextStyle(
                                  color: isRunning
                                      ? AppColors.primary(isDark)
                                      : AppColors.muted(isDark),
                                  fontFamily: 'IBM Plex Mono',
                                  fontSize: 13,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: isRunning
                                      ? AppColors.primary(isDark)
                                      : AppColors.muted(isDark),
                                ),
                                onPressed: () {
                                  if (isRunning) {
                                    widget.appState.pauseTimer(issue.issueId);
                                  } else {
                                    widget.appState.playTimer(issue.issueId);
                                  }
                                },
                                child: Text(
                                  isRunning ? 'Остановить' : 'Начать',
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => AddTimeDialog.show(
                                  context,
                                  appState: widget.appState,
                                  issue: issue,
                                ),
                                icon: const Icon(Icons.add, size: 15),
                                label: const Text('Добавить время'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- Правая колонка: очередь логов и история ---

  Widget _buildQueueColumn(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unconsumed = widget.appState.unconsumedLogs;
    final consumed = widget.appState.consumedLogs;
    final hasRunningTimers = unconsumed.any((l) => l.isRunning);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildQueueTab(
              context,
              tab: WorkScreenQueueTab.queue,
              label: 'Очередь',
              count: unconsumed.length,
            ),
            const SizedBox(width: 18),
            _buildQueueTab(
              context,
              tab: WorkScreenQueueTab.history,
              label: 'История',
              count: consumed.length,
            ),
            const Spacer(),
            if (_currentQueueTab == WorkScreenQueueTab.queue &&
                unconsumed.isNotEmpty)
              Text(
                'Всего ${LogClock.formatHoursMinutes(widget.appState.totalUnconsumedSeconds)}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.muted(isDark),
                  fontFamily: 'IBM Plex Mono',
                ),
              ),
            if (hasRunningTimers &&
                _currentQueueTab == WorkScreenQueueTab.queue)
              IconButton(
                tooltip: 'Поставить все таймеры на паузу',
                visualDensity: VisualDensity.compact,
                onPressed: widget.appState.pauseAllTimers,
                icon: const Icon(Icons.pause, size: 17),
              ),
          ],
        ),
        Divider(height: 1, color: AppColors.line(isDark)),
        Expanded(
          child: _currentQueueTab == WorkScreenQueueTab.queue
              ? _buildQueueList(context, unconsumed)
              : _buildHistoryList(context, consumed),
        ),
      ],
    );
  }

  Widget _buildQueueTab(
    BuildContext context, {
    required WorkScreenQueueTab tab,
    required String label,
    required int count,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = _currentQueueTab == tab;
    return InkWell(
      onTap: () => setState(() => _currentQueueTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          count == 0 ? label : '$label  $count',
          style: TextStyle(
            fontSize: selected ? 16 : 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.text(isDark) : AppColors.muted(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildQueueList(BuildContext context, List<LocalLog> logs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.access_time_outlined,
              size: 36,
              color: AppColors.muted(isDark),
            ),
            const SizedBox(height: 8),
            const Text(
              'Очередь логов пуста',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              'Запустите таймер на задаче или добавьте время вручную.',
              style: TextStyle(color: AppColors.muted(isDark), fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: logs.length,
      separatorBuilder: (context, index) =>
          Divider(height: 1, color: AppColors.line(isDark)),
      itemBuilder: (context, index) {
        final log = logs[index];
        final clockResult = LogClock.calculateElapsed(
          log: log,
          nowUtc: widget.appState.nowProvider(),
        );
        final isSelected = widget.appState.selectedLogIds.contains(log.id);
        final isInDraft = widget.appState.isLogInDraft(log.id);
        final draftDate = widget.appState.getDraftDateForLog(log.id);
        final isInSelectedDateDraft =
            isInDraft && draftDate == widget.appState.selectedDateString;
        final canRemoveFromDraft =
            isInDraft && widget.appState.canRemoveLogFromDraft(log.id);

        return Container(
          key: ValueKey('log-${log.id}'),
          color: log.isRunning
              ? (isDark ? AppColors.insetDark : AppColors.selectedLight)
              : isSelected && !isDark
              ? AppColors.selectedLight
              : null,
          padding: const EdgeInsets.fromLTRB(0, 11, 4, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (log.isRunning)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.sensors,
                        size: 15,
                        color: AppColors.primary(isDark),
                      ),
                    )
                  else if (isInSelectedDateDraft)
                    SizedBox(
                      width: 22,
                      height: 24,
                      child: Tooltip(
                        message: canRemoveFromDraft
                            ? 'Убрать лог из черновика на $draftDate'
                            : 'После начала отправки состав дня изменить нельзя',
                        child: Checkbox(
                          value: true,
                          onChanged: canRemoveFromDraft
                              ? (_) => _removeLogFromDraft(context, log.id)
                              : null,
                        ),
                      ),
                    )
                  else if (isInDraft)
                    SizedBox(
                      width: 22,
                      height: 24,
                      child: Tooltip(
                        message:
                            'Запись уже включена в день ${_formatDraftDate(draftDate!)}',
                        child: Icon(
                          Icons.event_available_outlined,
                          size: 17,
                          color: AppColors.muted(isDark),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: 22,
                      height: 24,
                      child: Tooltip(
                        message: 'Выбрать для сборки дня',
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (_) =>
                              widget.appState.toggleLogSelection(log.id),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    _getIssueKey(log.issueId),
                    style: TextStyle(
                      color: log.isRunning
                          ? AppColors.primary(isDark)
                          : AppColors.muted(isDark),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (log.fixedStartTime != null) ...[
                    const SizedBox(width: 10),
                    Icon(
                      Icons.lock_outline,
                      size: 13,
                      color: AppColors.muted(isDark),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      log.fixedStartTime!,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.muted(isDark),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    log.isRunning
                        ? LogClock.formatDigital(clockResult.elapsedSeconds)
                        : LogClock.formatHoursMinutes(
                            clockResult.elapsedSeconds,
                          ),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: log.isRunning
                          ? AppColors.primary(isDark)
                          : AppColors.text(isDark),
                      fontFamily: 'IBM Plex Mono',
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (log.isRunning)
                    Tooltip(
                      message:
                          'Поставьте таймер на паузу перед выбором для сборки дня',
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: Checkbox(value: false, onChanged: null),
                      ),
                    ),
                  if (log.isRunning)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Поставить таймер на паузу',
                      onPressed: () => widget.appState.pauseLog(log.id),
                      icon: const Icon(Icons.pause, size: 17),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 30, top: 5),
                child: Text(
                  log.titleSnapshot,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              if (log.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 30, top: 3),
                  child: Text(
                    log.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.muted(isDark),
                    ),
                  ),
                ),
              if (log.isRunning)
                Padding(
                  padding: const EdgeInsets.only(left: 30, top: 3),
                  child: Text(
                    'Остановите таймер, чтобы добавить запись в день.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.muted(isDark),
                    ),
                  ),
                ),
              if (clockResult.hasClockRollback)
                Padding(
                  padding: const EdgeInsets.only(left: 30, top: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber,
                        size: 14,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          clockResult.errorMessage ??
                              'Обнаружен откат системного времени!',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.brown,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(left: 30, top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Создан: ${_formatDateTime(log.createdAtUtc)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.muted(isDark),
                        ),
                      ),
                    ),
                    if (isInDraft && draftDate != null) ...[
                      TextButton.icon(
                        key: ValueKey('open-draft-${log.id}'),
                        onPressed: () => _openDraft(draftDate),
                        icon: const Icon(Icons.open_in_new, size: 14),
                        label: Text(
                          'В дне ${_formatDraftDate(draftDate)} · Открыть',
                        ),
                      ),
                      if (!isInSelectedDateDraft && canRemoveFromDraft)
                        PopupMenuButton<String>(
                          key: ValueKey('draft-actions-${log.id}'),
                          tooltip: 'Действия с записью в другом дне',
                          icon: const Icon(Icons.more_horiz, size: 19),
                          onSelected: (_) =>
                              _removeLogFromDraft(context, log.id),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'remove-from-draft',
                              child: Text(
                                'Убрать из дня ${_formatDraftDate(draftDate)}',
                              ),
                            ),
                          ],
                        ),
                    ] else if (!log.isRunning)
                      PopupMenuButton<String>(
                        tooltip: 'Действия с логом',
                        icon: const Icon(Icons.more_horiz, size: 19),
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              EditLogDialog.show(
                                context,
                                appState: widget.appState,
                                log: log,
                              );
                              break;
                            case 'split':
                              SplitLogDialog.show(
                                context,
                                appState: widget.appState,
                                log: log,
                              );
                              break;
                            case 'merge':
                              MergeLogsDialog.show(
                                context,
                                appState: widget.appState,
                                log: log,
                              );
                              break;
                            case 'delete':
                              _confirmDeleteLog(context, log);
                              break;
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Редактировать'),
                          ),
                          PopupMenuItem(value: 'split', child: Text('Разбить')),
                          PopupMenuItem(
                            value: 'merge',
                            child: Text('Объединить с…'),
                          ),
                          PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Удалить'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryList(BuildContext context, List<LocalLog> logs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (logs.isEmpty) {
      return Center(
        child: Text(
          'История отправленных логов пока пуста.',
          style: TextStyle(color: AppColors.muted(isDark)),
        ),
      );
    }

    final sortedLogs = [...logs]
      ..sort(
        (a, b) => (b.consumedAtUtc ?? b.createdAtUtc).compareTo(
          a.consumedAtUtc ?? a.createdAtUtc,
        ),
      );
    final children = <Widget>[];
    DateTime? previousDate;
    for (final log in sortedLogs) {
      final sentAt = (log.consumedAtUtc ?? log.createdAtUtc).toLocal();
      final date = DateTime(sentAt.year, sentAt.month, sentAt.day);
      if (date != previousDate) {
        children.add(
          Padding(
            padding: EdgeInsets.only(
              top: children.isEmpty ? 12 : 20,
              bottom: 8,
            ),
            child: Text(
              _formatHistoryDate(date),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.muted(isDark),
              ),
            ),
          ),
        );
        previousDate = date;
      }
      children.add(
        Container(
          key: ValueKey('history-${log.id}'),
          padding: const EdgeInsets.fromLTRB(0, 10, 4, 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.line(isDark))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _getIssueKey(log.issueId),
                    style: TextStyle(
                      color: AppColors.primary(isDark),
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    LogClock.formatHoursMinutes(log.accumulatedSeconds),
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Mono',
                      fontFeatures: [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                log.titleSnapshot,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (log.description.isNotEmpty)
                Text(
                  log.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.muted(isDark),
                  ),
                ),
              Text(
                _formatDateTime(log.consumedAtUtc ?? log.createdAtUtc),
                style: TextStyle(fontSize: 11, color: AppColors.muted(isDark)),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(padding: EdgeInsets.zero, children: children);
  }

  String _formatHistoryDate(DateTime date) =>
      _formatHeaderDate(date, includeWeekday: false);

  Widget _buildBottomAssemblyBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_currentQueueTab == WorkScreenQueueTab.history) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 27),
        decoration: BoxDecoration(
          color: AppColors.inset(isDark),
          border: Border(top: BorderSide(color: AppColors.line(isDark))),
        ),
        child: Row(
          children: [
            Icon(
              Icons.archive_outlined,
              size: 18,
              color: AppColors.muted(isDark),
            ),
            const SizedBox(width: 10),
            Text(
              'История отправок хранится на этом устройстве',
              style: TextStyle(fontSize: 13, color: AppColors.muted(isDark)),
            ),
          ],
        ),
      );
    }
    final count = widget.appState.selectedLogIds.length;
    final totalSec = widget.appState.totalSelectedSeconds;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 27),
      decoration: BoxDecoration(
        color: AppColors.inset(isDark),
        border: Border(top: BorderSide(color: AppColors.line(isDark))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count == 0
                      ? 'Для ${_formatHeaderDate(widget.appState.selectedDate, includeWeekday: false)} записи не выбраны'
                      : 'Выбрано $count ${_logWord(count)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: LogClock.formatHoursMinutes(totalSec),
                        style: const TextStyle(fontFamily: 'IBM Plex Mono'),
                      ),
                      TextSpan(
                        text: ' исходного времени',
                        style: TextStyle(color: AppColors.muted(isDark)),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            'Собрать на',
            style: TextStyle(fontSize: 12, color: AppColors.muted(isDark)),
          ),
          const SizedBox(width: 24),
          OutlinedButton.icon(
            onPressed: () => _pickAssemblyDate(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 36),
              visualDensity: VisualDensity.standard,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              textStyle: const TextStyle(fontSize: 13),
            ),
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: Text(
              _formatHeaderDate(
                widget.appState.selectedDate,
                includeYear: true,
              ),
            ),
          ),
          const SizedBox(width: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.action(isDark),
              foregroundColor: AppColors.onAction(isDark),
              minimumSize: const Size(0, 36),
              visualDensity: VisualDensity.standard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              textStyle: const TextStyle(fontSize: 13),
            ),
            onPressed: count == 0 ? null : () => _handleBuildDay(context),
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: const Text('Собрать день'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAssemblyDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.appState.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Дата для сборки дня',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    if (picked != null) widget.appState.setSelectedDate(picked);
  }

  Future<void> _handleBuildDay(BuildContext context) async {
    try {
      await widget.appState.buildDay();
      widget.appState.selectTab(1);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  String _formatAssemblyDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  String _formatHeaderDate(
    DateTime date, {
    bool includeYear = false,
    bool includeWeekday = true,
  }) {
    const months = [
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
    ];
    const weekdays = [
      'понедельник',
      'вторник',
      'среда',
      'четверг',
      'пятница',
      'суббота',
      'воскресенье',
    ];
    final dateText = '${date.day} ${months[date.month - 1]}';
    if (includeYear) return '$dateText ${date.year}';
    if (!includeWeekday) return dateText;
    final weekday = weekdays[date.weekday - 1];
    return '${weekday[0].toUpperCase()}${weekday.substring(1)}, $dateText';
  }

  String _filterPeriodLabel(IssueFilterPeriod period) => switch (period) {
    IssueFilterPeriod.days7 => 'За 7 дней',
    IssueFilterPeriod.days30 => 'За 30 дней',
    IssueFilterPeriod.all => 'За всё время',
  };

  String _logWord(int count) {
    final lastTwo = count % 100;
    final last = count % 10;
    if (lastTwo >= 11 && lastTwo <= 14) return 'записей';
    if (last == 1) return 'запись';
    if (last >= 2 && last <= 4) return 'записи';
    return 'записей';
  }

  String _formatDraftDate(String date) {
    final parsed = DateTime.tryParse(date);
    return parsed == null ? date : _formatAssemblyDate(parsed);
  }

  void _openDraft(String date) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return;
    widget.appState.setSelectedDate(parsed);
    widget.appState.selectTab(1);
  }

  void _removeLogFromDraft(BuildContext context, String logId) {
    try {
      widget.appState.removeLogFromDraft(logId);
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  String _getIssueKey(String issueId) {
    final issue = widget.appState.issues
        .where((i) => i.issueId == issueId)
        .firstOrNull;
    return issue?.key ?? issueId;
  }

  void _confirmDeleteLog(BuildContext context, LocalLog log) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить запись времени?'),
        content: Text(
          'Запись «${log.titleSnapshot}» (${LogClock.formatHoursMinutes(log.accumulatedSeconds)}) будет удалена безвозвратно.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.appState.deleteLog(log.id);
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dtUtc) {
    final local = dtUtc.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final mon = local.month.toString().padLeft(2, '0');
    return '$day.$mon $h:$m';
  }
}
