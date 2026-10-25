class_name AllianceDialog
extends DiplomacyDialog
## Alliance (GDD §9.7): offer one with the acceptance chance shown first; while allied, see what
## the ally sends, renew it in its last turns or cancel it.

var _info: Label
var _preview: Label
var _propose_button: Button
var _cancel_button: Button


func _title() -> String:
	return "Liên minh với %s" % clan_data().display_name


func _build(content: VBoxContainer) -> void:
	var rules := _label(("Đồng minh gửi %d%% quân hiện có vào mọi trận của bạn (bị cướp, bị xâm lược, đi đánh), trừ khi "
			+ "kẻ địch là bạn của họ hoặc quân họ dưới %d%%. Liên minh %d lượt, quan hệ +%d suốt thời gian đó; "
			+ "quan hệ dưới Thân thiện thì liên minh tự tan.") % [roundi(Alliances.HELP_SHARE * 100),
			roundi(Alliances.HELP_MIN_STRENGTH * 100), Alliances.ALLIANCE_TURNS, Diplomacy.ALLIANCE_BASE_BONUS], 13)
	rules.add_theme_color_override("font_color", MUTED_COLOR)
	content.add_child(rules)
	_info = _label("", 15)
	content.add_child(_info)
	_preview = _label("", 15)
	content.add_child(_preview)


func _build_actions() -> void:
	_propose_button = add_action("Đề nghị liên minh", _on_propose_pressed)
	_cancel_button = add_action("Hủy liên minh", _on_cancel_pressed, true)


func _refresh() -> void:
	var clan := state.diplomacy.clans[clan_id]
	var alliances := state.alliances
	var allied := clan.is_allied()
	_cancel_button.visible = allied
	_info.visible = allied
	if allied:
		var help := alliances.help_size(clan_id)
		_info.text = "Đang liên minh, còn %d lượt. %s" % [clan.alliance_turns,
				"Gửi %d lính vào mỗi trận của bạn." % help if help > 0 else "Quân họ đang yếu, tạm không gửi quân."]
	var result := alliances.check_alliance(clan_id)
	_propose_button.text = "Gia hạn liên minh" if allied else "Đề nghị liên minh"
	if result == Alliances.AllianceResult.ALREADY_ALLIED:
		_propose_button.disabled = true
		set_preview(_preview, "Có thể gia hạn trong %d lượt cuối." % Alliances.ALLIANCE_RENEW_TURNS, true)
	elif result == Alliances.AllianceResult.OK:
		var chance := alliances.alliance_chance(clan_id)
		# A 0% offer can only be refused and would block new offers for a few turns.
		_propose_button.disabled = chance <= 0.0
		set_preview(_preview, "%s %d lượt. Khả năng đồng ý: %s (%d%%)." % ["Gia hạn thêm" if allied else "Liên minh",
				Alliances.ALLIANCE_TURNS, Diplomacy.chance_name(chance), roundi(chance * 100)], chance > 0.0)
	else:
		_propose_button.disabled = true
		set_preview(_preview, Alliances.describe_alliance(result), false)


func _on_propose_pressed() -> void:
	var result := state.alliances.propose_alliance(state.rng, clan_id)
	set_status(Alliances.describe_alliance(result), result == Alliances.AllianceResult.OK)


## Breaking an alliance costs a lot of relation: the first click asks for confirmation.
func _on_cancel_pressed() -> void:
	if _cancel_button.text == "Hủy liên minh":
		_cancel_button.text = "Chắc chắn hủy? (quan hệ -%d)" % (Alliances.ALLIANCE_CANCEL_PENALTY + Diplomacy.ALLIANCE_BASE_BONUS)
		return
	_cancel_button.text = "Hủy liên minh"
	state.alliances.cancel_alliance(clan_id)
	set_status("Đã hủy liên minh. Quan hệ -%d, và mất +%d của liên minh." % [Alliances.ALLIANCE_CANCEL_PENALTY,
			Diplomacy.ALLIANCE_BASE_BONUS], false)
