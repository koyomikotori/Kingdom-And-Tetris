class_name Officer
extends RefCounted
## What generals and advisors share (GDD §8): name, stars, wounds, the level they grow through
## (M11e: XP toward the next level and points not yet added to a stat) and their look (M12c).

## Names (GDD §13: half the officers are women). Male given names differ for generals and
## advisors (Generals.GIVEN_NAMES, Advisors.ADVISOR_NAMES).
const FAMILY_NAMES: Array[String] = ["Trần", "Lê", "Phạm", "Hoàng", "Vũ", "Đặng", "Bùi", "Đỗ", "Ngô", "Dương",
		"Đinh", "Mạc", "Phan", "Tôn", "Khúc", "Lạc", "Thạch", "Kiều"]
const MALE_MIDDLE_NAMES: Array[String] = ["Văn", "Đức", "Minh", "Quốc", "Hữu", "Công", "Thành", "Bá", "Trọng", "Khắc"]
const FEMALE_MIDDLE_NAMES: Array[String] = ["Thị", "Ngọc", "Diệu", "Thanh", "Bảo", "Quỳnh", "Mỹ", "Kim"]
const FEMALE_GIVEN_NAMES: Array[String] = ["Lan", "Mai", "Hoa", "Thảo", "Ngọc", "Linh", "Trang", "Yến", "Hằng",
		"Quyên", "Nguyệt", "Châu", "Uyên", "Diệp", "Hương", "Vân", "Anh", "Nhi", "Tuyết", "Phượng"]

var name: String
var stars: int
var wounded_turns := 0
var level := 1
## XP gathered toward the next level (reset on each level up).
var xp := 0
## Unspent level points.
var points := 0
## Portrait and battle sprite (OfficerLook).
var look := OfficerLook.new()


## A full name for `look.gender`: family name, then a middle and a given name for that gender.
static func random_name(rng: RandomNumberGenerator, female: bool, given_names: Array[String]) -> String:
	var middle := FEMALE_MIDDLE_NAMES if female else MALE_MIDDLE_NAMES
	var given := FEMALE_GIVEN_NAMES if female else given_names
	return "%s %s %s" % [FAMILY_NAMES[rng.randi_range(0, FAMILY_NAMES.size() - 1)],
			middle[rng.randi_range(0, middle.size() - 1)], given[rng.randi_range(0, given.size() - 1)]]


func is_ready() -> bool:
	return wounded_turns <= 0


func star_text() -> String:
	return "★".repeat(stars)


func max_level() -> int:
	return Experience.general_max_level(stars)


func xp_to_next() -> int:
	return Experience.general_xp_to_next(level)


## "Cấp 2/5 · Kinh nghiệm 40/200", or "Cấp 5 (tối đa)" (GDD §8, M11e).
func level_text() -> String:
	if level >= max_level():
		return "Cấp %d (tối đa)" % level
	return "Cấp %d/%d · Kinh nghiệm %d/%d" % [level, max_level(), xp, xp_to_next()]


## Adds XP and levels up (1 point per level) until the max level, where extra XP is dropped.
## Returns how many levels were gained.
func gain_xp(amount: int) -> int:
	var gained := 0
	xp += maxi(0, amount)
	while level < max_level() and xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		points += 1
		gained += 1
	if level >= max_level():
		xp = 0
	return gained


func _officer_save() -> Dictionary:
	return {"name": name, "stars": stars, "wounded_turns": wounded_turns, "level": level, "xp": xp, "points": points,
			"look": look.to_save()}


func _officer_load(data: Dictionary) -> void:
	name = data.name
	stars = int(data.stars)
	wounded_turns = int(data.wounded_turns)
	level = int(data.level)
	xp = int(data.xp)
	points = int(data.points)
	# Saves from before M12c have no look: make one from the name.
	look = OfficerLook.from_save(data.look) if data.has("look") else OfficerLook.from_seed(name)
