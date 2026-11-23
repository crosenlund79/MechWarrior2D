class_name StoryCard
extends Control
## Story dialogue: drains Session.story_cards one card at a time. A card is
## either a speaker line ({speaker, text}: portrait ui.portrait_<speaker>, name,
## role, text) or an act title ({title}). The game pauses while a card is up;
## E / Enter / Space / click continues. When the queue empties and the story
## asked for the ending, Session.take_ending() starts it.

var _panel: PanelContainer
var _portrait: TextureRect
var _name: Label
var _role: Label
var _text: Label
var _title: Label
var _more: Label
var _showing := false
var _cool := 0.0
var _card: Dictionary = {}
var _site := Session.site_serial   # a card UI of a map we already left must not take cards


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.name = "StoryPanel"
	_panel.add_theme_stylebox_override("panel", UiTheme.panel(0.94))
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -470
	_panel.offset_right = 470
	_panel.offset_top = -270
	_panel.offset_bottom = -70
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_next())
	add_child(_panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	_panel.add_child(h)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(150, 150)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(_portrait)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_name = UiTheme.label("", 21, UiTheme.STRAW)
	v.add_child(_name)
	_role = UiTheme.label("", 13, UiTheme.DIM)
	v.add_child(_role)
	_text = UiTheme.label("", 17, UiTheme.PAPER)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_text)
	_more = UiTheme.label(tr("STORY_CONTINUE"), 12, UiTheme.DIM)
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_more)
	_title = UiTheme.label("", 44, UiTheme.STRAW)
	_title.name = "ActTitle"
	_title.set_anchors_preset(Control.PRESET_CENTER)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.grow_vertical = Control.GROW_DIRECTION_BOTH
	_title.visible = false
	_title.add_theme_constant_override("outline_size", 10)
	_title.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.04))
	add_child(_title)


func showing() -> bool:
	return _showing


func _exit_tree() -> void:
	# leaving the map mid-card: put the card back so the next screen shows it
	if _showing and not _card.is_empty():
		Session.story_cards.push_front(_card)
		_showing = false


func _process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	if _site != Session.site_serial:
		return
	if _showing or not Session.running or Session.story_cards.is_empty():
		if not _showing and Session.running and Session.story_cards.is_empty() and Session.take_ending():
			pass
		return
	var hud := get_parent()
	if hud and hud.has_method("modal_open") and hud.modal_open():
		return   # wait until the garage / map is closed
	_show(Session.story_cards.pop_front())


func _show(card: Dictionary) -> void:
	_showing = true
	_card = card
	_cool = 0.35
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var hud := get_parent()
	if hud and hud.get("help") and hud.help:
		hud.help.visible = false   # read the story first; H brings the guide back
	if card.has("title"):
		_panel.visible = false
		_title.visible = true
		_title.text = tr(str(card["title"]))
		return
	_title.visible = false
	_panel.visible = true
	var sp := str(card.get("speaker", ""))
	var cast := Story.cast(sp)
	_portrait.texture = Assets.texture("ui.portrait_" + sp)
	_name.text = tr(str(cast.get("name", sp)))
	_role.text = tr(str(cast.get("role", "")))
	_text.text = tr(str(card.get("text", "")))


func _next() -> void:
	if not _showing or _cool > 0.0:
		return
	_showing = false
	_panel.visible = false
	_title.visible = false
	if Session.story_cards.is_empty():
		get_tree().paused = false
	else:
		_show(Session.story_cards.pop_front())


func _unhandled_input(event: InputEvent) -> void:
	if not _showing:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
		get_viewport().set_input_as_handled()
		_next()
	elif event is InputEventKey and event.pressed:
		get_viewport().set_input_as_handled()   # swallow other keys while reading
