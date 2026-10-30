class_name AgentDialog
extends DiplomacyDialog
## Sends an idle agent to this clan (GDD §8 M14e): pick the agent and the mission; shows what it
## does at the agent's level and the risk of being caught.

## The agent to pick first (set before open, e.g. from "Giao nhiệm vụ" at the Sở cảnh sát).
var preferred: Agent
var _agent: Agent
var _mission: StringName = Agent.RELATIONS
var _agent_row: HFlowContainer
var _mission_row: HBoxContainer
var _info: Label
var _preview: Label
var _send_button: Button


func _title() -> String:
	return "Cử đặc vụ sang %s" % clan_data().display_name


func _build(content: VBoxContainer) -> void:
	content.add_child(_label("Đặc vụ:", 15, false))
	_agent_row = HFlowContainer.new()
	content.add_child(_agent_row)
	content.add_child(_label("Nhiệm vụ (%d lượt):" % Agents.MISSION_TURNS, 15, false))
	_mission_row = HBoxContainer.new()
	content.add_child(_mission_row)
	_info = _label("", 14)
	content.add_child(_info)
	_preview = _label("", 15)
	content.add_child(_preview)
	var idle := _idle_agents()
	_agent = preferred if idle.has(preferred) else (idle[0] if not idle.is_empty() else null)


func _build_actions() -> void:
	_send_button = add_action("Cử đi", _on_send_pressed)


func _idle_agents() -> Array[Agent]:
	var idle: Array[Agent] = []
	for agent in state.agents.agents:
		if not agent.is_busy():
			idle.append(agent)
	return idle


func _refresh() -> void:
	for row: Container in [_agent_row, _mission_row]:
		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()
	for agent in _idle_agents():
		_agent_row.add_child(_choice("%s %s" % [agent.name, agent.star_text()], agent == _agent, func() -> void:
			_agent = agent
			refresh()))
	for mission: StringName in Agent.MISSION_NAMES:
		_mission_row.add_child(_choice(Agent.MISSION_NAMES[mission], mission == _mission, func() -> void:
			_mission = mission
			refresh()))
	if _agent == null:
		_info.text = ""
		_send_button.disabled = true
		set_preview(_preview, "Không có đặc vụ nào đang rảnh.", false)
		return
	if _mission == Agent.RELATIONS:
		_info.text = "Mỗi lượt quan hệ với họ +%d (theo cấp đặc vụ), mờ dần như quà tặng." % _agent.relation_gain()
	else:
		_info.text = "Quân của họ hồi chậm hơn: −%s%% mỗi lượt (mức hồi thường là %d%%)." % [
				String.num(_agent.sabotage_share() * 100, 1), roundi(Wars.STRENGTH_REGEN_SHARE * 100)]
	_info.text += "\nMỗi lượt có %s%% bị lộ; bị lộ thì %d%% bị giết, quan hệ −%d." % [
			String.num(Agents.detect_chance(state.police_level()) * 100, 1), roundi(Agents.kill_chance(_agent.stars) * 100),
			-Agents.CAUGHT_RELATION]
	var result := state.agents.check_mission(_agent, clan_id, state.wars)
	_send_button.disabled = result != Agents.Result.OK
	set_preview(_preview, "Sẵn sàng." if result == Agents.Result.OK else Agents.describe(result), result == Agents.Result.OK)


func _choice(text: String, chosen: bool, on_pressed: Callable) -> Button:
	var button := _button(text, on_pressed)
	button.toggle_mode = true
	button.button_pressed = chosen
	button.custom_minimum_size = Vector2(130, 36)
	return button


func _on_send_pressed() -> void:
	var result := state.start_agent_mission(_agent, _mission, clan_id)
	if result == Agents.Result.OK:
		Sfx.play(&"recruit")
		set_status("%s lên đường: %s, %d lượt." % [_agent.name, Agent.MISSION_NAMES[_mission].to_lower(), Agents.MISSION_TURNS])
		_agent = null
		var idle := _idle_agents()
		if not idle.is_empty():
			_agent = idle[0]
		refresh()
	else:
		set_status(Agents.describe(result), false)
