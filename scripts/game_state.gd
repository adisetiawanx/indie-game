extends Node

## Slow Leaf - state ekonomi game (autoload Game).
## SEMUA angka dan aturan ekonomi hidup di sini. UI cuma pembaca.
## Desain lengkap ada di GAME.md.

signal coins_changed
signal stock_changed
signal xp_changed

const SAVE_PATH := "user://save.json"
const VERSION := "0.1.0-m0"

# --- Data statis: tanaman (waktu dalam detik) ---
const TEA_PLANTS := {
	"green": {"name": "Green Tea", "grow_seconds": 45.0, "yield": 3},
	"white": {"name": "White Tea", "grow_seconds": 120.0, "yield": 5},
	"oolong": {"name": "Oolong", "grow_seconds": 300.0, "yield": 8},
}

# --- Data statis: produk teh ---
# station = tempat mulai proses, steps = berapa stasiun dilewati berurutan.
# Urutan stasiun mengikuti rantai: withering -> rolling -> oxidation -> dryer.
const TEA_PRODUCTS := {
	"green_tea": {
		"name": "Green Tea", "plant": "green", "raw_cost": 3,
		"chain": ["dryer"], "serve_price": 6, "xp": 1,
	},
	"white_tea": {
		"name": "White Tea", "plant": "white", "raw_cost": 5,
		"chain": ["withering", "dryer"], "serve_price": 14, "xp": 2,
	},
	"oolong_tea": {
		"name": "Oolong Tea", "plant": "oolong", "raw_cost": 8,
		"chain": ["withering", "rolling", "oxidation"], "serve_price": 30, "xp": 4,
	},
	"puer_cake": {
		"name": "Pu-erh Cake", "plant": "oolong", "raw_cost": 8,
		"press_cost": 10, "chain": ["withering", "rolling", "dryer"],
		"serve_price": 40, "xp": 6,
	},
}

# --- Data statis: stasiun ---
const STATIONS := {
	"withering": {"name": "Withering Rack", "base_cost": 25.0, "growth": 1.6},
	"dryer": {"name": "Tea Dryer", "base_cost": 60.0, "growth": 1.6},
	"rolling": {"name": "Rolling Table", "base_cost": 120.0, "growth": 1.6},
	"oxidation": {"name": "Oxidation Tray", "base_cost": 250.0, "growth": 1.6},
}

# --- Level kedai: membuka resep dan stasiun ---
const SHOP_LEVELS := {
	1: {"xp": 0, "unlocks": ["green_tea", "white_tea"]},
	2: {"xp": 30, "unlocks": ["oolong_tea", "rolling"]},
	3: {"xp": 80, "unlocks": ["puer_cake", "oxidation"]},
}

const XP_LEVELS := [0, 30, 80, 160]  # xp total minimum per level kedai

# Durasi satu langkah stasiun (detik) untuk semua produk di M0.
const STEP_SECONDS := 10.0

# --- Pasar & aging pu-erh (hook utama, lihat GAME.md) ---
# Harga dasar kue pu-erh sebelum multiplier.
const PUER_BASE_PRICE := 40.0
# Tier aging berbasis WAKTU RIIL (detik), berlaku juga saat game mati.
const AGE_TIERS := [
	{"name": "Fresh", "seconds": 0.0, "mult": 1.0},
	{"name": "Aged", "seconds": 259200.0, "mult": 2.0},       # 3 hari
	{"name": "Reserve", "seconds": 604800.0, "mult": 4.0},    # 7 hari
	{"name": "Vintage", "seconds": 2592000.0, "mult": 12.0},  # 30 hari
	{"name": "Ancestral", "seconds": 8640000.0, "mult": 40.0}, # 100 hari
]
# Kisaran multiplier pasar.
const MARKET_MIN := 0.5
const MARKET_MAX := 1.7

