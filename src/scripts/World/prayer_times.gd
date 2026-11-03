# src/scripts/World/prayer_times.gd
# Purpose: Today's five real prayer times for Kuwait City, worked out from the sun, for the reminder in the menu.
# Uses the Kuwait method: Fajr at 18 degrees, Isha at 17.5 degrees, Asr when a shadow equals its object.

class_name PrayerTimes
extends RefCounted

const LATITUDE: float = 29.3759
const LONGITUDE: float = 47.9774
const FAJR_ANGLE: float = 18.0
const ISHA_ANGLE: float = 17.5
const SUN_EDGE: float = 0.833
## The five prayers in order of the day. Sunrise is worked out too, but is not a prayer.
const NAMES: Array[String] = ["fajr", "dhuhr", "asr", "maghrib", "isha"]

## Minutes after local midnight for each prayer on the given date: {"fajr": 262, ...}.
static func for_date(year: int, month: int, day: int, zone_hours: float) -> Dictionary:
	var julian: float = _julian(year, month, day) - LONGITUDE / (15.0 * 24.0)
	var fajr: float = _sun_angle_time(julian, FAJR_ANGLE, 5.0 / 24.0, true)
	var dhuhr: float = _mid_day(julian, 12.0 / 24.0)
	var asr: float = _asr_time(julian, 13.0 / 24.0)
	var maghrib: float = _sun_angle_time(julian, SUN_EDGE, 18.0 / 24.0, false)
	var isha: float = _sun_angle_time(julian, ISHA_ANGLE, 18.0 / 24.0, false)
	var shift: float = zone_hours - LONGITUDE / 15.0
	var hours: Array[float] = [fajr, dhuhr, asr, maghrib, isha]
	var out: Dictionary = {}
	for i: int in NAMES.size():
		out[NAMES[i]] = int(round(fposmod(hours[i] + shift, 24.0) * 60.0))
	return out

## Today's times by the phone's own clock and time zone.
static func today() -> Dictionary:
	var date: Dictionary = Time.get_date_dict_from_system()
	return for_date(int(date["year"]), int(date["month"]), int(date["day"]), zone_hours())

static func zone_hours() -> float:
	return float(Time.get_time_zone_from_system().get("bias", 180)) / 60.0

static func now_minutes() -> int:
	var now: Dictionary = Time.get_time_dict_from_system()
	return int(now["hour"]) * 60 + int(now["minute"])

## The next prayer from now today, as [name, minutes], or fajr tomorrow after isha.
static func next_prayer(times: Dictionary, now: int) -> Array:
	for name: String in NAMES:
		if int(times[name]) > now:
			return [name, int(times[name])]
	return ["fajr", int(times["fajr"])]

## "4:32" in the phone's usual 12-hour style, with the AM/PM word from the language.
static func clock_text(minutes: int) -> String:
	var hour: int = (minutes / 60) % 24
	var shown: int = hour % 12
	if shown == 0:
		shown = 12
	return "%d:%02d %s" % [shown, minutes % 60, Locale.t("am" if hour < 12 else "pm")]

static func _julian(year: int, month: int, day: int) -> float:
	if month <= 2:
		year -= 1
		month += 12
	var a: float = floorf(year / 100.0)
	var b: float = 2.0 - a + floorf(a / 4.0)
	return floorf(365.25 * (year + 4716)) + floorf(30.6001 * (month + 1)) + day + b - 1524.5

## The sun's declination in degrees and the equation of time in hours, for a day plus a part of it.
static func _sun(julian: float) -> Vector2:
	var d: float = julian - 2451545.0
	var g: float = deg_to_rad(fposmod(357.529 + 0.98560028 * d, 360.0))
	var q: float = fposmod(280.459 + 0.98564736 * d, 360.0)
	var l: float = deg_to_rad(fposmod(q + 1.915 * sin(g) + 0.020 * sin(2.0 * g), 360.0))
	var e: float = deg_to_rad(23.439 - 0.00000036 * d)
	var right_ascension: float = fposmod(rad_to_deg(atan2(cos(e) * sin(l), cos(l))) / 15.0, 24.0)
	var declination: float = rad_to_deg(asin(sin(e) * sin(l)))
	var equation: float = q / 15.0 - right_ascension
	equation -= 24.0 * roundf(equation / 24.0)
	return Vector2(declination, equation)

static func _mid_day(julian: float, part: float) -> float:
	return fposmod(12.0 - _sun(julian + part).y, 24.0)

## When the sun is the given angle below the horizon, before noon (morning) or after it.
static func _sun_angle_time(julian: float, angle: float, part: float, morning: bool) -> float:
	var declination: float = deg_to_rad(_sun(julian + part).x)
	var latitude: float = deg_to_rad(LATITUDE)
	var cosine: float = (-sin(deg_to_rad(angle)) - sin(declination) * sin(latitude)) / (cos(declination) * cos(latitude))
	var span: float = rad_to_deg(acos(clampf(cosine, -1.0, 1.0))) / 15.0
	var noon: float = _mid_day(julian, part)
	return noon - span if morning else noon + span

static func _asr_time(julian: float, part: float) -> float:
	var declination: float = _sun(julian + part).x
	var angle: float = -rad_to_deg(atan(1.0 / (1.0 + tan(deg_to_rad(absf(LATITUDE - declination))))))
	return _sun_angle_time(julian, angle, part, false)
