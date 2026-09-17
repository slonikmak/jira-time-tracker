import 'package:flutter/material.dart';
import '../app_state.dart';
import '../log_clock.dart';
import '../models.dart';
import '../service_tickets.dart';
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

  const WorkScreen({super.key, required this.appState});

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
            final isNarrow = constraints.maxWidth < 650;
            final taskWidth = constraints.maxWidth < 1000 ? 320.0 : 380.0;

            final tasksCol = _buildTasksColumn(context);
            final queueCol = _buildQueueColumn(context);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Работа',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Записывайте время сейчас. Распределяйте по дням позже.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted(isDark),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildAddIssueRow(context),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: isNarrow
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Column(
                            children: [
                              SizedBox(height: 420, child: tasksCol),
                              const SizedBox(height: 20),
                              queueCol,
                            ],
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: taskWidth, child: tasksCol),
                              const SizedBox(width: 22),
                              Expanded(child: queueCol),
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
          child: TextField(
            controller: _addController,
            decoration: const InputDecoration(
              hintText: 'Ключ, ID или ссылка на задачу Jira',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _handleAddIssue(),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _isAdding ? null : _handleAddIssue,
          icon: _isAdding
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add, size: 18),
          label: const Text('Добавить'),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<ServiceTicket>(
          tooltip: 'Выбрать служебный тикет (EG Project)',
          offset: const Offset(0, 36),
          onSelected: (ticket) async {
            final issue = await widget.appState.addServiceTicket(ticket);
            if (context.mounted) {
              await AddTimeDialog.show(
                context,
                appState: widget.appState,
                issue: issue,
              );
            }
          },
          itemBuilder: (context) {
            return kServiceTickets.map((t) {
              return PopupMenuItem<ServiceTicket>(
                value: t,
                child: SizedBox(
                  width: 380,
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
                              t.key,
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
                              t.category,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        t.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.muted(isDark),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              );
            }).toList();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.line(isDark)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bookmark_outline,
                  size: 16,
                  color: AppColors.primary(isDark),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Служебный тикет',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () =>
              AddTimeDialog.show(context, appState: widget.appState),
          icon: const Icon(Icons.more_time, size: 18),
          label: const Text('Записать время'),
        ),
      ],
    );
  }

  Widget _buildTasksColumn(BuildContext context) {
    final filteredIssues = widget.appState.filteredIssues;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Поиск
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Поиск по ключу или названию...',
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      widget.appState.setIssueSearchQuery('');
                    },
                  )
                : null,
          ),
          onChanged: (val) => widget.appState.setIssueSearchQuery(val),
        ),
        const SizedBox(height: 8),

        // Фильтры давности и кнопка выбора
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            SegmentedButton<IssueFilterPeriod>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: const [
                ButtonSegment(
                  value: IssueFilterPeriod.days7,
                  label: Text('7 дн'),
                ),
                ButtonSegment(
                  value: IssueFilterPeriod.days30,
                  label: Text('30 дн'),
                ),
                ButtonSegment(value: IssueFilterPeriod.all, label: Text('Все')),
              ],
              selected: {widget.appState.filterPeriod},
              onSelectionChanged: (set) {
                widget.appState.setIssueFilterPeriod(set.first);
              },
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isSelectionMode &&
                    widget.appState.selectedIssueIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => widget.appState.startSelectedIssues(),
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: Text(
                        'Запустить выбранные (${widget.appState.selectedIssueIds.length})',
                      ),
                    ),
                  ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = !_isSelectionMode;
                      if (!_isSelectionMode) {
                        widget.appState.clearIssueSelection();
                      }
                    });
                  },
                  icon: Icon(
                    _isSelectionMode ? Icons.close : Icons.checklist,
                    size: 18,
                  ),
                  label: Text(_isSelectionMode ? 'Отмена' : 'Выбрать'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Заголовок списка задач
        Text(
          'Недавние задачи (${filteredIssues.length})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const Divider(),

        // Список задач
        Expanded(
          child: filteredIssues.isEmpty
              ? Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.assignment_outlined,
                          size: 36,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.appState.issues.isEmpty
                              ? 'Нет добавленных задач.\nВведите ключ, ID или ссылку выше.'
                              : 'Нет задач, соответствующих фильтру.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: filteredIssues.length,
                  itemBuilder: (context, index) {
                    final issue = filteredIssues[index];
                    final isSelected = widget.appState.selectedIssueIds
                        .contains(issue.issueId);
                    final currentLog = widget.appState.getCurrentLogForIssue(
                      issue.issueId,
                    );
                    final isRunning = currentLog?.isRunning ?? false;

                    final elapsedSeconds = currentLog != null
                        ? LogClock.calculateElapsed(
                            log: currentLog,
                            nowUtc: widget.appState.nowProvider(),
                          ).elapsedSeconds
                        : 0;

                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.surface(isDark),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: isRunning
                              ? AppColors.green(isDark).withValues(alpha: 0.6)
                              : AppColors.line(isDark),
                          width: isRunning ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Верхняя строка: чекбокс и ключ задачи слева, статус задачи у правого края
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isSelectionMode) ...[
                                      Checkbox(
                                        value: isSelected,
                                        onChanged: (_) => widget.appState
                                            .toggleIssueSelection(issue.issueId),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isRunning
                                            ? AppColors.greenBg(isDark)
                                            : AppColors.selected(isDark),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        issue.key,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: isRunning
                                              ? AppColors.green(isDark)
                                              : AppColors.primary(isDark),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (issue.status != null &&
                                    issue.status!.isNotEmpty)
                                  Flexible(
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: _buildStatusBadge(
                                        issue.status!,
                                        isDark,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Средняя строка: название задачи
                            Text(
                              issue.summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                            if (findServiceTicket(issue.key) != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                findServiceTicket(issue.key)!.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted(isDark),
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),

                            // Нижняя строка: активность и кнопки действий (запуск таймера и добавление времени)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        'Активность: ${_formatDateTime(issue.lastUsedAtUtc)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.muted(isDark),
                                        ),
                                      ),
                                      if (isRunning)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.greenBg(isDark),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: AppColors.green(isDark),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                LogClock.formatDigital(
                                                  elapsedSeconds,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.green(isDark),
                                                  fontFeatures: const [
                                                    FontFeature.tabularFigures(),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else if (elapsedSeconds > 0)
                                        Text(
                                          '(${LogClock.formatHoursMinutes(elapsedSeconds)})',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.muted(isDark),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: isRunning
                                            ? AppColors.greenBg(isDark)
                                            : AppColors.selected(isDark),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: Icon(
                                          isRunning
                                              ? Icons.pause_circle_filled
                                              : Icons.play_circle_filled,
                                          color: isRunning
                                              ? AppColors.green(isDark)
                                              : AppColors.primary(isDark),
                                          size: 22,
                                        ),
                                        tooltip: isRunning
                                            ? 'Остановить таймер'
                                            : 'Запустить таймер',
                                        onPressed: () {
                                          if (isRunning) {
                                            widget.appState.pauseTimer(
                                              issue.issueId,
                                            );
                                          } else {
                                            widget.appState.playTimer(
                                              issue.issueId,
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(
                                        Icons.more_time,
                                        size: 18,
                                      ),
                                      tooltip: 'Добавить время вручную',
                                      onPressed: () {
                                        AddTimeDialog.show(
                                          context,
                                          appState: widget.appState,
                                          issue: issue,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
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
        // Вкладки Очередь / История и кнопка общей паузы
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildQueueTab(
                  context,
                  tab: WorkScreenQueueTab.queue,
                  label: 'Не отправлены',
                  count: unconsumed.length,
                ),
                const SizedBox(width: 15),
                _buildQueueTab(
                  context,
                  tab: WorkScreenQueueTab.history,
                  label: 'История',
                  count: consumed.length,
                ),
              ],
            ),
            if (hasRunningTimers &&
                _currentQueueTab == WorkScreenQueueTab.queue)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.greenBg(isDark),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.green(isDark).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.green(isDark),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.green(isDark),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => widget.appState.pauseAllTimers(),
                      icon: const Icon(Icons.pause, size: 14),
                      label: const Text(
                        'Пауза для всех',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Заголовок и суммарное время
        if (_currentQueueTab == WorkScreenQueueTab.queue) ...[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                'Логи к сборке (${unconsumed.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Всего: ${LogClock.formatHoursMinutes(widget.appState.totalUnconsumedSeconds)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.muted(isDark),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ] else ...[
          Text(
            'Использованные логи (${consumed.length})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
        Divider(color: AppColors.line(isDark)),

        // Содержимое
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
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.primary(isDark) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          count == 0 ? label : '$label  $count',
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.text(isDark) : AppColors.muted(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildQueueList(BuildContext context, List<LocalLog> logs) {
    if (logs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.access_time_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'Очередь логов пуста',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 4),
            Text(
              'Запустите таймер на задаче или добавьте время вручную.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: logs.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: AppColors.line(Theme.of(context).brightness == Brightness.dark),
      ),
      itemBuilder: (context, index) {
        final log = logs[index];
        final clockResult = LogClock.calculateElapsed(
          log: log,
          nowUtc: widget.appState.nowProvider(),
        );
        final isSelected = widget.appState.selectedLogIds.contains(log.id);

        final isInDraft = widget.appState.isLogInDraft(log.id);
        final draftDate = widget.appState.getDraftDateForLog(log.id);
        final canRemoveFromDraft =
            isInDraft && widget.appState.canRemoveLogFromDraft(log.id);

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.selected(isDark) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isInDraft)
                    Tooltip(
                      message: canRemoveFromDraft
                          ? 'Убрать лог из черновика на $draftDate'
                          : 'После начала отправки состав дня изменить нельзя',
                      child: Checkbox(
                        value: true,
                        onChanged: canRemoveFromDraft
                            ? (_) => _removeLogFromDraft(context, log.id)
                            : null,
                      ),
                    )
                  else
                    Tooltip(
                      message: log.isRunning
                          ? 'Поставьте таймер на паузу перед выбором для сборки дня'
                          : 'Выбрать для сборки дня',
                      child: Checkbox(
                        value: isSelected,
                        onChanged: log.isRunning
                            ? null
                            : (_) => widget.appState.toggleLogSelection(log.id),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: log.isRunning
                          ? AppColors.greenBg(isDark)
                          : AppColors.selected(isDark),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getIssueKey(log.issueId),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: log.isRunning
                            ? AppColors.green(isDark)
                            : AppColors.primary(isDark),
                      ),
                    ),
                  ),
                  if (log.fixedStartTime != null) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary(isDark).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.primary(isDark).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, size: 11, color: AppColors.primary(isDark)),
                          const SizedBox(width: 3),
                          Text(
                            log.fixedStartTime!,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: AppColors.primary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      log.titleSnapshot,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (isInDraft && draftDate != null) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Tooltip(
                        message: 'Открыть черновик за $draftDate',
                        child: TextButton.icon(
                          key: ValueKey('open-draft-${log.id}'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 7),
                            foregroundColor: AppColors.primary(isDark),
                            backgroundColor: AppColors.selected(isDark),
                          ),
                          onPressed: () => _openDraft(draftDate),
                          icon: const Icon(Icons.open_in_new, size: 13),
                          label: Text(
                            'Открыть день · ${_formatDraftDate(draftDate)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (log.isRunning)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.pause, color: Colors.orange),
                      tooltip: 'Поставить на паузу',
                      onPressed: () => widget.appState.pauseLog(log.id),
                    )
                  else if (!isInDraft) ...[
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Редактировать лог',
                      onPressed: () => EditLogDialog.show(
                        context,
                        appState: widget.appState,
                        log: log,
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Дополнительные действия',
                      icon: const Icon(Icons.more_vert, size: 18),
                      onSelected: (val) {
                        switch (val) {
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
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'split',
                          child: Row(
                            children: [
                              Icon(Icons.call_split, size: 16),
                              SizedBox(width: 8),
                              Text('Разбить'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'merge',
                          child: Row(
                            children: [
                              Icon(Icons.merge_type, size: 16),
                              SizedBox(width: 8),
                              Text('Объединить с...'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Удалить', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              if (log.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 36, bottom: 4),
                  child: Text(
                    log.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted(isDark),
                    ),
                  ),
                ),
              if (clockResult.hasClockRollback)
                Padding(
                  padding: const EdgeInsets.only(left: 36, bottom: 4),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber,
                          size: 14,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
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
                ),
              Padding(
                padding: const EdgeInsets.only(left: 36, top: 2),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Создан: ${_formatDateTime(log.createdAtUtc)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    if (log.isRunning)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.play_arrow,
                              size: 14,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              LogClock.formatDigital(
                                clockResult.elapsedSeconds,
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.green(isDark),
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        LogClock.formatHoursMinutes(clockResult.elapsedSeconds),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
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
    if (logs.isEmpty) {
      return const Center(
        child: Text(
          'История отправленных логов пока пуста.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: AppColors.surface(isDark),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: AppColors.line(isDark)),
            borderRadius: BorderRadius.circular(9),
          ),
          child: ListTile(
            dense: true,
            leading: Icon(
              Icons.check_circle,
              color: AppColors.green(isDark),
              size: 20,
            ),
            title: Text(
              log.titleSnapshot,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              '${LogClock.formatHoursMinutes(log.accumulatedSeconds)} • Отправлен: ${_formatDateTime(log.consumedAtUtc ?? log.createdAtUtc)}',
              style: TextStyle(color: AppColors.muted(isDark)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomAssemblyBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = widget.appState.selectedLogIds.length;
    final totalSec = widget.appState.totalSelectedSeconds;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
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
                  '$count ${count == 1 ? 'лог' : 'логов'} · ${LogClock.formatHoursMinutes(totalSec)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Выбрано для сборки · исходное время',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.muted(isDark),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _pickAssemblyDate(context),
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: Text(_formatAssemblyDate(widget.appState.selectedDate)),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary(isDark),
              foregroundColor: AppColors.onPrimary(isDark),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

  Widget _buildStatusBadge(String status, bool isDark) {
    final lower = status.toLowerCase();
    Color bg;
    Color fg;
    Color border;

    if (lower.contains('done') ||
        lower.contains('готов') ||
        lower.contains('закрыт') ||
        lower.contains('resolved')) {
      bg = AppColors.greenBg(isDark);
      fg = AppColors.green(isDark);
      border = AppColors.green(isDark).withValues(alpha: 0.3);
    } else if (lower.contains('progress') ||
        lower.contains('работ') ||
        lower.contains('in dev') ||
        lower.contains('development')) {
      bg = AppColors.selected(isDark);
      fg = AppColors.primary(isDark);
      border = AppColors.primary(isDark).withValues(alpha: 0.3);
    } else if (lower.contains('review') ||
        lower.contains('тест') ||
        lower.contains('test') ||
        lower.contains('qa')) {
      bg = AppColors.warnBg(isDark);
      fg = AppColors.warn(isDark);
      border = AppColors.warn(isDark).withValues(alpha: 0.3);
    } else {
      bg = AppColors.hover(isDark);
      fg = AppColors.muted(isDark);
      border = AppColors.line(isDark);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border),
      ),
      child: Text(
        status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