# --- Data statis: pelanggan ---
const CUSTOMER_NAMES := [
	"Mira", "Tomas", "Aiko", "Bram", "Selin", "Oren", "Yuki", "Pak Darma",
	"Nyonya Lian", "Si Kecil Jun", "Pak Wayan", "Ibu Ratna",
]

# --- State dinamis ---
var coins: float = 20.0
var xp: int = 0
var shop_level: int = 1
var raw_leaves: int = 0

var plots: Array = []            # [{plant, planted_at, ready_at}]
var plot_price: float = 15.0
var plot_growth: float = 1.5

var station_counts := {"withering": 1, "dryer": 1, "rolling": 0, "oxidation": 0}
var station_queues := {}         # station -> [{product, step_index, done_at}]
var batch_counter: int = 0

var stock := {}                  # product_id -> jumlah siap saji
var aging := []                  # [{ready_at}] kue pu-erh yang sedang mengering
var vintage := []                # [{finished_at}] kue kering, menua real-time

var customer: Dictionary = {}    # pelanggan aktif {name, product, reward, xp}
var customer_cooldown: float = 0.0

var stats_served: int = 0
var stats_earned: float = 0.0


func _ready() -> void:
	for st in STATIONS.keys():
		station_queues[st] = []


# ============ LEVEL KEDAI ============

func xp_for_level(level: int) -> int:
	if level - 1 < XP_LEVELS.size():
		return XP_LEVELS[level - 1]
	return XP_LEVELS[XP_LEVELS.size() - 1] * (level - XP_LEVELS.size() + 1)


func unlocked_products() -> Array:
	var out := []
	for pid in TEA_PRODUCTS.keys():
		var lvl: int = _product_level(pid)
		if lvl <= shop_level:
			out.append(pid)
	return out


func _product_level(pid: String) -> int:
	for lvl in SHOP_LEVELS.keys():
		if pid in SHOP_LEVELS[lvl]["unlocks"]:
			return lvl
	return 1


func check_level_up() -> void:
	while shop_level < XP_LEVELS.size() and xp >= XP_LEVELS[shop_level]:
		shop_level += 1


# ============ KEBUN ============

func plant_price() -> float:
	return plot_price * pow(plot_growth, plots.size())


func can_buy_plot() -> bool:
	return coins >= plant_price()


func buy_plot(plant_id: String) -> bool:
	if not TEA_PLANTS.has(plant_id) or not can_buy_plot():
		return false
	coins -= plant_price()
	var now: float = _now()
	plots.append({
		"plant": plant_id,
		"planted_at": now,
		"ready_at": now + float(TEA_PLANTS[plant_id]["grow_seconds"]),
	})
	coins_changed.emit()
	return true


func ready_plots() -> int:
	var now: float = _now()
	var n := 0
	for p in plots:
		if now >= float(p["ready_at"]):
			n += 1
	return n


func harvest_all() -> int:
	var now: float = _now()
	var got := 0
	var remaining := []
	for p in plots:
		if now >= float(p["ready_at"]):
			got += int(TEA_PLANTS[p["plant"]]["yield"])
		else:
			remaining.append(p)
	plots = remaining
	if got > 0:
		raw_leaves += got
		stock_changed.emit()
	return got


# ============ PENGOLAHAN ============

func station_cost(station: String) -> float:
	var base: float = STATIONS[station]["base_cost"]
	return base * pow(STATIONS[station]["growth"], station_counts[station])


func buy_station(station: String) -> bool:
	if not STATIONS.has(station):
		return false
	var cost := station_cost(station)
	if coins < cost:
		return false
	coins -= cost
	station_counts[station] = int(station_counts[station]) + 1
	coins_changed.emit()
	return true


func can_start(product_id: String) -> bool:
	if not unlocked_products().has(product_id):
		return false
	var prod: Dictionary = TEA_PRODUCTS[product_id]
	var press: int = int(prod.get("press_cost", 0))
	if raw_leaves < int(prod["raw_cost"]) or coins < press:
		return false
	# tiap stasiun di rantai harus punya slot antrian kosong
	for st in prod["chain"]:
		if station_queues[st].size() >= station_counts[st]:
			return false
	return true


