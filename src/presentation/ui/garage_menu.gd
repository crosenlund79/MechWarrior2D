class_name GarageMenu
extends UiRoot
## Eisenwolf Werke garage / settlement services (pauses the game). Tabs:
##   Werkstatt  — condition, repair (Mark), refuel (Mark/litre)
##   Markt      — sell recovered loot from the car, the pack or the store
##   Aufrüsten  — 8 upgrade lines: price, rank requirement, effect preview
##   Lager      — car cargo vs garage storage, Unload cargo
## Money, rank and fuel are always shown. Services depend on the garage (the
## canyon refuge field garage only repairs and stores). Calls Session request
## methods only; never edits state itself.

signal closed

var _body: VBoxContainer
var _status: Label
var _head: Label
var _tab := "workshop"
var _tabs: HBoxContainer

const TABS := ["workshop", "market", "contracts", "upgrades", "arsenal", "storage"]
const TAB_SERVICE := {"workshop": "repair", "market": "sell", "contracts": "sell", "upgrades": "upgrade", "arsenal": "repair", "storage": "storage"}
const EFFECT_KEYS := {
	"integrity": "GARAGE_FX_INTEGRITY", "cooling_mult": "GARAGE_FX_COOLING", "grip_mult": "GARAGE_FX_GRIP",
	"accel_mult": "GARAGE_FX_ACCEL", "speed_mult": "GARAGE_FX_SPEED", "damage_mult": "GARAGE_FX_DAMAGE",
	"cooldown_mult": "GARAGE_FX_RATE", "cargo": "GARAGE_FX_CARGO", "tracker_mult": "GARAGE_FX_TRACKER",
	"range_mult": "GARAGE_FX_RANGE", "bullet_mult": "GARAGE_FX_BULLET", "heat_mult": "GARAGE_FX_HEAT",
	"rough_mult": "GARAGE_FX_ROUGH", "impact_mult": "GARAGE_FX_IMPACT", "turn_mult": "GARAGE_FX_SLEW",
	"swap_mult": "GARAGE_FX_SWAP", "recoil_mult": "GARAGE_FX_RECOIL", "ammo_mult": "GARAGE_FX_AMMO",
	"scan_mult": "GARAGE_FX_SCAN", "fuel_cap": "GARAGE_FX_FUEL",
}


func _ready() -> void:
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # never buy blind (the reticle restores it on close)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(0.96))
	panel.custom_minimum_size = Vector2(920, 600)
	center.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_child(UiTheme.label(tr(str(Session.loc.get("garage", {}).get("name", "GARAGE_EISENWOLF"))), 24, UiTheme.STRAW))
	_head = UiTheme.label("", 15)
	v.add_child(_head)
	_tabs = HBoxContainer.new()
	v.add_child(_tabs)
	for t in TABS:
		var b := UiTheme.btn(tr("TAB_" + t.to_upper()), func() -> void:
			_tab = t
			_refresh())
		b.name = "Tab_" + t
		_tabs.add_child(b)
	v.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(880, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	v.add_child(HSeparator.new())
	var row := HBoxContainer.new()
	v.add_child(row)
	_status = UiTheme.label("", 14, UiTheme.WARNING)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_status)
	var close := UiTheme.btn(tr("GARAGE_CLOSE"), func() -> void: close_menu())
	close.name = "Close"
	row.add_child(close)
	if not (TAB_SERVICE[_tab] in Session.garage_services()):
		for t in TABS:
			if TAB_SERVICE[t] in Session.garage_services():
				_tab = t
				break
	_refresh()
	close.call_deferred("grab_focus")


func close_menu() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("garage"):
		get_viewport().set_input_as_handled()
		close_menu()


func _refresh() -> void:
	var m := Session.mech()
	var r: Dictionary = Session.state.get("rank", {})
	_head.text = tr("GARAGE_HEAD") % [Session.money(), int(r.get("level", 1)), tr("RANK_%d" % int(r.get("level", 1))),
		int(round(float(m["integrity"]))), int(round(Session.max_integrity())), int(round(float(m["radiator"]) * 100.0)),
		int(round(Session.fuel())), int(round(Session.fuel_capacity())), Session.cargo_bulk(), Session.cargo_capacity()]
	for b in _tabs.get_children():
		var t := str(b.name).trim_prefix("Tab_")
		(b as Button).disabled = not (TAB_SERVICE[t] in Session.garage_services())
		(b as Button).modulate = Color(1.25, 1.15, 0.9) if t == _tab else Color.WHITE
	for c in _body.get_children():
		c.queue_free()
	match _tab:
		"workshop":
			_workshop()
		"market":
			_market()
		"upgrades":
			_upgrades()
		"storage":
			_storage()
		"contracts":
			_contracts()
		"arsenal":
			_arsenal()


