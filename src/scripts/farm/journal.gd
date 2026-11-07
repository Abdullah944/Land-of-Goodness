# src/scripts/farm/journal.gd
# Purpose: Grandfather Saad's journal. Its six pages come back one by one as the story moves on:
# the first from Jassim after the first sale, then one with each finished village project.
# The pages follow progress that is already saved, so they need no save data of their own.

class_name Journal
extends RefCounted

const PAGE_COUNT: int = 6
## Who hands over each page after each project, and who starts the next chapter.
const GIVERS: Dictionary = {"well": "elder", "grove": "merchant", "market": "carpenter", "dock": "fisherman", "diwaniya": "chest"}
const NEXT: Dictionary = {"well": "grove", "grove": "market", "market": "dock", "dock": "diwaniya"}
## Which person has the next page, by how many pages are found.
const HINTS: Array[String] = ["jassim", "elder", "merchant", "carpenter", "fisherman", "chest"]

static func found(systems: Node) -> int:
	var activities: Activities = systems.get_node_or_null("Activities") as Activities
	if activities == null or not activities.quest_done:
		return 0
	var count: int = 1
	var works: VillageWorks = systems.get_node_or_null("VillageWorks") as VillageWorks
	if works != null:
		for project: Dictionary in VillageWorks.PROJECTS:
			if works.is_done(str(project["id"])):
				count += 1
	return mini(count, PAGE_COUNT)

## Jassim's talk when he hands over the first page.
static func first_page_lines() -> PackedStringArray:
	return PackedStringArray([Locale.t("page_from_jassim"), Locale.t("page_1"), Locale.t("chapter_well")])

## What is said when a project is finished: who gives the page, the page, and how the next chapter starts.
static func chapter_lines(project_id: String) -> PackedStringArray:
	var index: int = 1
	for project: Dictionary in VillageWorks.PROJECTS:
		index += 1
		if str(project["id"]) == project_id:
			break
	var lines: PackedStringArray = PackedStringArray([
		Locale.t("page_from_" + str(GIVERS.get(project_id, "elder"))),
		Locale.t("page_%d" % index),
	])
	if NEXT.has(project_id):
		lines.append(Locale.t("chapter_" + str(NEXT[project_id])))
	return lines

## Every page found so far, then a hint about who has the next one.
static func read_lines(systems: Node) -> PackedStringArray:
	var count: int = found(systems)
	var lines: PackedStringArray = PackedStringArray()
	for i: int in count:
		lines.append("%s\n%s" % [Locale.t("page_title") % [i + 1, PAGE_COUNT], Locale.t("page_%d" % (i + 1))])
	if count < PAGE_COUNT:
		lines.append(Locale.t("page_hint_" + HINTS[count]))
	return lines
