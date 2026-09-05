extends Control

## Slow Leaf - UI utama. Semua UI dibangun via kode supaya seluruh game
## bisa diiterasi dari file teks. State hidup di autoload Game, UI cuma pembaca.
## Mode khusus: --selftest (headless) dan --screenshot (windowed, 2 detik).

const COL_BG := Color("0f0f0e")
const COL_PANEL := Color("1c1a17")
const COL_SURFACE := Color("252521")
const COL_SURFACE_2 := Color("2e2c27")
const COL_ACCENT := Color("d97757")
const COL_ACCENT_HOVER := Color("e08a6d")
const COL_ACCENT_PRESS := Color("b95f40")
const COL_TEXT := Color("f2efe9")
const COL_MUTED := Color("908f85")
const COL_SUCCESS := Color("8fbc6f")

var tab_garden: Button
var tab_shop: Button
var tab_processing: Button
var tab_market: Button
var pages: Dictionary = {}

# garden page
var coins_label: Label
var harvest_button: Button
var plant_buttons: Dictionary = {}
var plot_price_label: Label

# shop page
var stock_rows: VBoxContainer
var customer_panel: PanelContainer
var customer_name: Label
var customer_want: Label
var serve_button: Button

# processing page
var leaves_label: Label
var product_rows: VBoxContainer
var station_rows: VBoxContainer

# market page
var market_label: Label
var market_hint: Label
var vintage_rows: VBoxContainer

var status_label: Label
var status_tween: Tween
var press_button: Button
var interactive := true  # false saat selftest, supaya _process tidak jalan
var plot_bars: VBoxContainer  # progress bar tanaman di garden page
var bg_texture: TextureRect  # ilustrasi latar per halaman


func _ready() -> void:
	_build_ui()
	Game.load_save()
	randomize()

	var args := OS.get_cmdline_user_args()
	if args.has("--selftest"):
		interactive = false
		_run_selftest()
		return
	if args.has("--screenshot"):
		_run_screenshot()
		return

	var autosave := Timer.new()
	autosave.wait_time = 5.0
	autosave.autostart = true
	autosave.timeout.connect(Game.save)
	add_child(autosave)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Game.save()


func _process(delta: float) -> void:
	if not interactive:
		return
	Game.poll_stations()
	Game.maybe_spawn_customer(delta)
	if not Game.customer.is_empty():
		Game.customer["patience"] = float(Game.customer["patience"]) - delta
		if float(Game.customer["patience"]) <= 0.0:
			Game.customer = {}
			Game.customer_cooldown = 8.0
	_refresh()


# ============ PEMBANGUNAN UI ============

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# ilustrasi latar storybook (fallback: tetap warna polos kalau aset absen)
	bg_texture = TextureRect.new()
	bg_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_texture.modulate = Color(1, 1, 1, 0.9)
	add_child(bg_texture)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# --- header ---
	var header := PanelContainer.new()
	var hstyle := StyleBoxFlat.new()
	hstyle.bg_color = COL_PANEL
	hstyle.content_margin_left = 24.0
	hstyle.content_margin_right = 24.0
	hstyle.content_margin_top = 14.0
	hstyle.content_margin_bottom = 14.0
	header.add_theme_stylebox_override("panel", hstyle)
	root.add_child(header)

	var hrow := HBoxContainer.new()
	header.add_child(hrow)

	var title := Label.new()
	title.text = "Slow Leaf"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", COL_ACCENT)
	hrow.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(spacer)

	coins_label = Label.new()
	coins_label.add_theme_font_size_override("font_size", 18)
	coins_label.add_theme_color_override("font_color", COL_TEXT)
	hrow.add_child(coins_label)

	# --- tab bar ---
	var tabbar := HBoxContainer.new()
	tabbar.add_theme_constant_override("separation", 8)
	var tab_margin := MarginContainer.new()
	tab_margin.add_theme_constant_override("margin_left", 24)
	tab_margin.add_theme_constant_override("margin_top", 12)
	tab_margin.add_theme_constant_override("margin_bottom", 4)
	tab_margin.add_child(tabbar)
	root.add_child(tab_margin)

	tab_garden = _make_tab("Garden")
	tab_shop = _make_tab("Shop")
	tab_processing = _make_tab("Processing")
	tab_market = _make_tab("Market")
	for b in [tab_garden, tab_shop, tab_processing, tab_market]:
		tabbar.add_child(b)
	tab_garden.pressed.connect(func(): _show_page("garden"))
	tab_shop.pressed.connect(func(): _show_page("shop"))
	tab_processing.pressed.connect(func(): _show_page("processing"))
	tab_market.pressed.connect(func(): _show_page("market"))

	# --- halaman ---
	var page_holder := MarginContainer.new()
	page_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	page_holder.add_theme_constant_override("margin_left", 24)
	page_holder.add_theme_constant_override("margin_right", 24)
	page_holder.add_theme_constant_override("margin_bottom", 16)
	page_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(page_holder)

	pages["garden"] = _build_garden_page()
	pages["shop"] = _build_shop_page()
	pages["processing"] = _build_processing_page()
	pages["market"] = _build_market_page()
	for k in pages.keys():
		page_holder.add_child(pages[k])
		pages[k].visible = false

	# --- status bar ---
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", COL_MUTED)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var status_margin := MarginContainer.new()
	status_margin.add_theme_constant_override("margin_bottom", 10)
	status_margin.add_child(status_label)
	root.add_child(status_margin)

	_show_page("garden")


