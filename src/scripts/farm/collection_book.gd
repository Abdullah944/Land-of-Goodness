# src/scripts/farm/collection_book.gd
# Purpose: The collections book. Four pages of everything the boy can grow, catch, mine or make.
# A thing counts as found the first time it lands in his bag, and stays found after it is sold or used.
# The first time a page is full, he earns a little Khair, once per page.

class_name CollectionBook
extends RefCounted

const PAGES: Array[Dictionary] = [
	{"key": "book_farm", "items": ["turnips", "tomatoes", "wheat", "watermelons", "eggs", "milk", "wool"]},
	{"key": "book_sea", "items": ["fish", "pearl", "wood", "dates", "forage"]},
	{"key": "book_cave", "items": ["stone", "copper", "iron"]},
	{"key": "book_made", "items": ["feed", "sprinkler", "toy_dhow"]},
]
const PAGE_REWARD: int = 3

static func all_items() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for page: Dictionary in PAGES:
		for item_id: String in page["items"]:
			ids.append(item_id)
	return ids

static func has_item(item_id: String) -> bool:
	return item_id in all_items()

static func total() -> int:
	return all_items().size()

static func found_on(page: Dictionary, found: Dictionary) -> int:
	var count: int = 0
	for item_id: String in page["items"]:
		if found.has(item_id):
			count += 1
	return count

static func found_total(found: Dictionary) -> int:
	var count: int = 0
	for page: Dictionary in PAGES:
		count += found_on(page, found)
	return count

static func page_full(page: Dictionary, found: Dictionary) -> bool:
	return found_on(page, found) == (page["items"] as Array).size()

## The pages that are full but not yet rewarded, by key.
static func unpaid_full(found: Dictionary, paid: Dictionary) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for page: Dictionary in PAGES:
		var key: String = str(page["key"])
		if not paid.has(key) and page_full(page, found):
			keys.append(key)
	return keys
