import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/services/avatar/sign_video_cache.dart';

void main() {
  tearDown(() {
    SignVideoCache.setCacheRootForTest(null);
  });

  group('SignVideoCache', () {
    test('cacheFileName is stable for the same URL', () {
      const url = 'https://example.dev/isl/hello.mp4';
      expect(SignVideoCache.cacheFileName(url), SignVideoCache.cacheFileName(url));
      expect(SignVideoCache.cacheFileName(url), contains('hello.mp4'));
    });

    test('localPathIfCached returns path after write', () async {
      final temp = await Directory.systemTemp.createTemp('sign_video_cache_test');
      SignVideoCache.setCacheRootForTest(temp);

      const url = 'https://example.dev/asl/you.mp4';
      final file = File(
        '${temp.path}/${SignVideoCache.cacheFileName(url)}',
      );
      await file.writeAsBytes([1, 2, 3]);

      expect(await SignVideoCache.localPathIfCached(url), file.path);
      await temp.delete(recursive: true);
    });
  });
}
