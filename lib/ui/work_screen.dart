import 'package:flutter/material.dart';
import '../app_state.dart';
import '../log_clock.dart';
import '../models.dart';
import 'add_time_dialog.dart';
import 'app_theme.dart';
import 'edit_log_dialog.dart';

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
            final isNarrow = constraints.maxWidth < 750;

            final tasksCol = _buildTasksColumn(context);
            final queueCol = _buildQueueColumn(context);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Заголовок экрана «Работа» (.jt-heading)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Рабочее пространство',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.4,
                                  fontSize: 20,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Записывайте время сейчас. Распределяйте по дням позже.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted(isDark),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: isNarrow
                      ? SingleChildScrollView(
                          child: Column(
                            children: [
                              tasksCol,
                              Divider(height: 1, color: AppColors.line(isDark)),
                              queueCol,
                            ],
                          ),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: tasksCol),
                            VerticalDivider(
                              width: 1,
                              color: AppColors.line(isDark),
                            ),
                            Expanded(flex: 5, child: queueCol),
                          ],
                        ),
                ),
                if (widget.appState.selectedLogIds.isNotEmpty)
                  _buildBottomAssemblyBar(context),
              ],
            );
          },
        );
      },
    );
  }

  // --- Левая колонка: задачи ---

  Widget _buildTasksColumn(BuildContext context) {
    final filteredIssues = widget.appState.filteredIssues;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Поле ввода для добавления задачи и ручного времени
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addController,
                  decoration: const InputDecoration(
                    labelText: 'ID или URL задачи',
                    hintText: 'PROJ-123, 10023 или ссылка /browse/...',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.add_task),
                  ),
                  onSubmitted: (_) => _handleAddIssue(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _isAdding ? null : _handleAddIssue,
                icon: _isAdding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: const Text('Добавить'),
              ),
              const SizedBox(width: 4),
              IconButton.outlined(
                onPressed: () =>
                    AddTimeDialog.show(context, appState: widget.appState),
                icon: const Icon(Icons.more_time, size: 20),
                tooltip: 'Добавить время вручную',
              ),
            ],
          ),
          const SizedBox(height: 12),

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
                  ButtonSegment(
                    value: IssueFilterPeriod.all,
                    label: Text('Все'),
                  ),
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.assignment_outlined,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.appState.issues.isEmpty
                              ? 'Нет добавленных задач.\nВведите ключ (PROJ-123), ID или ссылку выше.'
                              : 'Нет задач, соответствующих фильтру.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
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
                              // Верхняя строка: чекбокс/ключ, название, кнопка Play/Pause
                              Row(
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
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      issue.summary,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
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
                                        size: 24,
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
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Нижняя строка: активность/таймер и вспомогательные действия
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 8,
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
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.greenBg(isDark),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    color: AppColors.green(
                                                      isDark,
                                                    ),
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
                                                    color: AppColors.green(
                                                      isDark,
                                                    ),
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
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.more_time, size: 18),
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
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- Правая колонка: очередь логов и история ---

  Widget _buildQueueColumn(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unconsumed = widget.appState.unconsumedLogs;
    final consumed = widget.appState.consumedLogs;
    final hasRunningTimers = unconsumed.any((l) => l.isRunning);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Вкладки Очередь / История и кнопка общей паузы
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              SegmentedButton<WorkScreenQueueTab>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: [
                  ButtonSegment(
                    value: WorkScreenQueueTab.queue,
                    label: Text('Очередь (${unconsumed.length})'),
                  ),
                  ButtonSegment(
                    value: WorkScreenQueueTab.history,
                    label: Text('История (${consumed.length})'),
                  ),
                ],
                selected: {_currentQueueTab},
                onSelectionChanged: (set) {
                  setState(() {
                    _currentQueueTab = set.first;
                  });
                },
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

    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        final clockResult = LogClock.calculateElapsed(
          log: log,
          nowUtc: widget.appState.nowProvider(),
        );
        final isSelected = widget.appState.selectedLogIds.contains(log.id);

        final isInDraft = widget.appState.isLogInDraft(log.id);
        final draftDate = widget.appState.getDraftDateForLog(log.id);

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: isSelected
              ? AppColors.selected(isDark)
              : AppColors.surface(isDark),
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: log.isRunning
                  ? AppColors.green(isDark).withValues(alpha: 0.6)
                  : isSelected
                  ? AppColors.primary(isDark).withValues(alpha: 0.4)
                  : AppColors.line(isDark),
              width: log.isRunning ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Tooltip(
                      message: log.isRunning
                          ? 'Поставьте таймер на паузу перед выбором для сборки дня'
                          : (isInDraft
                                ? 'Лог уже включен в черновик на $draftDate'
                                : 'Выбрать для сборки дня'),
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (log.isRunning || isInDraft)
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        log.titleSnapshot,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (isInDraft) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          'В черновике ($draftDate)',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.indigo,
                            fontWeight: FontWeight.bold,
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
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.red,
                        ),
                        tooltip: 'Удалить лог',
                        onPressed: () => _confirmDeleteLog(context, log),
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
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
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
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
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
                          LogClock.formatHoursMinutes(
                            clockResult.elapsedSeconds,
                          ),
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
          Icon(
            Icons.check_box_outlined,
            color: AppColors.primary(isDark),
            size: 20,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Выбрано для сборки дня: $count (${LogClock.formatHoursMinutes(totalSec)})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                'Выбрано для сборки · исходное время',
                style: TextStyle(fontSize: 11, color: AppColors.muted(isDark)),
              ),
            ],
          ),
          const Spacer(),
          TextButton(
            onPressed: () => widget.appState.clearLogSelection(),
            child: const Text('Снять выбор'),
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
            onPressed: () {
              // Переход на экран «День»
              widget.appState.selectTab(1);
            },
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: const Text('Собрать день'),
          ),
        ],
      ),
    );
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
