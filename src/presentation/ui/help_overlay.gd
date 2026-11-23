class_name HelpOverlay
extends PanelContainer
## In-game field guide (H). Left: how to drive, shoot, track, harvest, trade.
## Right: the Jäger's hunting record — every species seen and brought down
## (state.bestiary), the apexes, this map's anomalies, the campaign act.
## Shown once at the start of a new game while "show tutorial" is on; the
## record refreshes every time the guide opens.

const ORDER := ["skirr", "aschenlaeufer", "grindback", "dornmaul", "rimeback", "glutkriecher",
	"eisback_alt", "dornkoenig", "glutmutter", "kaltvater"]

var _record: VBoxContainer


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.panel(0.93))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	add_child(h)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.custom_minimum_size = Vector2(500, 0)
	h.add_child(v)
	v.add_child(UiTheme.label(tr("HELP_TITLE"), 22, UiTheme.STRAW))
	for k in ["HELP_DRIVE", "HELP_SHOOT", "HELP_HEAT", "HELP_TRACK", "HELP_HUNT", "HELP_HARVEST", "HELP_GARAGE", "HELP_FOOT"]:
		var l := UiTheme.label(_fmt(tr(k)), 13, UiTheme.PAPER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(490, 0)
		v.add_child(l)
	v.add_child(UiTheme.label(_fmt(tr("HELP_CLOSE")), 13, UiTheme.DIM))
	h.add_child(VSeparator.new())
	_record = VBoxContainer.new()
	_record.name = "HuntingRecord"
	_record.add_theme_constant_override("separation", 3)
	_record.custom_minimum_size = Vector2(330, 0)
	h.add_child(_record)
	visibility_changed.connect(func() -> void:
		if visible:
			refresh())
	refresh()


## Rebuilds the hunting record from the save.
func refresh() -> void:
	if _record == null:
		return
	for c in _record.get_children():
		c.queue_free()
	_record.add_child(UiTheme.label(tr("GUIDE_RECORD"), 20, UiTheme.STRAW))
	if not Session.running:
		return
	var b: Dictionary = Session.state.get("bestiary", {})
	var tc := Session.creature_tuning()
	var seen_n := 0
	var killed_total := 0
	for sp in ORDER:
		var e: Dictionary = b.get(sp, {})
		var seen := int(e.get("seen", 0))
		var killed := int(e.get("killed", 0))
		killed_total += killed
		var apex := bool(tc.get(sp, {}).get("apex", false))
		if seen == 0 and killed == 0:
			_record.add_child(UiTheme.label(("★ " if apex else "· ") + tr("GUIDE_UNKNOWN"), 13, UiTheme.DIM))
			continue
		seen_n += 1
		var line := "%s%s — %s" % ["★ " if apex else "· ", tr("SPECIES_" + sp.to_upper()),
			(tr("GUIDE_SLAIN") if killed > 0 else tr("GUIDE_AT_LARGE")) if apex else tr("GUIDE_TALLY") % [seen, killed]]
		_record.add_child(UiTheme.label(line, 13, UiTheme.COOLANT if killed > 0 else UiTheme.PAPER))
	_record.add_child(HSeparator.new())
	_record.add_child(UiTheme.label(tr("GUIDE_TOTALS") % [seen_n, ORDER.size(), killed_total], 13, UiTheme.STRAW))
	var pois := Session.pois()
	if not pois.is_empty():
		var found := 0
		for p in pois:
			if bool(Session.poi_state(str(p["id"]))["discovered"]):
				found += 1
		_record.add_child(UiTheme.label(tr("GUIDE_ANOMALIES") % [found, pois.size()], 13, UiTheme.PAPER))
	var visited: int = Session.journey().get("visited", {}).size()
	_record.add_child(UiTheme.label(tr("GUIDE_MAPS") % [visited, Journey.nodes().size()], 13, UiTheme.PAPER))
	_record.add_child(UiTheme.label(tr(str(Story.data().get("acts", {}).get(str(Session.act()), ""))), 13, UiTheme.DIM))


## Replaces {action} with the current key binding.
func _fmt(t: String) -> String:
	for a in Settings.ACTIONS:
		t = t.replace("{%s}" % a, Settings.key_label(a))
	return t
