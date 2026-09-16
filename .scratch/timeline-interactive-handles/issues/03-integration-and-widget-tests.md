# 03. Интеграция в DayScreen и сквозные тесты (Ticket 03)

Status: resolved

## Описание
1. Подключить коллбэки `onResizeSegmentRight` и `onResizeSegmentLeft` в `lib/ui/day_screen.dart` к вызовам `appState.resizeSegmentRight` и `appState.resizeSegmentLeft`.
2. Обработка упоров в записи Jira (показ информативного SnackBar, если сдвиг упёрся в лог Jira).
3. Интеграционные тесты перетаскивания границ мышью на таймлайне и проверки результирующего расписания.
4. Полный прогон `flutter test` и `flutter analyze`.
