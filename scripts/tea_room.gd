extends Node2D

## Ruangan kedai Slow Leaf: lantai+dinding dari Room_Builder, furnisi dari
## Interiors, karakter beranimasi dari sheet Adam.
## Sheet di assets/tiles/ adalah placeholder dev (non-komersial), gitignored.

const T := 16          # ukuran tile sumber
const S := 3           # skala render
const COLS := 20
const ROWS := 12

const RB := "res://assets/tiles/Room_Builder_free_16x16.png"
const IT := "res://assets/tiles/Interiors_free_16x16.png"
const IDLE_SHEET := "res://assets/tiles/Adam_idle_anim_16x16.png"
const SIT_SHEET := "res://assets/tiles/Adam_sit_16x16.png"

# koordinat tile terverifikasi (pixel-probe + contact sheet berlabel)
const WALL_TOP := Vector2i(1, 13)   # dinding merah-coklat gelap, cap putih
const WALL_BODY := Vector2i(1, 14)  # badan dinding gelap + baseboard
const FLOOR := Vector2i(4, 11)      # lantai wood plank tan (kolom 4-6, baris 11)
const WINDOW := Vector2i(2, 33)  # 2x2
const CAKES := Vector2i(11, 13)  # 2x1
const PLANT_BUSH := Vector2i(2, 48)
const PLANT_POT := Vector2i(12, 48)
const CHAIR := Vector2i(0, 36)      # kursi kayu menghadap depan
const TABLE_SQ := Vector2i(2, 41)   # meja persegi kecil
const SHELF := Vector2i(5, 13)      # rak makanan 1x2


func _atlas(path: String, x: int, y: int, w := 1, h := 1) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = load(path)
	at.region = Rect2(x * T, y * T, w * T, h * T)
	return at


func _tile(path: String, x: int, y: int, gx: int, gy: int, w := 1, h := 1, flip := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _atlas(path, x, y, w, h)
	s.centered = false
	s.flip_h = flip
	s.scale = Vector2(S, S)
	s.position = Vector2(gx * T * S, gy * T * S)
	add_child(s)
	return s


func _ready() -> void:
	_build_room()
	_build_furniture()
	_build_characters()
	print("TEA_ROOM children=", get_child_count(),
		" wall_tex=", load(RB) != null, " it_tex=", load(IT) != null)


func _build_room() -> void:
	for gy in ROWS:
		for gx in COLS:
			if gy == 0:
				_tile(RB, WALL_TOP.x, WALL_TOP.y, gx, gy)
			elif gy < 3:
				_tile(RB, WALL_BODY.x, WALL_BODY.y, gx, gy)
			else:
				_tile(RB, FLOOR.x, FLOOR.y, gx, gy)


func _build_furniture() -> void:
	# bayangan lebih dulu (lapisan bawah)
	for fx in [9.2, 12.2]:
		_shadow(fx, 6.0)
	_shadow(8.2, 5.6)
	_shadow(14.5, 8.0)
	# jendela 2x2 di dinding
	_tile(IT, WINDOW.x, WINDOW.y, 3, 0, 2, 2)
	_tile(IT, WINDOW.x, WINDOW.y, 11, 0, 2, 2)
	# rak makanan 1x2 di dinding
	_tile(IT, SHELF.x, SHELF.y, 7, 1, 1, 2)
	_tile(IT, SHELF.x, SHELF.y, 13, 1, 1, 2)
	# dua set meja persegi + kursi depan di lantai
	for tx in [9, 13]:
		_tile(IT, TABLE_SQ.x, TABLE_SQ.y, tx, 6)
		_tile(IT, CHAIR.x, CHAIR.y, tx, 7)
		_tile(IT, CHAIR.x, CHAIR.y, tx, 5, 1, 1, true)
	# tanaman pojok
	_tile(IT, PLANT_BUSH.x, PLANT_BUSH.y, 0, 9)
	_tile(IT, PLANT_POT.x, PLANT_POT.y, 19, 9)


func _make_anims() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	# idle: 24 frame 16x32 -> 4 arah x 6 frame
	var dirs := {"left": 0, "up": 6, "right": 12, "down": 18}
	for dir in dirs.keys():
		frames.add_animation("idle_" + dir)
		frames.set_animation_speed("idle_" + dir, 5.0)
		for i in range(6):
			frames.add_frame("idle_" + dir, _atlas(IDLE_SHEET, dirs[dir] + i, 0))
	# sit: 12 frame stride 32 offset 6 -> s0-5 menghadap kiri, s6-11 kanan
	frames.add_animation("sit_left")
	frames.set_animation_speed("sit_left", 4.0)
	for i in range(6):
		var at := AtlasTexture.new()
		at.atlas = load(SIT_SHEET)
		at.region = Rect2(6 + i * 32, 0, 16, 32)
		frames.add_frame("sit_left", at)
	frames.add_animation("sit_right")
	frames.set_animation_speed("sit_right", 4.0)
	for i in range(6):
		var at2 := AtlasTexture.new()
		at2.atlas = load(SIT_SHEET)
		at2.region = Rect2(6 + (6 + i) * 32, 0, 16, 32)
		frames.add_frame("sit_right", at2)
	return frames


func _character(gx: float, gy: float, anim: String) -> AnimatedSprite2D:
	var c := AnimatedSprite2D.new()
	c.sprite_frames = _make_anims()
	c.scale = Vector2(S, S)
	# anchor: kaki karakter di dasar sel grid
	c.position = Vector2(gx * T * S + T * S / 2.0, gy * T * S + T * S)
	c.play(anim)
	add_child(c)
	return c


func _build_characters() -> void:
	# pelanggan duduk di kursi sisi meja kiri, menghadap kanan ke meja
	_character(8.2, 5.6, "sit_right")
	# staf berdiri di dekat meja kanan menghadap bawah
	_character(14.5, 8.0, "idle_down")


func _shadow(gx: float, gy: float) -> void:
	# bayangan elips lembut di bawah objek/karakter
	var s := Sprite2D.new()
	var img := Image.create(20, 8, false, Image.FORMAT_RGBA8)
	for yy in range(8):
		for xx in range(20):
			var dx := (xx - 10.0) / 10.0
			var dy := (yy - 4.0) / 4.0
			var a := 0.28 * (1.0 - sqrt(dx * dx + dy * dy))
			img.set_pixel(xx, yy, Color(0, 0, 0, clampf(a, 0.0, 1.0)))
	var tex := ImageTexture.create_from_image(img)
	s.texture = tex
	s.centered = false
	s.position = Vector2(gx * T * S - T * S / 2.0, gy * T * S + T * S - 18)
	add_child(s)
