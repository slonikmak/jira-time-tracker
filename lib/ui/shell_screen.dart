import 'package:flutter/material.dart';
import '../app_state.dart';
import 'app_theme.dart';
import 'day_screen.dart';
import 'settings_dialog.dart';
import 'work_screen.dart';

/// Главный экран-оболочка с десктопным заголовком, навигацией в стиле HTML-макета
/// и переключением экранов «Работа» и «День».
class ShellScreen extends StatelessWidget {
  final AppState appState;

  const ShellScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final unconsumedCount = appState.unconsumedLogs.length;
        final hasDraft = appState.currentDraft != null;

        return Scaffold(
          body: Column(
            children: [
              // Десктопная панель навигации с названием приложения (.jt-nav)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface(isDark),
                  border: Border(
                    bottom: BorderSide(color: AppColors.line(isDark)),
                  ),
                ),
                child: Row(
                  children: [
                    // Название приложения
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.primary(isDark),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.timer,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      'Jira Time Tracker',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.text(isDark),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      height: 18,
                      width: 1,
                      color: AppColors.line(isDark),
                    ),
                    const SizedBox(width: 14),

                    // Вкладка «Работа»
                    _NavTabButton(
                      label: 'Работа',
                      icon: Icons.layers_outlined,
                      count: unconsumedCount > 0 ? unconsumedCount : null,
                      isSelected: appState.selectedTabIndex == 0,
                      onPressed: () => appState.selectTab(0),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),

                    // Вкладка «День»
                    _NavTabButton(
                      label: 'День',
                      icon: Icons.calendar_today_outlined,
                      count: hasDraft ? 1 : null,
                      isSelected: appState.selectedTabIndex == 1,
                      onPressed: () => appState.selectTab(1),
                      isDark: isDark,
                    ),

                    const Spacer(),

                    // Кнопка «Настройки» справа (.jt-right)
                    InkWell(
                      borderRadius: BorderRadius.circular(7),
                      onTap: () => _openSettingsDialog(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.settings_outlined,
                              size: 16,
                              color: AppColors.text(isDark),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Настройки',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.text(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Уведомление статуса (.jt-toast)
              if (appState.statusMessage != null &&
                  appState.statusMessage!.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.selected(isDark),
                    border: Border(
                      bottom: BorderSide(color: AppColors.line(isDark)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 15,
                        color: AppColors.primary(isDark),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          appState.statusMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary(isDark),
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        iconSize: 16,
                        icon: Icon(
                          Icons.close,
                          color: AppColors.primary(isDark),
                        ),
                        onPressed: () => appState.setStatusMessage(null),
                      ),
                    ],
                  ),
                ),

              // 4. Баннер read-only режима (A19)
              if (appState.isReadOnly)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warnBg(isDark),
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.warn(isDark).withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 16,
                        color: AppColors.warn(isDark),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Режим только чтения: другой экземпляр приложения удерживает блокировку записи (A19).',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.warn(isDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // 5. Тело экранов (IndexedStack)
              Expanded(
                child: IndexedStack(
                  index: appState.selectedTabIndex,
                  children: [
                    WorkScreen(appState: appState),
                    DayScreen(appState: appState),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openSettingsDialog(BuildContext context) {
    SettingsDialog.show(context, appState);
  }
}

/// Кнопка вкладки в стиле .jt-tab
class _NavTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final int? count;
  final bool isSelected;
  final VoidCallback onPressed;
  final bool isDark;

  const _NavTabButton({
    required this.label,
    required this.icon,
    this.count,
    required this.isSelected,
    required this.onPressed,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fgColor = isSelected
        ? AppColors.primary(isDark)
        : AppColors.text(isDark);
    final bgColor = isSelected
        ? AppColors.selected(isDark)
        : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fgColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: fgColor,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary(isDark).withValues(alpha: 0.15)
                        : AppColors.hover(isDark),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? AppColors.primary(isDark)
                          : AppColors.muted(isDark),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
