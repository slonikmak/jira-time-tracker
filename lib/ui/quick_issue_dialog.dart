import '../app_message.dart';
import '../l10n/app_localizations.dart';
import '../ui/message_format.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import 'app_theme.dart';

/// Добавление проверенной Jira-задачи в быстрые или изменение её подсказки.
class QuickIssueDialog extends StatefulWidget {
  final AppState appState;
  final QuickIssue? quickIssue;
  final Issue? issue;

  const QuickIssueDialog._({
    required this.appState,
    this.quickIssue,
    this.issue,
  });

  static Future<void> showAdd(
    BuildContext context, {
    required AppState appState,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .30),
      builder: (_) => QuickIssueDialog._(appState: appState),
    );
  }

  static Future<void> showEdit(
    BuildContext context, {
    required AppState appState,
    required QuickIssue quickIssue,
    required Issue issue,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .30),
      builder: (_) => QuickIssueDialog._(
        appState: appState,
        quickIssue: quickIssue,
        issue: issue,
      ),
    );
  }

  @override
  State<QuickIssueDialog> createState() => _QuickIssueDialogState();
}

class _QuickIssueDialogState extends State<QuickIssueDialog> {
  late final TextEditingController _inputController;
  late final TextEditingController _noteController;
  Issue? _foundIssue;
  Object? _error;
  bool _isSearching = false;
  bool _isSaving = false;

  bool get _isEditing => widget.quickIssue != null;

  @override
  void initState() {
    super.initState();
    _foundIssue = widget.issue;
    _inputController = TextEditingController(text: widget.issue?.key ?? '');
    _noteController = TextEditingController(
      text: widget.quickIssue?.note ?? '',
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _findIssue() async {
    final input = _inputController.text.trim();
    if (input.isEmpty) {
      setState(
        () => _error = AppMessage(
          'enterAJiraIssueKeyIdOrLink',
          [],
          'Введите ключ, ID или ссылку на задачу Jira',
        ),
      );
      return;
    }
    setState(() {
      _isSearching = true;
      _foundIssue = null;
      _error = null;
    });
    try {
      final issue = await widget.appState.previewQuickIssue(input);
      if (mounted) setState(() => _foundIssue = issue);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _save() async {
    final foundIssue = _foundIssue;
    if (!_isEditing && foundIssue == null) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      if (_isEditing) {
        await widget.appState.updateQuickIssueNote(
          widget.quickIssue!.issueId,
          _noteController.text,
        );
      } else {
        await widget.appState.addQuickIssue(
          foundIssue!.key,
          note: _noteController.text,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _friendlyError(error);
          _isSaving = false;
        });
      }
    }
  }

  Object _friendlyError(Object error) {
    if (error is MessageException) return error.messageText;
    final value = error.toString();
    return value
        .replaceFirst('Bad state: ', '')
        .replaceFirst('FormatException: ', '')
        .replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final busy = _isSearching || _isSaving;
    return AlertDialog(
      constraints: const BoxConstraints(minWidth: 440, maxWidth: 480),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 16, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 22),
      title: Row(
        children: [
          Expanded(
            child: Text(
              _isEditing
                  ? AppLocalizations.of(context).editQuickIssue
                  : AppLocalizations.of(context).addQuickIssue,
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
            ),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).close,
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isEditing) ...[
              Text(
                AppLocalizations.of(
                  context,
                ).findAnExistingIssueInTheConnectedJira,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).keyIdOrLink,
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('quick-issue-input'),
                      controller: _inputController,
                      enabled: !busy,
                      autofocus: true,
                      onChanged: (_) {
                        if (_foundIssue != null || _error != null) {
                          setState(() {
                            _foundIssue = null;
                            _error = null;
                          });
                        }
                      },
                      onSubmitted: (_) => _findIssue(),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context).forExampleProj,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    key: const ValueKey('quick-issue-find'),
                    onPressed: busy ? null : _findIssue,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(76, 42),
                    ),
                    child: _isSearching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(AppLocalizations.of(context).find),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 17,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      renderMessage(context, _error!),
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_foundIssue != null) ...[
              if (!_isEditing) const SizedBox(height: 16),
              _IssuePreview(issue: _foundIssue!, isDark: isDark),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).note,
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              TextField(
                key: const ValueKey('quick-issue-note'),
                controller: _noteController,
                enabled: !busy,
                minLines: 2,
                maxLines: 3,
                maxLength: 240,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(
                    context,
                  ).optionalWhenToUseThisIssue,
                  alignLabelWithHint: true,
                ),
              ),
              Text(
                AppLocalizations.of(context).theNoteIsLocalAndIsNotSubmitted,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).cancel),
        ),
        FilledButton(
          key: const ValueKey('quick-issue-save'),
          onPressed: busy || _foundIssue == null ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _isEditing
                      ? AppLocalizations.of(context).save
                      : AppLocalizations.of(context).add,
                ),
        ),
      ],
    );
  }
}

class _IssuePreview extends StatelessWidget {
  final Issue issue;
  final bool isDark;

  const _IssuePreview({required this.issue, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('quick-issue-preview'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.hover(isDark),
        border: Border.all(color: AppColors.line(isDark)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            issue.key,
            style: TextStyle(
              color: AppColors.primary(isDark),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(issue.summary, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
