import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jira_time_tracker/secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Windows keeps the existing Credential Manager backend', () {
    if (Platform.isWindows) {
      expect(createPlatformSecureStorage(), isA<WindowsCredentialStorage>());
    } else if (Platform.isMacOS) {
      expect(createPlatformSecureStorage(), isA<MacOsKeychainStorage>());
    }
  });

  test('Keychain adapter persists, reads and deletes Unicode values', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    final values = <String, String>{};
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      final arguments = call.arguments as Map;
      final options = arguments['options'] as Map;
      expect(options['usesDataProtectionKeychain'], 'false');
      expect(options['accountName'], 'JiraTimeTracker');
      final key = arguments['key'] as String;
      switch (call.method) {
        case 'write':
          values[key] = arguments['value'] as String;
        case 'read':
          return values[key];
        case 'delete':
          values.remove(key);
        default:
          fail('Unexpected storage operation: ${call.method}');
      }
      return null;
    });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
    });
    final storage = MacOsKeychainStorage();
    expect(await storage.read('test-token'), isNull);
    await storage.write('test-token', 'Тест-é-🔐');
    expect(await storage.read('test-token'), 'Тест-é-🔐');
    await storage.delete('test-token');
    expect(await storage.read('test-token'), isNull);
  });
}
