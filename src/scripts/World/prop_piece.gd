# src/scripts/World/prop_piece.gd
# Purpose: Adds one picture to a place from a small data row, for projects and house decorations.

class_name PropPiece
extends RefCounted

const MARK: Script = preload("res://src/scripts/World/spot_mark.gd")

static func add_to(place: Node, piece: Dictionary) -> void:
	var picture: Texture2D = piece.get("texture") as Texture2D
	if picture == null:
		picture = load(str(piece["path"])) as Texture2D
	if picture == null:
		return
	if bool(piece.get("flat", false)):
		var mat: Sprite2D = Sprite2D.new()
		mat.name = str(piece["name"])
		mat.texture = picture
		mat.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		mat.region_enabled = true
		mat.region_rect = Rect2(Vector2.ZERO, piece.get("size", picture.get_size()))
		mat.position = piece["at"]
		place.add_child(mat)
		return
	var mark: Node2D = MARK.new() as Node2D
	mark.name = str(piece["name"])
	mark.position = piece["at"]
	mark.set("person", picture)
	mark.set("stand_on_feet", not bool(piece.get("centered", false)))
	mark.set("fit_pixels", int(piece.get("fit", 0)))
	mark.set("group_name", str(piece.get("group", "")))
	mark.set("block_size", piece.get("block", Vector2.ZERO))
	place.add_child(mark)