func _make_tab(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", COL_MUTED)
	b.add_theme_color_override("font_hover_color", COL_TEXT)
	b.add_theme_color_override("font_pressed_color", Color("1a120c"))
	b.add_theme_color_override("font_hover_pressed_color", Color("1a120c"))
	var normal := _box(COL_SURFACE, 10)
	normal.content_margin_left = 16.0
	normal.content_margin_right = 16.0
	b.add_theme_stylebox_override("normal", normal)
	var hover := _box(COL_SURFACE_2, 10)
	hover.content_margin_left = 16.0
	hover.content_margin_right = 16.0
	b.add_theme_stylebox_override("hover", hover)
	var pressed := _box(COL_ACCENT, 10)
	pressed.border_color = COL_ACCENT_HOVER
	pressed.set_border_width_all(2)
	pressed.content_margin_left = 16.0
	pressed.content_margin_right = 16.0
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	return b


func _page_backing(inner: Control) -> Control:
	# Panel semi-transparan di belakang konten halaman supaya teks tetap
	# terbaca di atas ilustrasi latar.
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.066, 0.06, 0.72)
	style.set_corner_radius_all(14)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(inner)
	return panel


func _show_page(page: String) -> void:
	for k in pages.keys():
		pages[k].visible = (k == page)
	# sinkronkan toggle tab dengan halaman aktif
	tab_garden.button_pressed = page == "garden"
	tab_shop.button_pressed = page == "shop"
	tab_processing.button_pressed = page == "processing"
	tab_market.button_pressed = page == "market"
	# ganti latar sesuai halaman (market pakai latar banner lembah teh)
	var tex_path := "res://assets/bg_%s.webp" % page
	if page == "market":
		tex_path = "res://assets/banner.webp"
	if ResourceLoader.exists(tex_path):
		bg_texture.texture = load(tex_path)
	else:
		bg_texture.texture = null


func _build_garden_page() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	var h := Label.new()
	h.text = "Garden"
	h.add_theme_font_size_override("font_size", 26)
	h.add_theme_color_override("font_color", COL_TEXT)
	vbox.add_child(h)

	var sub := Label.new()
	sub.text = "Plant tea, wait for it to grow, harvest the leaves."
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", COL_MUTED)
	vbox.add_child(sub)

	vbox.add_child(_spacer(8))

	var buy_row := HBoxContainer.new()
	buy_row.add_theme_constant_override("separation", 10)
	vbox.add_child(buy_row)

	for pid in Game.TEA_PLANTS.keys():
		var info: Dictionary = Game.TEA_PLANTS[pid]
		var b := Button.new()
		b.text = "%s  ·  %ds  ·  +%d leaves" % [
			info["name"], int(info["grow_seconds"]), int(info["yield"]),
		]
		b.add_theme_font_size_override("font_size", 14)
		_style_action_button(b)
		b.pressed.connect(_on_plant.bind(pid))
		buy_row.add_child(b)
		plant_buttons[pid] = b

	plot_price_label = Label.new()
	plot_price_label.add_theme_font_size_override("font_size", 13)
	plot_price_label.add_theme_color_override("font_color", COL_MUTED)
	vbox.add_child(plot_price_label)

	var harvest := Button.new()
	harvest.text = "Nothing ready to harvest"
	harvest.add_theme_font_size_override("font_size", 15)
	_style_action_button(harvest)
	harvest.pressed.connect(_on_harvest)
	harvest.disabled = true
	vbox.add_child(harvest)
	harvest_button = harvest

	vbox.add_child(_spacer(10))
	var gh := Label.new()
	gh.text = "Growing"
	gh.add_theme_font_size_override("font_size", 15)
	gh.add_theme_color_override("font_color", COL_MUTED)
	vbox.add_child(gh)

	plot_bars = VBoxContainer.new()
	plot_bars.size_flags_vertical = Control.SIZE_EXPAND_FILL
	plot_bars.add_theme_constant_override("separation", 6)
	vbox.add_child(plot_bars)

	return _page_backing(scroll)