func start_product(product_id: String) -> bool:
	if not can_start(product_id):
		return false
	var prod: Dictionary = TEA_PRODUCTS[product_id]
	raw_leaves -= int(prod["raw_cost"])
	var press: int = int(prod.get("press_cost", 0))
	if press > 0:
		coins -= press
		coins_changed.emit()
	stock_changed.emit()
	# Batch mulai di stasiun PERTAMA saja. Pindah stasiun terjadi saat
	# langkah selesai (lihat _finish_step), bukan semua sekaligus.
	batch_counter += 1
	station_queues[prod["chain"][0]].append({
		"id": batch_counter,
		"product": product_id,
		"step": 0,
		"done_at": _now() + STEP_SECONDS,
	})
	return true


func poll_stations() -> void:
	var now: float = _now()
	for st in station_queues.keys():
		var q: Array = station_queues[st]
		var remaining := []
		for item in q:
			if now >= float(item["done_at"]):
				_finish_step(item)
			else:
				remaining.append(item)
		station_queues[st] = remaining


func _finish_step(item: Dictionary) -> void:
	var prod: Dictionary = TEA_PRODUCTS[item["product"]]
	var chain: Array = prod["chain"]
	if int(item["step"]) >= chain.size() - 1:
		# langkah terakhir: kue pu-erh masuk rack pengering, lainnya ke stok
		if item["product"] == "puer_cake":
			aging.append({"ready_at": _now() + 60.0})
		else:
			stock[item["product"]] = int(stock.get(item["product"], 0)) + 1
			stock_changed.emit()
	else:
		# langkah bukan terakhir: lanjut ke stasiun berikutnya, mulai sekarang
		item["step"] = int(item["step"]) + 1
		item["done_at"] = _now() + STEP_SECONDS
		var next_st: String = chain[int(item["step"])]
		station_queues[next_st].append(item)


func aging_count() -> int:
	return aging.size()


func ready_cakes() -> int:
	var now: float = _now()
	var n := 0
	for c in aging:
		if now >= float(c["ready_at"]):
			n += 1
	return n


func collect_cakes() -> int:
	var now: float = _now()
	var remaining := []
	var got := 0
	for c in aging:
		if now >= float(c["ready_at"]):
			got += 1
			vintage.append({"finished_at": now})
		else:
			remaining.append(c)
	aging = remaining
	if got > 0:
		stock_changed.emit()
	return got


# ============ PASAR & AGING PU-ERH ============

## Multiplier pasar deterministik dari jam unix: sama untuk semua pemain,
## berputar mulus tanpa save state, tetap benar setelah game mati berhari-hari.
func market_mult() -> float:
	return market_mult_at(_now())


## Arah pasar: bandingkan multiplier sekarang vs satu jam lalu.
func market_direction() -> String:
	var m_now: float = market_mult()
	var m_prev: float = market_mult_at(_now() - 3600.0)
	if m_now > m_prev * 1.03:
		return "rising"
	elif m_now < m_prev * 0.97:
		return "falling"
	return "steady"


func market_mult_at(unix_seconds: float) -> float:
	var hours: float = unix_seconds / 3600.0
	var wave: float = (
		0.35 * sin(hours * 0.26)
		+ 0.22 * sin(hours * 0.83 + 1.7)
		+ 0.13 * sin(hours * 2.1 + 4.2)
	)
	var t: float = (wave + 0.7) / 1.4
	return MARKET_MIN + t * (MARKET_MAX - MARKET_MIN)


func age_info(age_seconds: float) -> Dictionary:
	var idx := 0
	for i in AGE_TIERS.size():
		if age_seconds >= float(AGE_TIERS[i]["seconds"]):
			idx = i
	var tier: Dictionary = AGE_TIERS[idx]
	var out := {
		"tier_index": idx,
		"tier_name": tier["name"],
		"mult": float(tier["mult"]),
		"next_seconds": -1.0,
		"next_mult": 0.0,
	}
	if idx + 1 < AGE_TIERS.size():
		out["next_seconds"] = float(AGE_TIERS[idx + 1]["seconds"])
		out["next_mult"] = float(AGE_TIERS[idx + 1]["mult"])
	return out


