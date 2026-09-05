extends Node2D

## Root scene Slow Leaf: ruangan kedai sebagai dunia, UI dashboard meluncur
## sebagai panel. Mode khusus: --selftest, --screenshot, --dev-speed.

const TeaRoom := preload("res://scripts/tea_room.gd")
const MainUI := preload("res://scripts/main.gd")

var ui: Control
var ui_visible := true


func _ready() -> void:
	# dunia
	var room := Node2D.new()
	room.set_script(TeaRoom)
	add_child(room)

	# UI dashboard (Control di atas dunia)
	ui = Control.new()
	ui.set_script(MainUI)
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ui)

	var args := OS.get_cmdline_user_args()
	if args.has("--selftest"):
		ui.interactive = false
		ui._run_selftest()
		return
	if args.has("--screenshot"):
		# screenshot dunia: sembunyikan panel dashboard
		ui.visible = false
		ui.interactive = false
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var out := ProjectSettings.globalize_path("user://screenshot_world.png")
		img.save_png(out)
		print("SCREENSHOT_SAVED: " + out)
		ui._run_screenshot()  # lanjut screenshot UI panel seperti biasa
		return


func _unhandled_input(event: InputEvent) -> void:
	# toggle panel dashboard (nanti: tombol H / otomatis saat aksi)
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		ui_visible = not ui_visible
		ui.visible = ui_visible
