# Manual Test Checklist (V2 and 0.4.0)

`tools/run_checks.ps1` runs the automated tests. They cover:
- logic, data and save/load round trips;
- reachability of every place (including boat routes, the closed and open mountain pass, and inside caves);
- the full story chain (Act 1, the five Hearthstones, the finale);
- farming, fishing, cooking, villagers, the request board and puzzles;
- music cue selection and settings.

They cannot judge feel, readability, audio quality or real hardware. The items below need a person at the keyboard (and a gamepad). **None of them has been executed yet.**

Mark each item: ☐ not run / ✅ pass / ❌ fail (with a note).

## Start and flow
- ☐ Splash, then the main menu (wordmark, backdrop, Continue when a save exists), then Start Adventure, "Choose a journey" and the overworld. **No questionnaire** appears in the default game.
- ☐ A new journey shows the comfort-mode card (Balanced pre-selected), then the mood check (five faces, Skip, "Don't ask again"). Lumi's reply is neutral and kind. Continuing a journey shows neither card.
- ☐ Pause > Return to menu or Quit Game shows "Before you go..." (a short summary of real events, optional faces). "Keep playing" returns. With the setting off, the game leaves directly.
- ☐ The private mood journal: off by default. When on, entries appear on the journal's "Feelings" page and can be exported and deleted in Data & Privacy.
- ☐ Continue a journey after quitting the game: the position, inventory, homestead, villagers and quests are all there.
- ☐ Start over and delete a slot (with confirmations). The other slots are untouched.
- ☐ About: credits (your name from `game/data/credits.json`), licenses, version 0.4.0, the disclaimer.

## Study Mode (0.4.0; follow docs/STUDY_MODE.md)
- ☐ Unlock: 7 clicks on the version label, then `LUMERIA-STUDY`. The badge shows, and it stays after a restart until "Leave Study Mode". `--study` works for one run.
- ☐ Setup: invalid codes are refused (P01-P999 only). 10/15/20 minutes; the language is chosen.
- ☐ A full session: check-in with consent, a fresh world, the gentle end ("Our walk is almost done..."; never during dialogue or a minigame), reflection, results, "Next session".
- ☐ Main Menu from the study pause menu shows the incomplete-session warning, and returning works.
- ☐ Export study data, and run `analysis/analyze_study.py` on it. The player's own saves (slots 1-3) are untouched.

## Movement, camera, world
- ☐ Walking feels responsive in 8 directions. Shift running is comfortable; the toggle option works.
- ☐ Camera look-ahead is gentle, with no jitter. *Reduced camera motion* stops look-ahead and zoom changes.
- ☐ No empty space is visible at any map edge. The sea, cliffs and the closed mountain pass block the way.
- ☐ Walking across all regions shows no visible pop-in and no stutter at chunk borders.
- ☐ Region titles, map fog, pins, the minimap and the compass all behave as set in Settings.

## Act 1 (V1 content)
- ☐ Lights, then the Heart Tree, Lantern Night, the Crystal Creek puzzle, the veil, and the altar finale.

## Gathering, crafting, cottage, homestead (M3-M4)
- ☐ Gathering is pleasant (pickup notes are grouped, at most 5). Resources come back after the stated days.
- ☐ Crafting at hand, workbench and cottage workbench. Storage chest materials count when nearby.
- ☐ Restore all 8 cottage steps. Sleep in the bed (fade, autosave, morning).
- ☐ Build mode inside and outside: place, rotate, store, undo, with mouse and keyboard. Invalid spots explain why.
- ☐ Cooking: known dishes, experiments (nothing used up), and gentle buffs.

