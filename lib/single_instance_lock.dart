import 'dart:io';

/// Межпроцессная файловая блокировка единственного пишущего экземпляра.
class SingleInstanceLock {
  RandomAccessFile? _lockedFile;
  bool _isHeld = false;

  /// Удерживает ли данный экземпляр процесса блокировку.
  bool get isHeld => _isHeld;

  /// Пытается захватить эксклюзивную блокировку файла.
  /// Возвращает true, если блокировка получена.
  /// Возвращает false, если другой процесс уже удерживает блокировку (сценарий A19).
  bool tryAcquire(String lockFilePath) {
    if (_isHeld) return true;

    try {
      final file = File(lockFilePath);
      if (!file.existsSync()) {
        file.parent.createSync(recursive: true);
        file.createSync();
      }
      final raf = file.openSync(mode: FileMode.write);
      try {
        raf.lockSync(FileLock.exclusive);
        _lockedFile = raf;
        _isHeld = true;
        return true;
      } catch (_) {
        try {
          raf.closeSync();
        } catch (_) {}
        _isHeld = false;
        return false;
      }
    } catch (_) {
      _isHeld = false;
      return false;
    }
  }

  /// Освобождает захваченную блокировку.
  void release() {
    if (_lockedFile != null) {
      try {
        _lockedFile!.unlockSync();
      } catch (_) {}
      try {
        _lockedFile!.closeSync();
      } catch (_) {}
      _lockedFile = null;
    }
    _isHeld = false;
  }
}
