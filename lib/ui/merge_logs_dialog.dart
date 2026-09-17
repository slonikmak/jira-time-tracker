import 'package:flutter/material.dart';
import '../app_state.dart';
import '../log_clock.dart';
import '../models.dart';
import 'app_theme.dart';

/// Диалог объединения двух неиспользованных логов.
class MergeLogsDialog extends StatefulWidget {
  final AppState appState;
  final LocalLog primaryLog;

  const MergeLogsDialog({
    super.key,
    required this.appState,
    required this.primaryLog,
  });

  static Future<void> show(
    BuildContext context, {
    required AppState appState,
    required LocalLog log,
  }) async {
    return showDialog(
      context: context,
      builder: (ctx) => MergeLogsDialog(appState: appState, primaryLog: log),
    );
  }

  @override
  State<MergeLogsDialog> createState() => _MergeLogsDialogState();
}

class _MergeLogsDialogState extends State<MergeLogsDialog> {
  LocalLog? _selectedCandidate;
  String? _targetIssueId;
  String? _errorMessage;
  bool _isSaving = false;

  List<LocalLog> get _candidates {
    return widget.appState.unconsumedLogs.where((l) {
      if (l.id == widget.primaryLog.id) return false;
      if (l.isRunning) return false;
      if (widget.appState.isLogInDraft(l.id)) return false;
      return true;
    }).toList();
  }

  Future<void> _handleMerge() async {
    final candidate = _selectedCandidate;
    if (candidate == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final targetIssueId = _targetIssueId ?? widget.primaryLog.issueId;
      await widget.appState.mergeLogs(
        logIds: [widget.primaryLog.id, candidate.id],
        targetIssueId: targetIssueId,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Логи успешно объединены. Общая длительность: ${LogClock.formatHoursMinutes(widget.primaryLog.accumulatedSeconds + candidate.accumulatedSeconds)}',
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
    final candidates = _candidates;

    return AlertDialog(
      title: const Text('Объединить с другим логом'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Текущий лог: ${widget.primaryLog.titleSnapshot}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                'Длительность: ${LogClock.formatHoursMinutes(widget.primaryLog.accumulatedSeconds)}',
                style: TextStyle(fontSize: 12, color: AppColors.muted(isDark)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Выберите лог для объединения:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),

              if (candidates.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Нет доступных свободных логов для объединения.',
                      style: TextStyle(color: AppColors.muted(isDark), fontSize: 13),
                    ),
                  ),
                )
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.line(isDark)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: candidates.length,
                    separatorBuilder: (_, index) => Divider(height: 1, color: AppColors.line(isDark)),
                    itemBuilder: (context, index) {
                      final candidate = candidates[index];
                      final isSelected = _selectedCandidate?.id == candidate.id;
                      final isSameIssue = candidate.issueId == widget.primaryLog.issueId;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedCandidate = candidate;
                            _targetIssueId = isSameIssue
                                ? widget.primaryLog.issueId
                                : widget.primaryLog.issueId;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          color: isSelected
                              ? AppColors.selected(isDark)
                              : Colors.transparent,
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                size: 18,
                                color: isSelected
                                    ? AppColors.primary(isDark)
                                    : AppColors.muted(isDark),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      candidate.titleSnapshot,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                    ),
                                    if (candidate.description.isNotEmpty)
                                      Text(
                                        candidate.description,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.muted(isDark),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                LogClock.formatHoursMinutes(candidate.accumulatedSeconds),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // Если выбрана задача другого тикета — выбор целевой задачи
              if (_selectedCandidate != null &&
                  _selectedCandidate!.issueId != widget.primaryLog.issueId) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Логи принадлежат разным задачам. Выберите задачу для результата:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      RadioGroup<String>(
                        groupValue: _targetIssueId,
                        onChanged: (val) => setState(() => _targetIssueId = val),
                        child: Column(
                          children: [
                            RadioListTile<String>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                widget.primaryLog.titleSnapshot,
                                style: const TextStyle(fontSize: 12),
                              ),
                              value: widget.primaryLog.issueId,
                            ),
                            RadioListTile<String>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                _selectedCandidate!.titleSnapshot,
                                style: const TextStyle(fontSize: 12),
                              ),
                              value: _selectedCandidate!.issueId,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
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
          onPressed: _isSaving || _selectedCandidate == null ? null : _handleMerge,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Объединить'),
        ),
      ],
    );
  }
}
