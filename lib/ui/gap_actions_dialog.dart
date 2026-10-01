import '../app_message.dart';
import '../l10n/app_localizations.dart';
import '../ui/message_format.dart';
import 'package:flutter/material.dart';
import '../models.dart';
import 'app_theme.dart';

/// Диалог быстрых целевых действий над свободным промежутком расписания (Gap Actions).
class GapActionsDialog extends StatefulWidget {
  final Break breakItem;
  final GapNeighbors neighbors;
  final VoidCallback onSnap;
  final VoidCallback onFillLeft;
  final void Function(int newDurationSeconds) onSetDuration;
  final Object? Function(int newDurationSeconds)? onValidateDuration;

  const GapActionsDialog({
    super.key,
    required this.breakItem,
    required this.neighbors,
    required this.onSnap,
    required this.onFillLeft,
    required this.onSetDuration,
    this.onValidateDuration,
  });

  @override
  State<GapActionsDialog> createState() => _GapActionsDialogState();
}

class _GapActionsDialogState extends State<GapActionsDialog> {
  late TextEditingController _minutesController;
  Object? _errorMessage;

  @override
  void initState() {
    super.initState();
    final initialMinutes = (widget.breakItem.durationSeconds / 60).round();
    _minutesController = TextEditingController(text: initialMinutes.toString());
  }

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  void _applyDuration(int minutes) {
    if (minutes <= 0) {
      setState(() {
        _errorMessage = AppMessage(
          'breakDurationMustBeGreaterThanMinutes',
          [],
          "Длительность перерыва должна быть больше 0 минут.",
        );
      });
      return;
    }
    final sec = minutes * 60;
    if (widget.onValidateDuration != null) {
      final err = widget.onValidateDuration!(sec);
      if (err != null) {
        setState(() {
          _errorMessage = err;
        });
        return;
      }
    }
    widget.onSetDuration(sec);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final startLocal = widget.breakItem.startUtc.toLocal();
    final endLocal = widget.breakItem.endUtc.toLocal();
    final startStr =
        '${startLocal.hour.toString().padLeft(2, '0')}:${startLocal.minute.toString().padLeft(2, '0')}';
    final endStr =
        '${endLocal.hour.toString().padLeft(2, '0')}:${endLocal.minute.toString().padLeft(2, '0')}';
    final durationStr = formatHoursMinutes(
      context,
      widget.breakItem.durationSeconds,
    );

    final leftTask = widget.neighbors.leftSegment;
    final leftLocked = widget.neighbors.isLeftLocked;
    final canFillLeft = leftTask != null && !leftLocked;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.coffee, color: AppColors.muted(isDark)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(
                    context,
                  ).break354(renderMessage(context, durationStr)),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$startStr — $endStr',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.muted(isDark),
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
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
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          renderMessage(context, _errorMessage),
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Блок быстрых действий
              Text(
                AppLocalizations.of(context).quickActions,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // 1. Схлопнуть паузу
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: AppColors.line(isDark)),
                ),
                leading: const Icon(Icons.compress, color: Colors.blue),
                title: Text(
                  AppLocalizations.of(context).collapseBreak,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  AppLocalizations.of(
                    context,
                  ).moveFollowingTasksTogetherRemoveTheGap,
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  widget.onSnap();
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 8),

              // 2. Растянуть предыдущую задачу
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: AppColors.line(isDark)),
                ),
                leading: Icon(
                  Icons.trending_flat,
                  color: canFillLeft ? Colors.green : Colors.grey,
                ),
                title: Text(
                  AppLocalizations.of(context).extendPreviousTask,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  canFillLeft
                      ? AppLocalizations.of(
                          context,
                        ).extendTaskBy(renderMessage(context, durationStr))
                      : leftLocked
                      ? AppLocalizations.of(
                          context,
                        ).thePreviousEntryIsFixedInJira
                      : AppLocalizations.of(context).thisIsTheStartOfTheDayNo,
                  style: TextStyle(
                    fontSize: 12,
                    color: canFillLeft ? null : AppColors.muted(isDark),
                  ),
                ),
                enabled: canFillLeft,
                onTap: canFillLeft
                    ? () {
                        widget.onFillLeft();
                        Navigator.of(context).pop();
                      }
                    : null,
              ),
              const SizedBox(height: 18),

              // Разделитель и блок точной длительности
              const Divider(height: 1),
              const SizedBox(height: 14),

              Text(
                AppLocalizations.of(context).setBreakDuration,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(
                  context,
                ).followingTasksWillShiftTogetherPreservingTheirDurations,
                style: TextStyle(fontSize: 11, color: AppColors.muted(isDark)),
              ),
              const SizedBox(height: 10),

              // Быстрые чипы длительности
              Wrap(
                spacing: 8,
                children: [15, 30, 45, 60].map((mins) {
                  return ActionChip(
                    label: Text(
                      AppLocalizations.of(
                        context,
                      ).min(renderMessage(context, mins)),
                    ),
                    onPressed: () {
                      _minutesController.text = mins.toString();
                      _applyDuration(mins);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // Ручной ввод минут
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minutesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).minutes,
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() => _errorMessage = null),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () {
                      final mins =
                          int.tryParse(_minutesController.text.trim()) ?? 0;
                      _applyDuration(mins);
                    },
                    child: Text(AppLocalizations.of(context).apply),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).close),
        ),
      ],
    );
  }
}
