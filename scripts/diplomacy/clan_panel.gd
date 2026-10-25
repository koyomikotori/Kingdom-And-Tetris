class_name ClanPanel
extends VBoxContainer
## Right-hand column of the world map: details of the selected clan plus trade, gift and
## long-term agreement forms.
## Every action goes through Diplomacy; buttons are disabled with the reason shown when an action
## is not possible. No hover needed (touch-ready).

const MUTED_COLOR := Color(1, 1, 1, 0.65)
const WARNING_COLOR := Color(1, 0.6, 0.5)
const DEFAULT_AMOUNT := 5
const DEFAULT_AGREEMENT_TURNS := 10

var _diplomacy: Diplomacy
var _stockpile: Stockpile
var _rng: RandomNumberGenerator
var _resource_types: Array[ResourceTypeData] = []
var _clan_id: StringName = &""

var _hint: Label
var _details: VBoxContainer
var _name_label: Label
var _description: Label
var _info: Label
var _relation_bar: ProgressBar
var _relation_label: Label
var _goods: Label
var _give_option: OptionButton
var _give_amount: SpinBox
var _get_option: OptionButton
var _trade_preview: Label
var _trade_button: Button
var _gift_option: OptionButton
var _gift_amount: SpinBox
var _gift_preview: Label
var _gift_button: Button
var _offer_box: VBoxContainer
var _offer_give_amount: SpinBox
var _offer_give_option: OptionButton
var _offer_get_amount: SpinBox
var _offer_get_option: OptionButton
var _offer_turns: SpinBox
var _offer_preview: Label
var _offer_button: Button
var _contract_box: VBoxContainer
var _contract_label: Label
var _cancel_button: Button
var _status: Label


## `rng` decides whether clans accept agreement offers (KingdomState.rng, so games replay).
func setup(diplomacy: Diplomacy, stockpile: Stockpile, resource_types: Array[ResourceTypeData],
		rng: RandomNumberGenerator) -> void:
	_diplomacy = diplomacy
	_stockpile = stockpile
	_rng = rng
	_resource_types = resource_types
	add_theme_constant_override("separation", 8)
	_hint = _label("Chạm vào một gia tộc trên bản đồ để xem thông tin và giao thương.", 14)
	add_child(_hint)
	_details = VBoxContainer.new()
	_details.add_theme_constant_override("separation", 6)
	_details.visible = false
	add_child(_details)
	_build_details()
	_diplomacy.changed.connect(refresh)
	_stockpile.changed.connect(refresh)


func show_clan(clan_id: StringName) -> void:
	_clan_id = clan_id
	_status.text = ""
	_cancel_button.text = "Hủy hợp đồng"
	refresh()


func refresh() -> void:
	_hint.visible = _clan_id == &""
	_details.visible = _clan_id != &""
	if _clan_id == &"":
		return
	var clan := _diplomacy.clans[_clan_id]
	var data := clan.data
	_name_label.text = data.display_name
	_name_label.add_theme_color_override("font_color", data.color)
	_description.text = data.description
	_info.text = "%s · %s · Sức mạnh quân sự: %d" % [ClanData.DIRECTION_NAMES[data.direction],
			ClanData.PERSONALITY_NAMES[data.personality], data.military_strength]
	var tier := Diplomacy.tier_for(clan.relation)
	_relation_bar.value = clan.relation
	var fill := StyleBoxFlat.new()
	fill.bg_color = WorldMapView.TIER_COLORS[tier]
	_relation_bar.add_theme_stylebox_override("fill", fill)
	_relation_label.text = "Quan hệ: %d (%s)" % [clan.relation, Diplomacy.TIER_NAMES[tier]]
	_goods.text = "Dư: %s · Thiếu: %s" % [_resource_names(data.surplus), _resource_names(data.deficit)]
	_refresh_trade()
	_refresh_gift()
	_refresh_agreement()


