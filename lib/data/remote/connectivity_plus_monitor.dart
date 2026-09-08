import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../domain/repositories/connectivity_monitor.dart';

/// The only file importing `connectivity_plus`. "Online" = at least one
/// non-`none` interface. This is an optimistic hint for the Sync Manager — an
/// actual failed request is still handled by retry/backoff.
class ConnectivityPlusMonitor implements ConnectivityMonitor {
  ConnectivityPlusMonitor({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _anyOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  @override
  Future<bool> get isOnline async =>
      _anyOnline(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onlineChanges =>
      _connectivity.onConnectivityChanged.map(_anyOnline).distinct();
}
