class_name AttackDialog
extends DiplomacyDialog
## Attacking a clan at war (GDD §9.6): both sides' forces (with allies and the clan's friends)
## and the stakes, then the player confirms and the kingdom scene runs the battle.

## The player confirmed; the kingdom scene closes the map and plays the battle.
signal attack_confirmed(clan_id: StringName)

var _forces: Label
var _preview: Label
var _attack_button: Button


func _title() -> String:
	return "Tấn công %s" % clan_data().display_name


func _build(content: VBoxContainer) -> void:
	_forces = _label("", 15)
	content.add_child(_forces)
	var stakes := _label(("Thắng: mỗi lính địch tử trận = +1 lương thực, +1 gỗ, +1 đá. Họ còn dưới %d%% quân thì "
			+ "đầu hàng và bị sáp nhập.\nThua: mất toàn bộ quân (rút lui thì đơn vị chưa vỡ giữ 50%%) và bồi thường "
			+ "%d%% mỗi loại tài nguyên.") % [roundi(Wars.ANNEX_THRESHOLD * 100), roundi(Wars.ATTACK_DEFEAT_COMPENSATION * 100)], 13)
	stakes.add_theme_color_override("font_color", MUTED_COLOR)
	content.add_child(stakes)
	_preview = _label("", 15)
	content.add_child(_preview)


func _build_actions() -> void:
	_attack_button = add_action("Tấn công!", _on_attack_pressed, true)


func _refresh() -> void:
	var alliances := state.alliances
	var front := state.wars.fronts[clan_id]
	var lines: Array[String] = ["Phe bạn: %d lính (%d đơn vị)" % [state.army.count_soldiers(), state.army.count_squads()]]
	for ally in alliances.helping_allies(clan_id):
		lines.append("  + Đồng minh %s: %d lính" % [_clan_name(ally), alliances.help_size(ally)])
	lines.append("Phe %s: %d lính" % [clan_data().display_name, front.strength])
	for friend in alliances.helping_friends(clan_id):
		lines.append("  + %s (bạn của họ): %d lính" % [_clan_name(friend), alliances.help_size(friend)])
	_forces.text = "\n".join(lines)
	var result := state.wars.check_attack(clan_id, state.army.count_squads() > 0)
	_attack_button.disabled = result != Wars.AttackResult.OK
	set_preview(_preview, "Toàn bộ quân của bạn sẽ ra trận." if result == Wars.AttackResult.OK
			else Wars.describe_attack(result), result == Wars.AttackResult.OK)


func _on_attack_pressed() -> void:
	attack_confirmed.emit(clan_id)
	close()
