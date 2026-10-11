class_name CsvFileStore
extends RefCounted
## A small append-only CSV file with a fixed header (used for the Study Mode
## files). It follows the same rules as SessionStorage:
## * the header is written with the first row, and a file whose header does
##   not match is never modified;
## * writes are verified by length before success is reported;
## * every operation returns {"ok": bool, "message": String, ...}.
## Only ever writes to its own path or to an export destination the
## researcher picked. No data leaves the device.

var path: String
var columns: PackedStringArray


func _init(file_path: String, header: PackedStringArray) -> void:
	path = file_path
	columns = header


func exists() -> bool:
	return FileAccess.file_exists(path)


func get_absolute_path() -> String:
	return ProjectSettings.globalize_path(path)


func header_line() -> String:
	return CsvCodec.encode_row(columns)


## Appends one row (the same number of fields as columns).
func append_row(fields: PackedStringArray) -> Dictionary:
	if fields.size() != columns.size():
		return _result(false, "Row has %d fields, expected %d." % [fields.size(), columns.size()])
	var dir_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var mk_err := DirAccess.make_dir_recursive_absolute(dir_path)
		if mk_err != OK:
			return _result(false, L.t("Could not create the data folder (%s).") % error_string(mk_err))
	var line := CsvCodec.encode_row(fields)
	var existing := ""
	if exists():
		existing = FileAccess.get_file_as_string(path)
		var read_err := FileAccess.get_open_error()
		if read_err != OK:
			return _result(false, L.t("Could not read the existing session file (%s). Nothing was written.") % error_string(read_err))
	var payload := ""
	if existing.is_empty():
		payload = header_line() + line
	else:
		var check := _check_header(existing)
		if not check["ok"]:
			return check
		if not existing.ends_with("\n"):
			payload = "\n"
		payload += line
	var file := FileAccess.open(path, FileAccess.READ_WRITE if not existing.is_empty() else FileAccess.WRITE)
	if file == null:
		return _result(false, L.t("Could not open the session file for writing (%s). Nothing was saved.") % error_string(FileAccess.get_open_error()))
	var length_before := file.get_length()
	file.seek_end()
	file.store_string(payload)
	file.flush()
	var write_err := file.get_error()
	var length_after := file.get_length()
	file.close()
	if write_err != OK or length_after != length_before + payload.to_utf8_buffer().size():
		return _result(false, L.t("Writing the session record failed (%s). The record may be incomplete.") % error_string(write_err))
	return _result(true, "Saved.")


## Returns {"ok", "message", "rows": Array[Dictionary]}.
func read_rows() -> Dictionary:
	var out := _result(true, "")
	out["rows"] = []
	if not exists():
		return out
	var text := FileAccess.get_file_as_string(path)
	var check := _check_header(text)
	if not check["ok"]:
		check["rows"] = []
		return check
	var parsed := CsvCodec.parse_text(text)
	var rows: Array[Dictionary] = []
	for i in range(1, parsed.size()):
		var fields: PackedStringArray = parsed[i]
		if fields.size() != columns.size():
			continue
		var row := {}
		for c in columns.size():
			row[columns[c]] = fields[c]
		rows.append(row)
	out["rows"] = rows
	return out


## Copies the file to `destination` (must not be the file itself).
func export_to(destination: String) -> Dictionary:
	if not exists():
		return _result(false, "Nothing to export yet.")
	var dest_abs := ProjectSettings.globalize_path(destination).simplify_path()
	if dest_abs.to_lower() == get_absolute_path().simplify_path().to_lower():
		return _result(false, "Choose a different location; the export cannot replace the original data file.")
	var text := FileAccess.get_file_as_string(path)
	var out := FileAccess.open(destination, FileAccess.WRITE)
	if out == null:
		return _result(false, L.t("Could not write to the chosen location (%s).") % error_string(FileAccess.get_open_error()))
	out.store_string(text)
	out.flush()
	var err := out.get_error()
	var written := out.get_length()
	out.close()
	if err != OK or written != text.to_utf8_buffer().size():
		return _result(false, L.t("The export did not complete (%s).") % error_string(err))
	var done := _result(true, L.t("Exported to %s") % dest_abs)
	done["path"] = dest_abs
	return done


func delete_file() -> Dictionary:
	if not exists():
		return _result(true, "")
	var err := DirAccess.remove_absolute(get_absolute_path())
	if err != OK or exists():
		return _result(false, L.t("Could not delete the session file (%s).") % error_string(err))
	return _result(true, "")


func _check_header(text: String) -> Dictionary:
	var first_line := text.get_slice("\n", 0).strip_edges(false, true)
	if first_line != ",".join(columns):
		return _result(false, L.t("The file at %s does not have the expected CALMQUEST header, so it was left untouched. Export or delete it from Data & Privacy.") % get_absolute_path())
	return _result(true, "")


static func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}
