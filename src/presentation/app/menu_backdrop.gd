class_name MenuBackdrop
extends RefCounted
## Behind the main menu: the illustrated backdrop `ui.menu_backdrop` (replaceable
## like any other art), cover-scaled and darkened so the menu stays readable.


static func show_on(root: Node) -> void:
	if root.has_node("Backdrop"):
		return
	var layer := CanvasLayer.new()
	layer.name = "Backdrop"
	layer.layer = 0
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.12, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var tr := TextureRect.new()
	tr.texture = Assets.texture("ui.menu_backdrop")
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.modulate = Color(0.62, 0.58, 0.54)
	layer.add_child(tr)
	root.add_child(layer)


static func hide_from(root: Node) -> void:
	if root.has_node("Backdrop"):
		root.get_node("Backdrop").queue_free()
