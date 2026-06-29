import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../home/home_ui_copy.dart';

/// Maps sign worker / Gemini failures to short user-facing snackbar text.
abstract final class SignCaptureErrorMapper {
  static String userMessage(Object error, HomeUiCopy copy) {
    final context = _parseError(error);
    return _messageFor(context, copy);
  }

  static Duration snackbarDuration(Object error) {
    final context = _parseError(error);
    switch (context.category) {
      case _ErrorCategory.rateLimited:
      case _ErrorCategory.uploadTimeout:
      case _ErrorCategory.workerOverload:
        return const Duration(seconds: 6);
      default:
        return const Duration(seconds: 4);
    }
  }

  static String _messageFor(_SignCaptureErrorContext context, HomeUiCopy copy) {
    switch (context.category) {
      case _ErrorCategory.rateLimited:
        return copy.signCaptureRateLimitedLabel;
      case _ErrorCategory.modelUnavailable:
        return copy.signCaptureModelUnavailableLabel;
      case _ErrorCategory.noSignsDetected:
        return copy.signNoSignsDetectedLabel;
      case _ErrorCategory.notConfigured:
        return copy.signCaptureNotConfiguredLabel;
      case _ErrorCategory.unauthorized:
        return copy.signCaptureUnauthorizedLabel;
      case _ErrorCategory.uploadTimeout:
        return copy.signCaptureUploadTimeoutLabel;
      case _ErrorCategory.workerOverload:
        return copy.signCaptureWorkerOverloadLabel;
      case _ErrorCategory.recordingTooLarge:
        return copy.signRecordingTooLargeLabel;
      case _ErrorCategory.recordingEmpty:
        return copy.signRecordingEmptyLabel;
      case _ErrorCategory.serviceUnavailable:
        return copy.signCaptureServiceUnavailableLabel;
      case _ErrorCategory.genericFailure:
        return copy.signCaptureFailedLabel;
    }
  }

  static _SignCaptureErrorContext _parseError(Object error) {
    if (error is TimeoutException) {
      return const _SignCaptureErrorContext(
        category: _ErrorCategory.uploadTimeout,
      );
    }

    final haystack = _errorHaystack(error);
    final workerStatus = _workerStatus(error);
    final detail = _responseDetail(error);
    final detailHaystack = detail.toLowerCase();
    final geminiStatuses = _geminiStatuses('$detail\n$haystack');

    if (_matches(haystack, ['gemini_key not configured'])) {
      return const _SignCaptureErrorContext(
        category: _ErrorCategory.notConfigured,
      );
    }

    if (workerStatus != null) {
      return _contextForWorkerStatus(
        workerStatus: workerStatus,
        haystack: haystack,
        detailHaystack: detailHaystack,
        geminiStatuses: geminiStatuses,
      );
    }

    if (_matches(haystack, ['timeoutexception', 'future not completed'])) {
      return const _SignCaptureErrorContext(
        category: _ErrorCategory.uploadTimeout,
      );
    }

    if (_matches(haystack, ['socketexception', 'failed host lookup'])) {
      return const _SignCaptureErrorContext(
        category: _ErrorCategory.serviceUnavailable,
      );
    }

    if (_matches(haystack, [
      'no signs detected',
      'empty sign text',
      'sign worker returned empty text',
      'unable to parse gloss',
      'invalid gloss',
    ])) {
      return const _SignCaptureErrorContext(
        category: _ErrorCategory.noSignsDetected,
      );
    }

    if (_matches(haystack, [
      'payload too large',
      'too large',
      'max 10 mb',
      'max 8 mb',
    ])) {
      return const _SignCaptureErrorContext(
        category: _ErrorCategory.recordingTooLarge,
      );
    }

    return const _SignCaptureErrorContext(
      category: _ErrorCategory.genericFailure,
    );
  }

