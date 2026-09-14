import 'package:flutter/material.dart';
import '../models.dart';

/// Диалог ручного редактирования времени начала, длительности и описания сегмента (сценарий A13).
class EditSegmentDialog extends StatefulWidget {
  final Segment segment;
  final String taskTitle;
  final void Function({
    required DateTime startUtc,
    required int durationSeconds,
    required String description,
  })
  onSave;

  const EditSegmentDialog({
    super.key,
    required this.segment,
    required this.taskTitle,
    required this.onSave,
  });

  @override
  State<EditSegmentDialog> createState() => _EditSegmentDialogState();
}

class _EditSegmentDialogState extends State<EditSegmentDialog> {
  late TimeOfDay _startTime;
  late TextEditingController _hoursController;
  late TextEditingController _minutesController;
  late TextEditingController _descriptionController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final localStart = widget.segment.startUtc.toLocal();
    _startTime = TimeOfDay(hour: localStart.hour, minute: localStart.minute);

    final totalSeconds = widget.segment.durationSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;

    _hoursController = TextEditingController(text: hours.toString());
    _minutesController = TextEditingController(text: minutes.toString());
    _descriptionController = TextEditingController(
      text: widget.segment.description,
    );
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  int get _parsedDurationSeconds {
    final h = int.tryParse(_hoursController.text.trim()) ?? 0;
    final m = int.tryParse(_minutesController.text.trim()) ?? 0;
    return h * 3600 + m * 60;
  }

  DateTime get _computedStartUtc {
    final localDate = widget.segment.startUtc.toLocal();
    final localDateTime = DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    return localDateTime.toUtc();
  }

  DateTime get _computedEndLocal {
    final startLocal = DateTime(
      widget.segment.startUtc.toLocal().year,
      widget.segment.startUtc.toLocal().month,
      widget.segment.startUtc.toLocal().day,
      _startTime.hour,
      _startTime.minute,
    );
    return startLocal.add(Duration(seconds: _parsedDurationSeconds));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      helpText: 'Выберите время начала',
      cancelText: 'Отмена',
      confirmText: 'Готово',
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  void _submit() {
    final durationSec = _parsedDurationSeconds;
    if (durationSec <= 0) {
      setState(() {
        _errorMessage = 'Длительность должна быть больше 0 минут.';
      });
      return;
    }

    widget.onSave(
      startUtc: _computedStartUtc,
      durationSeconds: durationSec,
      description: _descriptionController.text.trim(),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final startFormatted =
        '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
    final endFormatted =
        '${_computedEndLocal.hour.toString().padLeft(2, '0')}:${_computedEndLocal.minute.toString().padLeft(2, '0')}';

    return AlertDialog(
      title: Text(
        'Редактировать интервал: ${widget.taskTitle}',
        style: const TextStyle(fontSize: 18),
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontSize: 13,
                    ),
                  ),
                ),
              // Время начала
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: const Text('Время начала:'),
                subtitle: Text(
                  '$startFormatted (окончание: $endFormatted)',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: OutlinedButton(
                  onPressed: _pickTime,
                  child: const Text('Изменить'),
                ),
              ),
              const SizedBox(height: 12),
              // Длительность
              const Text(
                'Длительность:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hoursController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Часы',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _minutesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Минуты',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Описание
              const Text(
                'Описание работы (комментарий Jira):',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Что было сделано за этот интервал...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Сохранить')),
      ],
    );
  }
}
