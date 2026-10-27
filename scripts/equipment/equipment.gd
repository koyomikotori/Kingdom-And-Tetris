class_name Equipment
extends RefCounted
## The kingdom's items (GDD §8 "Trang bị", M12e): the shared storage, making random and legendary
## items, equipping, dismantling, the forge's job and battle loot. Owned by KingdomState; takes
## what it needs as arguments (stockpile, officers).

signal changed

enum Result { OK, FULL, WRONG_KIND, NOT_IN_STORAGE, BUSY, CANNOT_AFFORD, NO_FORGE }

const MAX_STORAGE := 20
## Dismantling gives back this share of the forging cost, more for rarer items (× (rarity + 1)).
const DISMANTLE_SHARE := 0.15
## Forging: Khoáng sản + Gỗ cứng, more at higher forge levels; FORGE_TURNS later one item.
const FORGE_COST: Dictionary[StringName, int] = {&"ore": 6, &"hardwood": 6}
const FORGE_COST_PER_LEVEL: Dictionary[StringName, int] = {&"ore": 2, &"hardwood": 2}
const FORGE_TURNS := 2
## Rarity weights (Thường, Tốt, Hiếm, Sử thi) by forge level 1–4. The forge never makes legendaries.
const FORGE_ODDS: Array = [[55, 30, 13, 2], [40, 35, 20, 5], [25, 37, 28, 10], [15, 33, 35, 17]]
## Loot after a won battle: chance, then rarity weights (Thường … Huyền thoại).
const ATTACK_LOOT_CHANCE := 0.35
const ATTACK_LOOT_ODDS: Array[int] = [30, 30, 22, 13, 5]
const DEFENSE_LOOT_CHANCE := 0.12
const DEFENSE_LOOT_ODDS: Array[int] = [50, 30, 15, 5, 0]

static var _effects: Dictionary[StringName, ItemEffectData] = {}

var items: Array[Item] = []
var next_uid := 1
## Legendary items already found this game (never made twice).
var found_legendaries: Array[StringName] = []
var legendaries: Dictionary[StringName, LegendaryItemData] = LegendaryItemData.load_all()
## {"kind", "slot", "turns", "level"} while the forge works, else empty.
var forge_job: Dictionary = {}
## Own random numbers, so items never shift the kingdom's other rolls.
var rng := RandomNumberGenerator.new()


## Every effect's data (loaded once).
static func effect_data() -> Dictionary[StringName, ItemEffectData]:
	if _effects.is_empty():
		_effects = ItemEffectData.load_all()
	return _effects


## The storage has room (a forge job already holds its place).
func has_room() -> bool:
	return items.size() + (1 if not forge_job.is_empty() else 0) < MAX_STORAGE


# --- Making items -------------------------------------------------------------------------

## A random item of this kind (&"general" / &"advisor"), slot and rarity (below legendary).
func create(kind: StringName, slot: StringName, rarity: int) -> Item:
	var item := Item.new()
	item.uid = next_uid
	next_uid += 1
	item.kind = kind
	item.slot = slot
	item.rarity = clampi(rarity, 0, Item.Rarity.EPIC) as Item.Rarity
	if kind == &"general" and slot == &"weapon":
		item.weapon_type = Item.WEAPON_TYPES[rng.randi_range(0, Item.WEAPON_TYPES.size() - 1)]
	item.display_name = Item.NAMES[item.type_key()][item.rarity]
	var pool: Array[StringName] = []
	for id in effect_data():
		if effect_data()[id].kind == kind:
			pool.append(id)
	for i in mini(Item.RARITY_EFFECTS[item.rarity], pool.size()):
		item.effects.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return item


## The legendary item `id`, marked as found. Null when it was found already.
func create_legendary(id: StringName) -> Item:
	var data: LegendaryItemData = legendaries.get(id)
	if data == null or found_legendaries.has(id):
		return null
	found_legendaries.append(id)
	var item := Item.new()
	item.uid = next_uid
	next_uid += 1
	item.kind = data.kind
	item.slot = data.slot
	item.weapon_type = data.weapon_type
	item.rarity = Item.Rarity.LEGENDARY
	item.display_name = data.display_name
	item.effects.assign(data.effects)
	item.legendary_id = id
	return item


