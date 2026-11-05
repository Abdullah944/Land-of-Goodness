# src/scripts/farm/letters.gd
# Purpose: Now and then a villager sends a short letter in the morning, often with a small gift.
# It is read as soon as the boy is up and nothing else is open.

class_name Letters
extends Node

## About one morning in three brings a letter.
const CHANCE: float = 0.33
## person, line key, gift item ("" for none, "season_seeds" for seeds that grow now), amount, seasons ([] for any).
const LETTERS: Array = [
	["jassim", "letter_eggs", "eggs", 2, []],
	["merchant", "letter_seeds", "season_seeds", 3, []],
	["fisherman", "letter_fish", "fish", 1, []],
	["elder", "letter_elder", "dates", 3, []],
	["carpenter", "letter_wood", "wood", 5, []],
	["jassim", "letter_herbs", "forage", 2, ["Spring", "Summer"]],
	["fisherman", "letter_weather", "", 0, []],
	["merchant", "letter_market", "", 0, []],
]
const SHOW_DELAY: float = 1.2

var pending: Dictionary = {}
var _wait: float = 0.0

func on_new_day() -> void:
	var clock: GameClock = get_parent().get_node("Clock") as GameClock
	if clock.day < 2 or randf() >= CHANCE:
		return
	var choices: Array = []
	for row: Array in LETTERS:
		var seasons: Array = row[4]
		if seasons.is_empty() or seasons.has(clock.season):
			choices.append(row)
	var pick: Array = choices[randi() % choices.size()]
	var item: String = str(pick[2])
	if item == "season_seeds":
		item = _season_seed(clock.season)
	pending = {"person": pick[0], "line": pick[1], "item": item, "amount": int(pick[3])}

func _process(delta: float) -> void:
	if pending.is_empty() or not _free():
		_wait = SHOW_DELAY
		return
	_wait -= delta
	if _wait <= 0.0:
		read()

## Opens the letter, hands over its gift, and forgets it.
func read() -> void:
	if pending.is_empty():
		return
	var letter: Dictionary = pending
	pending = {}
	var person: String = str(letter["person"])
	var who: String = Locale.t(person if person == "jassim" else person + "_name")
	var lines: PackedStringArray = PackedStringArray([Locale.t("letter_from") % who, Locale.t(str(letter["line"]))])
	var item: String = str(letter["item"])
	var amount: int = int(letter["amount"])
	if item != "" and amount > 0:
		(get_parent().get_node("Inventory") as Inventory).add_item(item, amount)
		lines.append(Locale.t("letter_gift") % [amount, Locale.item(item)])
		(get_parent().get_node("Activities") as Activities).pop_item(item, amount)
	var bank: Node = get_parent().get_node_or_null("SoundBank")
	if bank != null:
		bank.call("play", "level")
	Juice.tap(get_tree(), Juice.TAP_FIRM)
	var dialogue: DialogueBox = get_tree().current_scene.get_node("UI/Dialogue") as DialogueBox
	dialogue.set_speaker(person)
	dialogue.open_lines(lines)
	(get_parent().get_node("SaveGame") as SaveGame).write_now()

func to_data() -> Dictionary:
	return {"pending": pending.duplicate()}

func from_data(data: Dictionary) -> void:
	var stored: Variant = data.get("pending", {})
	pending = stored if stored is Dictionary and (stored as Dictionary).has("line") else {}

## Nothing open, nobody busy: the letter will not cover something the player is doing.
func _free() -> bool:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return false
	var player: Player = scene.find_child("Player", true, false) as Player
	if player == null or player.busy:
		return false
	for path: String in ["UI/Dialogue", "UI/FishGame", "UI/Ending"]:
		var box: Node = scene.get_node_or_null(path)
		if box != null and bool(box.get("visible")):
			return false
	var title: Node = scene.get_node_or_null("UI/TitleMenu")
	if title != null and bool(title.call("is_open")):
		return false
	var chest: Node = scene.get_node_or_null("UI/ChestPanel")
	return chest == null or not bool(chest.call("is_open"))

func _season_seed(season: String) -> String:
	for crop_id: String in CropCatalog.ids():
		var crop: Dictionary = CropCatalog.get_crop(crop_id)
		if (crop.get("seasons", []) as Array).has(season):
			return str(crop.get("seed_item", "seeds"))
	return "seeds"
