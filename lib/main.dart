import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'app_state.dart';
import 'connection_store.dart';
import 'jira_client.dart';
import 'local_store.dart';
import 'secure_storage.dart';
import 'single_instance_lock.dart';
import 'ui/app_theme.dart';
import 'ui/shell_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appDir = await getApplicationSupportDirectory();
  if (!appDir.existsSync()) {
    appDir.createSync(recursive: true);
  }

  final lockPath = p.join(appDir.path, 'app.lock');
  final singleInstanceLock = SingleInstanceLock();
  final isPrimary = singleInstanceLock.tryAcquire(lockPath);

  final dbPath = p.join(appDir.path, 'jira_time_tracker.db');
  final db = sqlite3.open(dbPath);
  final store = LocalStore(db, isReadOnly: !isPrimary);
  store.init();

  if (isPrimary) {
    store.recoverUnfinishedSending();
  }

  final secureStorage = WindowsCredentialStorage();
  final connectionStore = ConnectionStore(secureStorage: secureStorage);
  final jiraClient = JiraClient();

  final appState = AppState(
    store: store,
    connectionStore: connectionStore,
    jiraClient: jiraClient,
    isReadOnly: !isPrimary,
  );
  await appState.loadSavedConnection();
  if (isPrimary) {
    await appState.startApiServer();
  }

  runApp(JiraTimeTrackerApp(appState: appState));
}

class JiraTimeTrackerApp extends StatelessWidget {
  final AppState appState;

  const JiraTimeTrackerApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jira Time Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: ShellScreen(appState: appState),
    );
  }
}