## A random item of `rarity`: any kind and slot; a legendary not found yet (an epic item when every
## legendary is found).
func create_random(rarity: int) -> Item:
	if rarity >= Item.Rarity.LEGENDARY:
		var left: Array[StringName] = []
		for id in legendaries:
			if not found_legendaries.has(id):
				left.append(id)
		if not left.is_empty():
			return create_legendary(left[rng.randi_range(0, left.size() - 1)])
		rarity = Item.Rarity.EPIC
	return create(Item.KINDS[rng.randi_range(0, 1)], Item.SLOTS[rng.randi_range(0, 2)], rarity)


## An index into `weights`, rolled by weight.
func roll(weights: Array) -> int:
	var total := 0
	for weight: int in weights:
		total += weight
	var pick := rng.randi_range(1, maxi(1, total))
	for i in weights.size():
		pick -= weights[i]
		if pick <= 0:
			return i
	return 0


## Puts a new item in storage; when it is full the item is dismantled at once. Returns
## {"item": Item, "refund": amounts (empty when it was kept)}.
func receive(item: Item, stockpile: Stockpile) -> Dictionary:
	var refund: Dictionary[StringName, int] = {}
	if items.size() < MAX_STORAGE:
		items.append(item)
	else:
		refund = dismantle_value(item)
		stockpile.add(refund)
	changed.emit()
	return {"item": item, "refund": refund}


## After a won battle (attacking finds more): maybe an item. Returns receive()'s result, or {}.
func roll_loot(attacking: bool, stockpile: Stockpile) -> Dictionary:
	if rng.randf() >= (ATTACK_LOOT_CHANCE if attacking else DEFENSE_LOOT_CHANCE):
		return {}
	var item := create_random(roll(ATTACK_LOOT_ODDS if attacking else DEFENSE_LOOT_ODDS))
	return receive(item, stockpile) if item != null else {}


# --- Equipping ----------------------------------------------------------------------------

## Puts `item` from storage on `officer`; what they wore in that slot goes back to storage.
func equip(officer: Officer, item: Item) -> Result:
	if not item.fits(officer):
		return Result.WRONG_KIND
	if not items.has(item):
		return Result.NOT_IN_STORAGE
	items.erase(item)
	var old: Item = officer.items.get(item.slot)
	if old != null:
		items.append(old)
	officer.items[item.slot] = item
	changed.emit()
	return Result.OK


## Moves what `from` wears in `slot` onto `to`; what `to` wore there goes to `from` (both are
## the same kind of officer).
func swap(from: Officer, to: Officer, slot: StringName) -> Result:
	var item: Item = from.items.get(slot)
	if item == null:
		return Result.NOT_IN_STORAGE
	if not item.fits(to):
		return Result.WRONG_KIND
	var old: Item = to.items.get(slot)
	from.items.erase(slot)
	if old != null:
		from.items[slot] = old
	to.items[slot] = item
	changed.emit()
	return Result.OK


## Takes off what `officer` wears in `slot` (needs room in storage).
func unequip(officer: Officer, slot: StringName) -> Result:
	var item: Item = officer.items.get(slot)
	if item == null:
		return Result.NOT_IN_STORAGE
	if items.size() >= MAX_STORAGE:
		return Result.FULL
	officer.items.erase(slot)
	items.append(item)
	changed.emit()
	return Result.OK


## A dismissed officer's items go back to storage (even past MAX_STORAGE).
func take_back(officer: Officer) -> void:
	for slot in officer.items.keys():
		items.append(officer.items[slot])
	officer.items.clear()
	changed.emit()


func dismantle_value(item: Item) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for resource_id in FORGE_COST:
		result[resource_id] = maxi(1, floori(FORGE_COST[resource_id] * DISMANTLE_SHARE * (item.rarity + 1)))
	return result


