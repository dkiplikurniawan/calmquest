<div align="center">

# 🌙 CALMQUEST: The Lost Light

### *A cozy 2D fantasy adventure where nothing can go wrong, and the world slowly brightens because you were kind to it.*

**Godot 4.7** · **GDScript (static typing)** · **Python 3.12 analysis** · **English & Bahasa Indonesia** · **v0.4.0** · **All rights reserved (source available)**

![Firefly Grove in the open world of Lumeria](screenshots/05_firefly_grove.png)

</div>

> [!IMPORTANT]
> CALMQUEST is an entertainment prototype oriented toward well-being. It is **not** a medical device. It does **not** diagnose, detect, treat or measure stress or anxiety. A change between two self-reported scores does not show that the game caused it.

---

## 📖 Table of contents

1. [The story in one breath](#-the-story-in-one-breath)
2. [Where this game is going: vision and goals](#-where-this-game-is-going-vision-and-goals)
3. [Design pillars](#-design-pillars)
4. [The player's journey (flowchart)](#-the-players-journey-flowchart)
5. [The core loop](#-the-core-loop)
6. [The story arc: Acts 1 to 3](#-the-story-arc-acts-1-to-3)
7. [Methods: how it works under the hood](#-methods-how-it-works-under-the-hood)
8. [System architecture](#-system-architecture)
9. [Data flow: from a click to a chart](#-data-flow-from-a-click-to-a-chart)
10. [Feature tour](#-feature-tour)
11. [Getting started](#-getting-started)
12. [Testing and quality](#-testing-and-quality)
13. [Privacy by design](#-privacy-by-design)
14. [Known limitations](#-known-limitations)
15. [Roadmap](#-roadmap)
16. [Repository map](#-repository-map)
17. [Credits and license](#-credits-and-license)

---

## ✨ The story in one breath

The light of the **Lumeria Isles** has faded. You wake as a quiet **Traveler** in Whispering Meadow, and a small fox-like light spirit named **Lumi** floats up to greet you. Together you gather drifting motes of light, restore the great **Heart Tree**, and step out into a wide world of glowing groves, misty pinewoods, singing caves, a sleepy lighthouse and frosty highlands under an aurora.

There are **no timers, no lives, no streaks, no damage and no punishment for stopping**. You can't lose. The only thing that changes is how bright the world becomes.

<div align="center">

| | |
|:---:|:---:|
| ![Main menu](screenshots/01_main_menu.png) | ![Whispering Meadow](screenshots/03_meadow_gentle.png) |
| *The main menu* | *Whispering Meadow, your home* |

</div>

---

## 🧭 Where this game is going: vision and goals

CALMQUEST asks one question:

> **Can a game feel restful *and* be honest about how it adapts to you?**

Many "relaxation" apps either measure people without explaining how, or present a black-box "AI" that claims to know how someone feels. CALMQUEST takes the opposite path: **fun first, transparent always.**

```mermaid
mindmap
  root((CALMQUEST))
    Play first
      A cozy open world
      No fail states
      Story you can finish at your own pace
    Player in control
      Gentle / Balanced / Playful
      Every mode is always selectable
      Calmer or livelier at any time
    Transparent adaptation
      Named rules, not a hidden model
      Suggestions, never assumptions
      Never raises difficulty automatically
    Respect for data
      Default game stores no research data
      Consent before any CSV row
      Nothing leaves the device
    Research ready
      Hidden Study Mode
      Reproducible Python analysis
      Neutral, non-causal wording
```

### Goals, in order of priority

| # | Goal | How we know we reached it |
|:-:|---|---|
| 1 | **A game people want to play** | A full open world with three acts, 9 regions, 5 villagers and a finale you can actually finish |
| 2 | **Zero pressure** | No failure path exists in code. Every puzzle has a reset lever and a 3-step hint ladder. Quests can never become impossible |
| 3 | **The player decides** | Comfort modes are *suggested* and never forced. The engine never raises difficulty by itself |
| 4 | **Explainable adaptation** | Every rule is a named constant in [`adaptive_comfort_engine.gd`](game/scripts/systems/adaptive_comfort_engine.gd), and every parameter is clamped to documented bounds |
| 5 | **Privacy you can verify** | No network code at all. Research data exists only in Study Mode, and only after consent |
| 6 | **Research you can reproduce** | A fixed CSV schema, a synthetic sample, tested Python scripts and a notebook |

### Version timeline

```mermaid
timeline
    title From one meadow to a wide world
    V1 "The Lost Light" : One meadow, Heart Tree, Lantern Night
                        : Three comfort modes and the check-in
                        : Opt-in CSV and Python analysis
    V2 "The Wide World of Lumeria" : 8 x 8.5 screen open world, 9 regions, 2 isles, 2 caves
                                   : Crafting, farming, fishing, cooking, decorating
                                   : Acts 2 and 3, villagers, 3 save slots, Bahasa Indonesia
    v0.4.0 "Polish" : One game, two layers (default play + hidden Study Mode)
                    : Calm HUD, mood check, rest spots, Breathe with Lumi
                    : Finale cinematic, softer audio, About screen
```

---

## 🌿 Design pillars

| Pillar | What it means in practice |
|---|---|
| 🕊️ **Calm, not empty** | Quiet music that follows the region and time of day, 12 rest spots where you can just sit, a fading HUD, weather you can turn off |
| 🫶 **Kindness as mechanics** | Gloomlings are *comforted* with light, song or food, never fought. Crops never die, and rain waters them |
| 🔍 **Curiosity over checklists** | Recipes are discovered through notes and experiments. Hearthstones can be found in any order |
| 🧩 **Puzzles without walls** | Every puzzle can be reset and offers a hint ladder. Gentle mode makes fishing catch automatically |
| 🪟 **Glass-box design** | Each adaptation is a documented rule that a reader can find, read and test |
| ♿ **Accessible by default** | Keyboard, mouse and gamepad, key remapping, text size, high contrast, reduce motion, captions, and shape cues that never rely on color alone |

---

## 🗺️ The player's journey (flowchart)

This is what a player sees from launch to leaving. The **default game** is the left path. **Study Mode** is a hidden branch for research sessions.

```mermaid
flowchart TD
    A([🚀 Launch]) --> B[Splash screen]
    B --> C{Main menu}

    C -->|Start Adventure| D[Choose a journey<br/>3 save slots]
    C -->|Settings| S[Audio, display, interface,<br/>controls, language]
    C -->|"Data &amp; Privacy"| P[Export, open folder,<br/>delete, reset]
    C -->|About| AB[Credits and info]
    C -.->|"--study flag, or 7 clicks on the<br/>version label + code"| SM[🔬 Study Mode setup]

    D --> E{New journey?}
    E -->|Yes| F[Pick a comfort mode<br/>Balanced pre-selected]
    F --> G{Optional mood check<br/>five drawn faces}
    G -->|Answer or Skip| W
    E -->|No, continue| W

    W[🌍 The world of Lumeria] --> L{Leave?}
    L -->|Keep playing| W
    L -->|Return to menu / Quit| BY["'Before you go...'<br/>summary of real events"]
    BY --> AS[💾 Autosave<br/>+ optional private journal]
    AS --> C

    SM --> CI[Check-in 0-10<br/>+ consent checkbox]
    CI --> FW[Fresh temporary world<br/>10 / 15 / 20 minutes]
    FW --> GE[Gentle end:<br/>waits until nothing is open]
    GE --> RF[Reflection 0-10<br/>+ experience rating]
    RF --> CSV{Consented?}
    CSV -->|Yes| WR[(sessions.csv<br/>study_sessions.csv<br/>study_events.csv)]
    CSV -->|No| NO[Nothing is written]
    WR --> RS[Results screen<br/>neutral wording]
    NO --> RS
    RS --> SM

    classDef study fill:#2b2a4a,stroke:#9d8cff,color:#eee;
    classDef world fill:#1f3b2c,stroke:#7fd18b,color:#eee;
    class SM,CI,FW,GE,RF,CSV,WR,NO,RS study;
    class W world;
```

---

## 🔁 The core loop

> **wander → discover → gather → craft & help → restore → watch the world brighten**

```mermaid
flowchart LR
    W((🚶 Wander)) --> D((🔭 Discover))
    D --> G((🌾 Gather))
    G --> C(("🛠️ Craft<br/>&amp; help"))
    C --> R((🌳 Restore))
    R --> B((✨ The world<br/>brightens))
    B -->|new regions, tools,<br/>villagers, recipes| W

    B -.-> REST(("🪑 Rest &amp;<br/>breathe"))
    REST -.-> W
```

Each restoration **unlocks** something that opens more of the world. Tools are the keys:

| Tool | Opens |
|---|---|
| 🏮 Bright Lantern | Clears gloom in Misty Pinewood |
| 🚿 Watering Can | Farming and the forgotten garden |
| 🎣 Fishing Rod | 11 fishing spots, 12 fish |
| ⛵ Small Boat | The two Sunpetal Isles |
| 💎 Crystal Tuner | The tuned crystal door in the caves |
| 🪢 Climbing Rope | The mountain pass to Frostbloom Highlands |

---

## 📜 The story arc: Acts 1 to 3

```mermaid
flowchart TD
    subgraph ACT1["🌱 Act 1: The Lost Light"]
        A1[Gather 8 lights] --> A2[Restore the Heart Tree]
        A2 --> A3[Firefly Grove:<br/>Lantern Night]
        A3 --> A4[Crystal Creek:<br/>beam puzzle]
        A4 --> A5[Moonlit Sanctuary:<br/>the Moon Altar]
    end

    subgraph ACT2["🔥 Act 2: The Five Hearthstones (any order)"]
        H1[🌲 of the Pines<br/>clear gloom, lead 3 fox kits home]
        H2[🗼 of the Shore<br/>relight the lighthouse]
        H3[🏝️ of the Isles<br/>sail to the Wreck Isle, signal puzzle]
        H4[🕳️ of the Echoes<br/>solve both Echo Caverns]
        H5[🌌 of the Aurora<br/>climb the pass, align the shrine]
    end

    subgraph ACT3["🏮 Act 3: Return of the Light"]
        F1[Set the stones in the circle] --> F2[Invite the five villagers]
        F2 --> F3[Light the Great Lantern]
        F3 --> F4[🎬 Finale cinematic<br/>skippable]
    end

    A5 --> HC{{Heart Tree circle:<br/>the light only reaches the meadow}}
    HC --> H1 & H2 & H3 & H4 & H5
    H1 & H2 & H3 & H4 & H5 --> F1
    F4 --> PG[🌍 Post-game: the world stays open<br/>'A Wider Journal', Aurora Stag, epilogue]
```

Along the way, the side life of Lumeria keeps going: restore the **cottage** (8 steps), decorate inside and out (18 decorations), plant 5 crops, cook 13 dishes, sketch 17 creatures, and befriend 5 spirit villagers with their own homes, routines and requests.

<div align="center">

| | | |
|:---:|:---:|:---:|
| ![Cottage restored](screenshots/16_cottage_restored.png) | ![Singing Grotto beams](screenshots/37_grotto_beam.png) | ![Festival of Light](screenshots/42_festival_of_light.png) |
| *A restored home* | *A cave beam puzzle* | *The Festival of Light* |

</div>

---

## 🧪 Methods: how it works under the hood

This section explains *which techniques* the project uses and *why*, so a reader can judge the design rather than take it on trust.

### 1. Transparent, rule-based adaptation (the "AI" that isn't a black box)

[`AdaptiveComfortEngine`](game/scripts/systems/adaptive_comfort_engine.gd) is a deterministic module with **no machine-learning model and no scene dependencies**, so it can be unit tested headlessly. It only uses things the player *explicitly* does: an optional self-reported score, the mode they pick, hint requests, near-miss interactions, and "calmer" or "livelier" requests.

```mermaid
flowchart TD
    S{Optional check-in score} -->|7 to 10| G[Suggest 🍃 Gentle]
    S -->|4 to 6| B[Suggest ⚖️ Balanced]
    S -->|0 to 3| Q[Ask: Balanced or Playful?<br/>Balanced pre-selected]
    S -->|Skipped or invalid| D[Balanced,<br/>every mode selectable]

    G & B & Q & D --> P[👤 Player makes the final choice]
    P --> M[ModeConfig applied to every system]

    M --> R1{3 explicit hint requests?}
    R1 -->|yes, unless player turned it off| GA[Turn on the guiding glow]
    M --> R2{2 presses just outside reach?}
    R2 -->|yes| RC[Explain the control<br/>and show the reach circle]
    M --> R3{Player asks calmer / livelier?}
    R3 -->|yes| SW[Switch mode now,<br/>keep all progress]
```

**What the engine never does:** raise difficulty automatically, or treat speed, pauses or mistakes as signs of stress.

| Parameter | 🍃 Gentle | ⚖️ Balanced | 🎉 Playful | Bounds |
|---|:---:|:---:|:---:|:---:|
| Interaction reach (px) | 104 | 72 | 64 | 40-140 |
| Light movement multiplier | 0.35 | 1.0 | 1.5 | 0-2 |
| Guiding glow by default | on | off | off | |
| Bonus Prism Motes | 0 | 0 | 3 | 0-3 |
| Lantern Catch lanterns (+ bonus) | 6 | 8 | 10 (+2) | 3-12 |
| Lantern drift speed (px/s) | 6 | 18 | 30 | 0-40 |

Modes reach beyond the meadow, too: hints, fishing (Gentle catches automatically), creatures, puzzles, Lantern Night and the day/night clock (Gentle can slow or pause it).

### 2. Data-driven content

Everything a designer might author lives as JSON in [`game/data/`](game/data/): the world map and points of interest, quests, items, recipes, creatures, restoration sites, caves (as ASCII maps), villagers, requests, lore, the cottage and the rest spots. **Adding a fish, a quest or a decoration needs no code.**

### 3. Deterministic procedural world

The 10240 × 6144 px world (40 × 24 macro cells of 256 px) is **authored at the macro level and filled in procedurally**.

```mermaid
flowchart LR
    J[(overworld.json<br/>cells, regions, paths,<br/>rivers, POIs)] --> WD[WorldData.load_from]
    WD --> T[Terrain<br/>shader ground, paths,<br/>river, row-run collision]
    WD --> CG["ChunkGenerator<br/>seed = hash(world_seed, cx, cy)"]
    CG --> WS[WorldStreamer<br/>1024 px chunks,<br/>max 1 build per frame]
    CG --> GD["GroundDetail + features<br/>own random streams"]
    WD --> POI[Controllers spawn<br/>hand-placed POIs]
    WS --> SCREEN([🖥️ What you see])
    GD --> SCREEN
    T --> SCREEN
    POI --> SCREEN
    GS[(GameState deltas<br/>gathered object ids)] -.-> WS
```

- **Seeded hashing** (`hash([world_seed, chunk.x, chunk.y])`) means the same chunk always produces the same scenery, so saves only need to store *what changed* (deltas), not the whole world.
- **Separate random streams** for ground detail and features keep object ids stable when new decoration is added.
- **Chunk streaming** builds at most one chunk per frame to avoid stutter.

### 4. Quest evaluation as a fixed point

[`QuestBook`](game/scripts/quests/quest_book.gd) reads facts from `GameState` (flags such as `hearthstone_pines`, counters such as `fish_species`) using conditions like `flag`, `counter`, `region`, `any` and `all`. Evaluation **repeats until nothing changes**, so:
- anything done early still counts;
- several steps can complete at once;
- completed quests never revert.

### 5. Procedural art and audio

- **Art** is drawn in GDScript (`_draw()`), with shaders for ground blending, rivers and the desaturating **gloom veil**. No external art files.
- **Sound effects** are synthesized at runtime with ±4% pitch variation and footsteps on six surfaces.
- **Music** is composed as original MIDI scores and rendered offline by [`tools/music/`](tools/music/). `MusicManager` crossfades cues by region, night amount, rain and finale, and automatically prefers real recordings in `assets/music/rendered/` when they exist.

### 6. Robust saves

Versioned saves with **migration**, **atomic writes plus a backup**, and autosaves on sleep, doors, quests and a timer. Damaged saves fall back to the backup. Research data is **never** part of a save.

### 7. Performance techniques

- **`ViewCull`**: animated objects only redraw near the camera (about 6-7 ms per frame saved).
- **Light budget**: at most 16 `PointLight2D` near the screen.
- **Batching**: ground detail is one triangle array per chunk; atmosphere particles are one per effect.

### 8. Localization

English is the source language. The Indonesian catalog (`game/data/i18n/id/*.json`) is registered as a runtime `Translation`, so the language **switches instantly** in Settings. `tools/i18n/extract.py` verifies that every player-facing string is translated with matching placeholders and line breaks. The research CSV never depends on the language.

### 9. Honest statistics

The Python pipeline is **descriptive only**:
- `score_delta = post - pre`; a negative value means the later self-report was lower;
- a skipped answer is an **empty cell, never 0** (because 0 is a valid answer);
- invalid rows are excluded whole and reported with a reason;
- missingness and denominators are always shown;
- summaries use neutral, **non-causal** wording.

The evaluation plan ([docs/EVALUATION_PLAN.md](docs/EVALUATION_PLAN.md)) recommends effect sizes with bootstrap confidence intervals over p-value claims, and lists what a real causal study would require.

### 10. Calm by design: rest and breathing

**12 rest spots** let you sit while Lumi curls up, the camera drifts, the HUD fades and the music swells. **"Breathe with Lumi"** offers three paces (Gentle 4 s in / 6 s out, Even 4/4, Slow 5/7) for 1-3 minutes or until you stop. Any key stops it, and there are no scores.

---

## 🏗️ System architecture

One authority per kind of state, pure logic separated from scenes, and gameplay code that never talks to the UI directly.

```mermaid
flowchart TB
    subgraph AUTO["⚙️ Autoloads (global singletons, in load order)"]
        direction LR
        GSet[GameSettings<br/>input, settings, language]
        AM[AudioManager<br/>buses, synthesized SFX]
        MM[MusicManager<br/>cues, crossfades]
        EB[EventBus<br/>global signals]
        TM[TimeManager<br/>day/night clock]
        GS[GameState<br/>persistent world]
        SS[SessionState<br/>+ adaptive engine]
        QM[QuestManager]
        SV[SaveManager<br/>slots, migration]
        WB[Wellbeing<br/>mood check, journal]
        ST[StudyMode]
        SR[SceneRouter]
    end

    subgraph OW["🌍 Overworld (scene orchestrator)"]
        direction LR
        TER[Terrain +<br/>WorldStreamer]
        ML[MeadowLoop<br/>Act 1 core]
        SC[StoryContent]
        HS[Homestead]
        RF[RegionFeatures<br/>wildlife, gloom,<br/>fishing, docks]
        CV[Caves]
        VL[Village<br/>Acts 2-3, finale]
        RE[Rest]
        PL[Player + Lumi<br/>+ Camera]
        HUD[HUD + menus]
    end

    DATA[(game/data/*.json)] --> QM
    DATA --> OW
    SS -->|ModeConfig| OW
    OW -->|writes facts| GS
    GS <--> EB
    GS --> QM
    QM -->|quest tracker| HUD
    SV <--> GS
    SV --> SAVES[(saves/slot_N.json)]
    SS --> REC[SessionRecord] --> CSV[(sessions.csv<br/>only with consent)]
    ST --> SCSV[(study_*.csv<br/>only with consent)]
    OW --> MM
```

**Pure, testable classes** (no scene tree required): `WorldData`, `ChunkGenerator`, `QuestBook`, `BeamPuzzle`, `CraftingBook`, `Inventory`, `DecorRules`, `Farming`, `Fishing`, `CreatureDB`, `VillageDB`, `Weather`, `Cosmetics`, `AdaptiveComfortEngine`, `SessionRecord` and `CsvCodec`.

Full details: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## 📊 Data flow: from a click to a chart

```mermaid
sequenceDiagram
    autonumber
    actor P as Participant
    participant SM as StudyMode
    participant SS as SessionState
    participant W as World (Overworld)
    participant FS as CsvFileStore
    participant PY as Python analysis

    P->>SM: Participant code, minutes, language
    SM->>SS: begin_session(consent?)
    P->>SS: Check-in score 0-10 (or skip)
    SS-->>P: Suggested mode (player decides)
    SM->>W: Fresh temporary world (STUDY_SLOT)
    loop During play
        W->>SS: hints, near-misses, items, mode changes
        W->>SM: events (only if consented)
    end
    SM->>W: Time is up: gentle end, waits until nothing is open
    P->>SS: Reflection score 0-10 + experience rating
    alt Consent given
        SS->>FS: v1 row → sessions.csv
        SM->>FS: study row → study_sessions.csv
    else No consent
        SS--xFS: nothing is written
    end
    SS-->>P: Results, neutral wording, no diagnosis
    P->>PY: Export CSV (Data & Privacy)
    PY-->>P: Validation report, summary, charts
```

### CSV schema (v1, one row per consented session)

```
schema_version, session_id, session_started_at, pre_stress_score, recommended_mode,
selected_mode, final_mode, session_duration_seconds, hints_used, interaction_help_events,
items_collected, garden_restored, post_stress_score, score_delta, experience_rating, completed
```

Full details: [docs/DATA_DICTIONARY.md](docs/DATA_DICTIONARY.md) and [docs/DATA_SCHEMA.md](docs/DATA_SCHEMA.md).

---

## 🎒 Feature tour

| Area | What works |
|---|---|
| 🌍 **Open world** | 10240 × 6144 px authored macro map, shader-blended biomes, seeded chunk streaming, sea and cliff boundaries, a mountain pass, 7 waystones with free travel, a world map with fog of war, pins, compass and minimap |
| 🏞️ **Regions** | Whispering Meadow (home), Firefly Grove, Crystal Creek, Moonlit Sanctuary, Misty Pinewood, Sunpetal Coast, two Sunpetal Isles (by boat), Frostbloom Highlands, two Echo Caverns |
| 🏡 **Home** | Cottage restoration, bed and sleep, storage chest, workbench tiers, cooking pot, grid build mode inside and out, garden plots |
| 🛠️ **Crafting** | 17 resources plus wild seeds, hotbar and bag upgrades, 40 recipes discovered through notes, restorations and experiments |
| 🌾🎣🍲 **Farming, fishing, cooking** | 5 crops that never die, 11 fishing spots, 12 fish with a no-fail minigame, 13 dishes with gentle optional buffs |
| 🦊 **Wildlife and gloom** | 17 creatures with a sketch journal and friendship; gloom patches and Gloomlings comforted with light, song or food |
| 🏘️ **Villagers** | 5 spirit villagers with homes, routines, gifts, friendship, personal quests and a never-expiring request board |
| 🧩 **Caves and puzzles** | Braziers, block pushing, a light bridge, a tuned crystal door, beam puzzles, signal lanterns, an aurora shrine. Reset levers and hint ladders everywhere |
| 🌦️ **Time and weather** | Day/night (15-24 min), clear, cloudy, rain and mist, fog, light shafts, cloud shadows, aurora |
| 💾 **Saves** | 3 slots, versioned with migration, atomic writes plus a backup, autosaves |
| 🎵 **Audio** | Music per place with crossfades, adaptive meadow layers, stingers, ambience, 5 buses, footsteps on six surfaces |
| 🧘 **Well-being layer** | Optional mood check, "Before you go..." summary, optional private mood journal (off by default), 12 rest spots, "Breathe with Lumi" |
| 🌐 **Languages** | English and Bahasa Indonesia, switchable live |
| 🔬 **Study Mode** | Hidden. Participant codes, 10/15/20 minutes, a fresh temporary world, a gentle end, consent-based CSVs. See [docs/STUDY_MODE.md](docs/STUDY_MODE.md) |

<details>
<summary><b>📸 More screenshots</b></summary>

| | |
|---|---|
| ![Choose a journey](screenshots/20_slot_select.png) | ![Crystal Creek puzzle](screenshots/07_crystal_creek_puzzle.png) |
| ![Misty Pinewood gloom](screenshots/21_pinewood_gloom.png) | ![Wildlife](screenshots/22_creatures.png) |
| ![Farm plots](screenshots/28_farm_plots.png) | ![Fishing](screenshots/30_fishing.png) |
| ![Lighthouse at night](screenshots/25_lighthouse_night.png) | ![Whispering Hollow cave](screenshots/34_cave_braziers.png) |
| ![The spirit village](screenshots/38_village.png) | ![Village evening](screenshots/41_village_evening.png) |
| ![Aurora over the highlands](screenshots/47_aurora_night.png) | ![Journal](screenshots/27_journal_creatures.png) |
| ![Mood check](screenshots/52_mood_check.png) | ![Before you go](screenshots/53_session_closing.png) |
| ![A rest spot at sunset](screenshots/54_rest_spot.png) | ![Breathe with Lumi](screenshots/56_breathing.png) |
| ![Finale credits](screenshots/42b_finale_credits.png) | ![Settings](screenshots/49_settings_audio.png) |

Screenshots are rendered from the real game by `tools/capture/capture_screenshots.tscn` (the same set in Bahasa Indonesia is in [`screenshots/id/`](screenshots/id/)). Some scenes are set up by the script, and the results screen shows a scripted test session, not real player data.

</details>

---

## 🚀 Getting started

### Requirements

- **Godot 4.7.x** (standard build, not .NET), tested with 4.7.2: <https://godotengine.org/download>
- **Python 3.12** (3.10+ should work) for the analysis, with pandas, matplotlib and Jupyter

No external art, fonts, audio samples, plugins, API keys or online services are needed.

### Run the game

1. Clone this repository.
2. Open Godot, click **Import**, and select `project.godot`.
3. Press **F5**. The entry point is `res://game/scenes/main/splash.tscn`.

From the command line:

```bash
godot --path . --import
```

```bash
godot --path .
```

### Controls (short version)

| Action | Keyboard | Gamepad |
|---|---|---|
| Move / run | WASD or arrows / Shift | Left stick or D-pad / B |
| Interact, sit at a rest spot | E | A |
| Bag and crafting | I or Tab | X |
| World map / pin | M / P | Right stick click / LT |
| Ask Lumi | H | Y |
| Journal | J | Back |
| Build mode | B | Left stick click |
| Pause / back | Escape | Start |

Keys can be remapped in **Settings > Controls**. Full list: [docs/CONTROLS.md](docs/CONTROLS.md).

### Run the analysis

```bash
python -m pip install -r analysis/requirements.txt
```

```bash
python analysis/analyze_sessions.py data/sample_sessions_SYNTHETIC.csv --out analysis/output
```

```bash
jupyter notebook analysis/session_analysis.ipynb
```

To analyse real sessions, export them in-game (**Data & Privacy > Export CSV...**) and pass that file instead. Study Mode data is analysed per participant with `analysis/analyze_study.py`.

---

## ✅ Testing and quality

```mermaid
flowchart LR
    RC[tools/run_checks.ps1] --> R[Static res:// references]
    RC --> U[188 GDScript unit tests]
    RC --> SM[678-check smoke test<br/>reachability flood-fill]
    RC --> OV[396-check overworld test<br/>plays Acts 1-3, save, relaunch]
    RC --> UI[175-check UI smoke test]
    RC --> SCN[All 9 screens load]
    RC --> I18N[Indonesian catalog check]
    RC --> PY[9 music-tool + 21 Python tests]
```

```bash
powershell -ExecutionPolicy Bypass -File tools/run_checks.ps1 -Godot "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"
```

Latest local run (Godot 4.7.2, Python 3.12, Windows 11, v0.4.0): **all 18 checks passed**. The analysis notebook also executes end-to-end. Visual and feel checks are manual: see [docs/MANUAL_TEST_CHECKLIST.md](docs/MANUAL_TEST_CHECKLIST.md) and [docs/TEST_PLAN.md](docs/TEST_PLAN.md).

---

## 🔒 Privacy by design

| Principle | Implementation |
|---|---|
| **Nothing by default** | The default game stores no research data at all |
| **Consent first** | Research rows are written only in Study Mode, after a clearly worded checkbox |
| **Nothing identifying** | No name, email, account, location or device id. Session ids are random |
| **Nothing leaves the device** | No network code, analytics or trackers |
| **You stay in control** | Data & Privacy offers export, open folder, delete and reset |

Files live in `%APPDATA%\CALMQUEST\` on Windows: `settings.cfg`, `saves/slot_N.json`, `progress.cfg`, the opt-in `sessions.csv`, the optional `wellbeing_journal.json`, and (Study Mode only) `study_sessions.csv` and `study_events.csv`. See [docs/PRIVACY.md](docs/PRIVACY.md).

---

## ⚠️ Known limitations

- **Music** is synthesized placeholder audio rendered from the game's own MIDI scores. Real recordings can drop into `assets/music/rendered/` (see [docs/MUSIC_PIPELINE.md](docs/MUSIC_PIPELINE.md)).
- **Not yet play-tested by people.** Everything is verified by automated tests and scripted screenshots only.
- **No physical gamepad** was available. Bindings are unit tested but not tried by hand.
- **Performance:** about 61 fps on average on the development laptop (RTX 3050, VSync on). Misty Pinewood is about 58 fps, and entering new chunks can still cause single slow frames.
- **Translation:** the Indonesian text has not been reviewed by a native speaker, and the stress question is a plain translation, not a validated instrument.
- **Self-report** is a single subjective 0-10 item, not a validated instrument.
- **Art** is procedural and intentionally simple, and the game uses Godot's default font until an OFL font is added to `assets/fonts/`.
- The Frostbloom Highlands are compact, and only Windows was tested.

---

## 🛤️ Roadmap

```mermaid
flowchart LR
    NOW([v0.4.0<br/>polished prototype]) --> U[Phase A:<br/>usability test<br/>5-8 adults, SUS]
    U --> PR[Phase B:<br/>preference study<br/>fixed vs chosen mode]
    NOW --> C[More content:<br/>areas, mini-games,<br/>cosmetics]
    NOW --> M[Real music<br/>recordings]
    C --> COOP[Shared Dream Garden<br/>co-op mode]
    PR --> ML[Only with enough consented data:<br/>a separately evaluated<br/>personalization model]
```

See [docs/EVALUATION_PLAN.md](docs/EVALUATION_PLAN.md) and [docs/DEVELOPMENT_ROADMAP.md](docs/DEVELOPMENT_ROADMAP.md).

---

## 📁 Repository map

```
project.godot            Godot project (entry: game/scenes/main/splash.tscn)
game/
├─ scenes/               main, ui, world, player, companion, collectibles, garden, minigames
├─ scripts/              autoload, systems (adaptive engine...), data (CSV layer), world, ui, ...
├─ data/                 JSON content: world, quests, items, recipes, wildlife, caves, villagers, i18n/id
└─ shaders/              ground, river and gloom shaders
assets/
├─ music/                midi/ (original scores), placeholder/ (synthesized), rendered/ (for recordings)
├─ ambience/             synthesized ambience loops
└─ fonts/, sprites/      empty except a README
tests/                   GDScript unit tests + smoke, overworld and UI tests
analysis/                analyze_sessions.py, analyze_study.py, notebook, tests, synthetic data generator
data/                    sample_sessions_SYNTHETIC.csv (synthetic only)
docs/                    design, architecture, data dictionary, privacy, tests, roadmap, evaluation
tools/                   run_checks.ps1, screenshot capture, perf probe, music/, i18n/extract.py
```

### Further reading

| Topic | Document |
|---|---|
| Game design (V1 and V2) | [GAME_DESIGN_DOCUMENT.md](docs/GAME_DESIGN_DOCUMENT.md), [GAME_DESIGN_V2.md](docs/GAME_DESIGN_V2.md) |
| Architecture | [ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| Art direction | [ART_DIRECTION.md](docs/ART_DIRECTION.md) |
| Study Mode | [STUDY_MODE.md](docs/STUDY_MODE.md) |
| Milestones | [V2_PROGRESS.md](docs/V2_PROGRESS.md) |
| Asset provenance | [ASSET_PROVENANCE.md](docs/ASSET_PROVENANCE.md) |

---

## 🙏 Credits and license

All art is drawn procedurally in GDScript. Sound effects are synthesized at runtime, and music and ambience are synthesized offline from original scores by `tools/music/`. All of it is original to this project, and no third-party assets are included. Godot Engine is MIT-licensed (© Godot Engine contributors).

Copyright © 2026 Dul Kipli Kurniawan. **All rights reserved.** The source code is published for review and portfolio purposes only; it is not open source. You may read and evaluate it, but you may not copy, modify, distribute or sell it, or its assets, without written permission. See [LICENSE](LICENSE).

<div align="center">

*Thank you for walking through Lumeria. Take your time. The light will wait for you.* 🌙

</div>