func _row(text: String, size_px: int = 16, color: Color = UiTheme.PAPER) -> HBoxContainer:
	var h := HBoxContainer.new()
	_body.add_child(h)
	var l := UiTheme.label(text, size_px, color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(l)
	return h


func _button(parent: Control, name_: String, text: String, enabled: bool, cb: Callable) -> Button:
	var b := UiTheme.btn(text, func() -> void:
		cb.call()
		_refresh())
	b.name = name_
	b.disabled = not enabled
	parent.add_child(b)
	return b


func _workshop() -> void:
	var rc := Session.garage_repair_cost()
	var h := _row(tr("GARAGE_REPAIR_M") % rc if rc > 0 else tr("GARAGE_REPAIR_NONE"))
	_button(h, "Repair", tr("GARAGE_REPAIR_BTN"), rc > 0 and Session.money() > 0 and Session.has_service("repair"), func() -> void:
		if not Session.garage_repair():
			_status.text = tr("NOTICE_NO_MONEY"))
	var fc := Session.refuel_cost()
	var h2 := _row(tr("GARAGE_FUEL") % [int(round(Session.fuel_capacity() - Session.fuel())), fc, float(Session.tun("shop").get("fuel_price", 2.0))]
		if fc > 0 else tr("GARAGE_FUEL_FULL"))
	_button(h2, "Refuel", tr("GARAGE_REFUEL_BTN"), fc > 0 and Session.money() > 0 and Session.has_service("fuel"), func() -> void:
		if Session.refuel() <= 0.0:
			_status.text = tr("NOTICE_NO_MONEY"))
	if not Session.has_service("fuel"):
		_row(tr("GARAGE_NO_FUEL_HERE"), 13, UiTheme.DIM)
	var ac := Session.restock_cost()
	var h3 := _row(tr("GARAGE_AMMO") % ac if ac > 0 else tr("GARAGE_AMMO_FULL"))
	_button(h3, "Restock", tr("GARAGE_RESTOCK_BTN"), ac > 0 and Session.money() > 0, func() -> void:
		if Session.restock_ammo() <= 0:
			_status.text = tr("NOTICE_NO_MONEY"))
	_row(tr("GARAGE_CARGO_OBJECTIVE") % tr(str(Journey.data().get("cargo", {}).get("name", ""))), 13, UiTheme.DIM)


func _market() -> void:
	var items := Session.sellable()
	if items.is_empty():
		_row(tr("MARKET_EMPTY"), 15, UiTheme.DIM)
	var total := 0
	var keys: Array = items.keys()
	keys.sort_custom(func(a, b): return Session.item_value(str(a)) > Session.item_value(str(b)))
	for item in keys:
		var n := int(items[item])
		var val := Session.item_value(str(item))
		total += val * n
		var rar := Loot.rarity(str(item))
		var col: Color = HuntMarks.RARITY_COLOR.get(rar, UiTheme.PAPER)
		var h := _row("%s ×%d  —  %d M %s  (%s)" % [tr(str(Content.items.get(item, {}).get("name", item))), n, val, tr("MARKET_EACH"), tr("RARITY_" + rar.to_upper())], 15, col)
		_button(h, "Sell1_" + str(item), tr("MARKET_SELL_ONE"), Session.has_service("sell"), func() -> void: Session.sell_item(str(item), 1))
		_button(h, "SellAll_" + str(item), tr("MARKET_SELL_ALL") % (val * n), Session.has_service("sell"), func() -> void: Session.sell_item(str(item), n))
	if not items.is_empty():
		var h2 := _row(tr("MARKET_TOTAL") % total, 15, UiTheme.STRAW)
		_button(h2, "SellEverything", tr("MARKET_SELL_EVERYTHING"), Session.has_service("sell"), func() -> void:
			for it in Session.sellable().keys():
				Session.sell_item(str(it), int(Session.sellable().get(it, 0))))
	_row(tr("MARKET_CARGO_NOTE") % tr(str(Journey.data().get("cargo", {}).get("name", ""))), 12, UiTheme.DIM)


func _upgrades() -> void:
	var tg: Dictionary = Session.tun("shop")
	for module in Garage.MODULES:
		var lv := Garage.level(Session.upgrades(), module)
		var mx := Garage.max_level(tg, module)
		var box := HBoxContainer.new()
		_body.add_child(box)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 1)
		box.add_child(col)
		var cur := Garage.current_level(tg, Session.upgrades(), module)
		var cur_name := tr(str(cur.get("name", ""))) if not cur.is_empty() else tr("UP_STOCK")
		col.add_child(UiTheme.label("%s  %s   %s" % [tr("MOD_" + module.to_upper()), "●".repeat(lv) + "○".repeat(mx - lv), cur_name], 16, UiTheme.STRAW))
		col.add_child(UiTheme.label(tr("MOD_" + module.to_upper() + "_DESC"), 12, UiTheme.DIM))
		var nxt := Garage.next_level(tg, Session.upgrades(), module)
		if nxt.is_empty():
			col.add_child(UiTheme.label(tr("GARAGE_MAXED"), 13, UiTheme.COOLANT))
			continue
		var reason := Session.garage_check(module)
		var need := tr("UP_NEXT") % [tr(str(nxt.get("name", ""))), int(nxt.get("price", 0)), int(nxt.get("rank", 1)), tr("RANK_%d" % int(nxt.get("rank", 1)))]
		col.add_child(UiTheme.label(need, 13, UiTheme.PAPER if reason == "" else UiTheme.WARNING))
		var fx: PackedStringArray = []
		for e in Garage.preview(tg, Session.upgrades(), module):
			fx.append(_fx_text(str(e[0]), float(e[1]), float(e[2])))
		col.add_child(UiTheme.label(" · ".join(fx), 13, UiTheme.COOLANT))
		var b := _button(box, "Fit_" + module, tr("GARAGE_BUY") % int(nxt.get("price", 0)), reason == "", func() -> void:
			if Session.garage_fit(module):
				_status.text = tr("NOTICE_FITTED") % [tr(str(nxt.get("name", ""))), Garage.level(Session.upgrades(), module)]
			else:
				_status.text = tr(Session.garage_check(module)))
		if reason != "":
			b.tooltip_text = tr(reason)


