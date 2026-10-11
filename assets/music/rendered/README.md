# Rendered music

This folder is **empty on purpose**. Real renders of the MIDI scores (for example made with MuseScore 4 by `tools/music/render_music.py`) go here as `<cue>.ogg` or `<cue>.wav`, using the same cue names as `assets/music/placeholder/`.

`MusicManager` plays a file from this folder when one exists, and the synthesized placeholder otherwise (with one warning per run). No code change is needed. See `docs/MUSIC_PIPELINE.md`, and record the sound library and its licence in `docs/ASSET_PROVENANCE.md` before adding files.
