class_name EndingScreen
extends UiRoot
## The end of the Kern-7 crossing: a few illustrated slides (data/story.json
## "ending": image asset + text), then the credits roll. "Keep hunting" returns
## to the game in Stahlheim — the world stays open after the campaign.

signal finished

var _slides: Array = []
var _i := -1
var _img: TextureRect
var _text: Label
var _credits: VBoxContainer
var _scroll := 0.0
var _rolling := false
var _cool := 0.0
var shade: ColorRect


func _ready() -> void:
	super._ready()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.03)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_img = TextureRect.new()
	_img.set_anchors_preset(Control.PRESET_FULL_RECT)
	_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_img.modulate = Color(1, 1, 1, 0.0)
	add_child(_img)
	shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.anchor_top = 0.68
	shade.anchor_right = 1.0
	shade.anchor_bottom = 1.0
	add_child(shade)
	_text = UiTheme.label("", 22, UiTheme.PAPER)
	_text.name = "EndingText"
	_text.anchor_left = 0.12
	_text.anchor_right = 0.88
	_text.anchor_top = 0.71
	_text.anchor_bottom = 0.97
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_text)
	_credits = VBoxContainer.new()
	_credits.name = "Credits"
	_credits.alignment = BoxContainer.ALIGNMENT_BEGIN
	_credits.add_theme_constant_override("separation", 5)
	_credits.anchor_left = 0.2
	_credits.anchor_right = 0.8
	_credits.visible = false
	add_child(_credits)
	_slides = Story.data().get("ending", [])
	_next()


func _next() -> void:
	_cool = 0.4
	_i += 1
	if _i < _slides.size():
		var sl: Dictionary = _slides[_i]
		_img.texture = Assets.texture(str(sl.get("image", "ui.photo_combat")))
		_img.modulate.a = 0.0
		create_tween().tween_property(_img, "modulate:a", 0.85, 1.2)
		_text.text = tr(str(sl.get("text", "")))
		return
	if not _rolling:
		_roll_credits()
		return
	_close()


func _roll_credits() -> void:
	_rolling = true
	_img.visible = false
	_text.visible = false
	shade.visible = false
	for c in _credits.get_children():
		c.queue_free()
	# the creator's logo heads the credits (ui.logo → assets/Illustrations/Thawborn Logo.png)
	var logo := TextureRect.new()
	logo.name = "CreditsLogo"
	logo.texture = Assets.texture("ui.logo")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(340, 190)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_credits.add_child(logo)
	for row in Story.data().get("credits", []):
		var k := UiTheme.label(tr(str(row[0])), 14, UiTheme.DIM)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_credits.add_child(k)
		var val := UiTheme.label(tr(str(row[1])), 22, UiTheme.PAPER)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_credits.add_child(val)
	var stats := UiTheme.label(_stats_line(), 15, UiTheme.COOLANT)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.custom_minimum_size = Vector2(560, 0)
	_credits.add_child(stats)
	var b := UiTheme.btn(tr("END_KEEP_HUNTING"), func() -> void: _close())
	b.name = "KeepHunting"
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_credits.add_child(b)
	_credits.visible = true
	_scroll = size.y
	_credits.position.y = _scroll


func _stats_line() -> String:
	var st: Dictionary = Session.state.get("stats", {})
	var kills := 0
	for sp in Session.state.get("bestiary", {}):
		kills += int(Session.state["bestiary"][sp].get("killed", 0))
	return tr("END_STATS") % [int(float(Session.state.get("playtime", 0.0)) / 60.0), int(float(st.get("distance", 0.0)) / 1000.0),
		kills, Session.money(), int(Session.state.get("rank", {}).get("level", 1))]


func _process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	if _rolling and _credits.visible:
		_scroll = maxf(_rest_y(), _scroll - delta * 60.0)
		_credits.position.y = _scroll


## Where the roll stops: near the top, or higher if the list is taller than the screen.
func _rest_y() -> float:
	return minf(size.y * 0.06, size.y - _credits.size.y - 16.0)


func _close() -> void:
	finished.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if _cool > 0.0:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and not _rolling):
		get_viewport().set_input_as_handled()
		if _rolling:
			_scroll = _rest_y()
		else:
			_next()
