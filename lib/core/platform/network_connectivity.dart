import 'dart:async';
import 'dart:io';

abstract final class NetworkConnectivity {
  static const _probeHosts = <String>[
    'cloudflare.com',
    'google.com',
    'one.one.one.one',
  ];

  static Future<bool> hasInternetConnection({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    for (final host in _probeHosts) {
      if (await _canReachHost(host, timeout: timeout)) {
        return true;
      }
    }
    return false;
  }

  static Future<bool> _canReachHost(
    String host, {
    required Duration timeout,
  }) async {
    try {
      final result = await InternetAddress.lookup(host).timeout(timeout);
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    }
  }
}
