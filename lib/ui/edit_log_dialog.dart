import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../models.dart';

/// Диалог редактирования свободного остановленного лога.
class EditLogDialog extends StatefulWidget {
  final AppState appState;
  final LocalLog log;

  const EditLogDialog({super.key, required this.appState, required this.log});

  static Future<void> show(
    BuildContext context, {
    required AppState appState,
    required LocalLog log,
  }) async {
    return showDialog(
      context: context,
      builder: (ctx) => EditLogDialog(appState: appState, log: log),
    );
  }

  @override
  State<EditLogDialog> createState() => _EditLogDialogState();
}

class _EditLogDialogState extends State<EditLogDialog> {
  late final TextEditingController _hoursController;
  late final TextEditingController _minutesController;
  late final TextEditingController _descController;
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final h = widget.log.accumulatedSeconds ~/ 3600;
    final m = (widget.log.accumulatedSeconds % 3600) ~/ 60;
    _hoursController = TextEditingController(text: h.toString());
    _minutesController = TextEditingController(text: m.toString());
    _descController = TextEditingController(text: widget.log.description);
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
      await widget.appState.editLog(
        logId: widget.log.id,
        durationSeconds: totalSeconds,
        description: _descController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
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
    return AlertDialog(
      title: const Text('Редактировать запись времени'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.log.titleSnapshot,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),

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

              const Text(
                'Что сделано (описание)',
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
