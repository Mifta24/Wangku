import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityProvider extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _subscription;

  bool _isConnected = true;
  bool get isConnected => _isConnected;

  ConnectivityProvider() {
    _checkInitial();
    _subscription = _connectivity.onConnectivityChanged.listen(_onChanged);
  }

  Future<void> _checkInitial() async {
    final results = await _connectivity.checkConnectivity();
    _update(results);
  }

  void _onChanged(List<ConnectivityResult> results) {
    _update(results);
  }

  void _update(List<ConnectivityResult> results) {
    final connected = results.any((r) => r != ConnectivityResult.none);
    if (connected != _isConnected) {
      _isConnected = connected;
      notifyListeners();
    }
  }

  Future<void> recheck() async {
    final results = await _connectivity.checkConnectivity();
    _update(results);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
