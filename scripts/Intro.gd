extends Control
## ============================================================================
##  PARALLAX — cutscene introduttiva (dopo GIOCA, prima del gioco)
##  Racconta la premessa senza spoiler: le notti delle Perseidi
##  nell'osservatorio, qualcuno che annotava tutto, una fotografia strappata
##  dal tempo, e il compito del giocatore: ricomporre il ricordo e aprire
##  la porta. Niente titolo: il logo resta al menu.
##
##  Beat (~21s, si salta con clic o tasto qualsiasi):
##   1. stelle + meteore (le Perseidi)          -> frase 1
##   2. la fotografia sale e fluttua            -> frase 2
##   3. la foto trema e si strappa in due meta' -> frase 3
##   4. "le stanze ricordano"                   -> frase 4
##   5. l'obiettivo del giocatore               -> frase 5 -> Game.tscn
##
##  Tutto generato in codice; usa solo asset esistenti (start_bg.png,
##  makina.otf). La musica continua dall'autoload Audio.
## ============================================================================

const P := "res://assets/parallax/"

const LINES: Array[String] = [
	"Ogni agosto, le Perseidi riempivano il cielo.",
	"Qualcuno restava quassù a guardarle, notte dopo notte,\ne annotava tutto.",
	"Poi il tempo ha strappato qualcosa.",
	"Ma le stanze ricordano: le date, i colori, le stelle.",
	"Ritrova ciò che manca. Ricomponi il ricordo...\ne apri quella porta.",
]

# inizio di ogni frase (secondi); ogni frase resta ~2.4s + dissolvenze
const LINE_TIMES: Array[float] = [1.5, 6.0, 10.4, 13.8, 17.2]
const TEAR_TIME := 10.8      # momento dello strappo della foto
const END_TIME := 20.6       # inizio dissolvenza finale

var _leaving := false
var _black: ColorRect
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = load(P + "makina.otf")
	ui_theme.default_font_size = 26
	theme = ui_theme
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()

	# --- cielo notturno (fondo) ---------------------------------------------
	var sky := ColorRect.new()
	sky.color = Color(0.02, 0.03, 0.08)
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)

	# --- tre strati di stelle (lontano / medio / vicino) --------------------
	# Ogni strato scorre a velocita' diversa: e' la parallasse.
	var star_tex := _make_star_texture(16)
	_add_star_layer(star_tex, 90, 12.0, Color(0.75, 0.80, 1.0), Vector2(0.20, 0.35))   # lontane
	_add_star_layer(star_tex, 60, 22.0, Color(0.90, 0.92, 1.0), Vector2(0.45, 0.75))   # medie
	_add_star_layer(star_tex, 34, 40.0, Color(1.00, 0.97, 0.90), Vector2(0.90, 1.50))  # vicine

	# --- meteore (le Perseidi) ----------------------------------------------
	# Qualche scia luminosa nei primi ~12 secondi, a istanti leggermente casuali.
	for t: float in [1.0, 2.6, 4.1, 5.4, 7.3, 9.0, 11.5]:
		var tw := create_tween()
		tw.tween_interval(t + _rng.randf_range(-0.3, 0.3))
		tw.tween_callback(_spawn_meteor)

	# --- fotografia rovinata (fluttua nello spazio) -------------------------
	var photo_tex: Texture2D = load(P + "start_bg.png")
	var pw := 620.0
	var ph := 349.0
	var target := Vector2((1280 - pw) / 2.0, (720 - ph) / 2.0 - 30)

	var photo := TextureRect.new()
	photo.texture = photo_tex
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_SCALE
	photo.size = Vector2(pw, ph)
	photo.position = target + Vector2(0, 90)      # parte piu' in basso
	photo.modulate = Color(1, 1, 1, 0)            # e trasparente
	photo.pivot_offset = Vector2(pw / 2.0, ph / 2.0)
	photo.scale = Vector2(0.94, 0.94)
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(photo)

	# --- le due meta' dello strappo (nascoste fino al beat 3) ---------------
	var tex_size := photo_tex.get_size()
	var left_half := _make_half(photo_tex, Rect2(Vector2.ZERO, Vector2(tex_size.x / 2.0, tex_size.y)),
		target, Vector2(pw / 2.0, ph))
	var right_half := _make_half(photo_tex, Rect2(Vector2(tex_size.x / 2.0, 0), Vector2(tex_size.x / 2.0, tex_size.y)),
		target + Vector2(pw / 2.0, 0), Vector2(pw / 2.0, ph))

	# --- frasi ----------------------------------------------------------------
	for i in LINES.size():
		var label := _make_line(LINES[i])
		_flash_line(label, LINE_TIMES[i], 2.4, 0.9, 0.7)

	# --- suggerimento "salta" -----------------------------------------------
	var skip := Label.new()
	skip.text = "clic per saltare"
	skip.add_theme_font_size_override("font_size", 16)
	skip.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	skip.position = Vector2(1080, 686)
	skip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(skip)

	# --- velo nero per la dissolvenza finale --------------------------------
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.modulate = Color(1, 1, 1, 0)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)

	# ========================================================================
	#  Sequenza temporale
	# ========================================================================

	# Beat 2: la fotografia sale e appare (3.5s -> 6.5s), poi respira.
	var photo_tw := create_tween().set_parallel(true)
	photo_tw.tween_property(photo, "position", target, 3.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(3.5)
	photo_tw.tween_property(photo, "modulate:a", 1.0, 2.5).set_delay(3.5)
	photo_tw.tween_property(photo, "scale", Vector2.ONE, 3.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(3.5)

	# Beat 3: tremito, poi strappo in due meta' che si allontanano.
	var tear_tw := create_tween()
	tear_tw.tween_interval(TEAR_TIME - 0.9)
	for i in 6:  # piccolo tremito prima dello strappo
		var off := Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-3, 3))
		tear_tw.tween_property(photo, "position", target + off, 0.07)
	tear_tw.tween_property(photo, "position", target, 0.07)
	tear_tw.tween_callback(func() -> void:
		photo.visible = false
		left_half.visible = true
		right_half.visible = true
		_tear_apart(left_half, Vector2(-260, 60), -9.0)
		_tear_apart(right_half, Vector2(260, -60), 9.0))

	# Dissolvenza finale in Game.tscn
	var end_tw := create_tween()
	end_tw.tween_interval(END_TIME)
	end_tw.tween_property(_black, "modulate:a", 1.0, 1.2)
	end_tw.tween_callback(_go_to_game)


