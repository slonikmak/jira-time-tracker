import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../log_clock.dart';
import '../models.dart';

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
    text: '0',
  );
  final TextEditingController _descController = TextEditingController();
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedIssueId =
        widget.initialIssue?.issueId ??
        (widget.appState.issues.isNotEmpty
            ? widget.appState.issues.first.issueId
            : null);
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

    final selectedIssue = widget.appState.issues
        .where((i) => i.issueId == _selectedIssueId)
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
    final issues = widget.appState.issues;

    return AlertDialog(
      title: const Text('Добавить время'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Выбор задачи
              const Text(
                'Задача',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              if (widget.initialIssue != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
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
                          widget.initialIssue!.key,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.initialIssue!.summary,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )
              else if (issues.isEmpty)
                const Text(
                  'Нет доступных задач. Сначала добавьте задачу.',
                  style: TextStyle(color: Colors.red),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedIssueId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: issues.map((i) {
                    return DropdownMenuItem(
                      value: i.issueId,
                      child: Text(
                        '${i.key}: ${i.summary}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedIssueId = val;
                    });
                  },
                ),
              const SizedBox(height: 16),

              // Поля длительности (часы и минуты)
              const Text(
                'Длительность',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hoursController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Часы',
                        border: OutlineInputBorder(),
                        isDense: true,
                        suffixText: 'ч',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _minutesController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Минуты',
                        border: OutlineInputBorder(),
                        isDense: true,
                        suffixText: 'м',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Описание сделанной работы (необязательно)
              const Text(
                'Что сделано (необязательно)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Краткое описание работы...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Сохранить'),
        ),
      ],
    );
  }
}