func _build_shop_page() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	var h := Label.new()
	h.text = "Tea House"
	h.add_theme_font_size_override("font_size", 26)
	h.add_theme_color_override("font_color", COL_TEXT)
	vbox.add_child(h)

	customer_panel = PanelContainer.new()
	var cp_style := _box(COL_SURFACE, 12)
	cp_style.content_margin_left = 18.0
	cp_style.content_margin_right = 18.0
	cp_style.content_margin_top = 14.0
	cp_style.content_margin_bottom = 14.0
	customer_panel.add_theme_stylebox_override("panel", cp_style)
	vbox.add_child(customer_panel)

	var cp_v := VBoxContainer.new()
	cp_v.add_theme_constant_override("separation", 4)
	customer_panel.add_child(cp_v)

	customer_name = Label.new()
	customer_name.add_theme_font_size_override("font_size", 16)
	customer_name.add_theme_color_override("font_color", COL_ACCENT)
	cp_v.add_child(customer_name)

	customer_want = Label.new()
	customer_want.add_theme_font_size_override("font_size", 14)
	customer_want.add_theme_color_override("font_color", COL_TEXT)
	cp_v.add_child(customer_want)

	var serve_row := HBoxContainer.new()
	serve_row.add_theme_constant_override("separation", 10)
	cp_v.add_child(serve_row)

	serve_button = Button.new()
	serve_button.text = "Serve"
	serve_button.add_theme_font_size_override("font_size", 15)
	serve_button.add_theme_color_override("font_color", Color("1a120c"))
	serve_button.add_theme_color_override("font_hover_color", Color("1a120c"))
	serve_button.add_theme_color_override("font_pressed_color", Color("1a120c"))
	serve_button.add_theme_color_override("font_hover_pressed_color", Color("1a120c"))
	serve_button.add_theme_color_override("font_disabled_color", COL_MUTED)
	serve_button.add_theme_stylebox_override("normal", _box(COL_ACCENT, 10))
	serve_button.add_theme_stylebox_override("hover", _box(COL_ACCENT_HOVER, 10))
	var serve_pressed := _box(COL_ACCENT_PRESS, 10)
	serve_button.add_theme_stylebox_override("pressed", serve_pressed)
	serve_button.add_theme_stylebox_override("hover_pressed", serve_pressed)
	var serve_disabled := _box(COL_SURFACE_2, 10)
	serve_button.add_theme_stylebox_override("disabled", serve_disabled)
	serve_button.pressed.connect(_on_serve)
	serve_row.add_child(serve_button)

	vbox.add_child(_spacer(10))

	var sh := Label.new()
	sh.text = "Stock"
	sh.add_theme_font_size_override("font_size", 15)
	sh.add_theme_color_override("font_color", COL_MUTED)
	vbox.add_child(sh)

	stock_rows = VBoxContainer.new()
	stock_rows.add_theme_constant_override("separation", 6)
	vbox.add_child(stock_rows)

	return _page_backing(scroll)


func _build_processing_page() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	var h := Label.new()
	h.text = "Processing"
	h.add_theme_font_size_override("font_size", 26)
	h.add_theme_color_override("font_color", COL_TEXT)
	vbox.add_child(h)

	leaves_label = Label.new()
	leaves_label.add_theme_font_size_override("font_size", 14)
	leaves_label.add_theme_color_override("font_color", COL_MUTED)
	vbox.add_child(leaves_label)

	vbox.add_child(_spacer(6))

	var ph := Label.new()
	ph.text = "Start a batch"
	ph.add_theme_font_size_override("font_size", 15)
	ph.add_theme_color_override("font_color", COL_MUTED)
	vbox.add_child(ph)

	product_rows = VBoxContainer.new()
	product_rows.add_theme_constant_override("separation", 6)
	vbox.add_child(product_rows)

	vbox.add_child(_spacer(4))
	press_button = Button.new()
	press_button.add_theme_font_size_override("font_size", 14)
	_style_action_button(press_button)
	press_button.pressed.connect(_on_press_cake)
	press_button.visible = false
	vbox.add_child(press_button)

	vbox.add_child(_spacer(10))

	var sh := Label.new()
	sh.text = "Stations"
	sh.add_theme_font_size_override("font_size", 15)
	sh.add_theme_color_override("font_color", COL_MUTED)
	vbox.add_child(sh)

	station_rows = VBoxContainer.new()
	station_rows.add_theme_constant_override("separation", 6)
	vbox.add_child(station_rows)

	return _page_backing(scroll)


