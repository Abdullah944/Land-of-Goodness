# src/scripts/data/quran_text.gd
# Purpose: The list of the 114 suras (number, verse count, Arabic and English names), read from the Tanzil
# sura list in assets/quran/. The game plays the Quran as recitation only; it shows no Quran text.
# Sura list: Tanzil Quran Metadata, Tanzil Project, https://tanzil.net

class_name QuranText
extends RefCounted

const DATA_PATH: String = "res://assets/quran/quran-data.xml"
const SURA_COUNT: int = 114
const AYA_COUNT: int = 6236

static var _suras: Array[Dictionary] = []

## Every sura, in order: {index, ayas, name (Arabic), tname (English letters), ename (English meaning)}.
static func suras() -> Array[Dictionary]:
	if _suras.is_empty():
		_read_suras()
	return _suras

static func sura(index: int) -> Dictionary:
	var all: Array[Dictionary] = suras()
	return all[index - 1] if index >= 1 and index <= all.size() else {}

static func total_verses() -> int:
	var count: int = 0
	for info: Dictionary in suras():
		count += int(info["ayas"])
	return count

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