func cake_age_seconds(finished_at: float) -> float:
	return maxf(0.0, _now() - finished_at)


func puer_price(finished_at: float) -> float:
	var info := age_info(cake_age_seconds(finished_at))
	return PUER_BASE_PRICE * float(info["mult"]) * market_mult()


func vintage_count() -> int:
	return vintage.size()


func sell_cake(index: int) -> bool:
	if index < 0 or index >= vintage.size():
		return false
	var cake: Dictionary = vintage[index]
	var price := puer_price(float(cake["finished_at"]))
	coins += price
	stats_earned += price
	vintage.remove_at(index)
	coins_changed.emit()
	return true


# ============ PENYAJIAN ============

func maybe_spawn_customer(delta: float) -> void:
	if not customer.is_empty():
		return
	customer_cooldown -= delta
	if customer_cooldown > 0.0:
		return
	var avail := unlocked_products()
	avail = avail.filter(func(pid): return int(stock.get(pid, 0)) > 0)
	if avail.is_empty():
		return
	var pid: String = avail[randi() % avail.size()]
	var prod: Dictionary = TEA_PRODUCTS[pid]
	customer = {
		"name": CUSTOMER_NAMES[randi() % CUSTOMER_NAMES.size()],
		"product": pid,
		"reward": float(prod["serve_price"]),
		"xp": int(prod["xp"]),
		"patience": 30.0,
	}


func serve_customer() -> bool:
	if customer.is_empty():
		return false
	var pid: String = customer["product"]
	if int(stock.get(pid, 0)) <= 0:
		return false
	stock[pid] = int(stock[pid]) - 1
	coins += float(customer["reward"])
	stats_earned += float(customer["reward"])
	xp += int(customer["xp"])
	stats_served += 1
	customer = {}
	customer_cooldown = 6.0
	check_level_up()
	coins_changed.emit()
	stock_changed.emit()
	xp_changed.emit()
	return true


# ============ UTIL ============

func _now() -> float:
	return Time.get_unix_time_from_system()


func reset() -> void:
	coins = 20.0
	xp = 0
	shop_level = 1
	raw_leaves = 0
	plots = []
	plot_price = 15.0
	station_counts = {"withering": 1, "dryer": 1, "rolling": 0, "oxidation": 0}
	for st in station_queues.keys():
		station_queues[st] = []
	stock = {}
	aging = []
	vintage = []
	customer = {}
	customer_cooldown = 0.0
	stats_served = 0
	stats_earned = 0.0


func save() -> void:
	var data := {
		"version": VERSION,
		"coins": coins, "xp": xp, "shop_level": shop_level,
		"raw_leaves": raw_leaves, "plots": plots,
		"plot_price": plot_price, "station_counts": station_counts,
		"stock": stock, "aging": aging, "vintage": vintage,
		"stats_served": stats_served,
		"stats_earned": stats_earned,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Gagal simpan save: %d" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data))
	f.close()


func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return
	coins = float(parsed.get("coins", 20.0))
	xp = int(parsed.get("xp", 0))
	shop_level = int(parsed.get("shop_level", 1))
	raw_leaves = int(parsed.get("raw_leaves", 0))
	plots = parsed.get("plots", [])
	plot_price = float(parsed.get("plot_price", 15.0))
	var sc: Dictionary = parsed.get("station_counts", {})
	for k in sc.keys():
		if station_counts.has(k):
			station_counts[k] = int(sc[k])
	stock = parsed.get("stock", {})
	aging = parsed.get("aging", [])
	vintage = parsed.get("vintage", [])
	stats_served = int(parsed.get("stats_served", 0))
	stats_earned = float(parsed.get("stats_earned", 0.0))
