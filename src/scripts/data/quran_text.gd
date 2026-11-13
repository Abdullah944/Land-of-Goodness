# src/scripts/data/quran_text.gd
# Purpose: Reads the Quran text and the list of suras from the Tanzil files in assets/quran/.
# The files are kept exactly as Tanzil gives them (with their copyright notice); nothing in them is changed.
# Text: Tanzil Quran Text (Uthmani, Version 1.1), Tanzil Project, https://tanzil.net

class_name QuranText
extends RefCounted

const TEXT_PATH: String = "res://assets/quran/quran-uthmani.txt"
const DATA_PATH: String = "res://assets/quran/quran-data.xml"
const SURA_COUNT: int = 114
const AYA_COUNT: int = 6236

static var _verses: Dictionary = {}
static var _suras: Array[Dictionary] = []

## Every sura, in order: {index, ayas, name (Arabic), tname (English letters), ename (English meaning)}.
static func suras() -> Array[Dictionary]:
	if _suras.is_empty():
		_read_suras()
	return _suras

static func sura(index: int) -> Dictionary:
	var all: Array[Dictionary] = suras()
	return all[index - 1] if index >= 1 and index <= all.size() else {}

## The verses of one sura, verse 1 first, exactly as in the text file.
static func verses(index: int) -> PackedStringArray:
	if _verses.is_empty():
		_read_text()
	return _verses.get(index, PackedStringArray())

## True when the reader shows the basmala as a heading above the verses: every sura but At-Tawba,
## which has none, and Al-Fatiha, where it is verse 1 itself.
static func has_basmala(index: int) -> bool:
	return index != 9 and index != 1

## The basmala, taken from the text itself (verse 1 of Al-Fatiha), so it matches letter for letter.
## Tanzil writes it at the start of verse 1 of every other sura but At-Tawba; the reader shows it as a heading.
static func basmala() -> String:
	return verses(1)[0] if not verses(1).is_empty() else ""

## A verse as the reader shows it: the basmala that opens verse 1 is shown as the heading instead.
static func shown_verse(index: int, number: int) -> String:
	var line: String = verses(index)[number - 1]
	if number != 1 or index == 1 or index == 9:
		return line
	# The basmala is the first four words. In two suras (95 and 97) its first word carries a shadda
	# (بِّسْمِ), so the first word is matched by its letter and the other three words exactly.
	var words: PackedStringArray = line.split(" ", false, 4)
	var expected: PackedStringArray = basmala().split(" ", false)
	if words.size() == 5 and expected.size() == 4 and words[0].begins_with("ب") \
			and words[1] == expected[1] and words[2] == expected[2] and words[3] == expected[3]:
		return words[4]
	return line

## Verse numbers in Arabic-Indic digits, as in a printed mushaf.
static func arabic_number(value: int) -> String:
	var digits: String = "٠١٢٣٤٥٦٧٨٩"
	var out: String = ""
	for ch: String in str(value):
		out += digits[int(ch)]
	return out

static func total_verses() -> int:
	if _verses.is_empty():
		_read_text()
	var count: int = 0
	for index: int in _verses:
		count += (_verses[index] as PackedStringArray).size()
	return count

static func _read_text() -> void:
	var file: FileAccess = FileAccess.open(TEXT_PATH, FileAccess.READ)
	if file == null:
		return
	# A packed array is copied when taken out of a dictionary, so each sura is collected first and stored once.
	var current: int = 0
	var lines: PackedStringArray = PackedStringArray()
	while not file.eof_reached():
		var line: String = file.get_line()
		if line == "" or line.begins_with("#"):
			continue
		var parts: PackedStringArray = line.split("|", true, 2)
		if parts.size() < 3:
			continue
		var index: int = int(parts[0])
		if index != current:
			if current != 0:
				_verses[current] = lines
			current = index
			lines = PackedStringArray()
		lines.append(parts[2])
	if current != 0:
		_verses[current] = lines

static func _read_suras() -> void:
	var parser: XMLParser = XMLParser.new()
	if parser.open(DATA_PATH) != OK:
		return
	while parser.read() == OK:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT or parser.get_node_name() != "sura":
			continue
		_suras.append({
			"index": int(parser.get_named_attribute_value_safe("index")),
			"ayas": int(parser.get_named_attribute_value_safe("ayas")),
			"name": parser.get_named_attribute_value_safe("name"),
			"tname": parser.get_named_attribute_value_safe("tname"),
			"ename": parser.get_named_attribute_value_safe("ename"),
		})
		if _suras.size() >= SURA_COUNT:
			break