# --- una meta' della fotografia (per lo strappo) -----------------------------
func _make_half(tex: Texture2D, region: Rect2, pos: Vector2, size_px: Vector2) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = region

	var half := TextureRect.new()
	half.texture = atlas
	half.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	half.stretch_mode = TextureRect.STRETCH_SCALE
	half.position = pos
	half.size = size_px
	half.pivot_offset = size_px / 2.0
	half.visible = false
	half.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(half)
	return half


# --- animazione di una meta' che vola via ------------------------------------
func _tear_apart(half: TextureRect, drift: Vector2, degrees: float) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(half, "position", half.position + drift, 2.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(half, "rotation_degrees", degrees, 2.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(half, "modulate:a", 0.0, 2.6).set_delay(0.4)


# --- una meteora: scia luminosa che attraversa il cielo ----------------------
func _spawn_meteor() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0))
	grad.set_color(1, Color(1.0, 0.98, 0.9, 0.9))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.width = 140
	gtex.height = 3
	gtex.fill_from = Vector2(0, 0.5)
	gtex.fill_to = Vector2(1, 0.5)

	var m := TextureRect.new()
	m.texture = gtex
	m.size = Vector2(140, 3)
	m.position = Vector2(_rng.randf_range(150, 1050), _rng.randf_range(40, 300))
	m.rotation_degrees = _rng.randf_range(18, 38)
	m.modulate = Color(1, 1, 1, 0)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(m)

	var dir := Vector2.RIGHT.rotated(deg_to_rad(m.rotation_degrees)) * _rng.randf_range(220, 320)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(m, "position", m.position + dir, 0.9) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "modulate:a", 1.0, 0.25)
	tw.tween_property(m, "modulate:a", 0.0, 0.45).set_delay(0.45)
	tw.chain().tween_callback(m.queue_free)


# --- costruzione di una frase centrata ---------------------------------------
func _make_line(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(0.96, 0.95, 0.90))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.size = Vector2(1100, 100)
	l.position = Vector2((1280 - 1100) / 2.0, 545)
	l.modulate = Color(1, 1, 1, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


# --- fa comparire e sparire una frase -----------------------------------------
func _flash_line(label: Label, start: float, hold: float, fade: float, fade_in: float) -> void:
	var tw := create_tween()
	tw.tween_interval(start)
	tw.tween_property(label, "modulate:a", 1.0, fade_in).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(hold)
	tw.tween_property(label, "modulate:a", 0.0, fade).set_trans(Tween.TRANS_SINE)


# --- uno strato di stelle che scorre (parallasse) -----------------------------
func _add_star_layer(tex: Texture2D, amount: int, speed: float, tint: Color,
		scale_range: Vector2) -> void:
	var p := GPUParticles2D.new()
	p.texture = tex
	p.amount = amount
	p.lifetime = 14.0
	p.preprocess = 14.0          # il campo e' gia' pieno all'avvio
	p.speed_scale = 1.0
	p.local_coords = false
	p.position = Vector2(640, 360)

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(760, 440, 0)
	mat.direction = Vector3(-1, 0.15, 0)
	mat.spread = 6.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = speed
	mat.initial_velocity_max = speed * 1.15
	mat.scale_min = scale_range.x
	mat.scale_max = scale_range.y
	mat.color = tint

	# leggero scintillio: le stelle "respirano" in dimensione
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.6))
	curve.add_point(Vector2(0.5, 1.0))
	curve.add_point(Vector2(1.0, 0.6))
	var ct := CurveTexture.new()
	ct.curve = curve
	mat.scale_curve = ct

	p.process_material = mat
	add_child(p)


# --- texture morbida e rotonda per una stella ---------------------------------
func _make_star_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size / 2.0, size / 2.0)
	var r := size / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / r
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = pow(a, 1.8)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


# --- salto / fine --------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if _leaving:
		return
	if (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventMouseButton and event.pressed):
		_go_to_game()


func _go_to_game() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file("res://scenes/Game.tscn")
