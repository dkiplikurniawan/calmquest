class_name CsvCodec
extends RefCounted
## Minimal RFC 4180-style CSV encoding/decoding used by the session data layer.
## Fields containing commas, quotes, line breaks or edge whitespace are quoted,
## and embedded quotes are doubled. Output is readable by pandas.read_csv.

const DELIMITER := ","
const LINE_END := "\n"


static func needs_quoting(field: String) -> bool:
	if field.is_empty():
		return false
	return (
		field.contains(DELIMITER)
		or field.contains("\"")
		or field.contains("\n")
		or field.contains("\r")
		or field.begins_with(" ")
		or field.ends_with(" ")
	)


static func escape_field(field: String) -> String:
	if not needs_quoting(field):
		return field
	return "\"" + field.replace("\"", "\"\"") + "\""


static func encode_row(fields: PackedStringArray) -> String:
	var escaped := PackedStringArray()
	for f in fields:
		escaped.append(escape_field(f))
	return DELIMITER.join(escaped) + LINE_END


## Parses CSV text into rows of fields. Handles quoted fields with embedded
## delimiters, doubled quotes and line breaks. A trailing newline does not
## create an empty final row.
static func parse_text(text: String) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var row := PackedStringArray()
	var field := ""
	var in_quotes := false
	var i := 0
	var n := text.length()
	var row_has_content := false
	while i < n:
		var ch := text[i]
		if in_quotes:
			if ch == "\"":
				if i + 1 < n and text[i + 1] == "\"":
					field += "\""
					i += 1
				else:
					in_quotes = false
			else:
				field += ch
		else:
			if ch == "\"":
				in_quotes = true
				row_has_content = true
			elif ch == DELIMITER:
				row.append(field)
				field = ""
				row_has_content = true
			elif ch == "\r":
				pass
			elif ch == "\n":
				row.append(field)
				rows.append(row)
				row = PackedStringArray()
				field = ""
				row_has_content = false
			else:
				field += ch
				row_has_content = true
		i += 1
	if row_has_content or not field.is_empty() or not row.is_empty():
		row.append(field)
		rows.append(row)
	return rows
