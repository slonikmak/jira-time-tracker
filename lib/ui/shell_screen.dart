import 'package:flutter/material.dart';
import '../app_state.dart';

/// Главный экран-оболочка с верхней панелью, навигацией и переключением вкладок.
class ShellScreen extends StatelessWidget {
  final AppState appState;

  const ShellScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return DefaultTabController(
          length: 2,
          initialIndex: appState.selectedTabIndex,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Jira Time Tracker'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Настройки',
                  onPressed: () => _openSettingsDialog(context),
                ),
                const SizedBox(width: 8),
              ],
              bottom: TabBar(
                onTap: (index) => appState.selectTab(index),
                tabs: const [
                  Tab(icon: Icon(Icons.work_outline), text: 'Работа'),
                  Tab(icon: Icon(Icons.calendar_today_outlined), text: 'День'),
                ],
              ),
            ),
            body: Column(
              children: [
                if (appState.isReadOnly)
                  Container(
                    width: double.infinity,
                    color: Theme.of(context).colorScheme.errorContainer,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Режим только чтения: другой экземпляр приложения удерживает блокировку записи (A19).',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildWorkTabPlaceholder(context),
                      _buildDayTabPlaceholder(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWorkTabPlaceholder(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Экран «Работа»',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Здесь будут недавние задачи, таймеры и очередь логов.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDayTabPlaceholder(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Экран «День»',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Здесь будут генерация черновика дня, расписание и отправка в Jira.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _openSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Настройки'),
        content: const Text(
          'Подключение к Jira и параметры сборщика дня (будут настроены в тикете 02).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}
