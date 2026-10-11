class_name L
extends RefCounted
## Localization (English source text, Indonesian translation).
##
## English is the source language: every player-facing string is written in
## English in the code and data, and the Indonesian catalog
## (game/data/i18n/id/*.json, {"English": "Bahasa Indonesia"}) maps it.
## - Controls (Label, Button, CheckBox, tabs) translate their text
##   automatically when it matches a catalog entry exactly.
## - Composed text uses L.t() on the template before formatting, e.g.
##   L.t("Talk to %s") % name, and data getters (item names, quests...)
##   return translated text.
## Missing entries simply stay in English. The language is a setting
## (GameSettings.language) and can be changed at any time.

const LANGUAGES := {"en": "English", "id": "Bahasa Indonesia"}
const ORDER: PackedStringArray = ["en", "id"]
const CATALOG_DIR := "res://game/data/i18n"

static var _registered: Dictionary = {}
static var load_errors: PackedStringArray = []


## Translates one string (unchanged if there is no translation).
static func t(text: String) -> String:
	if text.is_empty():
		return text
	return String(TranslationServer.translate(text))


## Translates every string in an array.
static func each(texts: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for s in texts:
		out.append(t(String(s)))
	return out


static func current() -> String:
	var loc := TranslationServer.get_locale()
	return "id" if loc.begins_with("id") else "en"


## Loads the catalog for a language (once) and switches to it.
static func set_language(code: String) -> void:
	if not LANGUAGES.has(code):
		code = "en"
	if code != "en":
		_ensure_catalog(code)
	TranslationServer.set_locale(code)


## The catalog as a dictionary (used by tests and tools).
static func catalog(code: String) -> Dictionary:
	var out := {}
	var dir_path := "%s/%s" % [CATALOG_DIR, code]
	var dir := DirAccess.open(dir_path)
	if dir == null:
		load_errors.append("Missing catalog folder %s" % dir_path)
		return out
	var files := dir.get_files()
	files.sort()
	for f in files:
		if not f.ends_with(".json"):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(f)))
		if typeof(parsed) != TYPE_DICTIONARY:
			load_errors.append("Invalid catalog file %s/%s" % [code, f])
			continue
		for k: String in parsed:
			out[k] = String(parsed[k])
	return out


static func _ensure_catalog(code: String) -> void:
	if _registered.has(code):
		return
	var translation := Translation.new()
	translation.locale = code
	var entries := catalog(code)
	for k: String in entries:
		if not String(entries[k]).is_empty():
			translation.add_message(k, entries[k])
	TranslationServer.add_translation(translation)
	_registered[code] = translation
	for e in load_errors:
		push_error("Locale: " + e)
