class_name TradeDialog
extends DiplomacyDialog
## One-off trade (GDD §9.4): give some of one resource, get another back at the clan's price.

var _give_amount: SpinBox
var _give_option: OptionButton
var _get_option: OptionButton
var _preview: Label
var _trade_button: Button


func _title() -> String:
	return "Trao đổi với %s" % clan_data().display_name


func _shows_stockpile() -> bool:
	return true


func _build(content: VBoxContainer) -> void:
	var hint := _label("Họ dư: %s · Họ thiếu: %s. Đưa thứ họ thiếu, lấy thứ họ dư thì được giá hơn." % [
			_resource_names(clan_data().surplus), _resource_names(clan_data().deficit)], 13)
	hint.add_theme_color_override("font_color", MUTED_COLOR)
	content.add_child(hint)
	_give_amount = _amount_box()
	_give_option = _resource_option(0)
	content.add_child(_row([_label("Bạn đưa", 15, false), _give_amount, _give_option]))
	_get_option = _resource_option(1)
	content.add_child(_row([_label("Bạn lấy", 15, false), _get_option]))
	_preview = _label("", 15)
	content.add_child(_preview)


func _build_actions() -> void:
	_trade_button = add_action("Trao đổi", _on_trade_pressed)


func _refresh() -> void:
	var diplomacy := state.diplomacy
	var give_id := _selected_resource(_give_option)
	var get_id := _selected_resource(_get_option)
	var amount := int(_give_amount.value)
	var result := diplomacy.check_trade(state.stockpile, clan_id, give_id, amount, get_id)
	_trade_button.disabled = result != Diplomacy.TradeResult.OK
	var capacity := "Lượt này họ còn nhận %d giá trị hàng." % diplomacy.remaining_capacity(clan_id)
	if result == Diplomacy.TradeResult.OK:
		set_preview(_preview, "Bạn nhận: %d %s.\n%s" % [diplomacy.trade_quote(clan_id, give_id, amount, get_id),
				_resource_name(get_id), capacity], true)
	else:
		set_preview(_preview, "%s\n%s" % [Diplomacy.describe_trade(result), capacity], false)


func _on_trade_pressed() -> void:
	var get_id := _selected_resource(_get_option)
	var before := state.stockpile.get_amount(get_id)
	var result := state.diplomacy.trade(state.stockpile, clan_id, _selected_resource(_give_option),
			int(_give_amount.value), get_id)
	var ok := result == Diplomacy.TradeResult.OK
	var text := Diplomacy.describe_trade(result)
	if ok:
		text += " Nhận %d %s." % [state.stockpile.get_amount(get_id) - before, _resource_name(get_id)]
	set_status(text, ok)
