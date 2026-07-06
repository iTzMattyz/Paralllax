extends Control
## ============================================================================
##  PARALLAX — schermata iniziale
##  Sfondo: la fotografia rovinata su cielo stellato (start_bg.png).
##  Logo PARALLAX + pulsante GIOCA (grafiche fornite) + "esci" discreto.
## ============================================================================


func _ready() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = load("res://assets/parallax/makina.otf")
	ui_theme.default_font_size = 22
	theme = ui_theme

	# --- sfondo -------------------------------------------------------------
	var bg := TextureRect.new()
	bg.texture = load("res://assets/parallax/start_bg.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# --- logo PARALLAX --------------------------------------------------------
	var logo := TextureRect.new()
	logo.texture = load("res://assets/parallax/logo.png")
	# expand_mode va impostato PRIMA di size, altrimenti la dimensione viene
	# bloccata alla dimensione minima della texture (1621x640).
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_SCALE
	logo.position = Vector2(140, 150)
	logo.size = Vector2(540, 213)   # proporzioni originali 1621x640
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)

	# --- pulsante GIOCA -------------------------------------------------------
	var gioca := TextureButton.new()
	gioca.texture_normal = load("res://assets/parallax/btn_gioca.png")
	gioca.ignore_texture_size = true
	gioca.stretch_mode = TextureButton.STRETCH_SCALE
	gioca.position = Vector2(140, 450)
	gioca.size = Vector2(260, 131)  # proporzioni originali 1032x519
	gioca.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gioca.mouse_entered.connect(func() -> void:
		gioca.modulate = Color(1.0, 0.85, 0.4))
	gioca.mouse_exited.connect(func() -> void:
		gioca.modulate = Color.WHITE)
	gioca.pressed.connect(_start_game)
	add_child(gioca)

	# --- esci ----------------------------------------------------------------
	var esci := Button.new()
	esci.text = "ESCI"
	esci.position = Vector2(1170, 660)
	esci.size = Vector2(90, 44)
	esci.focus_mode = Control.FOCUS_NONE
	esci.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	esci.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	esci.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	esci.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	esci.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	esci.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.4))
	esci.add_theme_color_override("font_pressed_color", Color(1.0, 0.85, 0.4))
	esci.pressed.connect(func() -> void: get_tree().quit())
	add_child(esci)


func _start_game() -> void:
	Audio.click()
	get_tree().change_scene_to_file("res://scenes/Intro.tscn")
