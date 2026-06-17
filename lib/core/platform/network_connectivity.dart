import 'dart:async';
import 'dart:io';

abstract final class NetworkConnectivity {
  static Future<bool> hasInternetConnection({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(timeout);
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    }
  }
}
