# Fonts

CALMQUEST can use a rounded, open-license (SIL OFL) font for its whole interface. **No font file is included yet**, so the game uses Godot's built-in default font.

To add one (it was not downloaded automatically, on purpose):

1. Download **Nunito** from Google Fonts (https://fonts.google.com/specimen/Nunito) or the official repository (https://github.com/googlefonts/nunito). It is licensed under the SIL Open Font License 1.1.
2. Copy `Nunito-VariableFont_wght.ttf` (or `Nunito-Regular.ttf`) into this folder.
3. Copy the font's `OFL.txt` into this folder as well. The license requires it to travel with the font.
4. Open the project once in Godot so the font is imported, then run `tools/run_checks.ps1`.
5. Record the font and its license in `docs/ASSET_PROVENANCE.md`.

Quicksand (`Quicksand-VariableFont_wght.ttf` or `Quicksand-Regular.ttf`) works too. The game picks the first file it finds, in the order listed in `game/scripts/ui/ui_theme.gd` (`FONT_CANDIDATES`). Nunito and Quicksand both cover the Latin characters used by English and Bahasa Indonesia. Check the screenshots after adding one.
