import '../l10n/app_localizations.dart';
import '../ui/message_format.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';
import 'app_theme.dart';

/// Диалог объединения двух сегментов дня в один.
class MergeSegmentsDialog extends StatefulWidget {
  final AppState appState;
  final Segment segment;

  const MergeSegmentsDialog({
    super.key,
    required this.appState,
    required this.segment,
  });

  static Future<void> show(
    BuildContext context, {
    required AppState appState,
    required Segment segment,
  }) async {
    return showDialog(
      context: context,
      builder: (ctx) =>
          MergeSegmentsDialog(appState: appState, segment: segment),
    );
  }

  @override
  State<MergeSegmentsDialog> createState() => _MergeSegmentsDialogState();
}

class _MergeSegmentsDialogState extends State<MergeSegmentsDialog> {
  Segment? _selectedSegment;
  Object? _errorMessage;
  bool _isSaving = false;

  List<Segment> get _candidates {
    return widget.appState.currentSegments
        .where(
          (s) =>
              s.id != widget.segment.id &&
              s.sourceLogId == widget.segment.sourceLogId &&
              s.sendState != SendState.sent,
        )
        .toList();
  }

  String _getIssueKey(String issueId) {
    final issue = widget.appState.issues
        .where((i) => i.issueId == issueId)
        .firstOrNull;
    return issue?.key ?? issueId;
  }

  String _getIssueSummary(String issueId) {
    final issue = widget.appState.issues
        .where((i) => i.issueId == issueId)
        .firstOrNull;
    return issue?.summary ?? '';
  }

  String _formatTimeRange(DateTime start, DateTime end) {
    final sLocal = start.toLocal();
    final eLocal = end.toLocal();
    final sStr =
        '${sLocal.hour.toString().padLeft(2, '0')}:${sLocal.minute.toString().padLeft(2, '0')}';
    final eStr =
        '${eLocal.hour.toString().padLeft(2, '0')}:${eLocal.minute.toString().padLeft(2, '0')}';
    return '$sStr — $eStr';
  }

  void _handleMerge() {
    if (_selectedSegment == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      widget.appState.mergeSegments(
        segmentId1: widget.segment.id,
        segmentId2: _selectedSegment!.id,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Builder(
              builder: (context) => Text(
                AppLocalizations.of(context).intervalsSuccessfullyMerged,
              ),
            ),
          ),
        );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final candidates = _candidates;
    final primaryKey = _getIssueKey(widget.segment.issueId);

    return AlertDialog(
      title: Text(AppLocalizations.of(context).mergeIntervals),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).currentInterval(
                  renderMessage(context, primaryKey),
                  renderMessage(
                    context,
                    _formatTimeRange(
                      widget.segment.startUtc,
                      widget.segment.endUtc,
                    ),
                  ),
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                AppLocalizations.of(context).duration376(
                  renderMessage(
                    context,
                    formatHoursMinutes(context, widget.segment.durationSeconds),
                  ),
                ),
                style: TextStyle(fontSize: 12, color: AppColors.muted(isDark)),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).selectAnIntervalToMerge,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),

              if (candidates.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      AppLocalizations.of(
                        context,
                      ).noOtherIntervalsAvailableToMerge,
                      style: TextStyle(
                        color: AppColors.muted(isDark),
                        fontSize: 13,
                      ),
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
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: AppColors.line(isDark)),
                    itemBuilder: (context, index) {
                      final candidate = candidates[index];
                      final isSelected = _selectedSegment?.id == candidate.id;
                      final candKey = _getIssueKey(candidate.issueId);
                      final candSummary = _getIssueSummary(candidate.issueId);

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedSegment = candidate;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
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
                                    Row(
                                      children: [
                                        Text(
                                          candKey,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatTimeRange(
                                            candidate.startUtc,
                                            candidate.endUtc,
                                          ),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.muted(isDark),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (candSummary.isNotEmpty)
                                      Text(
                                        candSummary,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.muted(isDark),
                                        ),
                                      ),
                                    if (candidate.description.isNotEmpty)
                                      Text(
                                        candidate.description,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: AppColors.muted(isDark),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formatHoursMinutes(
                                  context,
                                  candidate.durationSeconds,
                                ),
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

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  renderMessage(context, _errorMessage!),
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
          child: Text(AppLocalizations.of(context).cancel),
        ),
        FilledButton(
          onPressed: _isSaving || _selectedSegment == null
              ? null
              : _handleMerge,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppLocalizations.of(context).merge),
        ),
      ],
    );
  }
}
