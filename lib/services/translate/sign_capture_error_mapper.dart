import 'dart:convert';
import 'dart:io';

import '../home/home_ui_copy.dart';

/// Maps sign worker / Gemini failures to short user-facing snackbar text.
abstract final class SignCaptureErrorMapper {
  static String userMessage(Object error, HomeUiCopy copy) {
    final haystack = _errorHaystack(error);

    if (_matches(haystack, [
      '429',
      'rate limit',
      'resource exhausted',
      'you exceeded',
      'quota',
    ])) {
      return copy.signCaptureRateLimitedLabel;
    }

    if (_matches(haystack, [
      '404',
      'models/gemini',
      'model is not found',
      'not found for api version',
    ])) {
      return copy.signCaptureModelUnavailableLabel;
    }

    if (_matches(haystack, [
      'no signs detected',
      'empty sign text',
      'sign worker returned empty text',
      'unable to parse gloss',
      'invalid gloss',
    ])) {
      return copy.signNoSignsDetectedLabel;
    }

    if (_matches(haystack, ['gemini_key not configured'])) {
      return copy.signCaptureNotConfiguredLabel;
    }

    if (_matches(haystack, ['401', 'unauthorized'])) {
      return copy.signCaptureUnauthorizedLabel;
    }

    if (_matches(haystack, [
      '502',
      '503',
      '504',
      '1102',
      'sign recognition failed',
      'worker',
      'timeout',
      'timed out',
    ])) {
      return copy.signCaptureServiceUnavailableLabel;
    }

    return copy.signCaptureFailedLabel;
  }

  static Duration snackbarDuration(Object error) {
    final haystack = _errorHaystack(error);
    if (_matches(haystack, ['429', 'rate limit', 'you exceeded', 'quota'])) {
      return const Duration(seconds: 6);
    }
    return const Duration(seconds: 4);
  }

  static String _errorHaystack(Object error) {
    final parts = <String>[];

    if (error is HttpException) {
      parts.add(error.message);
      _appendJsonFields(error.message, parts);
    } else {
      parts.add(error.toString());
    }

    return parts.join('\n').toLowerCase();
  }

  static void _appendJsonFields(String message, List<String> parts) {
    final jsonStart = message.indexOf('{');
    if (jsonStart < 0) {
      return;
    }

    try {
      final decoded = jsonDecode(message.substring(jsonStart));
      if (decoded is! Map) {
        return;
      }
      for (final key in ['detail', 'error', 'message']) {
        final value = decoded[key];
        if (value != null) {
          parts.add('$value');
        }
      }
    } on Object {
      // Fall back to the raw HTTP message only.
    }
  }

  static bool _matches(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (haystack.contains(needle)) {
        return true;
      }
    }
    return false;
  }
}
