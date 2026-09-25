import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../log_clock.dart';
import '../models.dart';
import 'app_theme.dart';

class _TicketOption {
  final String id;
  final String key;
  final String title;
  final String? description;
  final bool isQuick;
  final bool startsGroup;

  const _TicketOption({
    required this.id,
    required this.key,
    required this.title,
    this.description,
    this.isQuick = false,
    this.startsGroup = false,
  });
}

/// Диалог ручного ввода времени для задачи (сценарий A01).
class AddTimeDialog extends StatefulWidget {
  final AppState appState;
  final Issue? initialIssue;

  const AddTimeDialog({super.key, required this.appState, this.initialIssue});

  static Future<void> show(
    BuildContext context, {
    required AppState appState,
    Issue? issue,
  }) async {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.30),
      builder: (ctx) => AddTimeDialog(appState: appState, initialIssue: issue),
    );
  }

  @override
  State<AddTimeDialog> createState() => _AddTimeDialogState();
}

class _AddTimeDialogState extends State<AddTimeDialog> {
  late String? _selectedIssueId;
  final TextEditingController _hoursController = TextEditingController(
    text: '1',
  );
  final TextEditingController _minutesController = TextEditingController(
    text: '00',
  );
  final TextEditingController _descController = TextEditingController();
  String? _fixedStartTime;
  String? _errorMessage;
  bool _isSaving = false;

  int get _durationSeconds =>
      ((int.tryParse(_hoursController.text.trim()) ?? 0) * 3600) +
      ((int.tryParse(_minutesController.text.trim()) ?? 0) * 60);