## Wider world (M6-M8, M10)
- ☐ Wildlife: creatures move away when you run, and come closer when you stand still (more easily in Gentle, slower in Playful). Sketching and treats work, and friendship gifts arrive.
- ☐ Gloom: the desaturated veil looks right at day and at night. The Bright Lantern and a Luma Bloom both clear it. Thorns melt.
- ☐ Gloomlings: all three choices comfort them; the path behind is free afterwards.
- ☐ The fox kits follow through doors and travel, and run home at the den.
- ☐ Lighthouse restoration, and the beam at night.
- ☐ Boat trips to both isles and back. The shipwreck signal puzzle with the captain's log, the lever and hints.
- ☐ Farming over several in-game days: watering, rain, regrowing strawberries, harvests. The forgotten garden.
- ☐ Fishing in every mode: Gentle auto-catch, Balanced and Playful reeling, missing a bite, a full bag. Old Whiskers.
- ☐ Both caves: braziers, blocks, the light bridge, the tuned door and two beam puzzles. Leave and come back (progress is kept). Save inside a cave and load.
- ☐ The mountain pass (rope as a tool), the highlands, the aurora shrine, and the aurora at night.

## Villagers and story (M9)
- ☐ Each villager arrives when the world is restored, lives in a tent, gets a home, and follows the routine (asleep at night).
- ☐ Chat, gifts (loved, liked, other; once per day), deliveries, best-friend presents, and the wardrobe in the Journal.
- ☐ The request board: three at a time; requests never expire.
- ☐ Act 2 starts at the Heart Tree circle. All five Hearthstones can be found in any order.
- ☐ Act 3: set the stones, invite everyone, then the finale cutscene and closing panel. Exploration continues, the Aurora Stag appears, and the epilogue note can be read.

## Audio (M11)
- ☐ **Listen to every music cue.** They are synthesized placeholders; check that nothing is harsh, too loud or clicky at the loop point.
- ☐ Crossfades between regions, the cottage and caves. Walking along a border does not restart the music.
- ☐ The meadow's day and night layers change smoothly at dusk and dawn.
- ☐ "Music with quiet pauses", "Music off", and the separate volume sliders (Music, Ambience, Sound effects, Interface).
- ☐ Ambience per region, and rain sound on rainy days (none indoors).
- ☐ Captions on: important sounds and music changes are shown as text.

## Developer listening checklist (0.4.0)
Do this once with headphones and once with speakers, at the default volumes:
- ☐ **Every cue**, start to end: lumeria_theme, meadow (base, day and night layers), cottage, grove, creek, pinewood, coast, caves, sanctuary, highlands, finale, stinger_restore. Note anything harsh, piercing, muddy or too loud.
- ☐ **Every loop seam:** let each looping cue run past its end at least twice. Listen for clicks, gaps or a jump in reverb.
- ☐ **Crossfades:** walk across region borders, enter and leave the cottage and a cave. Nothing cuts off, and walking back and forth along a border does not restart the music.
- ☐ **Night layers:** stay in the meadow through dusk and dawn. The piano layer replaces the flute gradually.
- ☐ **Stingers:** restore something (a site step, the Heart Tree). The music dips under the stinger and comes back smoothly.
- ☐ **Volume balance:** music against ambience in each region, and sound effects (gathering, crafting, cooking, placing, quest steps, fishing splash and catch) against the music. Nothing should startle.
- ☐ **Footsteps:** grass, a path, a bridge or dock, coast sand, highland snow, a cave, and the cottage floor. They should be barely noticeable, and Settings > Audio > Footsteps off silences them.
- ☐ If rendered files were added: they play instead of the placeholders, and the log no longer warns about placeholders.

## HUD and UI (0.4.0)
- ☐ The HUD feels calm: tracker top-left (it fades while walking), the day arc top-right, the hotbar fades when unused, no key buttons on screen.
- ☐ Key hints: "Sometimes" shows a hint when a control first matters and after about 45 s idle; "Always" keeps a strip; "Never" shows none. Remapped keys are shown.
- ☐ Toasts never cover the player or Lumi (try the cottage, the coast edge and caves). Pickups merge.
- ☐ Rings only on the target (and the 2 nearest in Gentle).
- ☐ Fishing in the world: the bobber and the bar beside the player are readable; large text and high contrast make the bar bigger.
- ☐ Display: windowed / fullscreen / borderless, VSync, UI scale 90-130% (the world stays the same size).

