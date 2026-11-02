# src/scripts/ui/ui_style.gd
# Purpose: One warm look for panels and buttons, and the bubble that shows something can be tapped.

class_name UiStyle
extends RefCounted

const CREAM: Color = Color("fff3dc")
const BEIGE: Color = Color("e7c99a")
const BROWN: Color = Color("7a4f32")
const DARK: Color = Color("3f2d27")
const GOLD: Color = Color("d9a441")
const WOOD_LIGHT: Color = Color("f6cf94")
const WOOD: Color = Color("e8a860")
const WOOD_DARK: Color = Color("8a4a22")

static func box(fill: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(2)
	return style

static func panel(control: Control) -> void:
	control.add_theme_stylebox_override("panel", box(WOOD_LIGHT, WOOD_DARK, 3))

static func button(target: Button) -> void:
	var normal: StyleBoxFlat = box(WOOD, WOOD_DARK, 2)
	target.add_theme_stylebox_override("normal", normal)
	target.add_theme_stylebox_override("hover", normal)
	target.add_theme_stylebox_override("focus", normal)
	target.add_theme_stylebox_override("pressed", box(WOOD_DARK, DARK, 2))
	target.add_theme_color_override("font_color", DARK)
	target.add_theme_color_override("font_hover_color", DARK)
	target.add_theme_color_override("font_focus_color", DARK)
	target.add_theme_color_override("font_pressed_color", CREAM)

static var _glow: Texture2D

## Gives a small sprite the same crisp look as everyone else: hard edges, few colors, and a dark outline.
static func crisp_sprite(source: Image) -> Image:
	var picture: Image = Image.create(source.get_width() + 2, source.get_height() + 2, false, Image.FORMAT_RGBA8)
	var solid: Array[bool] = []
	solid.resize(picture.get_width() * picture.get_height())
	for y: int in source.get_height():
		for x: int in source.get_width():
			var color: Color = source.get_pixel(x, y)
			if color.a < 0.5:
				continue
			var steps: float = 7.0
			picture.set_pixel(x + 1, y + 1, Color(round(color.r * steps) / steps, round(color.g * steps) / steps, round(color.b * steps) / steps, 1.0))
			solid[(y + 1) * picture.get_width() + x + 1] = true
	var outline: Color = Color("2b1b16")
	for y: int in picture.get_height():
		for x: int in picture.get_width():
			if solid[y * picture.get_width() + x]:
				continue
			for near: Vector2i in [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1), Vector2i(x, y + 1)]:
				if near.x >= 0 and near.y >= 0 and near.x < picture.get_width() and near.y < picture.get_height() and solid[near.y * picture.get_width() + near.x]:
					picture.set_pixel(x, y, outline)
					break
	return picture

## One soft round light, shared by every lamp.
static func glow_texture() -> Texture2D:
	if _glow != null:
		return _glow
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var round_light: GradientTexture2D = GradientTexture2D.new()
	round_light.gradient = fade
	round_light.width = 160
	round_light.height = 160
	round_light.fill = GradientTexture2D.FILL_RADIAL
	round_light.fill_from = Vector2(0.5, 0.5)
	round_light.fill_to = Vector2(1.0, 0.5)
	_glow = round_light
	return _glow

## A soft oval on the ground, so people and trees stand on the world instead of floating over it.
static func draw_shadow(canvas: CanvasItem, at: Vector2, width: float) -> void:
	canvas.draw_set_transform(at, 0.0, Vector2(1.0, 0.35))
	canvas.draw_circle(Vector2.ZERO, width * 0.5, Color(0.1, 0.08, 0.05, 0.28))
	canvas.draw_set_transform(Vector2.ZERO)

## The same oval as a node, for sprites that are not drawn by hand.
static func shadow_node(at: Vector2, width: float) -> Polygon2D:
	var oval: PackedVector2Array = PackedVector2Array()
	for i: int in 16:
		var angle: float = TAU * float(i) / 16.0
		oval.append(Vector2(cos(angle) * width * 0.5, sin(angle) * width * 0.175))
	var shadow: Polygon2D = Polygon2D.new()
	shadow.polygon = oval
	shadow.color = Color(0.1, 0.08, 0.05, 0.28)
	shadow.position = at
	shadow.show_behind_parent = true
	return shadow

## A small speech bubble over the boy's head. Touch players tap the person or the thing itself.
static func draw_bubble(canvas: CanvasItem, at: Vector2) -> void:
	canvas.draw_set_transform(at)
	canvas.draw_circle(Vector2.ZERO, 7.0, CREAM)
	canvas.draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 16, GOLD, 1.0)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-3, 5), Vector2(3, 5), Vector2(0, 10)]), CREAM)
	for x: float in [-3.0, 0.0, 3.0]:
		canvas.draw_circle(Vector2(x, 0.0), 1.0, DARK)
	canvas.draw_set_transform(Vector2.ZERO)
