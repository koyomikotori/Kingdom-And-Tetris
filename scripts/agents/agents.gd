class_name Agents
extends RefCounted
## The kingdom's spies (GDD §8 M14e), owned by KingdomState. Hired once at the Sở cảnh sát
## (no upkeep), as many as its level (`slots`, KingdomState.agent_slots), from 3 candidates that
## change every CANDIDATE_TURNS turns. Each mission lasts MISSION_TURNS turns on one clan anywhere
## on the map: relations (+level a turn) or sabotage (slower regrowth, read by Wars through
## sabotage_on). Every mission turn the agent may be caught (detect_chance): killed
## (kill_chance) or back home, the mission over and the clan angry.

signal changed

enum Result { OK, NO_ROOM, CANNOT_AFFORD, BUSY, ANNEXED, UNKNOWN_CLAN }

const CANDIDATES := 3
const CANDIDATE_TURNS := 5
const REFRESH_COST: Dictionary[StringName, int] = {&"food": 20}
const MISSION_TURNS := 10
const XP_PER_TURN := 10
## Chance a turn to be caught with a level-1 Sở cảnh sát; each level above takes DETECT_PER_LEVEL off.
const DETECT_CHANCE := 0.03
const DETECT_PER_LEVEL := 0.01
const MIN_DETECT_CHANCE := 0.005
## Chance a caught agent is killed: KILL_CHANCE − KILL_PER_STAR × stars.
const KILL_CHANCE := 0.4
const KILL_PER_STAR := 0.05
const CAUGHT_RELATION := -10
## Recruit cost: BASE_COST + COST_PER_STAR × stars.
const BASE_COST: Dictionary[StringName, int] = {&"food": 30}
const COST_PER_STAR: Dictionary[StringName, int] = {&"food": 20, &"wood": 10}

var rng := RandomNumberGenerator.new()
var agents: Array[Agent] = []
var candidates: Array[Agent] = []
var candidates_turn := 0


static func cost_of(stars: int) -> Dictionary[StringName, int]:
	var cost := BASE_COST.duplicate()
	for resource_id in COST_PER_STAR:
		cost[resource_id] = cost.get(resource_id, 0) + COST_PER_STAR[resource_id] * stars
	return cost


static func detect_chance(police_level: int) -> float:
	return maxf(MIN_DETECT_CHANCE, DETECT_CHANCE - DETECT_PER_LEVEL * maxi(0, police_level - 1))


static func kill_chance(stars: int) -> float:
	return maxf(0.0, KILL_CHANCE - KILL_PER_STAR * stars)


func generate(stars: int) -> Agent:
	var agent := Agent.new()
	agent.stars = clampi(stars, 1, 6)
	agent.look = OfficerLook.random(rng)
	agent.name = Officer.random_name(rng, agent.look.is_female(), Generals.GIVEN_NAMES)
	GameArt.assign_portrait(agent)
	return agent


## New candidates of up to `max_stars` stars (lower stars more likely, as for officers).
func refresh_candidates(max_stars: int, turn: int) -> void:
	candidates.clear()
	var weights := PackedFloat32Array()
	for stars in range(1, maxi(1, max_stars) + 1):
		weights.append(max_stars - stars + 1)
	for i in CANDIDATES:
		candidates.append(generate(rng.rand_weighted(weights) + 1))
	candidates_turn = turn
	changed.emit()


func buy_refresh(stockpile: Stockpile, max_stars: int, turn: int) -> bool:
	if not stockpile.spend(REFRESH_COST):
		return false
	refresh_candidates(max_stars, turn)
	return true


func check_recruit(stockpile: Stockpile, index: int, slots: int) -> Result:
	if index < 0 or index >= candidates.size() or agents.size() >= slots:
		return Result.NO_ROOM
	if not stockpile.can_afford(cost_of(candidates[index].stars)):
		return Result.CANNOT_AFFORD
	return Result.OK


func recruit(stockpile: Stockpile, index: int, slots: int) -> Result:
	var result := check_recruit(stockpile, index, slots)
	if result != Result.OK:
		return result
	var agent := candidates[index]
	stockpile.spend(cost_of(agent.stars))
	candidates.remove_at(index)
	agents.append(agent)
	changed.emit()
	return Result.OK


