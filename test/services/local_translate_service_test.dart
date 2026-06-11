import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/services/translate/local_translate_service.dart';
import 'package:sign_bridge/services/translate/translate_service.dart';

void main() {
  group('LocalTranslateService', () {
    test(
      'stopListening returns empty result when no speech captured',
      () async {
        final service = LocalTranslateService(forceMockListening: true);
        await service.startListening('ENG');
        final result = await service.stopListening('ENG');

        expect(result.hasTranscript, isFalse);
        expect(result.fullTranscript, isEmpty);
        expect(result.signSequence, isEmpty);
        expect(result.signSystem, SignLanguageSystem.asl);
      },
    );

    test('subscribe before activate receives partial captions', () async {
      final service = LocalTranslateService(forceMockListening: true);
      await service.prepareListening('ENG');

      final updates = <TalkListenUpdate>[];
      final sub = service.listenUpdates().listen(updates.add);
      await service.activateListening();

      await Future<void>.delayed(const Duration(milliseconds: 600));
      await sub.cancel();

      expect(updates.any((u) => u.fullTranscript.isNotEmpty), isTrue);
    });

    test('mock session emits final update with ASL gloss sequence', () async {
      final service = LocalTranslateService(forceMockListening: true);
      await service.startListening('ENG');

      TalkListenUpdate? finalUpdate;
      final sub = service.listenUpdates().listen((update) {
        if (update.isFinal) {
          finalUpdate = update;
        }
      });

      await Future<void>.delayed(const Duration(seconds: 4));
      await sub.cancel();

      expect(finalUpdate, isNotNull);
      final update = finalUpdate!;
      expect(update.fullTranscript, contains('Hello'));
      expect(update.signSystem, SignLanguageSystem.asl);
      expect(update.signSequence.map((t) => t.gloss), isNotEmpty);
    });

    test('mock session emits audio level updates while listening', () async {
      final service = LocalTranslateService(forceMockListening: true);
      await service.startListening('ENG');

      final levels = <double>[];
      final sub = service.audioLevelUpdates().listen(levels.add);

      await Future<void>.delayed(const Duration(milliseconds: 600));
      await sub.cancel();

      expect(levels, isNotEmpty);
      expect(levels.any((level) => level > 0.1), isTrue);
    });

    test('mock audio levels rise while words stream in', () async {
      final service = LocalTranslateService(forceMockListening: true);
      await service.prepareListening('ENG');

      final levels = <double>[];
      final levelSub = service.audioLevelUpdates().listen(levels.add);
      await service.activateListening();

      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await levelSub.cancel();

      expect(levels.length, greaterThan(4));
      final peak = levels.reduce((a, b) => a > b ? a : b);
      final quiet = levels.take(3).reduce((a, b) => a < b ? a : b);
      expect(peak, greaterThan(quiet + 0.15));
    });

    test('cancelListening clears an active mock session', () async {
      final service = LocalTranslateService(forceMockListening: true);
      await service.startListening('ENG');
      await service.cancelListening();
      final result = await service.stopListening('ENG');

      expect(result.hasTranscript, isFalse);
    });
  });
}
