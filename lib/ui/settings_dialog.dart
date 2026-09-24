import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../agent_api_server.dart';
import '../app_state.dart';
import '../jira_client.dart';
import '../models.dart';
import 'app_theme.dart';

/// Страница настроек подключения Jira и локального API.
class SettingsPage extends StatefulWidget {
  final AppState appState;
  final VoidCallback? onSaved;
  final VoidCallback? onCancel;

  const SettingsPage({
    super.key,
    required this.appState,
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
  late final TextEditingController _urlController;
  late final TextEditingController _emailController;
  late final TextEditingController _tokenController;
  late final TextEditingController _agentUrlController;
  late final TextEditingController _skillPromptController;
  late final Map<String, TextEditingController> _dayControllers;

  bool _isLoading = true;
  bool _isChecking = false;
  bool _obscureToken = true;
  String? _errorMessage;
  JiraConnection? _verifiedConnection;
  Map<String, String> _dayErrors = {};
  String? _dayMessage;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _emailController = TextEditingController();
    _tokenController = TextEditingController();
    final agentUrl = widget.appState.apiServerUrl ?? 'http://127.0.0.1:8765';
    _agentUrlController = TextEditingController(text: agentUrl);
    _skillPromptController = TextEditingController(
      text: AgentApiServer.generateSkillPrompt(agentUrl),
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
      widget.appState.updateDaySettings(settings);
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
      widget.onSaved?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Подключение к Jira успешно сохранено')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ColoredBox(
      color: AppColors.bg(Theme.of(context).brightness == Brightness.dark),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(40, 28, 40, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (constraints.maxWidth >= 1100)
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
              const SizedBox(height: 32),
              if (constraints.maxWidth >= 1380)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 380, child: _buildJiraSection(context)),
                    Container(
                      width: 460,
                      margin: const EdgeInsets.only(left: 40),
                      padding: const EdgeInsets.only(left: 40),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: scheme.outlineVariant),
                        ),
                      ),
                      child: _buildDaySection(context),
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.only(left: 40),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: scheme.outlineVariant),
                          ),
                        ),
                        child: _buildAgentApiSection(context),
                      ),
                    ),
                  ],
                )
              else ...[
                _buildJiraSection(context),
                const SizedBox(height: 32),
                Divider(color: scheme.outlineVariant),
                const SizedBox(height: 24),
                _buildDaySection(context),
                const SizedBox(height: 32),
                Divider(color: scheme.outlineVariant),
                const SizedBox(height: 24),
                _buildAgentApiSection(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsHeading(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Настройки', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Подключение к Jira, правила сборки дня и локальный API для AI-агентов.',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildThemeSelector(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            ),
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
              onPressed: widget.appState.isReadOnly
                  ? null
                  : () {
                      setState(() {
                        _fillDaySettings(const DaySettings());
                        _dayErrors = {};
                        _dayMessage = null;
                      });
                    },
              child: const Text('Сбросить'),
            ),
            const SizedBox(width: 10),
            FilledButton(
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
        ),
        const SizedBox(height: 16),
        _field(context, 'Email', _emailController, hint: 'user@company.com'),
        const SizedBox(height: 20),
        _field(
          context,
          'API-токен',
          _tokenController,
          obscureText: _obscureToken,
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
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Отмена'),
              ),
            OutlinedButton(
              onPressed: _isChecking ? null : _checkConnection,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 39),
                visualDensity: VisualDensity.standard,
                padding: const EdgeInsets.symmetric(horizontal: 21),
                textStyle: const TextStyle(fontSize: 13),
              ),
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
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 39),
                visualDensity: VisualDensity.standard,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                textStyle: const TextStyle(fontSize: 13),
              ),
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
            FilledButton.tonalIcon(
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
