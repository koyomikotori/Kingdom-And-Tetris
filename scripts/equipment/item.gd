class_name Item
extends RefCounted
## One piece of equipment (GDD §8 "Trang bị", M12e): for a general or an advisor, in one of three
## slots, with a rarity (main stat bonus) and special effects. Made by Equipment.

const KINDS: Array[StringName] = [&"general", &"advisor"]
const SLOTS: Array[StringName] = [&"weapon", &"armor", &"accessory"]
const SLOT_NAMES: Dictionary[StringName, String] = {&"weapon": "Vũ khí", &"armor": "Giáp", &"accessory": "Phụ kiện"}
## Generals' weapon types; each gives the bodyguard its own bonus (Generals.lead).
const WEAPON_TYPES: Array[StringName] = [&"dao", &"thuong", &"kiem", &"kich", &"chuy"]
const WEAPON_NAMES: Dictionary[StringName, String] = {&"dao": "Đao", &"thuong": "Thương", &"kiem": "Kiếm",
		&"kich": "Kích", &"chuy": "Chùy"}
const WEAPON_HINTS: Dictionary[StringName, String] = {&"dao": "cận vệ thêm sát thương cận chiến",
		&"thuong": "cận vệ thêm xung kích", &"kiem": "cận vệ thêm phòng thủ",
		&"kich": "cận vệ thêm cận chiến và xung kích", &"chuy": "đòn cận vệ bỏ qua một phần phòng thủ địch"}

enum Rarity { COMMON, GOOD, RARE, EPIC, LEGENDARY }
const RARITY_NAMES: Array[String] = ["Thường", "Tốt", "Hiếm", "Sử thi", "Huyền thoại"]
## Main stat bonus by rarity.
const RARITY_MAIN: Array[int] = [1, 2, 3, 4, 6]
## Special effects a random item of this rarity rolls.
const RARITY_EFFECTS: Array[int] = [0, 0, 1, 2, 2]
## Border colors (UI and art) by rarity.
const RARITY_COLORS: Array[Color] = [Color(0.62, 0.62, 0.6), Color(0.3, 0.68, 0.32), Color(0.27, 0.5, 0.88),
		Color(0.62, 0.35, 0.82), Color(0.95, 0.74, 0.2)]
## Names of random items by kind/slot (weapon types for generals' weapons), Thường → Sử thi.
const NAMES: Dictionary = {
	&"dao": ["Đao sắt", "Đao thép", "Yển nguyệt đao", "Hắc long đao"],
	&"thuong": ["Thương sắt", "Thương thép", "Hổ đầu thương", "Lượng ngân thương"],
	&"kiem": ["Kiếm sắt", "Kiếm thép", "Thanh phong kiếm", "Long tuyền kiếm"],
	&"kich": ["Kích sắt", "Kích thép", "Song nguyệt kích", "Hổ nha kích"],
	&"chuy": ["Chùy sắt", "Chùy thép", "Lưu tinh chùy", "Kim qua chùy"],
	&"general_armor": ["Giáp da", "Giáp lá sắt", "Giáp vảy cá", "Minh quang giáp"],
	&"general_accessory": ["Lệnh bài đồng", "Lệnh kỳ", "Hổ phù", "Soái ấn"],
	&"advisor_weapon": ["Quạt giấy", "Quạt lông", "Bút tử ngọc", "Quạt bạch vũ"],
	&"advisor_armor": ["Áo vải", "Áo gấm", "Đạo bào", "Hạc sưởng"],
	&"advisor_accessory": ["Ngọc bội", "Ấn đồng", "Ấn ngọc", "Kim ấn"],
}
## The stat (or bodyguard armor) the main bonus goes to, by kind/slot.
const MAIN_STATS: Dictionary = {
	&"general_weapon": &"might", &"general_armor": &"guard_armor", &"general_accessory": &"command",
	&"advisor_weapon": &"strategy", &"advisor_armor": &"admin", &"advisor_accessory": &"diplomacy",
}
const MAIN_STAT_NAMES: Dictionary = {&"might": "Võ lực", &"command": "Thống suất", &"guard_armor": "Giáp cận vệ",
		&"strategy": "Mưu lược", &"admin": "Nội chính", &"diplomacy": "Ngoại giao"}

## Unique within a game (Equipment.next_uid).
var uid := 0
var display_name := ""
var kind: StringName = &"general"
var slot: StringName = &"weapon"
var weapon_type: StringName = &""
var rarity := Rarity.COMMON
var effects: Array[StringName] = []
## The LegendaryItemData it is, or &"".
var legendary_id: StringName = &""


func type_key() -> StringName:
	if kind == &"general" and slot == &"weapon":
		return weapon_type
	return StringName("%s_%s" % [kind, slot])


func main_stat() -> StringName:
	return MAIN_STATS[StringName("%s_%s" % [kind, slot])]


func main_bonus() -> int:
	return RARITY_MAIN[rarity]


## Legendary effects count double.
func effect_multiplier() -> int:
	return 2 if rarity == Rarity.LEGENDARY else 1


## The icon (GameArt.item_icon): the legendary's own, otherwise the type's.
func icon_id() -> StringName:
	return legendary_id if legendary_id != &"" else type_key()


## What the item does, one line each: main bonus, weapon type, effects.
func describe_lines() -> Array[String]:
	var lines: Array[String] = ["+%d %s" % [main_bonus(), MAIN_STAT_NAMES[main_stat()]]]
	if weapon_type != &"":
		lines.append("%s: %s" % [WEAPON_NAMES[weapon_type], WEAPON_HINTS[weapon_type]])
	for id in effects:
		var data: ItemEffectData = Equipment.effect_data().get(id)
		if data != null:
			lines.append(data.describe(effect_multiplier()))
	return lines


func fits(officer: Officer) -> bool:
	return kind == (&"advisor" if officer is Advisor else &"general")


func to_save() -> Dictionary:
	var ids: Array[String] = []
	for id in effects:
		ids.append(String(id))
	return {"uid": uid, "name": display_name, "kind": String(kind), "slot": String(slot), "weapon": String(weapon_type),
			"rarity": rarity, "effects": ids, "legendary": String(legendary_id)}


static func from_save(data: Dictionary) -> Item:
	var item := Item.new()
	item.uid = int(data.uid)
	item.display_name = data.name
	item.kind = StringName(data.kind)
	item.slot = StringName(data.slot)
	item.weapon_type = StringName(data.weapon)
	item.rarity = clampi(int(data.rarity), 0, Rarity.LEGENDARY) as Rarity
	for id: String in data.effects:
		item.effects.append(StringName(id))
	item.legendary_id = StringName(data.legendary)
	return item
