# tools/hd_swap.gd
# Purpose: Puts painted HD pictures in place of old game pictures while keeping each one's game size.
# Run: Godot --headless --path . --script tools/hd_swap.gd -- <list.json>
# The list holds {"src": "/abs/new.png", "dst": "res://assets/...png"} entries. Optional keys:
#   "size": [w, h]   the game size to use, instead of matching the old picture's longest side
#   "tall": h        the game height to use, keeping the new picture's shape
#   "keep_canvas": true   keep the old canvas size and place the new picture at the bottom middle
#   "max": 1024     the longest side kept in the file

extends SceneTree

const DETAIL: float = 4.0

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Give the list path after --")
		quit(1)
		return
	var list: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not list is Array:
		push_error("The list must be a JSON array")
		quit(1)
		return
	for entry: Dictionary in list:
		_swap(entry)
	quit()

func _swap(entry: Dictionary) -> void:
	var dst: String = str(entry["dst"])
	var fresh: Image = Image.load_from_file(str(entry["src"]))
	fresh.convert(Image.FORMAT_RGBA8)
	var used: Rect2i = fresh.get_used_rect()
	if used.size != Vector2i.ZERO and not bool(entry.get("no_crop", false)):
		fresh = fresh.get_region(used)
	var game: Vector2 = _game_size(entry, dst, Vector2(fresh.get_size()))
	var longest: float = float(entry.get("max", 1024))
	var limit: float = minf(longest, maxf(game.x, game.y) * DETAIL)
	var shrink: float = minf(1.0, limit / float(maxi(fresh.get_width(), fresh.get_height())))
	if shrink < 1.0:
		fresh.resize(maxi(1, int(round(fresh.get_width() * shrink))), maxi(1, int(round(fresh.get_height() * shrink))), Image.INTERPOLATE_LANCZOS)
	if bool(entry.get("keep_canvas", false)) and FileAccess.file_exists(dst):
		var old_size: Vector2 = Vector2(_old_image(dst).get_size())
		var factor: float = float(fresh.get_width()) / game.x
		var canvas: Image = Image.create(int(round(old_size.x * factor)), int(round(old_size.y * factor)), false, Image.FORMAT_RGBA8)
		var at: Vector2i = Vector2i(int((canvas.get_width() - fresh.get_width()) * 0.5), canvas.get_height() - fresh.get_height())
		canvas.blit_rect(fresh, Rect2i(Vector2i.ZERO, fresh.get_size()), at)
		fresh = canvas
		game = old_size
	var path: String = ProjectSettings.globalize_path(dst)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var uid: String = _old_uid(path + ".import")
	fresh.save_png(path)
	var lines: Array[String] = ["[remap]", "", 'importer="khair_hd"', 'type="ImageTexture"']
	if uid != "":
		lines.append('uid="%s"' % uid)
	lines += ["", "[params]", "", "game_size=Vector2(%s, %s)" % [_num(game.x), _num(game.y)], ""]
	var out: FileAccess = FileAccess.open(path + ".import", FileAccess.WRITE)
	out.store_string("\n".join(lines))
	out.close()
	print("%s  game %dx%d  file %dx%d" % [dst, int(game.x), int(game.y), fresh.get_width(), fresh.get_height()])

## The size the game draws the picture at.
func _game_size(entry: Dictionary, dst: String, fresh: Vector2) -> Vector2:
	if entry.has("size"):
		return Vector2(float(entry["size"][0]), float(entry["size"][1]))
	if entry.has("tall"):
		var tall: float = float(entry["tall"])
		return Vector2(round(fresh.x * tall / fresh.y), tall)
	var old: Image = _old_image(dst)
	var reach: float = 64.0
	if old != null:
		var old_used: Rect2i = old.get_used_rect()
		reach = float(maxi(old_used.size.x, old_used.size.y)) if old_used.size != Vector2i.ZERO else float(maxi(old.get_width(), old.get_height()))
		reach /= _old_detail(dst)
	var factor: float = reach / maxf(fresh.x, fresh.y)
	return Vector2(round(fresh.x * factor), round(fresh.y * factor))

## The old picture, as the game drew it before this swap.
func _old_image(dst: String) -> Image:
	var path: String = ProjectSettings.globalize_path(dst)
	if not FileAccess.file_exists(path):
		return null
	return Image.load_from_file(path)

## How many file pixels one game pixel had, when the old picture was already HD.
func _old_detail(dst: String) -> float:
	var text: String = FileAccess.get_file_as_string(ProjectSettings.globalize_path(dst) + ".import")
	var at: int = text.find("game_size=Vector2(")
	if at < 0:
		return 1.0
	var inside: String = text.substr(at + 18, text.find(")", at) - at - 18)
	var game_w: float = float(inside.split(",")[0])
	var file_w: float = float(_old_image(dst).get_width())
	return file_w / game_w if game_w > 0.0 else 1.0

func _old_uid(import_path: String) -> String:
	if not FileAccess.file_exists(import_path):
		return ""
	for line: String in FileAccess.get_file_as_string(import_path).split("\n"):
		if line.begins_with("uid="):
			return line.substr(5, line.length() - 6)
	return ""

func _num(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, round(value)) else "%.2f" % value
