import 'dart:async';
import 'dart:collection';

import '../translate/sign_token.dart';

/// Plays gloss tokens one at a time for the native avatar renderer.
final class GlossPlaybackQueue {
  GlossPlaybackQueue({
    required this.onTokenChanged,
    this.tokenDuration = const Duration(milliseconds: 1200),
  });

  final void Function(SignToken token) onTokenChanged;
  final Duration tokenDuration;

  final Queue<SignToken> _pending = Queue<SignToken>();
  bool _playing = false;
  Timer? _timer;

  void enqueue(List<SignToken> tokens) {
    if (tokens.isEmpty) {
      return;
    }
    _pending.addAll(tokens);
    _pump();
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    _pending.clear();
    _playing = false;
  }

  void dispose() {
    reset();
  }

  void _pump() {
    if (_playing || _pending.isEmpty) {
      return;
    }

    _playing = true;
    final token = _pending.removeFirst();
    onTokenChanged(token);
    _timer = Timer(tokenDuration, () {
      _playing = false;
      _pump();
    });
  }
}
