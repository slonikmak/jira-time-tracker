import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../log_clock.dart';
import '../models.dart';
import '../service_tickets.dart';
import 'app_theme.dart';

class _TicketOption {
  final String id;
  final String key;
  final String title;
  final String? description;
  final bool isService;

  const _TicketOption({
    required this.id,
    required this.key,
    required this.title,
    this.description,
    this.isService = false,
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

  List<_TicketOption> _getTicketOptions() {
    final List<_TicketOption> options = [];
    final existingIssues = widget.appState.issues;
    final Set<String> existingKeys = {};

    for (final issue in existingIssues) {
      existingKeys.add(issue.key.toUpperCase());
      final service = findServiceTicket(issue.key);
      options.add(
        _TicketOption(
          id: issue.issueId,
          key: issue.key,
          title: issue.summary,
          description: service?.description,
          isService: service != null,
        ),
      );
    }

    // Добавляем все предопределённые служебные тикеты, которых ещё нет в списке недавних
    for (final service in kServiceTickets) {
      if (!existingKeys.contains(service.key.toUpperCase())) {
        options.add(
          _TicketOption(
            id: service.key,
            key: service.key,
            title: service.category,
            description: service.description,
            isService: true,
          ),
        );
      }
    }

    return options;
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
        .where((i) => i.issueId == _selectedIssueId || i.key == _selectedIssueId)
        .firstOrNull;

    if (selectedIssue == null && _selectedIssueId != null) {
      final ticket = findServiceTicket(_selectedIssueId!);
      if (ticket != null) {
        selectedIssue = await widget.appState.addServiceTicket(ticket);
        _selectedIssueId = selectedIssue.issueId;
      }
    }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = _getTicketOptions();
    if (options.isNotEmpty &&
        !options.any((o) => o.id == _selectedIssueId)) {
      final matchedByKey = options
          .where((o) => o.key.toUpperCase() == _selectedIssueId?.toUpperCase())
          .firstOrNull;
      _selectedIssueId = matchedByKey?.id ?? options.first.id;
    }
    final selectedOpt = options
        .where((o) => o.id == _selectedIssueId)
        .firstOrNull;

    return AlertDialog(
      title: const Text('Добавить время'),
      content: SizedBox(
        width: 460,
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
              if (widget.initialIssue != null) ...[
                Builder(
                  builder: (context) {
                    final service = findServiceTicket(widget.initialIssue!.key);
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.hover(isDark),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.line(isDark)),
                      ),
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
                          if (service != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              service.description,
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
                DropdownButtonFormField<String>(
                  initialValue: _selectedIssueId,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  selectedItemBuilder: (context) {
                    return options.map((opt) {
                      final descPart = opt.description != null
                          ? ' — ${opt.description}'
                          : '';
                      return Text(
                        '${opt.key}: ${opt.title}$descPart',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      );
                    }).toList();
                  },
                  items: options.map((opt) {
                    return DropdownMenuItem<String>(
                      value: opt.id,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
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
                                    color: opt.isService
                                        ? AppColors.selected(isDark)
                                        : AppColors.hover(isDark),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    opt.key,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: opt.isService
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
                if (selectedOpt?.description != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.hover(isDark),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.line(isDark)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 15,
                          color: AppColors.primary(isDark),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            selectedOpt!.description!,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.muted(isDark),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
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
