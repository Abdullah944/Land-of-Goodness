# src/scripts/data/quran_audio.gd
# Purpose: Where each sura's recitation comes from and where it is kept on the phone.
# Recitation: Mishary Alafasy, from the Islamic Network audio CDN (alquran.cloud), which allows streaming and
# downloading for personal and educational use and asks apps to keep the files. Each sura is downloaded only
# when the player asks for it, once, and then plays without internet.

class_name QuranAudio
extends RefCounted

const URL: String = "https://cdn.islamic.network/quran/audio-surah/128/ar.alafasy/%d.mp3"
const FOLDER: String = "user://quran_audio/"
## Anything smaller than this is an error page, not a recitation.
const SMALLEST_BYTES: int = 20000

static func url(index: int) -> String:
	return URL % index

static func file_path(index: int) -> String:
	return FOLDER + "alafasy_%03d.mp3" % index

static func part_path(index: int) -> String:
	return file_path(index) + ".part"

static func has(index: int) -> bool:
	return FileAccess.file_exists(file_path(index))

## True when the bytes look like an MP3 file (an ID3 tag or an MP3 frame at the start).
static func looks_like_mp3(path: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < SMALLEST_BYTES:
		return false
	var head: PackedByteArray = file.get_buffer(3)
	return head.get_string_from_ascii() == "ID3" or (head[0] == 0xFF and (head[1] & 0xE0) == 0xE0)

## Keeps a finished download, or throws it away when it is not a recitation.
static func keep(index: int) -> bool:
	var part: String = ProjectSettings.globalize_path(part_path(index))
	if not looks_like_mp3(part_path(index)):
		DirAccess.remove_absolute(part)
		return false
	return DirAccess.rename_absolute(part, ProjectSettings.globalize_path(file_path(index))) == OK

static func stream(index: int) -> AudioStreamMP3:
	if not has(index):
		return null
	var sound: AudioStreamMP3 = AudioStreamMP3.new()
	sound.data = FileAccess.get_file_as_bytes(file_path(index))
	return sound
