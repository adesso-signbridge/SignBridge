/// Quick-phrase sections shown as filter chips on the Phrases screen.
enum PhraseCategory {
  greetings('greetings', 'Greetings'),
  medical('medical', 'Medical'),
  transport('transport', 'Transport'),
  shopping('shopping', 'Shopping'),
  emergency('emergency', 'Emergency');

  const PhraseCategory(this.id, this.defaultLabel);

  final String id;
  final String defaultLabel;
}
