import 'package:flutter/material.dart';
import '../models.dart';

/// Диалог ручного редактирования времени начала, длительности и описания сегмента (сценарий A13).
class EditSegmentDialog extends StatefulWidget {
  final Segment segment;
  final String taskTitle;
  final VoidCallback? onDelete;
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
    this.onDelete,
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

    try {
      widget.onSave(
        startUtc: _computedStartUtc,
        durationSeconds: durationSec,
        description: _descriptionController.text.trim(),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _errorMessage = e is ArgumentError
            ? (e.message?.toString() ?? e.toString())
            : e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final startFormatted =
        '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
    final endFormatted =
        '${_computedEndLocal.hour.toString().padLeft(2, '0')}:${_computedEndLocal.minute.toString().padLeft(2, '0')}';

    return AlertDialog(
      constraints: BoxConstraints(
        maxWidth: 620,
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      titlePadding: const EdgeInsets.fromLTRB(28, 27, 28, 0),
      contentPadding: const EdgeInsets.fromLTRB(28, 23, 28, 8),
      actionsPadding: const EdgeInsets.fromLTRB(28, 22, 28, 27),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Изменить интервал',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 24),
                ),
              ),
              IconButton(
                tooltip: 'Закрыть',
                onPressed: () => Navigator.of(context).pop(),
                constraints: const BoxConstraints.tightFor(
                  width: 24,
                  height: 24,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close, size: 17),
              ),
            ],
          ),
          const SizedBox(height: 25),
          Text(
            widget.taskTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 13,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Начало', style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 7),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _pickTime,
                            style: OutlinedButton.styleFrom(
                              alignment: Alignment.centerLeft,
                              minimumSize: const Size(0, 46),
                            ),
                            child: Text(
                              startFormatted,
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Длительность',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _hoursController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: 'Часы',
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TextField(
                                controller: _minutesController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: 'Минуты',
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 15,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              Text(
                'Окончание: $endFormatted',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 22),
              const Text('Что сделано', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 7),
              SizedBox(
                height: 104,
                child: TextField(
                  controller: _descriptionController,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  decoration: const InputDecoration(
                    hintText: 'Что было сделано за этот интервал...',
                    isDense: true,
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 10,
          runSpacing: 8,
          children: [
            if (widget.onDelete != null)
              TextButton(
                onPressed: widget.onDelete,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  textStyle: const TextStyle(fontSize: 12),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 39),
                ),
                child: const Text('Удалить интервал'),
              ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(82, 39),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size(101, 39),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ],
    );
  }
}
