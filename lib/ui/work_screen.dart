import 'package:flutter/material.dart';
import '../app_state.dart';

/// Экран «Работа»: левая колонка — задачи Jira, правая колонка — очередь логов.
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
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Левая колонка: задачи
            Expanded(flex: 5, child: _buildTasksColumn(context)),
            const VerticalDivider(width: 1),
            // Правая колонка: очередь логов (будет наполнена в тикетах 04-05)
            Expanded(flex: 5, child: _buildQueueColumnPlaceholder(context)),
          ],
        );
      },
    );
  }

  Widget _buildTasksColumn(BuildContext context) {
    final filteredIssues = widget.appState.filteredIssues;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Поле ввода для добавления задачи
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
                : ListView.separated(
                    itemCount: filteredIssues.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final issue = filteredIssues[index];
                      final isSelected = widget.appState.selectedIssueIds
                          .contains(issue.issueId);

                      return ListTile(
                        dense: true,
                        leading: _isSelectionMode
                            ? Checkbox(
                                value: isSelected,
                                onChanged: (_) => widget.appState
                                    .toggleIssueSelection(issue.issueId),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  issue.key,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                        title: Text(
                          issue.summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Активность: ${_formatDateTime(issue.lastUsedAtUtc)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.play_arrow),
                              tooltip: 'Запустить таймер (тикет 04)',
                              onPressed: () {},
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              tooltip: 'Добавить время вручную (тикет 04)',
                              onPressed: () {},
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueColumnPlaceholder(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.access_time_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text(
            'Очередь логов',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 4),
          Text(
            'Будет реализована в тикетах 04 и 05.',
            style: TextStyle(color: Colors.grey),
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
