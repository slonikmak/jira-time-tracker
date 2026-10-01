import '../l10n/app_localizations.dart';
import '../ui/message_format.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import 'app_theme.dart';
import 'day_screen.dart';
import 'settings_dialog.dart';
import 'work_screen.dart';

/// Десктопная оболочка с навигацией и общими состояниями приложения.
class ShellScreen extends StatefulWidget {
  final AppState appState;

  const ShellScreen({super.key, required this.appState});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  bool _settingsOpen = false;
  SettingsSection _settingsSection = SettingsSection.jira;

  void _openSettings([SettingsSection section = SettingsSection.jira]) {
    setState(() {
      _settingsSection = section;
      _settingsOpen = true;
    });
  }

  void _selectTab(int index) {
    setState(() => _settingsOpen = false);
    widget.appState.selectTab(index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        final appState = widget.appState;
        return Scaffold(
          body: Column(
            children: [
              Container(
                height: 76,
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.sizeOf(context).width < 700 ? 16 : 40,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface(isDark),
                  border: Border(
                    bottom: BorderSide(color: AppColors.line(isDark)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: AppColors.text(isDark),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Jira Time Tracker',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.text(isDark),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.sizeOf(context).width >= 1200
                          ? 152
                          : 28,
                    ),

                    // Вкладка «Работа»
                    _NavTabButton(
                      label: AppLocalizations.of(context).work,
                      icon: Icons.layers_outlined,
                      isSelected:
                          !_settingsOpen && appState.selectedTabIndex == 0,
                      onPressed: () => _selectTab(0),
                      isDark: isDark,
                    ),
                    SizedBox(
                      width: MediaQuery.sizeOf(context).width >= 900 ? 20 : 8,
                    ),

                    // Вкладка «День»
                    _NavTabButton(
                      label: AppLocalizations.of(context).day,
                      icon: Icons.calendar_today_outlined,
                      isSelected:
                          !_settingsOpen && appState.selectedTabIndex == 1,
                      onPressed: () => _selectTab(1),
                      isDark: isDark,
                    ),

                    const Spacer(),

                    if (appState.currentConnection != null) ...[
                      Icon(
                        Icons.check_circle_outline,
                        color: AppColors.green(isDark),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      if (MediaQuery.sizeOf(context).width >= 1050)
                        Text(
                          AppLocalizations.of(context).jiraConnected,
                          style: TextStyle(
                            color: AppColors.muted(isDark),
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(width: 28),
                    ],

                    OutlinedButton.icon(
                      onPressed: _openSettings,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _settingsOpen
                            ? AppColors.selected(isDark)
                            : AppColors.surface(isDark),
                        minimumSize: const Size(0, 36),
                        visualDensity: VisualDensity.standard,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                      icon: const Icon(Icons.tune, size: 15),
                      label: Text(AppLocalizations.of(context).settings),
                    ),
                  ],
                ),
              ),

              if (appState.statusMessage != null &&
                  appState.statusMessage!.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
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
                          renderMessage(context, appState.statusText),
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

              if (appState.isReadOnly)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
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
                          AppLocalizations.of(
                            context,
                          ).readOnlyModeAnotherApplicationInstanceHoldsThe,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.warn(isDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: IndexedStack(
                  index: _settingsOpen ? 2 : appState.selectedTabIndex,
                  children: [
                    WorkScreen(
                      appState: appState,
                      onOpenQuickIssueSettings: () =>
                          _openSettings(SettingsSection.quickIssues),
                    ),
                    DayScreen(appState: appState),
                    if (_settingsOpen)
                      SettingsPage(
                        appState: appState,
                        initialSection: _settingsSection,
                        onSaved: () => setState(() => _settingsOpen = false),
                        onCancel: () => setState(() => _settingsOpen = false),
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;
  final bool isDark;

  const _NavTabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fgColor = isSelected
        ? AppColors.primary(isDark)
        : AppColors.muted(isDark);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? AppColors.primary(isDark)
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fgColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: fgColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
