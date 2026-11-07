# src/scripts/World/phone_notices.gd
# Purpose: One gentle phone notification while the game is closed, such as "Your turnips are ready".
# It is planned when the game goes to the background and taken back when the player returns.
# Rules: at most one a day, only between 8 AM and 9 PM, only when there is something true to say,
# and it can be turned off in Settings. It works on the phone alone, with no server.

class_name PhoneNotices
extends Node

const NOTICE_ID: int = 1
## The farm moves one night forward after this long away (see SaveGame.AWAY_NIGHT), so the notice waits at least as long.
const WAIT: float = SaveGame.AWAY_NIGHT
const EARLIEST_HOUR: int = 8
const LATEST_HOUR: int = 21

var _scheduler: NotificationScheduler
var _ready_to_send: bool = false

func _ready() -> void:
	if not Engine.has_singleton(NotificationScheduler.PLUGIN_SINGLETON_NAME):
		return
	_scheduler = NotificationScheduler.new()
	add_child(_scheduler)
	_scheduler.initialization_completed.connect(func() -> void: _ready_to_send = true)
	_scheduler.initialize()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		send_plan()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_cancel()

## Asks the phone once for permission, at a moment when the reason is clear: the first night's sleep.
func ask_once() -> void:
	var stead: Stead = _stead()
	if _scheduler == null or stead == null or bool(stead.flags.get("asked_notices", false)):
		return
	stead.flags["asked_notices"] = true
	if not _scheduler.has_post_notifications_permission():
		_scheduler.request_post_notifications_permission()

func send_plan() -> void:
	_cancel()
	var stead: Stead = _stead()
	if _scheduler == null or not _ready_to_send or stead == null or not stead.phone_notices:
		return
	if not _scheduler.has_post_notifications_permission():
		return
	var now: float = Time.get_unix_time_from_system()
	var plan: Dictionary = plan_for(get_parent(), now, float(stead.flags.get("notice_sent_at", 0.0)))
	if plan.is_empty():
		return
	var notice: NotificationData = NotificationData.new()
	notice.set_id(NOTICE_ID).set_title(Locale.t("app_name")).set_content(str(plan["text"])).set_delay(int(plan["delay"]))
	if _scheduler.schedule(notice) == OK:
		stead.flags["notice_sent_at"] = now + float(plan["delay"])

func _cancel() -> void:
	if _scheduler != null and _ready_to_send:
		_scheduler.cancel(NOTICE_ID)

## What to say and how many seconds from now, or {} when there is nothing worth a notification.
## last_sent is when the previous notice was due, so two never land on the same day.
static func plan_for(systems: Node, now: float, last_sent: float) -> Dictionary:
	var text: String = _what_to_say(systems)
	if text == "":
		return {}
	var when: float = _gentle_time(now + WAIT)
	if last_sent > 0.0 and _day_of(when) == _day_of(last_sent):
		when = _gentle_time(_next_morning(when))
	return {"text": text, "delay": int(when - now)}

## After one night away, what will be true: ripe crops first, then a fair, then a birthday.
static func _what_to_say(systems: Node) -> String:
	var clock: GameClock = systems.get_node_or_null("Clock") as GameClock
	var farm: FarmField = systems.get_node_or_null("FarmField") as FarmField
	if clock == null or farm == null:
		return ""
	var next_season: String = GameClock.SEASONS[int(float(clock.day + 1) / 7.0) % GameClock.SEASONS.size()]
	var ripe: Dictionary = farm.ripe_tomorrow(next_season, clock.next_weather == "Rain")
	for item: String in farm.ripe_now():
		ripe[item] = int(ripe.get(item, 0)) + int(farm.ripe_now()[item])
	var best: String = ""
	for item: String in ripe:
		if best == "" or int(ripe[item]) > int(ripe[best]):
			best = item
	if best != "":
		return Locale.t("notice_ripe") % Locale.item(best)
	var fairs: Festivals = systems.get_node_or_null("Festivals") as Festivals
	if fairs != null and not fairs.tomorrow().is_empty():
		return Locale.t("notice_fair") % Locale.t("fair_" + str(fairs.tomorrow()["id"]))
	var friends: Friendship = systems.get_node_or_null("Friendship") as Friendship
	if friends != null:
		var person: String = friends.birthday_on(clock.day + 1, next_season)
		if person != "":
			return Locale.t("notice_birthday") % Locale.t("name_" + person)
	return ""

## Moves a time into the friendly hours: before 8 AM waits until 8, after 9 PM waits until the next 8 AM.
static func _gentle_time(when: float) -> float:
	var local: Dictionary = Time.get_datetime_dict_from_unix_time(int(when + _zone_seconds()))
	var hour: int = int(local["hour"])
	if hour >= EARLIEST_HOUR and hour < LATEST_HOUR:
		return when
	var midnight: float = when - (hour * 3600 + int(local["minute"]) * 60 + int(local["second"]))
	if hour >= LATEST_HOUR:
		midnight += 86400.0
	return midnight + EARLIEST_HOUR * 3600.0

static func _next_morning(when: float) -> float:
	var local: Dictionary = Time.get_datetime_dict_from_unix_time(int(when + _zone_seconds()))
	var midnight: float = when - (int(local["hour"]) * 3600 + int(local["minute"]) * 60 + int(local["second"]))
	return midnight + 86400.0 + EARLIEST_HOUR * 3600.0

static func _day_of(when: float) -> String:
	return Time.get_date_string_from_unix_time(int(when + _zone_seconds()))

static func _zone_seconds() -> float:
	return float(Time.get_time_zone_from_system().get("bias", 0)) * 60.0

func _stead() -> Stead:
	return get_parent().get_node_or_null("Stead") as Stead
