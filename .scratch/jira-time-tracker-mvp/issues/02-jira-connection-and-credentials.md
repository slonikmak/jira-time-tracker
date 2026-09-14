# 02: Настройки подключения к Jira (Env, SecureStore, проверка маршрутов)

**What to build:** Слой управления учетными данными ConnectionStore и JiraClient для авторизации. Чтение переменных окружения (`JIRA_BASE_URL`, `JIRA_EMAIL`, `JIRA_TOKEN`), безопасное хранение учетных данных в защищенном хранилище Windows (`WindowsCredentialStorage`), read-only проверка подключения по двум маршрутам (прямой GET `/rest/api/3/myself` и scoped через `/_edge/tenant_info`), модальное окно настроек с маскированием токена и отменой.

**Blocked by:** 01: Каркас Flutter Desktop, SQLite, single-instance lock и навигация

**Status:** resolved

## Acceptance criteria

- [x] `ConnectionStore` считывает переменные окружения процесса при первом запуске; сохранённый пользователем ввод имеет приоритет при последующих открытиях формы (сценарий A16).
- [x] API-токен сохраняется исключительно в защищенном хранилище Windows (`WindowsCredentialStorage`), никогда не попадает в SQLite, открытые логи или README.
- [x] Отмена редактирования формы настроек оставляет прежнее подтвержденное подключение нетронутым (сценарий A16).
- [x] `JiraClient` выполняет read-only проверку подключения: сначала пробует прямой маршрут GET `/rest/api/3/myself`, а при отказе проверяет scoped-маршрут с получением `cloudId` через `/_edge/tenant_info` (сценарий A17).
- [x] Интерфейс настроек маскирует токен, отображает имя и `accountId` пользователя при успехе, либо понятную причину ошибки.
- [x] Написаны тесты с подставным `http.Client` (`MockClient`), покрывающие сценарии A16 и A17, включая обработку кодов 401, 403 и сетевых сбоев.

## Answer

Тикет 02 полностью реализован:
- Создан модуль `secure_storage.dart` с абстракцией `SecureStorage`, реализацией `InMemorySecureStorage` (для тестов) и `WindowsCredentialStorage` (нативное хранение секретов через Windows Credential Manager FFI). Токены никогда не попадают в SQLite, логи или открытые файлы.
- Создан модуль `connection_store.dart` (`ConnectionStore`): чтение переменных окружения (`JIRA_BASE_URL`, `JIRA_EMAIL`, `JIRA_TOKEN`), приоритет сохранённых значений над переменными окружения, сохранение метаданных и токена в защищённом хранилище.
- Создан модуль `jira_client.dart` (`JiraClient`): read-only проверка подключения через GET `/rest/api/3/myself`, поддержка scoped-маршрута с получением `cloudId` через `/_edge/tenant_info` при 401 на прямом маршруте, обработка ошибок 401, 403, 429 (с `Retry-After`).
- Создан диалог настроек `lib/ui/settings_dialog.dart` с маскированием токена, кнопкой тестирования подключения, отображением аккаунта и безопасной отменой (сценарий A16).
- `AppState` расширен поддержкой `activeScope` (`baseUrl#accountId`) и хранением текущего проверенного подключения (сценарий A17).
- Написаны и проходят 9 тестов в `test/jira_connection_test.dart` (всего 18 тестов в проекте).
- Проверена сборка приложения под Windows (`flutter build windows --debug`).

## Comments
