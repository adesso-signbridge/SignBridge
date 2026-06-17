# SignBridge ASL & ISL Grammar Rules

This document describes the **rule-based gloss grammar** implemented in SignBridge. Spoken text is tokenized, reordered, and mapped to uppercase gloss tokens shown on the signing chip and avatar.

**Implementation:** `lib/services/translate/sign_grammar_engine.dart`  
**ASL reference constants:** `lib/services/translate/asl_grammar_rules.dart`  
**ISL reference constants:** `lib/services/translate/isl_grammar_rules.dart`  
**Compliance tests:** `test/services/asl_spec_compliance_test.dart`, `test/services/isl_spec_compliance_test.dart`

---

## Pipeline (both languages)

```
SpokenTextPrep.normalize
  → strip function words (is/am/are, a/the, do/can/must, prepositions, and/or …)
  → lemmatize verbs, map pronouns
  → numerical incorporation (Rule of 9 / ISL numeral compounds)
  → language-specific reorder (_applyAslRules / _applyIslRules)
  → aspect & modality (WILL, FINISH, NOT-CAN)
  → noun–adjective swap
  → NMM markers (questions, negation, intensity)
  → SignLexiconBuilder → gloss tokens
```

| Spoken language code | Sign system |
|----------------------|-------------|
| `ENG` | ASL |
| `HI`, `TA`, `ML` | ISL |

---

## ASL rules

Primary framework: **Time + Topic + Comment** (Germanna / LifePrint curriculum model).

### Module 1 — Foundational structures

| Rule | Pattern | Example (English → gloss) |
|------|---------|---------------------------|
| Time first | Time adverb before topic/comment | *I went to the store yesterday* → `YESTERDAY STORE ME GO` |
| Topic–comment | Object/topic before subject + feeling verb | *I like dogs* → `DOG ME LIKE` |
| IF clauses | Condition then result | *If it rains, the game is cancelled* → `IF RAIN GAME CANCEL` |
| Simple SVO | Three-word transitive (non-pronoun) | *The boy sees a dog* → `BOY SEE DOG` |
| Pronoun wrap | Optional trailing copy of subject | *I eat an apple* → `ME EAT APPLE ME` |

**Omitted from gloss:** articles (`a`, `the`), copula (`am`, `is`, `are`), most auxiliaries, conjunction `and` (lists use body tilt / listing NMM instead).

### Module 2 — Questions, negation, rhetoric

| Rule | Pattern | Example |
|------|---------|---------|
| WH-final | WH-sign at end + `[wh-q]` | *Why did you go?* → `YOU GO WHY [wh-q]` |
| Y/N questions | `[y/n-q]` prefix + pronoun copy | *Are you Deaf?* → `[y/n-q] YOU DEAF YOU` |
| Post-fix negation | `NOT` / `CANNOT` + `[headshake]` | *I cannot cook* → `ME COOK CANNOT [headshake]` |
| Rhetorical WHY | `because` / `so` → `[rh-q] WHY` + reason | *I am late because traffic was heavy* → `… [rh-q] WHY TRAFFIC …` |

### Module 3 — Word mechanics

| Rule | Pattern | Example |
|------|---------|---------|
| Copula drop | Identity / adjective predicates | *The car is red* → `CAR RED` |
| Identity | Subject + noun | *I am a teacher* → `ME TEACHER` |

### Module 4 — Directional verbs

Agreement verbs incorporate subject/object direction:

| Example | Gloss |
|---------|-------|
| *I give you* | `ME 1-GIVE-YOU ME` |
| *You tell me* | `YOU TELL-ME YOU` |

### Module 5 — Time, numbers, aspect

| Rule | Pattern | Example |
|------|---------|---------|
| Rule of 9 | Cardinals 1–9 fuse with time units | *3 weeks ago* → `3-WEEKS-AGO` |
| ≥10 separate | Large numbers stay separate | *12 weeks ago* → `12 WEEK PAST` |
| Age incorporation | Small cardinal + years | *I am 5 years old* → `ME 5-YEARS-OLD` |
| FINISH aspect | Past / `have` without time anchor | *I have eaten* → `ME EAT FINISH` |
| AND omitted | Conjoined nouns listed | *I like dogs and cats* → `DOG CAT ME LIKE` |

### Module 6 — Space, loci, NMM

| Rule | Pattern | Example |
|------|---------|---------|
| Locatives | Location first, then compound | *The phone is on the table* → `TABLE PHONE-ON-TOP` |
| Spatial loci | Named referents get `IX-a`, `IX-b` | *John likes Mary* → `JOHN IX-a LIKE MARY IX-b` |
| Contextual NMM | Appended when triggered by vocabulary | `[mm]` routine, `[cha]` intense, `[th]` accidental, `[cs]` closeness |

### ASL gloss order (default clause)

When no specialized handler matches:

1. **Time** words moved to front (`today`, `yesterday`, `now`, …)
2. **Topic** (nouns / objects)
3. **Subject** pronouns (`ME`, `YOU`, `MY`, …)
4. **Comment** (verbs)
5. **WH** signs at end

Negated clauses may reorder to **Topic + Subject + NOT + Verb**.

### ASL non-manual markers (NMM)

