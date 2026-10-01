import 'app_message.dart';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

/// Сохраняет прежнее хранилище Windows и использует системный Keychain на macOS.
SecureStorage createPlatformSecureStorage() => Platform.isWindows
    ? WindowsCredentialStorage()
    : Platform.isMacOS
    ? MacOsKeychainStorage()
    : throw UnsupportedError('Supported platforms: Windows and macOS');

/// Абстракция защищённого хранилища учётных данных.
abstract class SecureStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class MacOsKeychainStorage implements SecureStorage {
  final FlutterSecureStoragePlatform storage;
  static const _options = <String, String>{
    'accountName': 'JiraTimeTracker',
    'usesDataProtectionKeychain': 'false',
  };

  MacOsKeychainStorage({FlutterSecureStoragePlatform? storage})
    : storage = storage ?? MethodChannelFlutterSecureStorage();

  @override
  Future<String?> read(String key) => storage.read(key: key, options: _options);

  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value, options: _options);

  @override
  Future<void> delete(String key) =>
      storage.delete(key: key, options: _options);
}

/// Реализация в памяти для тестов и сред без Windows Credential Manager.
class InMemorySecureStorage implements SecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<String?> read(String key) async => _storage[key];

  @override
  Future<void> write(String key, String value) async {
    _storage[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _storage.remove(key);
  }
}

/// Нативная реализация защищённого хранилища через Windows Credential Manager.
class WindowsCredentialStorage implements SecureStorage {
  final String prefix;

  WindowsCredentialStorage({this.prefix = 'JiraTimeTracker:'});

  String _target(String key) => '$prefix$key';

  @override
  Future<String?> read(String key) async {
    if (!Platform.isWindows) return null;

    final targetName = _target(key).toNativeUtf16();
    final pCredential = calloc<Pointer<CREDENTIAL>>();
    try {
      final result = CredRead(
        PCWSTR(targetName),
        CRED_TYPE_GENERIC,
        pCredential,
      );
      if (!result.value) {
        return null;
      }
      final cred = pCredential.value.ref;
      if (cred.CredentialBlobSize == 0 || cred.CredentialBlob == nullptr) {
        return '';
      }
      final blob = cred.CredentialBlob.cast<Uint8>();
      final bytes = List<int>.generate(cred.CredentialBlobSize, (i) => blob[i]);
      CredFree(pCredential.value.cast());
      return String.fromCharCodes(bytes);
    } catch (_) {
      return null;
    } finally {
      calloc.free(pCredential);
      calloc.free(targetName);
    }
  }

  @override
  Future<void> write(String key, String value) async {
    if (!Platform.isWindows) return;

    final targetName = _target(key).toNativeUtf16();
    final credential = calloc<CREDENTIAL>();
    final bytes = value.codeUnits;
    final blob = calloc<Uint8>(bytes.length);
    for (var i = 0; i < bytes.length; i++) {
      blob[i] = bytes[i];
    }

    try {
      credential.ref.Type = CRED_TYPE_GENERIC;
      credential.ref.TargetName = PWSTR(targetName);
      credential.ref.CredentialBlobSize = bytes.length;
      credential.ref.CredentialBlob = blob.cast<Uint8>();
      credential.ref.Persist = CRED_PERSIST_LOCAL_MACHINE;

      final result = CredWrite(credential, 0);
      if (!result.value) {
        throw AppStateError(
          AppMessage(
            'couldNotSaveCredentialsInWindowsCredentialManager',
            [],
            'Не удалось сохранить учетные данные в Windows Credential Manager',
          ),
        );
      }
    } finally {
      calloc.free(blob);
      calloc.free(credential);
      calloc.free(targetName);
    }
  }

  @override
  Future<void> delete(String key) async {
    if (!Platform.isWindows) return;

    final targetName = _target(key).toNativeUtf16();
    try {
      CredDelete(PCWSTR(targetName), CRED_TYPE_GENERIC);
    } finally {
      calloc.free(targetName);
    }
  }
}