  static _SignCaptureErrorContext _contextForWorkerStatus({
    required int workerStatus,
    required String haystack,
    required String detailHaystack,
    required Set<int> geminiStatuses,
  }) {
    switch (workerStatus) {
      case 400:
        if (_matches(detailHaystack, [
          'missing video',
          'empty video',
          'empty video upload',
        ])) {
          return const _SignCaptureErrorContext(
            category: _ErrorCategory.recordingEmpty,
          );
        }
        return const _SignCaptureErrorContext(
          category: _ErrorCategory.genericFailure,
        );
      case 401:
        return const _SignCaptureErrorContext(
          category: _ErrorCategory.unauthorized,
        );
      case 404:
        return const _SignCaptureErrorContext(
          category: _ErrorCategory.serviceUnavailable,
        );
      case 413:
        return const _SignCaptureErrorContext(
          category: _ErrorCategory.recordingTooLarge,
        );
      case 429:
        return const _SignCaptureErrorContext(
          category: _ErrorCategory.rateLimited,
        );
      case 502:
        return _contextForUpstreamFailure(
          detailHaystack: detailHaystack,
          geminiStatuses: geminiStatuses,
        );
      case 503:
        if (_matches(haystack, ['1102', 'cpu time limit', 'exceeded cpu'])) {
          return const _SignCaptureErrorContext(
            category: _ErrorCategory.workerOverload,
          );
        }
        return const _SignCaptureErrorContext(
          category: _ErrorCategory.serviceUnavailable,
        );
      case 504:
        return const _SignCaptureErrorContext(
          category: _ErrorCategory.uploadTimeout,
        );
      case 500:
      case 520:
      case 521:
      case 522:
      case 524:
        return const _SignCaptureErrorContext(
          category: _ErrorCategory.serviceUnavailable,
        );
      default:
        if (workerStatus >= 500) {
          return const _SignCaptureErrorContext(
            category: _ErrorCategory.serviceUnavailable,
          );
        }
        return const _SignCaptureErrorContext(
          category: _ErrorCategory.genericFailure,
        );
    }
  }

  /// Gemini / recognition failures returned inside worker HTTP 502.
  static _SignCaptureErrorContext _contextForUpstreamFailure({
    required String detailHaystack,
    required Set<int> geminiStatuses,
  }) {
    if (geminiStatuses.contains(429) ||
        _matches(detailHaystack, [
          'rate limit',
          'resource exhausted',
          'you exceeded',
          'quota',
        ])) {
      return const _SignCaptureErrorContext(
        category: _ErrorCategory.rateLimited,
      );
    }

    if (geminiStatuses.contains(503) ||
        _matches(detailHaystack, ['high demand', 'overloaded'])) {
      return const _SignCaptureErrorContext(
        category: _ErrorCategory.rateLimited,
      );
    }

    if (geminiStatuses.contains(404) ||
        _matches(detailHaystack, [
          'models/gemini',
          'model is not found',
          'not found for api version',
        ])) {
      return const _SignCaptureErrorContext(
        category: _ErrorCategory.modelUnavailable,
      );
    }

    if (_matches(detailHaystack, ['gemini_key not configured'])) {
      return const _SignCaptureErrorContext(
        category: _ErrorCategory.notConfigured,
      );
    }

    if (_matches(detailHaystack, [
      'no signs detected',
      'empty sign text',
      'sign worker returned empty text',
      'unable to parse gloss',
      'invalid gloss',
    ])) {
      return const _SignCaptureErrorContext(
        category: _ErrorCategory.noSignsDetected,
      );
    }

    if (geminiStatuses.contains(504) || geminiStatuses.contains(500)) {
      return const _SignCaptureErrorContext(
        category: _ErrorCategory.uploadTimeout,
      );
    }

    return const _SignCaptureErrorContext(
      category: _ErrorCategory.serviceUnavailable,
    );
  }

  static int? _workerStatus(Object error) {
    if (error is! HttpException) {
      return null;
    }
    final match = RegExp(r'sign worker (\d+):', caseSensitive: false)
        .firstMatch(error.message);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1)!);
  }

  static String _responseDetail(Object error) {
    if (error is! HttpException) {
      return '';
    }

    final message = error.message;
    final jsonStart = message.indexOf('{');
    if (jsonStart < 0) {
      final colon = message.indexOf(':');
      if (colon < 0) {
        return message;
      }
      return message.substring(colon + 1).trim();
    }

    try {
      final decoded = jsonDecode(message.substring(jsonStart));
      if (decoded is! Map) {
        return message;
      }
      final parts = <String>[];
      for (final key in ['detail', 'error', 'message']) {
        final value = decoded[key];
        if (value != null) {
          parts.add('$value');
        }
      }
      return parts.join('\n');
    } on Object {
      return message;
    }
  }

  static Set<int> _geminiStatuses(String haystack) {
    final statuses = <int>{};
    for (final match
        in RegExp(r'gemini (\d+):', caseSensitive: false).allMatches(haystack)) {
      final status = int.tryParse(match.group(1)!);
      if (status != null) {
        statuses.add(status);
      }
    }
    return statuses;
  }

  static String _errorHaystack(Object error) {
    final parts = <String>[];

    if (error is HttpException) {
      parts.add(error.message);
      parts.add(_responseDetail(error));
    } else {
      parts.add(error.toString());
    }

    return parts.join('\n').toLowerCase();
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

enum _ErrorCategory {
  rateLimited,
  modelUnavailable,
  noSignsDetected,
  notConfigured,
  unauthorized,
  uploadTimeout,
  workerOverload,
  recordingTooLarge,
  recordingEmpty,
  serviceUnavailable,
  genericFailure,
}

final class _SignCaptureErrorContext {
  const _SignCaptureErrorContext({required this.category});

  final _ErrorCategory category;
}
