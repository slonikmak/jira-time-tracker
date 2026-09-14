import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'app_state.dart';
import 'local_store.dart';
import 'single_instance_lock.dart';
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

  final appState = AppState(store: store, isReadOnly: !isPrimary);

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0C66E4), // Atlassian Blue accent
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0C66E4),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: ShellScreen(appState: appState),
    );
  }
}
