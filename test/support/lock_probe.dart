import 'dart:io';
import 'package:jira_time_tracker/single_instance_lock.dart';

Future<void> main(List<String> arguments) async {
  final lock = SingleInstanceLock();
  try {
    stdout.writeln(lock.tryAcquire(arguments.single) ? 'acquired' : 'blocked');
    await stdin.first;
    stdout.writeln(lock.tryAcquire(arguments.single) ? 'acquired' : 'blocked');
  } finally {
    lock.release();
  }
}
