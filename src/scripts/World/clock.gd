# src/scripts/World/clock.gd
# Purpose: Moves the day forward and tells the field when morning comes.

class_name GameClock
extends Node

const SEASONS: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]
const NIGHT_COLOR: Color = Color(0.36, 0.42, 0.68)
const RAIN_LIGHT: Color = Color(0.68, 0.72, 0.8)
const SEASON_LIGHT: Dictionary = {"Spring": Color.WHITE, "Summer": Color(1.0, 0.98, 0.9), "Autumn": Color(1.0, 0.93, 0.82), "Winter": Color(0.96, 0.97, 1.0)}

var day: int = 1
var minute: float = 6.0 * 60.0
var season: String = "Spring"
var weather: String = "Clear"
## Tomorrow's weather is known a day ahead, so the morning can tell it.
var next_weather: String = "Clear"
## The low sun turns the light warm before dusk.
const EVENING_COLOR: Color = Color(1.0, 0.72, 0.48)

func _process(delta: float) -> void:
	if not held_by_ui():
		# Stardew on iPhone: ten game minutes take about seven real seconds.
		minute += delta * (10.0 / 7.0)
	if minute >= 26.0 * 60.0:
		_begin_morning(true)
	_paint_sky()
	var hud: Node = get_tree().current_scene.get_node_or_null("UI/HUD")
	if hud != null and hud.has_method("refresh"):
		hud.refresh()

func sleep_now() -> void:
	_begin_morning()

## True while the player is reading a talk box or sorting the chest.
func held_by_ui() -> bool:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return false
	var dialogue: Node = scene.get_node_or_null("UI/Dialogue")
	if dialogue != null and bool(dialogue.get("visible")):
		return true
	var fishing: Node = scene.get_node_or_null("UI/FishGame")
	if fishing != null and bool(fishing.get("visible")):
		return true
	var chest: Node = scene.get_node_or_null("UI/ChestPanel")
	return chest != null and bool(chest.call("is_open"))

func _begin_morning(stayed_up: bool = false) -> void:
	var old_season: String = season
	minute = 6.0 * 60.0
	day += 1
	season = SEASONS[int(float(day) / 7.0) % SEASONS.size()]
	weather = next_weather
	next_weather = "Rain" if randf() < 0.25 else "Clear"
	var farm: FarmField = get_parent().get_node("FarmField") as FarmField
	farm.advance_day(season, weather == "Rain")
	var activities: Activities = get_parent().get_node("Activities") as Activities
	activities.on_new_day()
	var kindness: Kindness = get_parent().get_node_or_null("Kindness") as Kindness
	if kindness != null:
		kindness.on_new_day()
	var friends: Friendship = get_parent().get_node_or_null("Friendship") as Friendship
	if friends != null:
		friends.on_new_day()
	var letters: Letters = get_parent().get_node_or_null("Letters") as Letters
	if letters != null:
		letters.on_new_day()
	var stead: Stead = get_parent().get_node_or_null("Stead") as Stead
	if stead != null:
		var morning: String = stead.on_new_day()
		if morning != "":
			activities.note = morning
		if stead.check_milestone():
			activities.note = Locale.t("milestone")
	if season != old_season:
		activities.note = Locale.t("season_" + season.to_lower())
		var bank: SoundBank = get_parent().get_node_or_null("SoundBank") as SoundBank
		if bank != null:
			bank.apply_levels()
	elif stayed_up:
		activities.note = Locale.t("stayed_up")
	var fairs: Festivals = get_parent().get_node_or_null("Festivals") as Festivals
	if fairs != null and fairs.morning_note() != "" and season == old_season:
		activities.note = fairs.morning_note()
	var bag: Inventory = get_parent().get_node("Inventory") as Inventory
	bag.refill_hearts()
	var save: SaveGame = get_parent().get_node("SaveGame") as SaveGame
	save.write_now()
	var works: VillageWorks = get_parent().get_node_or_null("VillageWorks") as VillageWorks
	var ending: Node = get_tree().current_scene.get_node_or_null("UI/Ending") if get_tree().current_scene != null else null
	if works != null and ending != null and works.festival_ready():
		ending.call_deferred("play")

func hour_text() -> String:
	var hour: int = int(minute / 60.0) % 24
	var mins: int = int((int(minute) % 60) / 10.0) * 10
	var suffix: String = Locale.t("am") if hour < 12 else Locale.t("pm")
	var shown_hour: int = hour % 12
	if shown_hour == 0:
		shown_hour = 12
	# Isolated left-to-right so Arabic text keeps "6:00" in reading order.
	return "\u2066%d:%02d\u2069 %s" % [shown_hour, mins, suffix]

func to_data() -> Dictionary:
	return {"day": day, "minute": minute, "season": season, "weather": weather, "next_weather": next_weather}

func from_data(data: Dictionary) -> void:
	day = maxi(1, int(data.get("day", 1)))
	minute = clampf(float(data.get("minute", 6.0 * 60.0)), 6.0 * 60.0, 26.0 * 60.0 - 1.0)
	season = str(data.get("season", "Spring"))
	if not season in SEASONS:
		season = SEASONS[int(float(day) / 7.0) % SEASONS.size()]
	weather = "Rain" if str(data.get("weather", "Clear")) == "Rain" else "Clear"
	next_weather = "Rain" if str(data.get("next_weather", "Clear")) == "Rain" else "Clear"

## "Tomorrow: rain" for the morning note and the quests page.
func forecast_text() -> String:
	return Locale.t("forecast") % Locale.t("weather_" + next_weather.to_lower())

func _paint_sky() -> void:
	var hud: Node = get_tree().current_scene.get_node_or_null("UI/HUD")
	if hud == null:
		return
	var rain: CanvasItem = hud.get_node_or_null("Rain") as CanvasItem
	var hour: float = minute / 60.0
	var darkness: float = 0.0
	if hour >= 17.0 and hour < 20.0:
		darkness = lerpf(0.0, 1.0, (hour - 17.0) / 3.0)
	elif hour >= 20.0 or hour < 6.0:
		darkness = 1.0
	elif hour < 7.0:
		darkness = lerpf(0.35, 0.0, hour - 6.0)
	# From four in the afternoon the light warms, and the warm light then fades into the night blue.
	var warm: float = 0.0
	if hour >= 16.0 and hour < 18.0:
		warm = (hour - 16.0) / 2.0
	elif hour >= 18.0 and hour < 20.0:
		warm = 1.0 - (hour - 18.0) / 2.0
	elif hour >= 6.0 and hour < 7.0:
		warm = 0.5 * (7.0 - hour)
	var day_light: Color = SEASON_LIGHT.get(season, Color.WHITE).lerp(EVENING_COLOR, warm * (0.4 if weather == "Rain" else 1.0))
	# A rainy day is grey and darker, so the rain reads at a glance.
	if weather == "Rain":
		day_light = day_light.lerp(RAIN_LIGHT, 0.7)
	var tint: CanvasModulate = get_tree().current_scene.get_node_or_null("NightTint") as CanvasModulate
	if tint != null:
		tint.color = day_light.lerp(NIGHT_COLOR, darkness)
	var lamps_on: bool = darkness > 0.25
	for light: Node in get_tree().get_nodes_in_group("night_light"):
		if bool(light.get("enabled")) != lamps_on:
			light.set("enabled", lamps_on)
	if rain != null:
		rain.visible = weather == "Rain"