## Breaks a stored item down into some of its materials.
func dismantle(item: Item, stockpile: Stockpile) -> Dictionary[StringName, int]:
	var refund: Dictionary[StringName, int] = {}
	if not items.has(item):
		return refund
	refund = dismantle_value(item)
	items.erase(item)
	stockpile.add(refund)
	changed.emit()
	return refund


# --- Forge ----------------------------------------------------------------------------------

static func forge_cost(forge_level: int) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for resource_id in FORGE_COST:
		result[resource_id] = FORGE_COST[resource_id] + FORGE_COST_PER_LEVEL[resource_id] * (forge_level - 1)
	return result


static func forge_odds(forge_level: int) -> Array:
	return FORGE_ODDS[clampi(forge_level, 1, FORGE_ODDS.size()) - 1]


## `forge_level`: 0 when there is no working forge.
func check_forge(stockpile: Stockpile, forge_level: int) -> Result:
	if forge_level <= 0:
		return Result.NO_FORGE
	if not forge_job.is_empty():
		return Result.BUSY
	if not has_room():
		return Result.FULL
	if not stockpile.can_afford(forge_cost(forge_level)):
		return Result.CANNOT_AFFORD
	return Result.OK


## Pays and starts forging an item for `kind` / `slot`; it is ready FORGE_TURNS turns later.
func start_forge(stockpile: Stockpile, forge_level: int, kind: StringName, slot: StringName) -> Result:
	var result := check_forge(stockpile, forge_level)
	if result == Result.OK:
		forge_job = {"kind": kind, "slot": slot, "turns": FORGE_TURNS, "level": forge_level}
		stockpile.spend(forge_cost(forge_level))
		changed.emit()
	return result


## One turn of forging (end of turn). Returns the finished item, or null.
func advance_forge() -> Item:
	if forge_job.is_empty():
		return null
	forge_job.turns -= 1
	if forge_job.turns > 0:
		changed.emit()
		return null
	var item := create(forge_job.kind, forge_job.slot, roll(forge_odds(forge_job.level)))
	forge_job = {}
	items.append(item)
	changed.emit()
	return item


## The forge was lost (demolished, taken): the job stops, nothing comes back.
func cancel_forge() -> void:
	if not forge_job.is_empty():
		forge_job = {}
		changed.emit()


static func describe(result: Result) -> String:
	match result:
		Result.FULL:
			return "Kho đồ đã đầy (%d món): phân rã bớt món không dùng." % MAX_STORAGE
		Result.WRONG_KIND:
			return "Món này không hợp với người này."
		Result.NOT_IN_STORAGE:
			return "Món này không có trong kho."
		Result.BUSY:
			return "Xưởng đang rèn một món khác."
		Result.CANNOT_AFFORD:
			return "Không đủ tài nguyên."
		Result.NO_FORGE:
			return "Cần một Xưởng rèn khí giới đang hoạt động."
	return ""


# --- Save (GDD §10.1) ---------------------------------------------------------------------

func to_save() -> Dictionary:
	var saved: Array = []
	for item in items:
		saved.append(item.to_save())
	var found: Array[String] = []
	for id in found_legendaries:
		found.append(String(id))
	var job := {}
	if not forge_job.is_empty():
		job = {"kind": String(forge_job.kind), "slot": String(forge_job.slot), "turns": forge_job.turns,
				"level": forge_job.level}
	return {"items": saved, "next_uid": next_uid, "found": found, "forge_job": job}


func load_save(data: Dictionary) -> void:
	items.clear()
	for entry: Dictionary in data.get("items", []):
		items.append(Item.from_save(entry))
	next_uid = int(data.get("next_uid", 1))
	found_legendaries.clear()
	for id: String in data.get("found", []):
		found_legendaries.append(StringName(id))
	var job: Dictionary = data.get("forge_job", {})
	forge_job = {} if job.is_empty() else {"kind": StringName(job.kind), "slot": StringName(job.slot),
			"turns": int(job.turns), "level": int(job.level)}
	changed.emit()