  Future<void> _pickFixedStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _fixedStartTime != null
          ? TimeOfDay(
              hour: int.parse(_fixedStartTime!.split(':')[0]),
              minute: int.parse(_fixedStartTime!.split(':')[1]),
            )
          : const TimeOfDay(hour: 11, minute: 0),
    );
    if (picked != null) {
      final hh = picked.hour.toString().padLeft(2, '0');
      final mm = picked.minute.toString().padLeft(2, '0');
      setState(() => _fixedStartTime = '$hh:$mm');
    }
  }

  List<_TicketOption> _getTicketOptions() {
    final options = <_TicketOption>[];
    final existingIssues = widget.appState.issues;
    final includedIssueIds = <String>{};

    for (final quickIssue in widget.appState.quickIssues) {
      final issue = existingIssues
          .where((candidate) => candidate.issueId == quickIssue.issueId)
          .firstOrNull;
      if (issue != null) {
        final startsGroup = options.isEmpty;
        includedIssueIds.add(issue.issueId);
        options.add(
          _TicketOption(
            id: issue.issueId,
            key: issue.key,
            title: issue.summary,
            description: quickIssue.note,
            isQuick: true,
            startsGroup: startsGroup,
          ),
        );
      }
    }

    var firstRecent = true;
    for (final issue in existingIssues) {
      if (includedIssueIds.contains(issue.issueId)) continue;
      options.add(
        _TicketOption(
          id: issue.issueId,
          key: issue.key,
          title: issue.summary,
          startsGroup: firstRecent,
        ),
      );
      firstRecent = false;
    }

    return options;
  }

  QuickIssue? _quickIssueFor(String issueId) {
    for (final quickIssue in widget.appState.quickIssues) {
      if (quickIssue.issueId == issueId) return quickIssue;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final initialId = widget.initialIssue?.issueId;
    if (initialId != null) {
      _selectedIssueId = initialId;
    } else {
      final options = _getTicketOptions();
      _selectedIssueId = options.isNotEmpty ? options.first.id : null;
    }
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() {
      _errorMessage = null;
    });

    if (_selectedIssueId == null) {
      setState(() {
        _errorMessage = 'Выберите задачу из списка';
      });
      return;
    }

    Issue? selectedIssue = widget.appState.issues
        .where(
          (i) => i.issueId == _selectedIssueId || i.key == _selectedIssueId,
        )
        .firstOrNull;

    if (selectedIssue == null) {
      setState(() {
        _errorMessage = 'Выбранная задача не найдена';
      });
      return;
    }

    final hours = int.tryParse(_hoursController.text.trim()) ?? 0;
    final minutes = int.tryParse(_minutesController.text.trim()) ?? 0;
    final totalSeconds = (hours * 3600) + (minutes * 60);

    if (totalSeconds <= 0) {
      setState(() {
        _errorMessage = 'Длительность времени должна быть больше нуля';
      });
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.appState.addManualLog(
        issueId: selectedIssue.issueId,
        durationSeconds: totalSeconds,
        description: _descController.text.trim(),
        fixedStartTime: _fixedStartTime,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Добавлено ${LogClock.formatHoursMinutes(totalSeconds)} к ${selectedIssue.key}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = _getTicketOptions();
    if (options.isNotEmpty && !options.any((o) => o.id == _selectedIssueId)) {
      final matchedByKey = options
          .where((o) => o.key.toUpperCase() == _selectedIssueId?.toUpperCase())
          .firstOrNull;
      _selectedIssueId = matchedByKey?.id ?? options.first.id;
    }
    return AlertDialog(
      constraints: const BoxConstraints(
        minWidth: 520,
        maxWidth: 520,
        minHeight: 598,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titlePadding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
      contentPadding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      actionsPadding: const EdgeInsets.fromLTRB(28, 4, 28, 27),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Добавить время',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 24),
                ),
              ),
              IconButton(
                tooltip: 'Закрыть',
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.muted(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Запись появится в очереди. Таймер запускать не нужно.',
            style: TextStyle(fontSize: 13, color: AppColors.muted(isDark)),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Выбор задачи
              Text(
                'Задача',
                style: TextStyle(fontSize: 12, color: AppColors.muted(isDark)),
              ),
              const SizedBox(height: 3),
              if (widget.initialIssue != null) ...[
                Builder(
                  builder: (context) {
                    final quickIssue = _quickIssueFor(
                      widget.initialIssue!.issueId,
                    );
                    return Container(
                      constraints: const BoxConstraints(minHeight: 64),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.hover(isDark),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.line(isDark)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.selected(isDark),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.initialIssue!.key,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.primary(isDark),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.initialIssue!.summary,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (quickIssue?.note?.isNotEmpty == true) ...[
                            const SizedBox(height: 4),
                            Text(
                              quickIssue!.note!,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.muted(isDark),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ] else if (options.isEmpty)
                const Text(
                  'Нет доступных задач. Сначала добавьте задачу.',
                  style: TextStyle(color: Colors.red),
                )
              else ...[
                SizedBox(
                  height: 64,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedIssueId,
                    isDense: false,
                    isExpanded: true,
                    itemHeight: null,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 15,
                      ),
                    ),
                    selectedItemBuilder: (context) => options
                        .map(
                          (opt) => Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${opt.key}\n',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primary(isDark),
                                  ),
                                ),
                                TextSpan(
                                  text: opt.title,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(height: 1.15),
                          ),
                        )
                        .toList(),
                    items: options.map((opt) {
                      return DropdownMenuItem<String>(
                        value: opt.id,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (opt.startsGroup) ...[
                                Text(
                                  opt.isQuick
                                      ? 'БЫСТРЫЕ ЗАДАЧИ'
                                      : 'НЕДАВНИЕ ЗАДАЧИ',
                                  style: TextStyle(
                                    fontSize: 9,
                                    letterSpacing: .4,
                                    color: AppColors.muted(isDark),
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: opt.isQuick
                                          ? AppColors.selected(isDark)
                                          : AppColors.hover(isDark),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      opt.key,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: opt.isQuick
                                            ? AppColors.primary(isDark)
                                            : null,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      opt.title,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (opt.description != null &&
                                  opt.description!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  opt.description!,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.muted(isDark),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedIssueId = val;
                        final selected = options
                            .where((o) => o.id == val)
                            .firstOrNull;
                        if (selected?.description != null &&
                            _descController.text.trim().isEmpty) {
                          _descController.text = selected!.description!;
                        }
                      });
                    },
                  ),
                ),
              ],
              const SizedBox(height: 25),

              // Поля длительности (часы и минуты)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Часы',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.muted(isDark),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Минуты',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.muted(isDark),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: TextField(
                        controller: _hoursController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 13,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: TextField(
                        controller: _minutesController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 13,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                ],
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 19),

              // Описание сделанной работы (необязательно)
              Row(
                children: [
                  const Expanded(
                    child: Text('Что сделано', style: TextStyle(fontSize: 12)),
                  ),
                  Text(
                    'Необязательно',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.muted(isDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 98,
                child: TextField(
                  controller: _descController,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Например, форма входа и обработка ошибок',
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ),
              const SizedBox(height: 23),
              if (_durationSeconds > 0) ...[
                Row(
                  children: [
                    InkWell(
                      onTap: _pickFixedStartTime,
                      child: Tooltip(
                        message: 'Указать время начала',
                        child: Icon(
                          Icons.access_time,
                          size: 15,
                          color: AppColors.primary(isDark),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Новая запись · ${LogClock.formatHoursMinutes(_durationSeconds)}',
                      style: TextStyle(
                        color: AppColors.primary(isDark),
                        fontSize: 12,
                      ),
                    ),
                    if (_fixedStartTime != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '· начало $_fixedStartTime',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted(isDark),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 15),
                        tooltip: 'Очистить фиксированное время',
                        onPressed: () => setState(() => _fixedStartTime = null),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(82, 39),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            textStyle: const TextStyle(fontSize: 12),
          ),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _handleSave,
          style: FilledButton.styleFrom(
            minimumSize: const Size(150, 39),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            textStyle: const TextStyle(fontSize: 12),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Сохранить запись'),
        ),
      ],
    );
  }
}
