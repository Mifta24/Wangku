import 'dart:async';
import 'dart:io';
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
    await _updateWithInternetCheck(results);
  }

  void _onChanged(List<ConnectivityResult> results) {
    _updateWithInternetCheck(results);
  }

  Future<void> _updateWithInternetCheck(List<ConnectivityResult> results) async {
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    final connected = hasNetwork ? await _hasInternetAccess() : false;
    if (connected != _isConnected) {
      _isConnected = connected;
      notifyListeners();
    }
  }

  Future<bool> _hasInternetAccess() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> recheck() async {
    final results = await _connectivity.checkConnectivity();
    await _updateWithInternetCheck(results);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
