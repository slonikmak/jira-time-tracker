import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../agent_api_server.dart';
import '../app_state.dart';
import '../jira_client.dart';
import '../models.dart';
import 'app_theme.dart';
import 'quick_issue_dialog.dart';

enum SettingsSection { jira, day, quickIssues, agentApi }

/// Страница настроек подключения Jira и локального API.
class SettingsPage extends StatefulWidget {
  final AppState appState;
  final SettingsSection initialSection;
  final VoidCallback? onSaved;
  final VoidCallback? onCancel;

  const SettingsPage({
    super.key,
    required this.appState,
    this.initialSection = SettingsSection.jira,
    this.onSaved,
    this.onCancel,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

/// Совместимый диалоговый вызов для контекстов вне навигации приложения.
class SettingsDialog {
  static Future<void> show(BuildContext context, AppState appState) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: SizedBox(
          width: 1100,
          height: MediaQuery.sizeOf(dialogContext).height * .85,
          child: SettingsPage(
            appState: appState,
            onSaved: () => Navigator.of(dialogContext).pop(),
            onCancel: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      ),
    );
  }
}

class _SettingsPageState extends State<SettingsPage> {
  static const _actionButtonStyle = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(0, 38)),
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(7)),
      ),
    ),
    textStyle: WidgetStatePropertyAll(
      TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    ),
    visualDensity: VisualDensity.standard,
  );

  late final TextEditingController _urlController;
  late final TextEditingController _emailController;
  late final TextEditingController _tokenController;
  late final TextEditingController _agentUrlController;
  late final TextEditingController _skillPromptController;
  late final TextEditingController _agentDayRuleController;
  late final Map<String, TextEditingController> _dayControllers;

  bool _isLoading = true;
  bool _isChecking = false;
  bool _obscureToken = true;
  String? _errorMessage;
  JiraConnection? _verifiedConnection;
  Map<String, String> _dayErrors = {};
  String? _dayMessage;
  late SettingsSection _selectedSection;

  @override
  void initState() {
    super.initState();
    _selectedSection = widget.initialSection;
    _urlController = TextEditingController();
    _emailController = TextEditingController();
    _tokenController = TextEditingController();
    final agentUrl = widget.appState.apiServerUrl ?? 'http://127.0.0.1:8765';
    _agentUrlController = TextEditingController(text: agentUrl);
    _skillPromptController = TextEditingController(
      text: AgentApiServer.generateSkillPrompt(agentUrl),
    );
    _agentDayRuleController = TextEditingController(
      text: widget.appState.agentDayRule,
    );
    _dayControllers = {
      for (final key in [
        'start-min',
        'start-max',
        'duration-min',
        'duration-max',
        'long-start-min',
        'long-start-max',
        'long-duration-min',
        'long-duration-max',
        'short-count-min',
        'short-count-max',
        'short-duration-min',
        'short-duration-max',
      ])
        key: TextEditingController(),
    };
    _fillDaySettings(widget.appState.daySettings);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final form = await widget.appState.connectionStore.loadForm();
    if (mounted) {
      setState(() {
        _urlController.text = form.baseUrl;
        _emailController.text = form.email;
        _tokenController.text = form.token;
        _verifiedConnection = widget.appState.currentConnection;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _emailController.dispose();
    _tokenController.dispose();
    _agentUrlController.dispose();
    _skillPromptController.dispose();
    _agentDayRuleController.dispose();
    for (final controller in _dayControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _clock(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  String _duration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours == 0) return '$minutes м';
    return minutes == 0 ? '$hours ч' : '$hours ч $minutes м';
  }

  void _fillDaySettings(DaySettings settings) {
    final values = <String, String>{
      'start-min': _clock(settings.startMinutesMin),
      'start-max': _clock(settings.startMinutesMax),
      'duration-min': _duration(settings.totalDurationSecondsMin),
      'duration-max': _duration(settings.totalDurationSecondsMax),
      'long-start-min': _clock(settings.lunchStartMinutesMin),
      'long-start-max': _clock(settings.lunchStartMinutesMax),
      'long-duration-min': _duration(settings.lunchDurationSecondsMin),
      'long-duration-max': _duration(settings.lunchDurationSecondsMax),
      'short-count-min': '${settings.shortBreakCountMin}',
      'short-count-max': '${settings.shortBreakCountMax}',
      'short-duration-min': _duration(settings.shortBreakDurationSecondsMin),
      'short-duration-max': _duration(settings.shortBreakDurationSecondsMax),
    };
    for (final entry in values.entries) {
      _dayControllers[entry.key]!.text = entry.value;
    }
  }

  int? _parseClock(String value) {
    final match = RegExp(r'^(\d{1,2}):([0-5]\d)$').firstMatch(value.trim());
    if (match == null) return null;
    final hour = int.parse(match.group(1)!);
    if (hour > 23) return null;
    return hour * 60 + int.parse(match.group(2)!);
  }

  int? _parseDuration(String value) {
    final match = RegExp(
      r'^(?:(\d+)\s*ч)?\s*(?:(\d+)\s*м)?$',
    ).firstMatch(value.trim());
    if (match == null || (match.group(1) == null && match.group(2) == null)) {
      return null;
    }
    final hours = int.tryParse(match.group(1) ?? '0');
    final minutes = int.tryParse(match.group(2) ?? '0');
    if (hours == null || minutes == null || (hours > 0 && minutes >= 60)) {
      return null;
    }
    return (hours * 60 + minutes) * 60;
  }

  void _saveDaySettings() {
    final errors = <String, String>{};
    int read(
      String key,
      String group,
      int? Function(String) parse,
      String hint,
    ) {
      final value = parse(_dayControllers[key]!.text);
      if (value == null) errors[group] = hint;
      return value ?? 0;
    }

    final settings = DaySettings(
      startMinutesMin: read(
        'start-min',
        'start',
        _parseClock,
        'Введите время в формате ЧЧ:ММ.',
      ),
      startMinutesMax: read(
        'start-max',
        'start',
        _parseClock,
        'Введите время в формате ЧЧ:ММ.',
      ),
      totalDurationSecondsMin: read(
        'duration-min',
        'duration',
        _parseDuration,
        'Введите длительность, например 7 ч 30 м.',
      ),
      totalDurationSecondsMax: read(
        'duration-max',
        'duration',
        _parseDuration,
        'Введите длительность, например 8 ч.',
      ),
      lunchStartMinutesMin: read(
        'long-start-min',
        'long_start',
        _parseClock,
        'Введите время в формате ЧЧ:ММ.',
      ),
      lunchStartMinutesMax: read(
        'long-start-max',
        'long_start',
        _parseClock,
        'Введите время в формате ЧЧ:ММ.',
      ),
      lunchDurationSecondsMin: read(
        'long-duration-min',
        'long_duration',
        _parseDuration,
        'Введите длительность, например 30 м.',
      ),
      lunchDurationSecondsMax: read(
        'long-duration-max',
        'long_duration',
        _parseDuration,
        'Введите длительность, например 45 м.',
      ),
      shortBreakCountMin: read(
        'short-count-min',
        'short_count',
        int.tryParse,
        'Введите целое число от 0.',
      ),
      shortBreakCountMax: read(
        'short-count-max',
        'short_count',
        int.tryParse,
        'Введите целое число от 0.',
      ),
      shortBreakDurationSecondsMin: read(
        'short-duration-min',
        'short_duration',
        _parseDuration,
        'Введите длительность, например 5 м.',
      ),
      shortBreakDurationSecondsMax: read(
        'short-duration-max',
        'short_duration',
        _parseDuration,
        'Введите длительность, например 10 м.',
      ),
    );
    if (errors.isEmpty) errors.addAll(settings.validationErrors());
    if (errors.isNotEmpty) {
      setState(() {
        _dayErrors = errors;
        _dayMessage = null;
      });
      return;
    }
    try {
      widget.appState.updateDaySettings(
        settings,
        agentRule: _agentDayRuleController.text,
      );
      setState(() {
        _dayErrors = {};
        _dayMessage = 'Параметры сборки дня сохранены.';
      });
    } catch (e) {
      setState(() => _dayMessage = 'Не удалось сохранить параметры: $e');
    }
  }

  Future<void> _checkConnection() async {
    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    try {
      final conn = await widget.appState.jiraClient.testConnection(
        baseUrl: _urlController.text,
        email: _emailController.text,
        token: _tokenController.text,
      );
      if (mounted) {
        setState(() {
          _verifiedConnection = conn;
          _errorMessage = null;
          _isChecking = false;
        });
      }
    } on JiraApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _verifiedConnection = null;
          _isChecking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка подключения: $e';
          _verifiedConnection = null;
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _saveConnection() async {
    if (_verifiedConnection == null) {
      await _checkConnection();
      if (_verifiedConnection == null) return;
    }

    await widget.appState.updateConnection(
      _verifiedConnection!,
      _tokenController.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Подключение к Jira успешно сохранено')),
      );
    }
  }

  void _invalidateConnectionVerification(String _) {
    if (_verifiedConnection == null && _errorMessage == null) return;
    setState(() {
      _verifiedConnection = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ColoredBox(
      color: AppColors.bg(Theme.of(context).brightness == Brightness.dark),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showSidebar = constraints.maxWidth >= 1300;
          return Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (constraints.maxWidth >= 760)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildSettingsHeading(context)),
                      const SizedBox(width: 24),
                      _buildThemeSelector(context),
                    ],
                  )
                else ...[
                  _buildSettingsHeading(context),
                  const SizedBox(height: 16),
                  _buildThemeSelector(context),
                ],
                const SizedBox(height: 24),
                Expanded(
                  child: showSidebar
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: 190,
                              child: _buildSectionNavigation(context),
                            ),
                            const VerticalDivider(width: 33),
                            Expanded(child: _buildSelectedSection(context)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildSectionSelector(context),
                            const SizedBox(height: 20),
                            Expanded(child: _buildSelectedSection(context)),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionNavigation(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: SettingsSection.values
          .map(
            (section) => _SettingsSectionButton(
              key: ValueKey('settings-section-${_sectionKey(section)}'),
              icon: _sectionIcon(section),
              label: _sectionLabel(section),
              selected: section == _selectedSection,
              onTap: () => setState(() => _selectedSection = section),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSectionSelector(BuildContext context) {
    return DropdownButtonFormField<SettingsSection>(
      key: const ValueKey('settings-section-selector'),
      initialValue: _selectedSection,
      isExpanded: true,
      decoration: const InputDecoration(isDense: true),
      items: SettingsSection.values
          .map(
            (section) => DropdownMenuItem(
              value: section,
              child: Row(
                children: [
                  Icon(_sectionIcon(section), size: 17),
                  const SizedBox(width: 9),
                  Text(_sectionLabel(section)),
                ],
              ),
            ),
          )
          .toList(),
      onChanged: (section) {
        if (section != null) setState(() => _selectedSection = section);
      },
    );
  }

  Widget _buildSelectedSection(BuildContext context) {
    final section = switch (_selectedSection) {
      SettingsSection.jira => _buildJiraSection(context),
      SettingsSection.day => _buildDaySection(context),
      SettingsSection.quickIssues => _buildQuickIssuesSection(context),
      SettingsSection.agentApi => _buildAgentApiSection(context),
    };
    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: section,
        ),
      ),
    );
  }

  Widget _buildQuickIssuesSection(BuildContext context) {
    final connection = widget.appState.currentConnection;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      key: const ValueKey('quick-issues-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Быстрые задачи',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Сохранённые задачи для быстрого добавления времени.',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (connection != null)
              FilledButton.icon(
                key: const ValueKey('quick-issue-add'),
                onPressed: widget.appState.isReadOnly
                    ? null
                    : () => QuickIssueDialog.showAdd(
                        context,
                        appState: widget.appState,
                      ),
                style: _actionButtonStyle,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Добавить задачу'),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (connection == null)
          _QuickIssuesEmptyState(
            icon: Icons.link_off_outlined,
            title: 'Сначала подключите Jira',
            message:
                'Быстрые задачи хранятся отдельно для каждого сайта и аккаунта.',
            actionLabel: 'Перейти к подключению',
            onAction: () =>
                setState(() => _selectedSection = SettingsSection.jira),
          )
        else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.hover(isDark),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: AppColors.line(isDark)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 17,
                  color: AppColors.green(isDark),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _connectionHost(connection.baseUrl),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${connection.displayName} · ${connection.email}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.appState.isReadOnly) ...[
            const SizedBox(height: 12),
            Text(
              'В режиме только чтения список можно просматривать, но нельзя изменять.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          if (widget.appState.quickIssues.isEmpty)
            _QuickIssuesEmptyState(
              icon: Icons.bolt_outlined,
              title: 'Быстрых задач пока нет',
              message:
                  'Добавьте часто используемую Jira-задачу — она появится здесь и на экране «Работа».',
              actionLabel: 'Добавить задачу',
              onAction: widget.appState.isReadOnly
                  ? null
                  : () => QuickIssueDialog.showAdd(
                      context,
                      appState: widget.appState,
                    ),
            )
          else
            ...widget.appState.quickIssues.map((quickIssue) {
              final issue = _issueForQuickIssue(quickIssue);
              if (issue == null) return const SizedBox.shrink();
              return _QuickIssueSettingsRow(
                quickIssue: quickIssue,
                issue: issue,
                readOnly: widget.appState.isReadOnly,
                onEdit: () => QuickIssueDialog.showEdit(
                  context,
                  appState: widget.appState,
                  quickIssue: quickIssue,
                  issue: issue,
                ),
                onDelete: () =>
                    widget.appState.deleteQuickIssue(quickIssue.issueId),
              );
            }),
        ],
      ],
    );
  }

  Issue? _issueForQuickIssue(QuickIssue quickIssue) {
    for (final issue in widget.appState.issues) {
      if (issue.issueId == quickIssue.issueId) return issue;
    }
    return null;
  }

  String _connectionHost(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    return uri?.host.isNotEmpty == true ? uri!.host : baseUrl;
  }

  String _sectionKey(SettingsSection section) => switch (section) {
    SettingsSection.jira => 'jira',
    SettingsSection.day => 'day',
    SettingsSection.quickIssues => 'quick-issues',
    SettingsSection.agentApi => 'agent-api',
  };

  String _sectionLabel(SettingsSection section) => switch (section) {
    SettingsSection.jira => 'Подключение к Jira',
    SettingsSection.day => 'Сборка дня',
    SettingsSection.quickIssues => 'Быстрые задачи',
    SettingsSection.agentApi => 'Локальный API',
  };

  IconData _sectionIcon(SettingsSection section) => switch (section) {
    SettingsSection.jira => Icons.link,
    SettingsSection.day => Icons.calendar_today_outlined,
    SettingsSection.quickIssues => Icons.bolt_outlined,
    SettingsSection.agentApi => Icons.terminal,
  };

  Widget _buildSettingsHeading(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Настройки', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Подключение к Jira, сборка дня, быстрые задачи и локальный API.',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildThemeSelector(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Тема оформления', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<UiThemeMode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: UiThemeMode.system,
              label: Text('Как в системе'),
            ),
            ButtonSegment(value: UiThemeMode.light, label: Text('Светлая')),
            ButtonSegment(value: UiThemeMode.dark, label: Text('Тёмная')),
          ],
          selected: {widget.appState.themeMode.value},
          onSelectionChanged: widget.appState.isReadOnly
              ? null
              : (selection) {
                  try {
                    widget.appState.selectThemeMode(selection.single);
                  } catch (e) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Не удалось сохранить тему: $e')),
                    );
                  }
                },
          style: _actionButtonStyle.copyWith(
            side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) return null;
              return states.contains(WidgetState.selected)
                  ? AppColors.selected(theme.brightness == Brightness.dark)
                  : Colors.transparent;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) return null;
              return states.contains(WidgetState.selected)
                  ? AppColors.primary(theme.brightness == Brightness.dark)
                  : scheme.onSurface;
            }),
          ),
        ),
        if (widget.appState.isReadOnly) ...[
          const SizedBox(height: 6),
          Text(
            'В режиме только чтения изменить тему нельзя.',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _buildDaySection(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Сборка дня',
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 13),
        Text(
          'Умная пересборка выбирает значения внутри этих диапазонов.',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'ПАРАМЕТР',
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              ),
            ),
            SizedBox(
              width: 100,
              child: Text(
                'ОТ',
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 100,
              child: Text(
                'ДО',
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _dayRangeRow(context, 'Начало дня', 'start', 'start-min', 'start-max'),
        _dayRangeRow(
          context,
          'Длительность дня',
          'duration',
          'duration-min',
          'duration-max',
        ),
        _dayRangeRow(
          context,
          'Начало длинной паузы',
          'long_start',
          'long-start-min',
          'long-start-max',
        ),
        _dayRangeRow(
          context,
          'Длительность длинной паузы',
          'long_duration',
          'long-duration-min',
          'long-duration-max',
        ),
        _dayRangeRow(
          context,
          'Короткие паузы за день',
          'short_count',
          'short-count-min',
          'short-count-max',
        ),
        _dayRangeRow(
          context,
          'Длительность короткой паузы',
          'short_duration',
          'short-duration-min',
          'short-duration-max',
        ),
        const SizedBox(height: 12),
        Text(
          'Минимальный рабочий интервал — 15 минут.',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
        const SizedBox(height: 20),
        Text('Правило сборки для агента', style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        Text(
          'Агент получает этот текст вместе с диапазонами через локальный API. Встроенный сборщик использует только диапазоны.',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('agent-day-rule'),
          controller: _agentDayRuleController,
          enabled: !widget.appState.isReadOnly,
          minLines: 5,
          maxLines: 8,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Опишите, как агенту использовать параметры сборки дня',
          ),
        ),
        if (_dayMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _dayMessage!,
            style: TextStyle(
              color: _dayMessage!.startsWith('Не удалось')
                  ? scheme.error
                  : AppColors.green(theme.brightness == Brightness.dark),
              fontSize: 12,
            ),
          ),
        ],
        if (widget.appState.isReadOnly) ...[
          const SizedBox(height: 8),
          Text(
            'В режиме только чтения изменить параметры нельзя.',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              style: _actionButtonStyle,
              onPressed: widget.appState.isReadOnly
                  ? null
                  : () {
                      setState(() {
                        _fillDaySettings(const DaySettings());
                        _agentDayRuleController.text =
                            AppState.defaultAgentDayRule;
                        _dayErrors = {};
                        _dayMessage = null;
                      });
                    },
              child: const Text('Сбросить'),
            ),
            const SizedBox(width: 10),
            FilledButton(
              style: _actionButtonStyle,
              onPressed: widget.appState.isReadOnly ? null : _saveDaySettings,
              child: const Text('Сохранить параметры'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dayRangeRow(
    BuildContext context,
    String label,
    String group,
    String minKey,
    String maxKey,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 13)),
              ),
              _dayInput(context, minKey),
              const SizedBox(width: 12),
              _dayInput(context, maxKey),
            ],
          ),
        ),
        if (_dayErrors[group] != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _dayErrors[group]!,
              style: TextStyle(fontSize: 11, color: scheme.error),
            ),
          ),
        Divider(height: 1, color: scheme.outlineVariant),
      ],
    );
  }

  Widget _dayInput(BuildContext context, String key) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 100,
      height: 42,
      child: TextField(
        key: ValueKey('day-$key'),
        controller: _dayControllers[key],
        enabled: !widget.appState.isReadOnly,
        style: const TextStyle(fontSize: 13, fontFamily: 'IBM Plex Mono'),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: scheme.surfaceContainerLow,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildJiraSection(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Подключение к Jira',
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Используется для загрузки задач и отправки времени.',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 22),
        _field(
          context,
          'Адрес Jira',
          _urlController,
          hint: 'https://company.atlassian.net',
          onChanged: _invalidateConnectionVerification,
        ),
        const SizedBox(height: 16),
        _field(
          context,
          'Email',
          _emailController,
          hint: 'user@company.com',
          onChanged: _invalidateConnectionVerification,
        ),
        const SizedBox(height: 20),
        _field(
          context,
          'API-токен',
          _tokenController,
          obscureText: _obscureToken,
          onChanged: _invalidateConnectionVerification,
          suffix: IconButton(
            tooltip: _obscureToken ? 'Показать токен' : 'Скрыть токен',
            icon: Icon(
              _obscureToken
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 18,
            ),
            onPressed: () => setState(() => _obscureToken = !_obscureToken),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          _statusMessage(context, _errorMessage!, error: true),
        ],
        if (_verifiedConnection != null) ...[
          const SizedBox(height: 22),
          Tooltip(
            message:
                'Account ID: ${_verifiedConnection!.accountId}\nМаршрут: ${_verifiedConnection!.route == JiraAuthRoute.direct ? "Прямой API" : "Scoped API (cloudId: ${_verifiedConnection!.cloudId})"}',
            child: _statusMessage(
              context,
              'Подключено · ${_verifiedConnection!.displayName}\n${_verifiedConnection!.email}',
            ),
          ),
        ],
        const SizedBox(height: 21),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            if (widget.onCancel != null)
              OutlinedButton(
                style: _actionButtonStyle,
                onPressed: widget.onCancel,
                child: const Text('Отмена'),
              ),
            OutlinedButton(
              onPressed: _isChecking ? null : _checkConnection,
              style: _actionButtonStyle,
              child: _isChecking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Проверить подключение'),
            ),
            FilledButton(
              onPressed: _isChecking || widget.appState.isReadOnly
                  ? null
                  : _saveConnection,
              style: _actionButtonStyle,
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAgentApiSection(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Локальный API для AI-агентов',
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 13),
        Text(
          'Встроенный HTTP-сервер позволяет AI-агентам логировать время и передавать готовое расписание дня.',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 22),
        _field(
          context,
          'Адрес локального сервера',
          _agentUrlController,
          readOnly: true,
          suffix: IconButton(
            tooltip: 'Скопировать адрес',
            icon: const Icon(Icons.copy, size: 17),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _agentUrlController.text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Адрес сервера скопирован в буфер обмена'),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Инструкция для скилла агента',
                style: theme.textTheme.titleSmall,
              ),
            ),
            FilledButton.icon(
              style: _actionButtonStyle,
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Скопировать инструкцию'),
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: _skillPromptController.text),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Инструкция для агента скопирована в буфер обмена',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _skillPromptController,
          readOnly: true,
          minLines: 16,
          maxLines: 16,
          style: const TextStyle(
            fontFamily: 'IBM Plex Mono',
            fontSize: 11,
            color: Color(0xFFD9DDE5),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF20242C),
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(
    BuildContext context,
    String label,
    TextEditingController controller, {
    String? hint,
    bool obscureText = false,
    bool readOnly = false,
    Widget? suffix,
    ValueChanged<String>? onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          readOnly: readOnly,
          onChanged: onChanged,
          style: TextStyle(fontSize: 14, color: scheme.onSurface),
          decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
        ),
      ],
    );
  }

  Widget _statusMessage(
    BuildContext context,
    String message, {
    bool error = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = error ? scheme.error : AppColors.green(isDark);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      decoration: BoxDecoration(
        color: error ? scheme.errorContainer : AppColors.greenBg(isDark),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error ? Icons.error_outline : Icons.check_circle_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 12, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SettingsSectionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = selected
        ? AppColors.primary(isDark)
        : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.selected(isDark) : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 17, color: color),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickIssuesEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  const _QuickIssuesEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('quick-issues-empty'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: scheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _QuickIssueSettingsRow extends StatelessWidget {
  final QuickIssue quickIssue;
  final Issue issue;
  final bool readOnly;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  const _QuickIssueSettingsRow({
    required this.quickIssue,
    required this.issue,
    required this.readOnly,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: ValueKey('quick-issue-${issue.issueId}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line(isDark))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.selected(isDark),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              issue.key,
              style: TextStyle(
                color: AppColors.primary(isDark),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(issue.summary, style: const TextStyle(fontSize: 13)),
                if (quickIssue.note?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    quickIssue.note!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            key: ValueKey('quick-issue-edit-${issue.issueId}'),
            tooltip: 'Изменить подсказку',
            visualDensity: VisualDensity.compact,
            onPressed: readOnly ? null : onEdit,
            icon: const Icon(Icons.edit_outlined, size: 17),
          ),
          PopupMenuButton<String>(
            tooltip: 'Действия',
            enabled: !readOnly,
            onSelected: (_) async {
              try {
                await onDelete();
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Не удалось удалить быструю задачу: $error',
                      ),
                    ),
                  );
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 17),
                    SizedBox(width: 8),
                    Expanded(child: Text('Удалить из быстрых')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
