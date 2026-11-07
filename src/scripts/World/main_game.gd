# src/scripts/World/main_game.gd
# Purpose: Puts the boy on the current place's spawn point.

extends Node

const HOME_AREA: Rect2 = Rect2(-630, -510, 1260, 1020)

@onready var player: Player = $World/Player

func _ready() -> void:
	_add_arabic_fallback()
	var tint: CanvasModulate = CanvasModulate.new()
	tint.name = "NightTint"
	add_child(tint)
	var notices: PhoneNotices = PhoneNotices.new()
	notices.name = "PhoneNotices"
	get_node("Systems").add_child(notices)
	var save: SaveGame = get_node("Systems/SaveGame") as SaveGame
	var loaded: bool = save.load_game()
	if loaded:
		save.catch_up()
	var farm: FarmField = get_node("Systems/FarmField") as FarmField
	var stead: Stead = get_node_or_null("Systems/Stead") as Stead
	if stead != null:
		Locale.language = stead.language
		stead.apply_buildings()
	farm.apply()
	var bank: SoundBank = get_node("Systems/SoundBank") as SoundBank
	bank.apply_levels()
	if TitleMenu.show_intro:
		TitleMenu.show_intro = false
		(get_node("UI/Dialogue") as DialogueBox).open_lines(_intro_lines())
	if loaded and stead != null and stead.place_name != "Home" and stead.scene_for(stead.place_name) != "":
		var loader: LevelLoader = get_node("Systems/LevelLoader") as LevelLoader
		var destination: PackedScene = load(stead.scene_for(stead.place_name)) as PackedScene
		if destination != null:
			loader.go_to(destination, "PlayerSpawn")
			return
	player.fit_camera()
	if loaded and save.has_position and HOME_AREA.has_point(save.saved_position):
		player.global_position = save.saved_position
	else:
		var spawn: Marker2D = _find_spawn()
		if spawn:
			player.global_position = spawn.global_position

## The default font has no Arabic letters on every phone, so the bundled Naskh font fills them in.
func _add_arabic_fallback() -> void:
	var base: Font = ThemeDB.fallback_font
	var naskh: Font = load(Locale.FONT_PATH) as Font if ResourceLoader.exists(Locale.FONT_PATH) else null
	if base == null or naskh == null or base.fallbacks.has(naskh):
		return
	var chain: Array[Font] = base.fallbacks.duplicate()
	chain.append(naskh)
	base.fallbacks = chain

func _intro_lines() -> PackedStringArray:
	return PackedStringArray([Locale.t("intro_1"), Locale.t("intro_2"), Locale.t("help_clear"), Locale.t("help_farm"), Locale.t("help_rest")])

func _find_spawn() -> Marker2D:
	var world: Node = get_node("World")
	for place: Node in world.get_children():
		var found: Node = place.get_node_or_null("PlayerSpawn")
		if found is Marker2D:
			return found
	return null
