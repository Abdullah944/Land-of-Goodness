# src/scripts/farm/tomorrow.gd
# Purpose: The one line shown at bedtime about what tomorrow brings, so the player wants to see the next day.

class_name Tomorrow
extends RefCounted

## The most exciting thing about tomorrow: a fair, a new season, a birthday, ripe crops, or else the weather.
static func line(systems: Node) -> String:
	var clock: GameClock = systems.get_node_or_null("Clock") as GameClock
	if clock == null:
		return ""
	var fairs: Festivals = systems.get_node_or_null("Festivals") as Festivals
	if fairs != null and not fairs.tomorrow().is_empty():
		return Locale.t("fair_tomorrow") % Locale.t("fair_" + str(fairs.tomorrow()["id"]))
	var next_season: String = GameClock.SEASONS[int(float(clock.day + 1) / 7.0) % GameClock.SEASONS.size()]
	if next_season != clock.season:
		return Locale.t("tomorrow_season") % Locale.t(next_season)
	var friends: Friendship = systems.get_node_or_null("Friendship") as Friendship
	if friends != null:
		var person: String = friends.birthday_on(clock.day + 1, next_season)
		if person != "":
			return Locale.t("tomorrow_birthday") % Locale.t("name_" + person)
	var farm: FarmField = systems.get_node_or_null("FarmField") as FarmField
	if farm != null:
		var ripe: Dictionary = farm.ripe_tomorrow(next_season, clock.next_weather == "Rain")
		var best: String = ""
		for item: String in ripe:
			if best == "" or int(ripe[item]) > int(ripe[best]):
				best = item
		if best != "":
			return Locale.t("tomorrow_ripe") % [int(ripe[best]), Locale.item(best)]
	return clock.forecast_text()
