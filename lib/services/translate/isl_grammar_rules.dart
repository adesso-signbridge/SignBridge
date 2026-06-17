/// ISL grammar references used by [SignGrammarEngine] for Hindi/Tamil/Malayalam.
library;

abstract final class IslGrammarRules {
  /// Spatial prepositions kept for locative compounds (TABLE BOOK-ON).
  static const spatialPrepositions = {
    'on',
    'under',
    'in',
    'inside',
    'beside',
    'next',
    'above',
    'below',
  };

  /// ISL third-person pronouns use pointing, not IX.
  static const islPronounOverrides = {
    'he': 'point-there',
    'she': 'point-there',
    'him': 'point-there',
    'her': 'point-there',
    'they': 'point-there-plural',
    'them': 'point-there-plural',
    'वह': 'point-there',
    'वे': 'point-there-plural',
    'அவர்': 'point-there',
    'அவள்': 'point-there',
    'அவர்கள்': 'point-there-plural',
    'അവൻ': 'point-there',
    'അവൾ': 'point-there',
    'അവർ': 'point-there-plural',
  };
}