func _refresh_trade() -> void:
	var give_id := _selected_resource(_give_option)
	var get_id := _selected_resource(_get_option)
	var amount := int(_give_amount.value)
	var result := _diplomacy.check_trade(_stockpile, _clan_id, give_id, amount, get_id)
	_trade_button.disabled = result != Diplomacy.TradeResult.OK
	var capacity := "Lượt này họ còn nhận %d giá trị hàng." % _diplomacy.remaining_capacity(_clan_id)
	if result == Diplomacy.TradeResult.OK:
		_trade_preview.text = "Bạn nhận: %d %s.\n%s" % [_diplomacy.trade_quote(_clan_id, give_id, amount, get_id),
				_resource_name(get_id), capacity]
		_trade_preview.remove_theme_color_override("font_color")
	else:
		_trade_preview.text = "%s\n%s" % [Diplomacy.describe_trade(result), capacity]
		_trade_preview.add_theme_color_override("font_color", WARNING_COLOR)


func _refresh_gift() -> void:
	var gift := {_selected_resource(_gift_option): int(_gift_amount.value)} as Dictionary[StringName, int]
	var result := _diplomacy.check_gift(_stockpile, _clan_id, gift)
	_gift_button.disabled = result != Diplomacy.GiftResult.OK
	if result == Diplomacy.GiftResult.OK:
		_gift_preview.text = "Quan hệ +%d." % _diplomacy.gift_gain(_clan_id, gift)
		_gift_preview.remove_theme_color_override("font_color")
	else:
		_gift_preview.text = Diplomacy.describe_gift(result)
		_gift_preview.add_theme_color_override("font_color", WARNING_COLOR)


func _refresh_agreement() -> void:
	var agreement := _diplomacy.get_agreement(_clan_id)
	_contract_box.visible = agreement != null
	_offer_box.visible = agreement == null
	if agreement != null:
		_contract_label.text = "Đang có hợp đồng: mỗi lượt đưa %d %s, nhận %d %s. Còn %d/%d lượt." % [
				agreement.give_amount, _resource_name(agreement.give_id), agreement.get_amount,
				_resource_name(agreement.get_id), agreement.turns_left, agreement.total_turns]
		return
	var give_id := _selected_resource(_offer_give_option)
	var get_id := _selected_resource(_offer_get_option)
	var give_amount := int(_offer_give_amount.value)
	var get_amount := int(_offer_get_amount.value)
	var result := _diplomacy.check_proposal(_clan_id, give_id, give_amount, get_id, get_amount, int(_offer_turns.value))
	_offer_button.disabled = result != Diplomacy.ProposalResult.OK
	if result != Diplomacy.ProposalResult.OK:
		_offer_preview.text = Diplomacy.describe_proposal(result)
		_offer_preview.add_theme_color_override("font_color", WARNING_COLOR)
		return
	var fair := _diplomacy.trade_quote(_clan_id, give_id, give_amount, get_id)
	var chance := _diplomacy.agreement_chance(_clan_id, give_id, give_amount, get_id, get_amount)
	_offer_preview.text = "Họ thấy công bằng: khoảng %d %s mỗi lượt.\nKhả năng đồng ý: %s (%d%%)." % [
			fair, _resource_name(get_id), Diplomacy.chance_name(chance), roundi(chance * 100)]
	# A 0% offer can only be refused and would waste this turn's proposal.
	_offer_button.disabled = chance <= 0.0
	if chance <= 0.0:
		_offer_preview.add_theme_color_override("font_color", WARNING_COLOR)
	else:
		_offer_preview.remove_theme_color_override("font_color")


## Fills the "receive" amount with what the clan considers fair for the current offer.
func _on_fair_pressed() -> void:
	var fair := _diplomacy.trade_quote(_clan_id, _selected_resource(_offer_give_option),
			int(_offer_give_amount.value), _selected_resource(_offer_get_option))
	_offer_get_amount.value = maxi(fair, 1)