func dismiss(agent: Agent) -> void:
	agents.erase(agent)
	changed.emit()


func check_mission(agent: Agent, clan_id: StringName, wars: Wars) -> Result:
	if not wars.fronts.has(clan_id):
		return Result.UNKNOWN_CLAN
	if agent.is_busy():
		return Result.BUSY
	if wars.fronts[clan_id].annexed:
		return Result.ANNEXED
	return Result.OK


func start_mission(agent: Agent, mission: StringName, clan_id: StringName, wars: Wars) -> Result:
	var result := check_mission(agent, clan_id, wars)
	if result != Result.OK:
		return result
	agent.mission = mission
	agent.target = clan_id
	agent.turns_left = MISSION_TURNS
	changed.emit()
	return Result.OK


## Regrowth share taken off `clan_id` by agents sabotaging it (Wars.STRENGTH_REGEN_SHARE at most).
func sabotage_on(clan_id: StringName) -> float:
	var total := 0.0
	for agent in agents:
		if agent.mission == Agent.SABOTAGE and agent.target == clan_id:
			total += agent.sabotage_share()
	return minf(Wars.STRENGTH_REGEN_SHARE, total)


## End of a turn: every agent on a mission learns, may be caught, and does its work; missions
## end after MISSION_TURNS turns; new candidates every CANDIDATE_TURNS turns. Returns what
## happened: [{"name", "clan_id", "mission", "event": &"done" | &"caught" | &"killed", "levels"}].
func end_turn(diplomacy: Diplomacy, police_level: int, max_stars: int, turn: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for agent in agents.duplicate():
		if not agent.is_busy():
			continue
		var entry := {"name": agent.name, "clan_id": agent.target, "mission": agent.mission,
				"levels": agent.gain_xp(XP_PER_TURN)}
		if rng.randf() < detect_chance(police_level):
			diplomacy.change_relation(agent.target, CAUGHT_RELATION, Diplomacy.MEMORY_AGENT)
			entry["event"] = &"killed" if rng.randf() < kill_chance(agent.stars) else &"caught"
			if entry.event == &"killed":
				agents.erase(agent)
			_end_mission(agent)
			events.append(entry)
			continue
		if agent.mission == Agent.RELATIONS:
			diplomacy.change_relation(agent.target, agent.relation_gain(), Diplomacy.MEMORY_AGENT)
		agent.turns_left -= 1
		if agent.turns_left <= 0:
			entry["event"] = &"done"
			_end_mission(agent)
			events.append(entry)
		elif entry.levels > 0:
			entry["event"] = &"level"
			events.append(entry)
	if turn - candidates_turn >= CANDIDATE_TURNS:
		refresh_candidates(max_stars, turn)
	changed.emit()
	return events


func _end_mission(agent: Agent) -> void:
	agent.mission = Agent.NO_MISSION
	agent.target = &""
	agent.turns_left = 0


static func describe(result: Result) -> String:
	match result:
		Result.NO_ROOM:
			return "Sở cảnh sát đã đủ đặc vụ: nâng cấp sở để giữ thêm."
		Result.CANNOT_AFFORD:
			return "Chưa đủ tài nguyên."
		Result.BUSY:
			return "Đặc vụ đang làm nhiệm vụ khác."
		Result.ANNEXED:
			return "Gia tộc này đã thuộc vương quốc."
		Result.UNKNOWN_CLAN:
			return "Không có gia tộc này."
	return ""


# --- Save (GDD §10.1) ---------------------------------------------------------------------

func to_save() -> Dictionary:
	return {"agents": agents.map(func(a: Agent) -> Dictionary: return a.to_save()),
			"candidates": candidates.map(func(a: Agent) -> Dictionary: return a.to_save()),
			"candidates_turn": candidates_turn}


func load_save(data: Dictionary) -> void:
	agents.clear()
	for saved: Dictionary in data.get("agents", []):
		agents.append(Agent.from_save(saved))
	candidates.clear()
	for saved: Dictionary in data.get("candidates", []):
		candidates.append(Agent.from_save(saved))
	candidates_turn = int(data.get("candidates_turn", 0))
	changed.emit()
