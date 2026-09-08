/// Connectivity signal for the Sync Manager. `connectivity_plus` is imported by
/// exactly one implementation (`data/remote/connectivity_plus_monitor.dart`);
/// this keeps it out of `domain/` and lets tests drive connectivity by hand.
///
/// "Online" here means "a network interface is up" — not "the internet
/// actually works". A push can still fail against a captive portal; that
/// failure is handled by the Sync Manager's retry/backoff, not here.
library;

abstract interface class ConnectivityMonitor {
  /// Whether a network interface is currently available.
  Future<bool> get isOnline;

  /// Emits `true`/`false` on every connectivity transition. Does not
  /// necessarily emit the current value on listen.
  Stream<bool> get onlineChanges;
}