func _on_offer_pressed() -> void:
	var result := _diplomacy.propose(_rng, _clan_id, _selected_resource(_offer_give_option),
			int(_offer_give_amount.value), _selected_resource(_offer_get_option), int(_offer_get_amount.value),
			int(_offer_turns.value))
	_status.text = Diplomacy.describe_proposal(result)
	if result == Diplomacy.ProposalResult.OK:
		_status.text += " Quan hệ +%d." % Diplomacy.AGREEMENT_SIGN_GAIN


## Breaking an agreement costs a lot of relation: the first click asks for confirmation.
func _on_cancel_pressed() -> void:
	if _cancel_button.text == "Hủy hợp đồng":
		_cancel_button.text = "Chắc chắn hủy? (quan hệ -%d)" % Diplomacy.AGREEMENT_CANCEL_PENALTY
		return
	_cancel_button.text = "Hủy hợp đồng"
	_diplomacy.cancel_agreement(_clan_id)
	_status.text = "Đã hủy hợp đồng. Quan hệ -%d." % Diplomacy.AGREEMENT_CANCEL_PENALTY


func _on_trade_pressed() -> void:
	var get_id := _selected_resource(_get_option)
	var before := _stockpile.get_amount(get_id)
	var result := _diplomacy.trade(_stockpile, _clan_id, _selected_resource(_give_option), int(_give_amount.value), get_id)
	_status.text = Diplomacy.describe_trade(result)
	if result == Diplomacy.TradeResult.OK:
		_status.text += " Nhận %d %s." % [_stockpile.get_amount(get_id) - before, _resource_name(get_id)]


func _on_gift_pressed() -> void:
	var gift := {_selected_resource(_gift_option): int(_gift_amount.value)} as Dictionary[StringName, int]
	var gain := _diplomacy.gift_gain(_clan_id, gift)
	var result := _diplomacy.give_gift(_stockpile, _clan_id, gift)
	_status.text = Diplomacy.describe_gift(result)
	if result == Diplomacy.GiftResult.OK:
		_status.text += " Quan hệ +%d." % gain


# --- Building -----------------------------------------------------------------------------

func _build_details() -> void:
	_name_label = _label("", 20)
	_details.add_child(_name_label)
	_description = _label("", 13)
	_description.add_theme_color_override("font_color", MUTED_COLOR)
	_details.add_child(_description)
	_info = _label("", 13)
	_details.add_child(_info)
	_relation_label = _label("", 14)
	_details.add_child(_relation_label)
	_relation_bar = ProgressBar.new()
	_relation_bar.min_value = Diplomacy.MIN_RELATION
	_relation_bar.max_value = Diplomacy.MAX_RELATION
	_relation_bar.show_percentage = false
	_relation_bar.custom_minimum_size = Vector2(0, 8)
	_details.add_child(_relation_bar)
	_goods = _label("", 13)
	_details.add_child(_goods)

	_details.add_child(HSeparator.new())
	_details.add_child(_label("Trao đổi", 16))
	var give_row := HBoxContainer.new()
	give_row.add_child(_label("Đưa", 13, false))
	_give_amount = _amount_box()
	give_row.add_child(_give_amount)
	_give_option = _resource_option(0)
	give_row.add_child(_give_option)
	_details.add_child(give_row)
	var get_row := HBoxContainer.new()
	get_row.add_child(_label("Lấy", 13, false))
	_get_option = _resource_option(1)
	_get_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	get_row.add_child(_get_option)
	_details.add_child(get_row)
	_trade_preview = _label("", 13)
	_details.add_child(_trade_preview)
	_trade_button = _button("Trao đổi", _on_trade_pressed)
	_details.add_child(_trade_button)

	_details.add_child(HSeparator.new())
	_details.add_child(_label("Tặng quà", 16))
	var gift_row := HBoxContainer.new()
	_gift_amount = _amount_box()
	gift_row.add_child(_gift_amount)
	_gift_option = _resource_option(0)
	gift_row.add_child(_gift_option)
	_details.add_child(gift_row)
	_gift_preview = _label("", 13)
	_details.add_child(_gift_preview)
	_gift_button = _button("Tặng", _on_gift_pressed)
	_details.add_child(_gift_button)

	_details.add_child(HSeparator.new())
	_details.add_child(_label("Hợp đồng giao thương dài hạn", 16))
	_build_agreement_section()

	_details.add_child(HSeparator.new())
	_status = _label("", 13)
	_details.add_child(_status)