func _build_market_page() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	var h := Label.new()
	h.text = "Tea Market"
	h.add_theme_font_size_override("font_size", 26)
	h.add_theme_color_override("font_color", COL_TEXT)
	vbox.add_child(h)

	# status pasar live
	var market_panel := PanelContainer.new()
	var mp_style := _box(COL_SURFACE, 12)
	mp_style.content_margin_left = 18.0
	mp_style.content_margin_right = 18.0
	mp_style.content_margin_top = 12.0
	mp_style.content_margin_bottom = 12.0
	market_panel.add_theme_stylebox_override("panel", mp_style)
	vbox.add_child(market_panel)
	var mp_v := VBoxContainer.new()
	mp_v.add_theme_constant_override("separation", 4)
	market_panel.add_child(mp_v)

	market_label = Label.new()
	market_label.add_theme_font_size_override("font_size", 15)
	market_label.add_theme_color_override("font_color", COL_TEXT)
	mp_v.add_child(market_label)

	market_hint = Label.new()
	market_hint.add_theme_font_size_override("font_size", 13)
	market_hint.add_theme_color_override("font_color", COL_MUTED)
	market_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mp_v.add_child(market_hint)

	vbox.add_child(_spacer(8))

	var vh := Label.new()
	vh.text = "Your cakes"
	vh.add_theme_font_size_override("font_size", 15)
	vh.add_theme_color_override("font_color", COL_MUTED)
	vbox.add_child(vh)

	vintage_rows = VBoxContainer.new()
	vintage_rows.add_theme_constant_override("separation", 8)
	vbox.add_child(vintage_rows)

	return _page_backing(scroll)


# ============ REFRESH ============

