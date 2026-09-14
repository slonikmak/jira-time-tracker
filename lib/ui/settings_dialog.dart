import 'package:flutter/material.dart';
import '../app_state.dart';
import '../jira_client.dart';
import '../models.dart';

/// Диалог настроек подключения к Jira и параметров сборки дня.
class SettingsDialog extends StatefulWidget {
  final AppState appState;

  const SettingsDialog({super.key, required this.appState});

  static Future<void> show(BuildContext context, AppState appState) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => SettingsDialog(appState: appState),
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _emailController;
  late final TextEditingController _tokenController;

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

  Future<void> _saveAndClose() async {
    if (_verifiedConnection == null) {
      await _checkConnection();
      if (_verifiedConnection == null) return;
    }

    await widget.appState.updateConnection(
      _verifiedConnection!,
      _tokenController.text.trim(),
    );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Подключение к Jira успешно сохранено')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Настройки подключения к Jira'),
      content: SizedBox(
        width: 520,
        child: _isLoading
            ? const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'URL Jira Cloud',
                        hintText: 'https://esprowteam.atlassian.net',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email аккаунта Atlassian',
                        hintText: 'user@example.com',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tokenController,
                      obscureText: _obscureToken,
                      decoration: InputDecoration(
                        labelText: 'API токен Atlassian',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.key_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureToken
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureToken = !_obscureToken;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _isChecking ? null : _checkConnection,
                          icon: _isChecking
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.wifi_tethering),
                          label: const Text('Проверить подключение'),
                        ),
                      ],
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
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
                    ],
                    if (_verifiedConnection != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Подключение подтверждено',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Пользователь: ${_verifiedConnection!.displayName} (${_verifiedConnection!.accountId})',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                            ),
                            Text(
                              'Маршрут: ${_verifiedConnection!.route == JiraAuthRoute.direct ? "Прямой API" : "Scoped API (cloudId: ${_verifiedConnection!.cloudId})"}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _isChecking ? null : _saveAndClose,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
