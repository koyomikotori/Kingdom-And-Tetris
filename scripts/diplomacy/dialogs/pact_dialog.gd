class_name PactDialog
extends DiplomacyDialog
## Non-aggression pact (GDD §9.7): what it does, then sign it.

var _preview: Label
var _sign_button: Button


func _title() -> String:
	return "Bất tương xâm với %s" % clan_data().display_name


func _build(content: VBoxContainer) -> void:
	var rules := _label(("Trong %d lượt, %s không tuyên chiến với bạn dù quan hệ có xấu đi, và quan hệ +%d. "
			+ "Họ cũng không gửi quân giúp bạn của họ khi bạn đánh bạn họ. Nếu bạn tuyên chiến với họ, "
			+ "hiệp ước bị phá và mọi gia tộc khác thêm %d quan hệ.") % [Alliances.PACT_TURNS, clan_data().display_name,
			Diplomacy.PACT_BASE_BONUS, Wars.BREAK_PACT_PENALTY], 14)
	content.add_child(rules)
	_preview = _label("", 15)
	content.add_child(_preview)


func _build_actions() -> void:
	_sign_button = add_action("Ký hiệp ước", _on_sign_pressed)


func _refresh() -> void:
	var clan := state.diplomacy.clans[clan_id]
	var result := state.alliances.check_pact(clan_id)
	_sign_button.disabled = result != Alliances.PactResult.OK
	if clan.has_pact():
		set_preview(_preview, "Đang có hiệp ước, còn %d lượt." % clan.pact_turns, true)
	elif result == Alliances.PactResult.OK:
		set_preview(_preview, "Gia tộc Thân thiện trở lên luôn đồng ý.", true)
	else:
		set_preview(_preview, Alliances.describe_pact(result), false)


func _on_sign_pressed() -> void:
	var result := state.alliances.sign_pact(clan_id)
	set_status(Alliances.describe_pact(result) + (" Quan hệ +%d." % Diplomacy.PACT_BASE_BONUS
			if result == Alliances.PactResult.OK else ""), result == Alliances.PactResult.OK)
