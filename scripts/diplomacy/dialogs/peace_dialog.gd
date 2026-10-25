class_name PeaceDialog
extends DiplomacyDialog
## Peace talks (GDD §9.6): optional tribute, acceptance chance shown first, one offer per turn.

var _tribute_amount: SpinBox
var _tribute_option: OptionButton
var _info: Label
var _preview: Label
var _peace_button: Button


func _title() -> String:
	return "Nghị hòa với %s" % clan_data().display_name


func _shows_stockpile() -> bool:
	return true


func _build(content: VBoxContainer) -> void:
	_info = _label("", 14)
	content.add_child(_info)
	_tribute_amount = _amount_box(0)
	_tribute_option = _resource_option(0)
	content.add_child(_row([_label("Bồi thường (không bắt buộc)", 15, false), _tribute_amount, _tribute_option]))
	_preview = _label("", 15)
	content.add_child(_preview)


func _build_actions() -> void:
	_peace_button = add_action("Đề nghị nghị hòa", _on_peace_pressed)


func _tribute() -> Dictionary[StringName, int]:
	var tribute: Dictionary[StringName, int] = {}
	if int(_tribute_amount.value) > 0:
		tribute[_selected_resource(_tribute_option)] = int(_tribute_amount.value)
	return tribute


func _refresh() -> void:
	var front := state.wars.fronts[clan_id]
	_info.text = ("Họ đã mất %d%% quân. Họ càng thua nặng, quan hệ càng tốt, bồi thường càng nhiều thì càng dễ đồng ý. "
			+ "Bồi thường chỉ phải trả khi họ đồng ý. Hòa xong: đình chiến %d lượt.") % [
			roundi(front.losses_share() * 100), Wars.TRUCE_TURNS]
	var tribute := _tribute()
	var result := state.wars.check_peace(state.stockpile, clan_id, tribute)
	_peace_button.disabled = result != Wars.PeaceResult.OK
	if result == Wars.PeaceResult.OK:
		var chance := state.wars.peace_chance(clan_id, tribute)
		# A 0% offer can only be refused and would waste this turn's offer.
		_peace_button.disabled = chance <= 0.0
		set_preview(_preview, "Khả năng đồng ý: %s (%d%%).%s" % [Diplomacy.chance_name(chance), roundi(chance * 100),
				" Thêm bồi thường hoặc đánh cho họ thua nặng hơn." if chance <= 0.0 else ""], chance > 0.0)
	else:
		set_preview(_preview, Wars.describe_peace(result), false)


func _on_peace_pressed() -> void:
	var result := state.wars.propose_peace(state.rng, state.stockpile, clan_id, _tribute())
	set_status(Wars.describe_peace(result), result == Wars.PeaceResult.OK)
