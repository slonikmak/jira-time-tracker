import '../app_message.dart';
import '../l10n/app_localizations.dart';
import '../ui/message_format.dart';
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
  String? _fixedStartTime;
  Object? _errorMessage;
  bool _isSaving = false;

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
      setState(() {
        _fixedStartTime =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final h = widget.log.accumulatedSeconds ~/ 3600;
    final m = (widget.log.accumulatedSeconds % 3600) ~/ 60;
    _hoursController = TextEditingController(text: h.toString());
    _minutesController = TextEditingController(text: m.toString());
    _descController = TextEditingController(text: widget.log.description);
    _fixedStartTime = widget.log.fixedStartTime;
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
        _errorMessage = AppMessage(
          'durationMustBeGreaterThanZero',
          [],
          "Длительность времени должна быть больше нуля",
        );
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
        fixedStartTime: _fixedStartTime,
        clearFixedStartTime: _fixedStartTime == null,
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e;
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
      contentPadding: const EdgeInsets.fromLTRB(28, 18, 28, 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppLocalizations.of(context).editTimeEntry,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 4),
          Text(
            widget.log.titleSnapshot,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).hours,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).minutes,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hoursController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _minutesController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  renderMessage(context, _errorMessage!),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 16),

              Text(
                AppLocalizations.of(context).workDoneDescription,
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 98,
                child: TextField(
                  controller: _descController,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(
                      context,
                    ).briefDescriptionOfTheWork,
                    isDense: true,
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const SizedBox(height: 4),
              if (_fixedStartTime == null)
                TextButton.icon(
                  onPressed: _pickFixedStartTime,
                  icon: const Icon(Icons.schedule, size: 16),
                  label: Text(AppLocalizations.of(context).setStartTime),
                )
              else
                Row(
                  children: [
                    Text(
                      AppLocalizations.of(context).fixedStart,
                      style: TextStyle(fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _pickFixedStartTime,
                      child: Text(_fixedStartTime!),
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context).clearFixedStartTime,
                      onPressed: () => setState(() => _fixedStartTime = null),
                      icon: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).cancel),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppLocalizations.of(context).save),
        ),
      ],
    );
  }
}
