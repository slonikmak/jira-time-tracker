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

  bool _isLoading = true;
  bool _isChecking = false;
  bool _obscureToken = true;
  String? _errorMessage;
  JiraConnection? _verifiedConnection;

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
    super.dispose();
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
              Text('Настройки', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Подключение к Jira и локальный API для агентов.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Text(
                'Тема оформления',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SegmentedButton<UiThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: UiThemeMode.system,
                    label: Text('Как в системе'),
                  ),
                  ButtonSegment(
                    value: UiThemeMode.light,
                    label: Text('Светлая'),
                  ),
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
                            SnackBar(
                              content: Text('Не удалось сохранить тему: $e'),
                            ),
                          );
                        }
                      },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  side: WidgetStatePropertyAll(
                    BorderSide(color: scheme.outline),
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
              if (widget.appState.isReadOnly) ...[
                const SizedBox(height: 6),
                Text(
                  'В режиме только чтения изменить тему нельзя.',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 36),
              if (constraints.maxWidth >= 1250)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 480, child: _buildJiraSection(context)),
                    const SizedBox(width: 64),
                    Container(
                      width: 1,
                      height: 620,
                      color: scheme.outlineVariant,
                    ),
                    const SizedBox(width: 40),
                    Expanded(child: _buildAgentApiSection(context)),
                  ],
                )
              else ...[
                _buildJiraSection(context),
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
                'Инструкция для создания скилла агента',
                style: theme.textTheme.titleSmall,
              ),
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Скопировать инструкцию для агента'),
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
          maxLines: 10,
          style: const TextStyle(fontFamily: 'IBM Plex Mono', fontSize: 11),
          decoration: const InputDecoration(contentPadding: EdgeInsets.all(12)),
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