## Jäger contracts: active ones (progress, turn in) and this board's offers.
func _contracts() -> void:
	var cs := Session.contracts()
	_row(tr("CT_ACTIVE") % [cs["active"].size(), Contracts.MAX_ACTIVE], 16, UiTheme.STRAW)
	var ready := 0
	for c in cs["active"]:
		var done := str(c.get("status", "")) == "ready"
		if done:
			ready += 1
		var h := _row("%s %s — %s  [%d/%d]  %d M" % ["✔" if done else "•", _ct_title(c), _ct_goal(c), int(c["progress"]), int(c["count"]), int(c.get("reward", 0))],
			15, UiTheme.COOLANT if done else UiTheme.PAPER)
		if not bool(c.get("story", false)) and not done:
			var cid := str(c["id"])
			_button(h, "Abandon_" + cid, tr("CT_ABANDON"), true, func() -> void: Session.abandon_contract(cid))
	if cs["active"].is_empty():
		_row(tr("CT_NONE"), 14, UiTheme.DIM)
	if ready > 0:
		var h2 := _row(tr("CT_READY") % ready, 15, UiTheme.STRAW)
		_button(h2, "TurnIn", tr("CT_TURN_IN"), true, func() -> void:
			var m := Session.turn_in_contracts()
			_status.text = tr("CT_PAID") % m)
	_body.add_child(HSeparator.new())
	_row(tr("CT_BOARD") % tr(str(Journey.node(Session.current_node()).get("name", ""))), 16, UiTheme.STRAW)
	var offers := Session.contract_board()
	if offers.is_empty():
		_row(tr("CT_BOARD_EMPTY"), 14, UiTheme.DIM)
	for c in offers:
		var cid2 := str(c["id"])
		var h3 := _row("%s%s — %s · %s\n%d M · %d XP" % ["★ " if bool(c.get("story", false)) else "", _ct_title(c), _ct_goal(c),
			tr(str(Journey.node(str(c.get("node", ""))).get("name", ""))) if str(c.get("node", "")) != "" else "", int(c.get("reward", 0)), int(c.get("xp", 0))], 14)
		if str(c.get("desc", "")) != "":
			_row("   " + tr(str(c["desc"])), 12, UiTheme.DIM)
		_button(h3, "Accept_" + cid2, tr("CT_ACCEPT"), cs["active"].size() < Contracts.MAX_ACTIVE, func() -> void:
			var err := Session.accept_contract(cid2)
			_status.text = tr(err) if err != "" else tr("CT_TAKEN_OK"))


func _ct_title(c: Dictionary) -> String:
	return tr(str(c.get("title", "CT_HUNT")))


func _ct_goal(c: Dictionary) -> String:
	match str(c.get("kind", "")):
		"hunt":
			return tr("CTG_HUNT") % [int(c.get("count", 1)), tr("SPECIES_" + str(c.get("species", "")).to_upper())]
		"cull":
			return tr("CTG_CULL") % int(c.get("count", 1))
		"apex":
			return tr("CTG_APEX") % tr(str(c.get("target_name", "APEX")))
		"investigate":
			return tr("CTG_INVESTIGATE")
		"recover":
			return tr("CTG_RECOVER")
	return ""