| Marker | When |
|--------|------|
| `[y/n-q]` | Yes/no question (clause start) |
| `[wh-q]` | WH question (clause end) |
| `[rh-q]` | Rhetorical question (before `WHY`) |
| `[headshake]` | Negation |
| `[mm]` | Habitual / routine |
| `[cha]` | Intensity (`very`, `slow`, …) |
| `[th]` | Accidental action |
| `[cs]` | Closeness / proximity |

Defined in `lib/services/translate/asl_nmm_markers.dart`.

### ASL references

- [Germanna ASL Grammar Guide](https://germanna.edu/sites/default/files/2023-07/ASL%20Grammar%20Guide%20%28edit%207-24-23%29.pdf)
- [LifePrint ASL grammar](https://lifeprint.com/asl101/pages-layout/grammar.htm)
- [LifePrint numbers / Rule of 9](https://lifeprint.com/asl101/topics/numbers.htm)

---

## ISL rules

Primary framework: **Time → Subject → Object → Verb (SOV)** with topic–comment for emphasized objects.

### Core sentence order

| Rule | Pattern | Example (English → gloss) |
|------|---------|---------------------------|
| SOV default | Time → subject → object → verb | *I went to school yesterday* → `YESTERDAY ME SCHOOL GO` |
| Object–verb | Object before verb | *I eat an apple* → `ME APPLE EAT` |
| Topic–comment | Fronted topic + comment | *That book, I like it* → `BOOK THAT ME LIKE` |
| Time + work | Time before action | *Today I go to work* → `TODAY ME WORK GO` |

### Questions & negation

| Rule | Pattern | Example |
|------|---------|---------|
| WH on sign | WH word gets `?` suffix (no trailing `[wh-q]` in chip) | *Where are you going?* → `YOU GO WHERE?` |
| Y/N prefix | `[y/n-q]` when subject is `YOU` / demonstrative | *Are you coming?* → `[y/n-q] YOU COME?` |
| Negation after verb | `NOT` immediately after verb | *I don't know* → `ME KNOW NOT` |

### Word mechanics

| Rule | Pattern | Example |
|------|---------|---------|
| Adjective after noun | Noun before adjective | *Big house* → `HOUSE BIG` |
| Copula drop | State predicates | *The boy is happy* → `BOY HAPPY` |
| Third person | Pointing, not `IX` | *He is happy* → `POINT-THERE HAPPY` |

Pronoun overrides for Hindi/Tamil/Malayalam in `IslGrammarRules.islPronounOverrides`.

### Spatial & compounds

| Rule | Pattern | Example |
|------|---------|---------|
| Locative compounds | Surface + `-ON` / `-IN` / `-UNDER` | *Book on table* → `TABLE BOOK-ON` |
| Directional give | Agreement verb | *I give you water* → `ME GIVE-YOU` |

### Clauses

| Rule | Pattern | Example |
|------|---------|---------|
| Because / reason first | Reason clause before main | *I stayed home because it rained* → `RAIN HOME ME STAY` |
| IF | Condition then result | *If rain comes, game cancelled* → `IF RAIN GAME CANCEL` |

### Numbers & age

| Rule | Pattern | Example |
|------|---------|---------|
| Numeral incorporation | Cardinal + unit fused | *3 days* → `3-DAY` |
| Age | Dedicated pattern | *I am 25 years old* → `ME AGE 25` |

### Names

| Rule | Pattern | Example |
|------|---------|---------|
| Name intro | `MY NAME` + fingerspelled name | *My name is Adarsha* → `MY NAME FS-ADARSHA` |
| Name question | Romanized or English | *tumara nam kya hai* → `YOUR NAME WHAT?` |

### ISL conversational polish

Applied after core reorder:

- `WANT` / `NEED` often clause-final
- `HOW-MUCH` for price/quantity questions
- `VERY` intensifier placement
- Imperatives: trailing `!` on `QUICK`, `CALL` (e.g. `AMBULANCE CALL QUICK!`)

Conversational corpus: `test/fixtures/isl_conversational_sets.txt` (300 HI/TA/ML sentences).

### ISL NMM

Same marker set as ASL except ISL WH questions use **`WHERE?`** on the sign instead of a separate `[wh-q]` token in the chip output.

Defined in `lib/services/translate/isl_nmm_markers.dart`.

---

## Validation & audit tests

| Test file | What it checks |
|-----------|----------------|
| `asl_spec_compliance_test.dart` | ASL Modules 1–6 examples |
| `isl_spec_compliance_test.dart` | ISL structure, spatial, time, names |
| `isl_conversational_audit_test.dart` | 300-sentence HI/TA/ML corpus (exact gloss match) |
| `isl_rules_audit_test.dart` | 18 core ISL grammar sentences |
| `category_corpus_audit_test.dart` | 100 English daily-life sentences (ASL coverage) |
| `asl_grammar_shift_audit_test.dart` | Complex English → ASL coverage |

Run all grammar compliance tests:

```bash
flutter test test/services/asl_spec_compliance_test.dart \
             test/services/isl_spec_compliance_test.dart \
             test/services/isl_rules_audit_test.dart
```

---

## Cloud gloss (optional)

When online, the app can send a completed caption to the Cloudflare gloss Worker (Gemini) via the send button on the stopped-session caption bubble. On-device rules above still drive live listening; cloud gloss replaces the chip after explicit user send.

See `workers/gloss/index.js` and `lib/services/gloss/cloudflare_gloss_service.dart`.