## Visuals and finale (0.4.0)
- ☐ Ground detail, small features (stumps, bird baths, shrines, mushroom rings), fireflies, water mist, stars, needles, snow, gulls and the lighthouse beam look calm and fit each region; nothing flickers or pops in.
- ☐ Village at night: lantern posts and windows glow warmly; the frame rate stays smooth.
- ☐ The Traveler's arm swing, breathing, blink and run puff, and Lumi's trail look natural; with Reduce motion they are calmer and the puff is gone.
- ☐ The finale cinematic: the lines are readable, the credits roll (they fade page by page with Reduce motion), "Hold Esc to skip" works at any moment, and afterwards the world is restored, the festival lanterns stand, and you can walk on.

## Rest spots and breathing (0.4.0)
- ☐ Find a few quiet places: a toast, a bench icon on the map, and the journal page "Quiet places".
- ☐ Sit (E, a click on the seat, gamepad A): the Traveler sits, Lumi curls up, the camera drifts, the HUD fades, the music swells a little. Nothing else happens; there is no timer.
- ☐ Stand up with a movement key, Esc, Shift, the stick, B, Start and the Stand up button.
- ☐ "Watch time pass while resting" on: a sunset passes in a minute or so; off: the clock runs normally.
- ☐ Breathe with Lumi (at a rest spot and from the pause menu): each pace feels even and comfortable; the note is shown; any key stops it; with Reduce motion the glow keeps its size and a line shows the progress. Nothing praises or scores you.

## Input and accessibility (M11)
- ☐ **Gamepad** (not tested with real hardware): move, interact, run, bag, hint, journal (with LB/RB tabs), pause, map, build mode (rotate, store, undo, LB/RB items), fishing (A to reel), and the use-item trigger. All menus can be navigated with the D-pad and A/B.
- ☐ Key remapping: change keys, see a clash warning, restart the game (bindings kept), and reset to defaults.
- ☐ Extra large text, high contrast, reduce motion (slower rain, fog and animations), and weather effects off.
- ☐ Lumi's nudges: "Helpful" in Gentle appears after about 2.5 minutes without progress; "Off" never nudges; H always answers.
- ☐ A keyboard-only playthrough of a full Act 2 activity.

## Language (English and Bahasa Indonesia)
- ☐ Settings > Language switches between English and Bahasa Indonesia at once, from the main menu and from the pause menu; the choice is kept after restarting the game.
- ☐ A native speaker reads the main menu, check-in, How to Play, Data & Privacy, Journal, villagers, quests and results in Indonesian, and notes anything unnatural or unclear.
- ☐ No Indonesian text is cut off or overflows at Normal and Extra large text sizes (prompts, toasts, quest panel, buttons).
- ☐ The stress question and its labels read naturally. The Indonesian wording is a plain translation, not a validated instrument; compare sessions in different languages with care.

## Research flow (Study Mode; the record is unchanged from V1)
- ☐ Consent unticked: nothing is written. Consent ticked: one row is appended to `sessions.csv` with correct values, plus the study files.
- ☐ The default game (not Study Mode) never writes `sessions.csv` or the study files.
- ☐ Data & Privacy: export, open folder, delete. Saves are not affected.

## Performance (record your hardware)
- ☐ Average and minimum FPS while running across regions, in the village at night, and in caves.
- Reference runs on an RTX 3050 Laptop GPU (GL Compatibility):
  - M2 scripted run: average 72.6 FPS, minimum 51;
  - latest capture (after M10): average about 61-68 FPS, minimum 44-51 during scripted running;
  - perf probe (after the M6 culling fix): 65-74 FPS with every system on;
  - perf probe 0.4.0 (after the ground-detail and atmosphere fixes): 61.1 FPS on average over five spots (pinewood 58, the village at night 60), 1% low 37 FPS, worst frame 39 ms.
