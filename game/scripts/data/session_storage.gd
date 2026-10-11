class_name SessionStorage
extends RefCounted
## Local CSV persistence for consented session records.
##
## * Only ever writes to its own file (default user://sessions.csv) or to an
##   export destination the player picked explicitly.
## * Refuses to append to a file whose header does not match the current schema,
##   so an unrelated or older file is never silently modified.
## * Every operation returns {"ok": bool, "message": String, ...} and only reports
##   success after verifying the bytes were written.
## No data ever leaves the device: there is no network code in this project.

const DEFAULT_PATH := "user://sessions.csv"
const EXPORT_EXTENSION := "csv"
const EXPORT_FILENAME_PREFIX := "calmquest_sessions_export_"

var path: String


func _init(file_path: String = DEFAULT_PATH) -> void:
	path = file_path


static func header_line() -> String:
	return CsvCodec.encode_row(SessionRecord.COLUMNS)


static func suggested_export_filename() -> String:
	var stamp := Time.get_datetime_string_from_system(false, false).replace(":", "").replace("-", "").replace("T", "_")
	return EXPORT_FILENAME_PREFIX + stamp + "." + EXPORT_EXTENSION


func exists() -> bool:
	return FileAccess.file_exists(path)


func get_absolute_path() -> String:
	return ProjectSettings.globalize_path(path)


## Appends one validated record. Creates the file (with header) when needed.
func append_record(record: SessionRecord) -> Dictionary:
	var problems := record.validate()
	if not problems.is_empty():
		return _result(false, L.t("The session record was not saved because it failed validation: %s.") % "; ".join(problems))

	var dir_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var mk_err := DirAccess.make_dir_recursive_absolute(dir_path)
		if mk_err != OK:
			return _result(false, L.t("Could not create the data folder (%s).") % error_string(mk_err))

	var line := CsvCodec.encode_row(record.to_row())
	var existing_text := ""
	if exists():
		existing_text = FileAccess.get_file_as_string(path)
		var read_err := FileAccess.get_open_error()
		if read_err != OK:
			return _result(false, L.t("Could not read the existing session file (%s). Nothing was written.") % error_string(read_err))

	var payload := ""
	if existing_text.is_empty():
		payload = header_line() + line
	else:
		var header_check := _check_header_text(existing_text)
		if not header_check["ok"]:
			return header_check
		if not existing_text.ends_with("\n"):
			payload = "\n"
		payload += line

	var mode := FileAccess.READ_WRITE if not existing_text.is_empty() else FileAccess.WRITE
	var file := FileAccess.open(path, mode)
	if file == null:
		return _result(false, L.t("Could not open the session file for writing (%s). Nothing was saved.") % error_string(FileAccess.get_open_error()))
	var length_before := file.get_length()
	file.seek_end()
	file.store_string(payload)
	file.flush()
	var write_err := file.get_error()
	var length_after := file.get_length()
	file.close()

	var expected := length_before + payload.to_utf8_buffer().size()
	if write_err != OK or length_after != expected:
		return _result(false, L.t("Writing the session record failed (%s). The record may be incomplete.") % error_string(write_err))
	return _result(true, "Session saved on this device.")


## Returns {"ok", "message", "rows": Array[Dictionary]} with one dictionary per record.
func read_rows() -> Dictionary:
	if not exists():
		var empty := _result(true, "No local session records yet.")
		empty["rows"] = []
		return empty
	var text := FileAccess.get_file_as_string(path)
	var read_err := FileAccess.get_open_error()
	if read_err != OK:
		var failed := _result(false, L.t("Could not read the session file (%s).") % error_string(read_err))
		failed["rows"] = []
		return failed
	var header_check := _check_header_text(text)
	if not header_check["ok"]:
		header_check["rows"] = []
		return header_check
	var parsed := CsvCodec.parse_text(text)
	var rows: Array[Dictionary] = []
	for i in range(1, parsed.size()):
		var fields: PackedStringArray = parsed[i]
		if fields.size() != SessionRecord.COLUMNS.size():
			continue
		var row := {}
		for c in SessionRecord.COLUMNS.size():
			row[SessionRecord.COLUMNS[c]] = fields[c]
		rows.append(row)
	var ok := _result(true, L.t("%d session record(s) found.") % rows.size())
	ok["rows"] = rows
	return ok


## Number of stored records, or -1 if the file could not be read.
func count_records() -> int:
	var result := read_rows()
	if not result["ok"]:
		return -1
	return (result["rows"] as Array).size()


## Copies the session file to a destination the player chose. The destination
## must be a .csv file and must not be the source file itself.
func export_to(destination: String) -> Dictionary:
	if not exists():
		return _result(false, "There are no saved session records to export yet.")
	if destination.strip_edges().is_empty():
		return _result(false, "Please choose a file name for the export.")
	if destination.get_extension().to_lower() != EXPORT_EXTENSION:
		return _result(false, "Exports must use the .csv extension.")
	var dest_abs := ProjectSettings.globalize_path(destination).simplify_path()
	if dest_abs.to_lower() == get_absolute_path().simplify_path().to_lower():
		return _result(false, "Choose a different location; the export cannot replace the original data file.")

	var text := FileAccess.get_file_as_string(path)
	var read_err := FileAccess.get_open_error()
	if read_err != OK:
		return _result(false, L.t("Could not read the session file (%s).") % error_string(read_err))
	var header_check := _check_header_text(text)
	if not header_check["ok"]:
		return header_check

	var out := FileAccess.open(destination, FileAccess.WRITE)
	if out == null:
		return _result(false, L.t("Could not write to the chosen location (%s).") % error_string(FileAccess.get_open_error()))
	out.store_string(text)
	out.flush()
	var write_err := out.get_error()
	var written := out.get_length()
	out.close()
	if write_err != OK or written != text.to_utf8_buffer().size():
		return _result(false, L.t("The export did not complete (%s).") % error_string(write_err))
	var done := _result(true, L.t("Exported to %s") % dest_abs)
	done["path"] = dest_abs
	return done


## Permanently deletes the local session file.
func delete_all() -> Dictionary:
	if not exists():
		return _result(true, "There is no local session data to delete.")
	var err := DirAccess.remove_absolute(get_absolute_path())
	if err != OK or exists():
		return _result(false, L.t("Could not delete the session file (%s).") % error_string(err))
	return _result(true, "All local session records were deleted.")


func _check_header_text(text: String) -> Dictionary:
	var first_line := text.get_slice("\n", 0).strip_edges(false, true)
	var expected := ",".join(SessionRecord.COLUMNS)
	if first_line != expected:
		return _result(false, L.t("The file at %s does not have the expected CALMQUEST header, so it was left untouched. Export or delete it from Data & Privacy.") % get_absolute_path())
	return _result(true, "Header OK.")


static func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}
