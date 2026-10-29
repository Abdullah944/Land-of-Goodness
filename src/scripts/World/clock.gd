# src/scripts/World/clock.gd
# Purpose: Moves the day forward and tells the field when morning comes.

class_name GameClock
extends Node

const SEASONS: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]

var day: int = 1
var minute: float = 6.0 * 60.0
var season: String = "Spring"
var weather: String = "Clear"

func _process(delta: float) -> void:
	# Stardew on iPhone: ten game minutes take about seven real seconds.
	minute += delta * (10.0 / 7.0)
	if minute >= 26.0 * 60.0:
		_begin_morning()
	_paint_sky()
	var hud: Node = get_tree().current_scene.get_node_or_null("UI/HUD")
	if hud != null and hud.has_method("refresh"):
		hud.refresh()

func sleep_now() -> void:
	_begin_morning()

func _begin_morning() -> void:
	minute = 6.0 * 60.0
	day += 1
	season = SEASONS[(day / 7) % SEASONS.size()]
	weather = "Rain" if randf() < 0.25 else "Clear"
	var farm: FarmField = get_parent().get_node("FarmField") as FarmField
	farm.advance_day(season, weather == "Rain")
	var activities: Activities = get_parent().get_node("Activities") as Activities
	activities.on_new_day()
	var bag: Inventory = get_parent().get_node("Inventory") as Inventory
	bag.refill_hearts()
	var save: SaveGame = get_parent().get_node("SaveGame") as SaveGame
	save.write_now()

func hour_text() -> String:
	var hour: int = int(minute / 60.0) % 24
	var mins: int = (int(minute) % 60) / 10 * 10
	var suffix: String = "am" if hour < 12 else "pm"
	var shown_hour: int = hour % 12
	if shown_hour == 0:
		shown_hour = 12
	return "%d:%02d %s" % [shown_hour, mins, suffix]

func to_data() -> Dictionary:
	return {"day": day, "minute": minute, "season": season, "weather": weather}

func from_data(data: Dictionary) -> void:
	day = int(data.get("day", 1))
	minute = float(data.get("minute", 6.0 * 60.0))
	season = str(data.get("season", "Spring"))
	weather = str(data.get("weather", "Clear"))

func _paint_sky() -> void:
	var hud: Node = get_tree().current_scene.get_node_or_null("UI/HUD")
	if hud == null:
		return
	var night: CanvasItem = hud.get_node_or_null("Night") as CanvasItem
	var rain: CanvasItem = hud.get_node_or_null("Rain") as CanvasItem
	if night != null:
		var darkness: float = 0.0
		var hour: float = minute / 60.0
		if hour >= 12.0 and hour < 17.0:
			darkness = 0.18
		elif hour >= 17.0 and hour < 20.0:
			darkness = lerpf(0.25, 0.62, (hour - 17.0) / 3.0)
		elif hour >= 20.0 or hour < 6.0:
			darkness = 0.68
		elif hour < 7.0:
			darkness = 0.28
		night.modulate.a = darkness
		night.visible = darkness > 0.0
	if rain != null:
		rain.visible = weather == "Rain"
