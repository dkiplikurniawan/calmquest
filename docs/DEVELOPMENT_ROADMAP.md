# Development Roadmap

## Implemented in v0.1.0 (MVP)

- [x] Godot 4.7 project, input actions, autoloads, scene routing with fades
- [x] Splash, main menu, How to Play, Settings, Data & Privacy
- [x] Whispering Meadow with boundary, landmarks, paths, pond, procedural art
- [x] Traveler movement, collision, interaction radius, feedback animations
- [x] Lumi companion (follow, recovery, reactions, optional hints)
- [x] Light motes, Heart Tree restoration, garden beds, hidden details, journal
- [x] Lantern Catch mini-game with mode-specific parameters
- [x] Adaptive Comfort Engine (presets, recommendations, overrides, assistance rules, bounds)
- [x] Pre/post reflection, neutral results, optional experience rating
- [x] Consent-based CSV storage, validation, export, deletion
- [x] Settings: volumes, fullscreen, window size, text size, high contrast, reduce motion, assistance toggles
- [x] Python analysis module, executed notebook, synthetic sample, tests
- [x] Automated GDScript unit and integration tests, reference checker, check runner

## Next (polish and evaluation)

- [ ] Small usability test with 5-8 participants (see [EVALUATION_PLAN.md](EVALUATION_PLAN.md)) and fixes based on it
- [ ] Gamepad support and remappable keys
- [ ] Sprite-based art pass (keeping the procedural fallback), richer footstep and ambient sounds
- [ ] Export builds for Windows (and possibly Web without file export)
- [ ] Localisation (Indonesian and English)
- [ ] Optional persistent meadow decorations unlocked by restoration (cosmetic only, no loss-aversion)

## Later (new content)

- [ ] **Moonwater Lake:** moonlit pond, glowing lilies, gentle light-reflection puzzles
- [ ] **Starlight Garden:** crystals and collectible decorations for a personal garden
- [ ] More calm mini-games (e.g. constellation tracing, firefly guiding)
- [ ] Cosmetic customization for the Traveler and Lumi

## Future research directions (only with appropriate evidence)

- [ ] **Preference personalization experiment:** predict a player's *preferred assistance level* from explicit, opt-in choices. This requires:
  - a clearly defined target;
  - adequate consented data with known provenance;
  - train/test separation;
  - comparison against the current rule-based baseline;
  - honest reporting of uncertainty.

  It would remain a *suggestion* behind the existing `recommend()` interface. The self-reported score is not a ground-truth label for psychological state, and no stress-detection model is planned.
- [ ] **Validated user study** comparing fixed settings with preference-based settings (ethics review, pre-registration).

## Future: Shared Dream Garden (co-op)

A cooperative mode where friends visit a shared garden, gather light together, grow plants, exchange cosmetic gifts and solve simple cooperative puzzles. It would have no competition and no leaderboards.

Requirements before building it:
- authoritative state on a host or server;
- synchronized collection by stable IDs;
- reconnection and late joins;
- safety features: no open chat by default, report and block;
- keeping all reflection data strictly local.

See [ARCHITECTURE.md](ARCHITECTURE.md#future-co-op-shared-dream-garden-considerations).

## Explicitly not planned

Ads, paid unlocks, login streaks, loss-aversion mechanics, leaderboards, online telemetry, and any claim of clinical effect.
