# addons/khair_hd/hd_importer.gd
# Purpose: Imports a painted HD picture with a smaller "game size". Scenes and scripts see the game size,
# so every position stays the same, while the screen draws all the painted detail.
# A picture uses it when its .import file says importer="khair_hd" (tools/hd_swap.gd writes those).

@tool
extends EditorImportPlugin

func _get_importer_name() -> String:
	return "khair_hd"

func _get_visible_name() -> String:
	return "Khair HD Picture"

func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["png"])

func _get_save_extension() -> String:
	return "res"

func _get_resource_type() -> String:
	return "ImageTexture"

func _get_priority() -> float:
	# Lower than Godot's own importer, so plain pictures keep using it.
	return 0.1

func _get_import_order() -> int:
	return 0

func _get_preset_count() -> int:
	return 1

func _get_preset_name(_preset_index: int) -> String:
	return "Default"

func _get_import_options(_path: String, _preset_index: int) -> Array[Dictionary]:
	return [{"name": "game_size", "default_value": Vector2.ZERO}]

func _get_option_visibility(_path: String, _option_name: StringName, _options: Dictionary) -> bool:
	return true

func _can_import_threaded() -> bool:
	return false

func _import(source_file: String, save_path: String, options: Dictionary, _platform_variants: Array[String], _gen_files: Array[String]) -> Error:
	var image: Image = Image.new()
	if image.load(ProjectSettings.globalize_path(source_file)) != OK or image.is_empty():
		return ERR_FILE_CORRUPT
	image.convert(Image.FORMAT_RGBA8)
	image.fix_alpha_edges()
	image.generate_mipmaps()
	var stored: PortableCompressedTexture2D = PortableCompressedTexture2D.new()
	stored.keep_compressed_buffer = true
	stored.create_from_image(image, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
	var size: Vector2 = options.get("game_size", Vector2.ZERO)
	if size.x <= 0.0 or size.y <= 0.0:
		size = Vector2(image.get_size())
	HdPicture.saving = true
	var picture: HdPicture = HdPicture.new()
	picture.game_size = size
	picture.source = stored
	var result: Error = ResourceSaver.save(picture, "%s.%s" % [save_path, _get_save_extension()])
	HdPicture.saving = false
	return result
