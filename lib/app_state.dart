import 'package:flutter/foundation.dart';
import 'local_store.dart';

/// Состояние приложения и координация взаимодействия с локальным хранилищем.
class AppState extends ChangeNotifier {
  final LocalStore store;
  final bool isReadOnly;

  int _selectedTabIndex = 0;
  String _activeScope = 'default';
  String? _statusMessage;

  AppState({required this.store, required this.isReadOnly});

  int get selectedTabIndex => _selectedTabIndex;
  String get activeScope => _activeScope;
  String? get statusMessage => _statusMessage;

  void selectTab(int index) {
    if (_selectedTabIndex != index) {
      _selectedTabIndex = index;
      notifyListeners();
    }
  }

  void setActiveScope(String scope) {
    if (_activeScope != scope) {
      _activeScope = scope;
      notifyListeners();
    }
  }

  void setStatusMessage(String? message) {
    _statusMessage = message;
    notifyListeners();
  }

  void clearStatusMessage() {
    if (_statusMessage != null) {
      _statusMessage = null;
      notifyListeners();
    }
  }
}