func _build_agreement_section() -> void:
	_offer_box = VBoxContainer.new()
	_details.add_child(_offer_box)
	var give_row := HBoxContainer.new()
	give_row.add_child(_label("Đưa", 13, false))
	_offer_give_amount = _amount_box()
	give_row.add_child(_offer_give_amount)
	_offer_give_option = _resource_option(1)
	give_row.add_child(_offer_give_option)
	_offer_box.add_child(give_row)
	var get_row := HBoxContainer.new()
	get_row.add_child(_label("Nhận", 13, false))
	_offer_get_amount = _amount_box()
	get_row.add_child(_offer_get_amount)
	_offer_get_option = _resource_option(0)
	get_row.add_child(_offer_get_option)
	_offer_box.add_child(get_row)
	var turns_row := HBoxContainer.new()
	turns_row.add_child(_label("Mỗi lượt, trong", 13, false))
	_offer_turns = _amount_box()
	_offer_turns.min_value = Diplomacy.AGREEMENT_MIN_TURNS
	_offer_turns.max_value = Diplomacy.AGREEMENT_MAX_TURNS
	_offer_turns.value = DEFAULT_AGREEMENT_TURNS
	turns_row.add_child(_offer_turns)
	turns_row.add_child(_label("lượt", 13, false))
	_offer_box.add_child(turns_row)
	_offer_preview = _label("", 13)
	_offer_box.add_child(_offer_preview)
	_offer_box.add_child(_button("Đòi đúng giá công bằng", _on_fair_pressed))
	_offer_button = _button("Đề nghị ký hợp đồng", _on_offer_pressed)
	_offer_box.add_child(_offer_button)

	_contract_box = VBoxContainer.new()
	_details.add_child(_contract_box)
	_contract_label = _label("", 13)
	_contract_box.add_child(_contract_label)
	_cancel_button = _button("Hủy hợp đồng", _on_cancel_pressed)
	_cancel_button.add_theme_color_override("font_color", WARNING_COLOR)
	_contract_box.add_child(_cancel_button)


## Labels inside a row must not wrap: a wrapping label in an HBoxContainer collapses to zero width.
func _label(text: String, font_size: int, wrap: bool = true) -> Label:
	var label := Label.new()
	label.text = text
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 40)
	button.pressed.connect(on_pressed)
	return button


func _amount_box() -> SpinBox:
	var box := SpinBox.new()
	box.min_value = 0
	box.max_value = 999
	box.value = DEFAULT_AMOUNT
	box.custom_minimum_size = Vector2(90, 0)
	box.value_changed.connect(func(_value: float) -> void: refresh())
	return box


func _resource_option(selected: int) -> OptionButton:
	var option := OptionButton.new()
	option.focus_mode = Control.FOCUS_NONE
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for type in _resource_types:
		option.add_item(type.display_name)
	option.select(mini(selected, _resource_types.size() - 1))
	option.item_selected.connect(func(_index: int) -> void: refresh())
	return option


func _selected_resource(option: OptionButton) -> StringName:
	return _resource_types[option.selected].resource_id


func _resource_name(resource_id: StringName) -> String:
	for type in _resource_types:
		if type.resource_id == resource_id:
			return type.display_name
	return String(resource_id)


func _resource_names(ids: Array[StringName]) -> String:
	var names: Array[String] = []
	for resource_id in ids:
		names.append(_resource_name(resource_id))
	return ", ".join(names) if not names.is_empty() else "—"