## Weapons (mounted, owned, for sale) and chassis (owned, for sale).
func _arsenal() -> void:
	_row(tr("ARS_WEAPONS"), 16, UiTheme.STRAW)
	for id in Session.owned_weapons():
		var d := Arsenal.def(str(id))
		var mounted := str(id) == Session.weapon_id()
		var h := _row("%s %s — %s  %d/%d" % ["▶" if mounted else " ", tr(str(d.get("name", id))), tr("ARS_AMMO"), Session.ammo(str(id)), Session.ammo_capacity(str(id))],
			15, UiTheme.COOLANT if mounted else UiTheme.PAPER)
		var wid := str(id)
		_button(h, "Mount_" + wid, tr("ARS_MOUNT"), not mounted, func() -> void: Session.select_weapon(wid))
	for id in Arsenal.for_sale(Session.current_node(), Session.mech()):
		var d2 := Arsenal.def(str(id))
		var reason := Session.weapon_check(str(id))
		var h2 := _row("%s — %s\n   %s" % [tr(str(d2.get("name", id))), tr("ARS_PRICE") % [int(d2.get("price", 0)), int(d2.get("rank", 1))], tr(str(d2.get("desc", "")))],
			14, UiTheme.PAPER if reason == "" else UiTheme.WARNING)
		var wid2 := str(id)
		var b := _button(h2, "BuyWeapon_" + wid2, tr("GARAGE_BUY") % int(d2.get("price", 0)), reason == "", func() -> void:
			if Session.buy_weapon(wid2):
				_status.text = tr("NOTICE_WEAPON_BOUGHT") % tr(str(d2.get("name", wid2)))
			else:
				_status.text = tr(Session.weapon_check(wid2)))
		if reason != "":
			b.tooltip_text = tr(reason)
	_body.add_child(HSeparator.new())
	_row(tr("ARS_CHASSIS"), 16, UiTheme.STRAW)
	for id in Vehicles.order():
		var cd := Vehicles.def(str(id))
		var owned: bool = Session.mech()["owned_chassis"].has(id)
		var driving := str(id) == Session.chassis_id()
		var sold: bool = Session.current_node() in cd.get("sold", [])
		if not owned and not sold:
			continue
		var line := "%s %s (%s)\n   %s" % ["▶" if driving else " ", tr(str(cd.get("name", id))), str(cd.get("maker", "")), tr(str(cd.get("desc", "")))]
		var cid := str(id)
		if owned:
			var h3 := _row(line, 14, UiTheme.COOLANT if driving else UiTheme.PAPER)
			_button(h3, "Drive_" + cid, tr("ARS_DRIVE"), not driving and Session.at_garage(), func() -> void: Session.switch_chassis(cid))
		else:
			var reason2 := Session.chassis_check(cid)
			var h4 := _row(line + "\n   " + tr("ARS_PRICE") % [int(cd.get("price", 0)), int(cd.get("rank", 1))], 14, UiTheme.PAPER if reason2 == "" else UiTheme.WARNING)
			var b2 := _button(h4, "BuyChassis_" + cid, tr("GARAGE_BUY") % int(cd.get("price", 0)), reason2 == "", func() -> void:
				if not Session.buy_chassis(cid):
					_status.text = tr(Session.chassis_check(cid)))
			if reason2 != "":
				b2.tooltip_text = tr(reason2)


func _storage() -> void:
	var m := Session.mech()
	var carried := {}
	for src in [m["storage"], Session.pilot()["pack"]]:
		for k in src:
			carried[k] = int(carried.get(k, 0)) + int(src[k])
	_row(tr("GARAGE_CARGO") % _list_items(carried), 15)
	_row(tr("GARAGE_STORED") % _list_items(Session.garage_storage()), 15)
	var h := _row(tr("GARAGE_UNLOAD_HINT"), 13, UiTheme.DIM)
	_button(h, "Unload", tr("GARAGE_UNLOAD"), not carried.is_empty() and Session.has_service("storage"), func() -> void:
		var n := Session.unload_cargo()
		_status.text = tr("NOTICE_UNLOADED") % n if n > 0 else tr("GARAGE_NOTHING_TO_UNLOAD"))


func _list_items(inv: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in inv:
		if int(inv[k]) > 0:
			parts.append("%s ×%d" % [tr(str(Content.items.get(k, {}).get("name", k))), int(inv[k])])
	return ", ".join(parts) if parts.size() > 0 else tr("GARAGE_EMPTY")


func _fx_text(key: String, now: float, nxt: float) -> String:
	var label := tr(str(EFFECT_KEYS.get(key, key)))
	if key.ends_with("_mult"):
		return "%s %+d%% → %+d%%" % [label, int(round((now - 1.0) * 100.0)), int(round((nxt - 1.0) * 100.0))]
	return "%s +%d → +%d" % [label, int(now), int(nxt)]
