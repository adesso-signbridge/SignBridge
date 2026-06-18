/// Result of an emergency call or SOS activation attempt.
final class SosActionResult {
  const SosActionResult({
    required this.ok,
    this.emergencyNumber,
    this.spokenMessage,
    this.errorMessage,
  });

  const SosActionResult.success({
    required String emergencyNumber,
    String? spokenMessage,
  }) : this(
         ok: true,
         emergencyNumber: emergencyNumber,
         spokenMessage: spokenMessage,
       );

  const SosActionResult.failure(String message)
    : this(ok: false, errorMessage: message);

  final bool ok;
  final String? emergencyNumber;
  final String? spokenMessage;
  final String? errorMessage;
}