func _refresh() -> void:
	var plural := "" if Game.plots.size() == 1 else "s"
	coins_label.text = "%d coins  ·  Shop level %d" % [int(Game.coins), Game.shop_level]

	# garden
	for pid in plant_buttons.keys():
		plant_buttons[pid].disabled = Game.coins < Game.plant_price()
	plot_price_label.text = "Next plot: %d coins  ·  %d plot%s planted" % [
		int(Game.plant_price()), Game.plots.size(), plural,
	]
	var ready := Game.ready_plots()
	harvest_button.disabled = ready == 0
	if ready == 0:
		harvest_button.text = "Nothing ready to harvest"
	else:
		harvest_button.text = "Harvest %d plant%s" % [ready, "" if ready == 1 else "s"]

	_clear_children(plot_bars)
	if Game.plots.is_empty():
		var empty := _muted_row("Nothing planted yet. Pick a tea above to start.")
		plot_bars.add_child(empty)
	for p in Game.plots:
		var info: Dictionary = Game.TEA_PLANTS[p["plant"]]
		var now: float = Game._now()
		var total: float = float(info["grow_seconds"])
		var left: float = maxf(0.0, float(p["ready_at"]) - now)
		var frac: float = clampf(1.0 - left / total, 0.0, 1.0)
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 14)
		if left <= 0.0:
			lbl.text = "%s  ·  READY, +%d leaves" % [info["name"], int(info["yield"])]
			lbl.add_theme_color_override("font_color", COL_ACCENT)
		else:
			lbl.text = "%s  ·  %d:%02d remaining" % [
				info["name"], int(left) / 60, int(left) % 60,
			]
			lbl.add_theme_color_override("font_color", COL_MUTED)
		row.add_child(lbl)
		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.value = frac
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		var bg_style := StyleBoxFlat.new()
		bg_style.bg_color = COL_SURFACE
		bg_style.set_corner_radius_all(5)
		var fill_style := StyleBoxFlat.new()
		fill_style.bg_color = COL_ACCENT if left <= 0.0 else Color("b08954")
		fill_style.set_corner_radius_all(5)
		bar.add_theme_stylebox_override("background", bg_style)
		bar.add_theme_stylebox_override("fill", fill_style)
		row.add_child(bar)
		plot_bars.add_child(row)

	# shop
	if Game.customer.is_empty():
		customer_panel.visible = false
	else:
		customer_panel.visible = true
		customer_name.text = str(Game.customer["name"])
		var want_name: String = Game.TEA_PRODUCTS[Game.customer["product"]]["name"]
		customer_want.text = "wants %s  ·  pays %d coins" % [
			want_name, int(Game.customer["reward"]),
		]
		var have: int = int(Game.stock.get(Game.customer["product"], 0))
		serve_button.disabled = have <= 0
		serve_button.text = "Serve" if have > 0 else "No %s in stock" % want_name
	_clear_children(stock_rows)
	var any_stock := false
	for pid in Game.unlocked_products():
		if pid == "puer_cake":
			continue  # kue pu-erh dijual lewat halaman Market, bukan kedai
		var n: int = int(Game.stock.get(pid, 0))
		any_stock = any_stock or n > 0
		var row_text := "%s  ·  %d ready" % [Game.TEA_PRODUCTS[pid]["name"], n]
		# stok tersedia terang, yang kosong redup biar beda status
		if n > 0:
			var bright := _muted_row(row_text)
			bright.add_theme_color_override("font_color", COL_TEXT)
			stock_rows.add_child(bright)
		else:
			stock_rows.add_child(_muted_row(row_text))
	if not any_stock:
		stock_rows.add_child(_muted_row("No tea ready to serve yet."))

	# processing
	leaves_label.text = "Raw leaves: %d" % Game.raw_leaves
	_clear_children(product_rows)
	for pid in Game.unlocked_products():
		var prod: Dictionary = Game.TEA_PRODUCTS[pid]
		if pid == "puer_cake":
			continue  # pu-erh lewat tombol press tersendiri
		var b := Button.new()
		var chain_names := []
		for st in prod["chain"]:
			chain_names.append(Game.STATIONS[st]["name"])
		b.text = "%s  ·  %d leaves  ·  %s  ·  sells %d" % [
			prod["name"], int(prod["raw_cost"]), " -> ".join(chain_names),
			int(prod["serve_price"]),
		]
		b.add_theme_font_size_override("font_size", 14)
		b.disabled = not Game.can_start(pid)
		b.pressed.connect(_on_start_product.bind(pid))
		product_rows.add_child(b)
	var can_press: bool = Game.unlocked_products().has("puer_cake")
	press_button.visible = can_press
	if can_press:
		press_button.text = "Press Pu-erh Cake  ·  %d leaves + %d coins" % [
			int(Game.TEA_PRODUCTS["puer_cake"]["raw_cost"]),
			int(Game.TEA_PRODUCTS["puer_cake"]["press_cost"]),
		]
		press_button.disabled = not Game.can_start("puer_cake")

	_clear_children(station_rows)
	for st in Game.STATIONS.keys():
		var sinfo: Dictionary = Game.STATIONS[st]
		var q: Array = Game.station_queues[st]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", COL_TEXT)
		if q.is_empty():
			lbl.text = "%s  ·  idle" % sinfo["name"]
		else:
			var first: Dictionary = q[0]
			var left: float = maxf(0.0, float(first["done_at"]) - Game._now())
			lbl.text = "%s  ·  working on %s  ·  %ds left  ·  %d in queue" % [
				sinfo["name"], Game.TEA_PRODUCTS[first["product"]]["name"],
				int(ceil(left)), q.size(),
			]
		row.add_child(lbl)
		var spacer2 := Control.new()
		spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer2)
		var buy := Button.new()
		var cost := Game.station_cost(st)
		buy.text = "+1  ·  %d coins" % int(cost)
		buy.add_theme_font_size_override("font_size", 13)
		buy.disabled = Game.coins < cost
		buy.pressed.connect(_on_buy_station.bind(st))
		row.add_child(buy)
		station_rows.add_child(row)

	# market
	var m_mult: float = Game.market_mult()
	var m_dir: String = Game.market_direction()
	var dir_icon := "="
	var dir_color := COL_MUTED
	if m_dir == "rising":
		dir_icon = "▲"
		dir_color = COL_SUCCESS
	elif m_dir == "falling":
		dir_icon = "▼"
		dir_color = COL_ACCENT
	market_label.text = "Market %s %dx  ·  base cake %d coins" % [
		dir_icon, snappedf(m_mult, 0.01), int(Game.PUER_BASE_PRICE),
	]
	market_label.add_theme_color_override("font_color", dir_color)
	market_hint.text = (
		"Cakes age in real time, even while the game is closed. "
		+ "Sell at a high tide or hold for the next age tier. "
		+ "Fresh cakes sell for less than the cost of making them, "
		+ "aged cakes are where the real money is."
	)

	_clear_children(vintage_rows)
	if Game.vintage.is_empty():
		var vempty := _muted_row(
			"No cakes yet. Press a Pu-erh cake in Processing, dry it, then it lands here to age."
		)
		vintage_rows.add_child(vempty)
	for i in Game.vintage.size():
		var cake: Dictionary = Game.vintage[i]
		var finished_at: float = float(cake["finished_at"])
		var age_sec := Game.cake_age_seconds(finished_at)
		var info: Dictionary = Game.age_info(age_sec)
		var price := Game.puer_price(finished_at)
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 10)
		var vlbl := Label.new()
		vlbl.add_theme_font_size_override("font_size", 14)
		var age_txt := _human_age(age_sec)
		var next_txt := ""
		if float(info["next_seconds"]) >= 0.0:
			var remain: float = float(info["next_seconds"]) - age_sec
			next_txt = "  ·  next tier in %s (x%s)" % [
				_human_age(remain), _fmt_mult(float(info["next_mult"])),
			]
		vlbl.text = "Pu-erh Cake  ·  %s (x%s)  ·  sells %d coins%s" % [
			info["tier_name"], _fmt_mult(float(info["mult"])), int(price), next_txt,
		]
		var is_fresh: bool = int(info["tier_index"]) == 0
		vlbl.add_theme_color_override(
			"font_color", COL_MUTED if is_fresh else COL_ACCENT
		)
		row2.add_child(vlbl)
		var spacer3 := Control.new()
		spacer3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(spacer3)
		var sell := Button.new()
		sell.text = "Sell  ·  %d" % int(price)
		sell.add_theme_font_size_override("font_size", 13)
		sell.pressed.connect(_on_sell_cake.bind(i))
		row2.add_child(sell)
		vintage_rows.add_child(row2)


