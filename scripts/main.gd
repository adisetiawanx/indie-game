extends Control

## Skeleton scene. Kosong sengaja: isi menyusul setelah desain core loop.


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("0f0f0e")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var label := Label.new()
	label.text = "skeleton ok"
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("908f85"))
	label.set_anchors_preset(Control.PRESET_CENTER)
	add_child(label)
