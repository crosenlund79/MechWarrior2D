class_name MenuBackdrop
extends RefCounted
## Behind the main menu: a dark field (Phase A). Kept as one function so the
## illustrated version can replace it without touching the menu logic.


static func show_on(root: Node) -> void:
	if root.has_node("Backdrop"):
		return
	var layer := CanvasLayer.new()
	layer.name = "Backdrop"
	layer.layer = 0
	var r := ColorRect.new()
	r.color = Color(0.16, 0.12, 0.09)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(r)
	root.add_child(layer)


static func hide_from(root: Node) -> void:
	if root.has_node("Backdrop"):
		root.get_node("Backdrop").queue_free()