func _human_age(seconds: float) -> String:
	if seconds < 90.0:
		return "%ds" % int(seconds)
	if seconds < 5400.0:
		return "%dm" % int(round(seconds / 60.0))
	if seconds < 129600.0:
		return "%dh" % int(round(seconds / 3600.0))
	return "%dd" % int(round(seconds / 86400.0))


func _fmt_mult(m: float) -> String:
	# tampilkan tanpa nol menggantung: 2 -> "2", 2.5 -> "2.5", 1.25 -> "1.25"
	var rounded: float = snappedf(m, 0.01)
	if absf(rounded - roundf(rounded)) < 0.005:
		return str(int(roundf(rounded)))
	return str(rounded).pad_decimals(2).rstrip("0").rstrip(".")


func _clear_children(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()


func _muted_row(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", COL_MUTED)
	return l


# ============ AKSI ============

func _on_plant(plant_id: String) -> void:
	if Game.buy_plot(plant_id):
		_flash("%s planted." % Game.TEA_PLANTS[plant_id]["name"])


func _on_harvest() -> void:
	var got := Game.harvest_all()
	if got > 0:
		_flash("+%d raw leaves" % got)
	else:
		_flash("Nothing ready yet.")


func _on_start_product(pid: String) -> void:
	if Game.start_product(pid):
		_flash("%s batch started." % Game.TEA_PRODUCTS[pid]["name"])


func _on_press_cake() -> void:
	if Game.start_product("puer_cake"):
		_flash("Cake pressed, drying on the rack.")


func _on_buy_station(st: String) -> void:
	if Game.buy_station(st):
		_flash("%s added." % Game.STATIONS[st]["name"])


func _on_sell_cake(index: int) -> void:
	if index >= Game.vintage.size():
		return
	var price := Game.puer_price(float(Game.vintage[index]["finished_at"]))
	if Game.sell_cake(index):
		_flash("Cake sold for %d coins." % int(price))


func _on_serve() -> void:
	if Game.customer.is_empty():
		return
	var who: String = str(Game.customer["name"])
	var pay: float = float(Game.customer["reward"])
	if Game.serve_customer():
		_flash("Served %s. +%d coins" % [who, int(pay)])


func _flash(msg: String) -> void:
	status_label.text = msg
	if status_tween and status_tween.is_valid():
		status_tween.kill()
	status_label.modulate.a = 1.0
	status_tween = create_tween()
	status_tween.tween_interval(2.5)
	status_tween.tween_property(status_label, "modulate:a", 0.0, 0.6)


# ============ STYLING ============

func _style_action_button(btn: Button) -> void:
	btn.add_theme_color_override("font_color", COL_TEXT)
	btn.add_theme_color_override("font_hover_color", COL_TEXT)
	btn.add_theme_color_override("font_pressed_color", Color("1a120c"))
	btn.add_theme_color_override("font_hover_pressed_color", Color("1a120c"))
	btn.add_theme_color_override("font_disabled_color", COL_MUTED)
	btn.add_theme_stylebox_override("normal", _box(COL_SURFACE, 10))
	btn.add_theme_stylebox_override("hover", _box(COL_SURFACE_2, 10))
	var pr := _box(COL_ACCENT_PRESS, 10)
	btn.add_theme_stylebox_override("pressed", pr)
	btn.add_theme_stylebox_override("hover_pressed", pr)
	var dis := _box(Color("232220"), 10)
	btn.add_theme_stylebox_override("disabled", dis)


func _box(c: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


# ============ SELFTEST ============

func _run_selftest() -> void:
	var fails := 0
	Game.reset()

	# --- kebun ---
	fails += _check(absf(Game.plant_price() - 15.0) < 0.01, "first plot costs 15")
	fails += _check(Game.buy_plot("green"), "can plant green tea with 20 coins")
	fails += _check(absf(Game.coins - 5.0) < 0.01, "coins deducted to 5")
	fails += _check(not Game.buy_plot("green"), "cannot afford second plot at 5 coins")
	fails += _check(Game.ready_plots() == 0, "nothing ready right after planting")
	var p: Dictionary = Game.plots[0]
	p["ready_at"] = Game._now() - 1.0  # paksa matang
	fails += _check(Game.ready_plots() == 1, "plot ready after time passes")
	fails += _check(Game.harvest_all() == 3, "green tea yields 3 leaves")
	fails += _check(Game.raw_leaves == 3, "raw leaves banked")
	fails += _check(Game.plots.is_empty(), "plot cleared after harvest")

	# --- pengolahan green tea ---
	fails += _check(Game.can_start("green_tea"), "can start green tea (3 leaves, 1 dryer)")
	fails += _check(Game.start_product("green_tea"), "green tea batch started")
	fails += _check(Game.raw_leaves == 0, "leaves consumed by batch")
	fails += _check(Game.station_queues["dryer"].size() == 1, "batch queued at dryer")
	Game.station_queues["dryer"][0]["done_at"] = Game._now() - 0.1
	Game.poll_stations()
	fails += _check(int(Game.stock.get("green_tea", 0)) == 1, "green tea ready after step completes")

	# --- rantai multi-stasiun: white tea (withering -> dryer) ---
	Game.coins = 100.0
	Game.raw_leaves = 20
	fails += _check(Game.buy_plot("white"), "plant white tea")
	fails += _check(Game.can_start("white_tea"), "can start white tea")
	fails += _check(Game.start_product("white_tea"), "white tea batch started")
	fails += _check(Game.station_queues["withering"].size() == 1, "white tea starts at withering")
	Game.station_queues["withering"][0]["done_at"] = Game._now() - 0.1
	Game.poll_stations()
	fails += _check(
		Game.station_queues["dryer"].size() == 1 and Game.station_queues["withering"].is_empty(),
		"white tea moved from withering to dryer"
	)
	Game.station_queues["dryer"][0]["done_at"] = Game._now() - 0.1
	Game.poll_stations()
	fails += _check(int(Game.stock.get("white_tea", 0)) == 1, "white tea finished into stock")

	# --- antrian penuh menolak ---
	Game.raw_leaves = 99
	# dryer count = 1, isi antrian 2 item -> slot penuh
	Game.station_queues["dryer"] = [
		{"product": "white_tea", "step": 1, "done_at": Game._now() + 99.0},
		{"product": "white_tea", "step": 1, "done_at": Game._now() + 99.0},
	]
	fails += _check(not Game.can_start("green_tea"), "cannot start when station queue is full")

	# --- level kedai ---
	Game.xp = 29
	Game.check_level_up()
	fails += _check(Game.shop_level == 1, "stays level 1 at 29 xp")
	Game.xp = 30
	Game.check_level_up()
	fails += _check(Game.shop_level == 2, "level 2 at 30 xp")
	fails += _check(Game.unlocked_products().has("oolong_tea"), "oolong unlocked at level 2")

	# --- pu-erh: press -> rantai -> aging -> collect ---
	Game.shop_level = 3
	Game.xp = 200
	Game.raw_leaves = 50
	Game.coins = 500.0
	for st in Game.station_queues.keys():
		Game.station_queues[st] = []  # kosongkan sisa tes antrian
	fails += _check(Game.buy_station("rolling"), "buy rolling table")
	fails += _check(Game.buy_station("oxidation"), "buy oxidation tray")
	fails += _check(Game.start_product("puer_cake"), "puer cake press started")
	fails += _check(absf(Game.coins - 120.0) < 0.01, "coins after stations + press = 120")
	for st in ["withering", "rolling", "dryer"]:
		# majukan satu stasiun per iterasi: pindah stasiun me-reset done_at
		if not Game.station_queues[st].is_empty():
			Game.station_queues[st][0]["done_at"] = Game._now() - 0.1
		Game.poll_stations()
	fails += _check(Game.aging.size() == 1, "puer cake enters aging rack")
	if Game.aging.size() > 0:
		Game.aging[0]["ready_at"] = Game._now() - 1.0
		fails += _check(Game.collect_cakes() == 1, "cake collected after drying")
		fails += _check(Game.vintage.size() == 1, "dried cake enters vintage shelf")
	else:
		fails += 2

	# --- pasar & aging (hook utama) ---
	var mm: float = Game.market_mult()
	fails += _check(mm >= Game.MARKET_MIN and mm <= Game.MARKET_MAX, "market mult within bounds")
	fails += _check(absf(Game.market_mult_at(1757000000.0) - Game.market_mult_at(1757000000.0)) < 1e-9,
		"market price deterministic at fixed time")
	var info0: Dictionary = Game.age_info(0.0)
	fails += _check(info0["tier_name"] == "Fresh" and absf(float(info0["mult"]) - 1.0) < 0.01,
		"fresh cake is tier 0 x1")
	var info3d: Dictionary = Game.age_info(259200.0 + 1.0)
	fails += _check(info3d["tier_name"] == "Aged" and absf(float(info3d["mult"]) - 2.0) < 0.01,
		"3-day-old cake is Aged x2")
	var fresh_price: float = Game.puer_price(Game._now())
	fails += _check(fresh_price > 0.0, "puer price computes positive")
	# simulasi kue tua: finished_at dimundurkan 8 hari -> tier Reserve x4
	var old_finished: float = Game._now() - (604800.0 + 3600.0)
	var old_info: Dictionary = Game.age_info(Game.cake_age_seconds(old_finished))
	fails += _check(old_info["tier_name"] == "Reserve" and absf(float(old_info["mult"]) - 4.0) < 0.01,
		"8-day-old cake is Reserve x4")
	fails += _check(Game.puer_price(old_finished) > fresh_price * 3.0,
		"aged cake worth far more than fresh")
	fails += _check(not Game.sell_cake(99), "selling invalid index rejected")
	var coins_pre_sell: float = Game.coins
	fails += _check(Game.sell_cake(0), "sell cake succeeds")
	fails += _check(Game.coins > coins_pre_sell, "selling credits coins")
	fails += _check(Game.vintage.is_empty(), "vintage empty after selling")

	# --- pelanggan ---
	Game.stock = {"green_tea": 2}  # stok tunggal biar pilihan pelanggan deterministik
	Game.customer = {}
	Game.customer_cooldown = 0.0
	Game.maybe_spawn_customer(1.0)
	fails += _check(not Game.customer.is_empty(), "customer spawns when stock exists")
	fails += _check(Game.customer["product"] == "green_tea", "customer wants available tea")
	var coins_before: float = Game.coins
	fails += _check(Game.serve_customer(), "serve succeeds")
	fails += _check(Game.coins == coins_before + 6.0, "serving green tea pays 6 coins")
	fails += _check(int(Game.stock["green_tea"]) == 1, "stock decremented")
	fails += _check(not Game.serve_customer(), "no customer to serve after")
	Game.maybe_spawn_customer(1.0)  # cooldown 6 detik belum habis
	fails += _check(Game.customer.is_empty(), "cooldown blocks instant respawn")

	# --- save/load ---
	Game.save()
	var saved_coins: float = Game.coins
	Game.reset()
	fails += _check(absf(Game.coins - 20.0) < 0.01, "reset returns to starting coins")
	Game.load_save()
	fails += _check(absf(Game.coins - saved_coins) < 0.01, "load restores coins")
	fails += _check(int(Game.stock.get("green_tea", 0)) == 1, "load restores stock")

	if fails == 0:
		print("SELFTEST PASS")
	else:
		print("SELFTEST FAIL: %d assertion(s) failed" % fails)
	get_tree().quit(fails)


func _check(cond: bool, msg: String) -> int:
	print("  [%s] %s" % ["ok" if cond else "FAIL", msg])
	return 0 if cond else 1


# ============ SCREENSHOT ============

func _run_screenshot() -> void:
	# isi state contoh biar screenshot informatif
	Game.coins = 87.0
	Game.raw_leaves = 12
	Game.stock = {"green_tea": 3, "white_tea": 1}
	Game.buy_plot("green")
	Game.buy_plot("white")
	Game.plots[0]["ready_at"] = Game._now() - 1.0
	Game.plots[1]["ready_at"] = Game._now() + 95.0
	Game.start_product("white_tea")
	Game.customer = {
		"name": "Nyonya Lian", "product": "green_tea",
		"reward": 6.0, "xp": 1, "patience": 28.0,
	}
	# kue contoh: satu fresh, satu berumur 8 hari (Reserve)
	Game.vintage = [
		{"finished_at": Game._now() - 120.0},
		{"finished_at": Game._now() - (604800.0 + 3600.0)},
	]
	var out_dir := ProjectSettings.globalize_path("user://")
	for entry in [["garden", "garden"], ["shop", "shop"], ["processing", "processing"], ["market", "market"]]:
		_show_page(entry[0])
		_refresh()
		await get_tree().process_frame
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var out: String = out_dir + "screenshot_" + str(entry[1]) + ".png"
		img.save_png(out)
		print("SCREENSHOT_SAVED: " + out)
	get_tree().quit()
