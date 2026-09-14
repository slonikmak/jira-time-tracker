# 01: Каркас Flutter Desktop, SQLite, single-instance lock и навигация

**What to build:** Базовый проект Flutter Desktop под Windows, механизм локального хранения LocalStore на SQLite с миграциями схемы, межпроцессная блокировка Windows для исключения параллельной работы нескольких пишущих экземпляров, каркас интерфейса Material 3 с навигацией (вкладки «Работа», «День» и кнопка вызова настроек).

**Blocked by:** None (can start immediately)

**Status:** resolved

## Acceptance criteria

- [x] Flutter Desktop (Windows) проект инициализирован в корне репозитория с сохранением существующих служебных файлов (`AGENTS.md`, `ARCHITECTURE.md`, `.agents/`, `docs/`).
- [x] `LocalStore` инициализирует базу данных SQLite в каталоге приложения с версионированием и поддержкой миграций схемы, с включенным режимом `foreign_keys`.
- [x] Реализован механизм межпроцессной блокировки Windows (file lock / named mutex): запуск второго экземпляра процесса не позволяет ему писать в БД или выполнять отправку (сценарий A19).
- [x] Приложение открывается на Windows, показывает базовую навигацию Material 3 (экраны «Работа», «День» и вызов настроек).
- [x] Написаны unit/integration тесты для `LocalStore` с временной/in-memory базой данных SQLite, проверяющие создание таблиц и миграции.

## Answer

Тикет реализован:
- Инициализирован Flutter Windows проект в текущем каталоге с сохранением существующих служебных файлов.
- Созданы базовые модели данных (`models.dart`).
- Реализован `LocalStore` (`local_store.dart`) с инициализацией SQLite схемы v1, поддержкой транзакционных миграций, включением `PRAGMA foreign_keys = ON`, защитой от записи в режиме read-only и восстановлением незавершенных `sending` статусов в `unknown` (сценарий A19).
- Реализован `SingleInstanceLock` (`single_instance_lock.dart`) на эксклюзивной файловой блокировке Windows.
- Создан UI-каркас Material 3 (`shell_screen.dart`, `app_state.dart`, `main.dart`) с вкладками «Работа» и «День», кнопкой настроек и предупреждающим баннером при работе в режиме второго (read-only) экземпляра.
- Написаны и успешно проходят 9 тестов (`test/local_store_test.dart`, `test/widget_test.dart`).
- Проверена компиляция Windows-приложения (`flutter build windows --debug`).

## Comments
