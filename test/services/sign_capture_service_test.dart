import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/services/translate/local_sign_capture_service.dart';

void main() {
  test('peekResult returns localized sample spoken text', () {
    final service = LocalSignCaptureService();

    expect(
      service.peekResult('ENG').text,
      'My name is Alex. I am deaf.',
    );
    expect(service.peekResult('ENG').formattedDuration(), '01:00');
  });
}
