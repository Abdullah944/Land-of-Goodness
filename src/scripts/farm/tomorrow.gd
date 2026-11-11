# src/scripts/farm/tomorrow.gd
# Purpose: The one line shown at bedtime about what tomorrow brings, so the player wants to see the next day.

class_name Tomorrow
extends RefCounted

## The most exciting thing about tomorrow: a fair, the caravan, a new season, a birthday, ripe crops,
## a book page or a friendship that is nearly there, or else the weather.
static func line(systems: Node) -> String:
	var clock: GameClock = systems.get_node_or_null("Clock") as GameClock
	if clock == null:
		return ""
	var fairs: Festivals = systems.get_node_or_null("Festivals") as Festivals
	if fairs != null and not fairs.tomorrow().is_empty():
		return Locale.t("fair_tomorrow") % Locale.t("fair_" + str(fairs.tomorrow()["id"]))
	if Caravan.is_day(clock.day + 1):
		return Locale.t("caravan_tomorrow")
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
	# Rain is news the farmer can use: no watering tomorrow.
	if clock.next_weather == "Rain":
		return clock.forecast_text()
	var near: String = _nearly_there(systems, friends)
	return near if near != "" else clock.forecast_text()

## Something one small step away: a book page missing one or two things, or a neighbor one hello from a new heart.
static func _nearly_there(systems: Node, friends: Friendship) -> String:
	var bag: Inventory = systems.get_node_or_null("Inventory") as Inventory
	if bag != null:
		var best: Dictionary = {}
		var best_missing: int = 3
		for page: Dictionary in CollectionBook.PAGES:
			var missing: int = (page["items"] as Array).size() - CollectionBook.found_on(page, bag.found)
			if missing > 0 and missing < best_missing and CollectionBook.found_on(page, bag.found) > 0:
				best = page
				best_missing = missing
		if not best.is_empty():
			return Locale.t("tomorrow_book") % [best_missing, Locale.t(str(best["key"]))]
	if friends != null:
		for person: String in Friendship.PEOPLE:
			var points: int = int(friends.points.get(person, 0))
			if friends.hearts(person) < Friendship.MAX_HEARTS and points % Friendship.HEART >= Friendship.HEART - Friendship.TALK_POINTS:
				return Locale.t("tomorrow_friend") % Locale.t("name_" + person)
	return ""
