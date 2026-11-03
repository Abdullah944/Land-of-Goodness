# tools/hd_cut.gd
# Purpose: Cuts a SpriteCook sheet laid out on an even grid into one picture per cell, trimmed to what is drawn.
# Run: Godot --headless --path . --script tools/hd_cut.gd -- <sheet.png> <columns> <rows> <out_dir> <name,name,...>
# A name of "-" skips that cell. Each printed line gives the piece's size and where it sat on the sheet. Each cell's soft background speckles below a small alpha are cleared.

extends SceneTree

const FAINT: float = 0.08

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 5:
		push_error("sheet columns rows out_dir names")
		quit(1)
		return
	var sheet: Image = Image.load_from_file(args[0])
	sheet.convert(Image.FORMAT_RGBA8)
	var columns: int = int(args[1])
	var rows: int = int(args[2])
	var names: PackedStringArray = args[4].split(",")
	var cell: Vector2 = Vector2(sheet.get_width() / float(columns), sheet.get_height() / float(rows))
	_clear_faint(sheet)
	var owner: PackedInt32Array = _owners(sheet, cell, columns)
	DirAccess.make_dir_recursive_absolute(args[3])
	for i: int in mini(names.size(), columns * rows):
		if names[i] == "-":
			continue
		var part: Image = Image.create(sheet.get_width(), sheet.get_height(), false, Image.FORMAT_RGBA8)
		for at: int in owner.size():
			if owner[at] == i:
				var x: int = at % sheet.get_width()
				var y: int = at / sheet.get_width()
				part.set_pixel(x, y, sheet.get_pixel(x, y))
		var used: Rect2i = part.get_used_rect()
		if used.size == Vector2i.ZERO:
			print("EMPTY ", names[i])
			continue
		part = part.get_region(used)
		part.save_png(args[3].path_join(names[i] + ".png"))
		print("%s %dx%d at %d,%d" % [names[i], part.get_width(), part.get_height(), used.position.x, used.position.y])
	quit(0)

## Finds each drawn blob and gives it to the cell its middle sits in, so a wide tree reaching
## over a grid line still comes out whole. Returns the cell number for every pixel, or -1.
func _owners(sheet: Image, cell: Vector2, columns: int) -> PackedInt32Array:
	var width: int = sheet.get_width()
	var height: int = sheet.get_height()
	var owner: PackedInt32Array = PackedInt32Array()
	owner.resize(width * height)
	owner.fill(-2)
	for start: int in owner.size():
		if owner[start] != -2:
			continue
		if sheet.get_pixel(start % width, start / width).a == 0.0:
			owner[start] = -1
			continue
		var blob: PackedInt32Array = PackedInt32Array([start])
		owner[start] = -3
		var reach: int = 0
		var box: Rect2i = Rect2i(start % width, start / width, 1, 1)
		while reach < blob.size():
			var at: int = blob[reach]
			reach += 1
			var x: int = at % width
			var y: int = at / width
			box = box.expand(Vector2i(x, y))
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var nx: int = x + dx
					var ny: int = y + dy
					if nx < 0 or ny < 0 or nx >= width or ny >= height:
						continue
					var near: int = ny * width + nx
					if owner[near] == -2 and sheet.get_pixel(nx, ny).a > 0.0:
						owner[near] = -3
						blob.append(near)
		var middle: Vector2 = Vector2(box.get_center())
		var cell_id: int = int(middle.y / cell.y) * columns + int(middle.x / cell.x)
		if blob.size() < 30:
			cell_id = -1
		for at: int in blob:
			owner[at] = cell_id
	return owner

func _clear_faint(part: Image) -> void:
	for y: int in part.get_height():
		for x: int in part.get_width():
			if part.get_pixel(x, y).a < FAINT:
				part.set_pixel(x, y, Color(0, 0, 0, 0))
