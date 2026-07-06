extends Control
## ============================================================================
##  PARALLAX — escape room punta-e-clicca · 2 stanze · 2 livelli
## ============================================================================
##  Grafica: assets/parallax/ (PNG 3840x2160 scalati a 1280x720; i ritagli per
##  gli zoom usano AtlasTexture con coordinate del canvas originale).
##
##  LIVELLO 1
##   1. telescopio (stanza 2)  -> immagine: le stelle disegnano "11"
##   2. diario (stanza 1)      -> pagina 11: data 12/08
##   3. quadro sul camino      -> inserisci 12/08 -> PICCOLA CHIAVE
##   4. bauletto (stanza 1)    -> con la chiave -> LETTERA con «3» «7» «5» «2»
##   5. porta (stanza 1)       -> codice 3752 -> CUTSCENE 1 -> LIVELLO 2
##
##  LIVELLO 2
##   1. cassetti a dx della scrivania -> FRAMMENTO 1
##   2. camino                        -> indizio a pallini colorati
##   3. libri sulla scrivania         -> clic nell'ordine dei colori -> "Mirta?"
##   4. dietro i libri                -> FRAMMENTO 2
##   5. foto sulla scrivania          -> ricomposta -> data 25/02
##   6. porta                         -> 2502 -> CUTSCENE 2 -> FINE
## ============================================================================

const P := "res://assets/parallax/"

# Ordine di clic dei libri = ordine dei pallini dipinti nel camino
# (viola=M, verde=I, rosso=R, marrone=T, grigio=A: compongono "MIRTA";
#  i pallini in puzzle_colori.png sono stati ricolorati per correggere
#  l'ordine sbagliato dell'asset originale).
const BOOKS_ORDER: Array[String] = ["M", "I", "R", "T", "A"]
const CODE_LVL1 := "3752"
const CODE_LVL2 := "2502"   # la data 25/02
const CODE_QUADRO := "1208" # la data 12/08
const DIARY_PAGES := 16
const DIARY_TARGET_PAGE := 11

# --- stato ------------------------------------------------------------------
var level := 1
var current_room := 1
var inventory: Array[String] = []
var state := {
	"quadro_solved": false,     # data inserita nel quadro sul camino
	"letter_found": false,      # bauletto aperto
	"fragment1_found": false,
	"books_solved": false,
	"photo_fixed": false,
}
var diary_page := 1
var books_progress := 0

# --- nodi -------------------------------------------------------------------
var room1: Control
var room2: Control
var room1_bg: TextureRect
var room2_bg: TextureRect
var inventory_bar: HBoxContainer
var overlay_layer: Control          # zoom / enigmi (uno alla volta)
var msg_layer: Control              # finestra messaggi, sopra gli overlay
var pause_layer: Control
var fade_layer: Control             # transizioni di livello / vittoria
var message_panel: Panel
var message_label: Label
var lvl2_hotspots: Array[Control] = []   # visibili solo al livello 2
var transitioning := false

var textures := {}


func _ready() -> void:
	randomize()
	var ui_theme := Theme.new()
	ui_theme.default_font = load(P + "makina.otf")
	ui_theme.default_font_size = 21
	theme = ui_theme

	textures = {
		"s1l1": load(P + "stanza1_lvl1.png"),
		"s1l2": load(P + "stanza1_lvl2.png"),
		"s2l1": load(P + "stanza2_lvl1.png"),
		"s2l2": load(P + "stanza2_lvl2.png"),
	}

	room1 = _new_layer()
	add_child(room1)
	room2 = _new_layer()
	room2.visible = false
	add_child(room2)

	room1_bg = _add_bg(room1)
	room2_bg = _add_bg(room2)

	_build_room1_hotspots()
	_build_room2_hotspots()
	_build_inventory_bar()

	overlay_layer = _new_layer()
	add_child(overlay_layer)
	msg_layer = _new_layer()
	add_child(msg_layer)
	_build_message_panel()
	pause_layer = _new_layer()
	add_child(pause_layer)
	_build_pause_menu()
	fade_layer = _new_layer()
	add_child(fade_layer)

	_apply_level()
	_show_level_intro("LIVELLO 1")


func _new_layer() -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return layer


func _add_bg(parent: Control) -> TextureRect:
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	return bg


func _apply_level() -> void:
	room1_bg.texture = textures["s1l1"] if level == 1 else textures["s1l2"]
	room2_bg.texture = textures["s2l1"] if level == 1 else textures["s2l2"]
	for h in lvl2_hotspots:
		h.visible = level == 2


# ============================================================================
#  RITAGLI (AtlasTexture sul canvas 3840x2160 originale)
# ============================================================================
func _atlas(file: String, region: Rect2) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = load(P + file)
	at.region = region
	return at


# ============================================================================
#  HOTSPOT — pulsanti invisibili sopra lo sfondo dipinto
# ============================================================================
func _add_hotspot(parent: Control, id: String, label: String, rect: Rect2) -> Button:
	var b := Button.new()
	b.position = rect.position
	b.size = rect.size
	b.tooltip_text = label
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1, 1, 1, 0.06)
	hover.set_corner_radius_all(6)
	hover.set_border_width_all(2)
	hover.border_color = Color(0.95, 0.8, 0.35, 0.85)
	b.add_theme_stylebox_override("hover", hover)
	b.pressed.connect(func() -> void:
		Audio.click()
		_on_hotspot(id))
	parent.add_child(b)
	return b


func _build_room1_hotspots() -> void:
	# mobili grandi prima (restano sotto agli oggetti che vi poggiano sopra)
	_add_hotspot(room1, "mobiletto", "Mobiletto", Rect2(963, 400, 255, 210))
	_add_hotspot(room1, "cassetti_sx", "Cassetti della scrivania", Rect2(12, 448, 105, 168))
	_add_hotspot(room1, "cassetti_dx", "Cassetti della scrivania", Rect2(342, 448, 90, 168))
	_add_hotspot(room1, "foto", "Fotografia", Rect2(44, 344, 64, 84))
	_add_hotspot(room1, "diario", "Diario", Rect2(100, 402, 75, 40))
	_add_hotspot(room1, "libri", "Libri", Rect2(327, 346, 95, 82))
	_add_hotspot(room1, "tazza", "Tazza", Rect2(272, 368, 32, 54))
	_add_hotspot(room1, "lavagna", "Appunti alla parete", Rect2(305, 218, 127, 112))
	_add_hotspot(room1, "orologio", "Orologio a pendolo", Rect2(487, 136, 65, 168))
	_add_hotspot(room1, "porta", "Porta", Rect2(645, 48, 215, 550))
	_add_hotspot(room1, "indizi", "Appunti appesi", Rect2(964, 144, 70, 158))
	_add_hotspot(room1, "ritratto", "Ritratto", Rect2(1072, 121, 102, 136))
	_add_hotspot(room1, "pianta", "Pianta", Rect2(1027, 272, 82, 130))
	_add_hotspot(room1, "teca", "Teca di vetro", Rect2(1110, 300, 94, 106))
	_add_hotspot(room1, "cassetta", "Bauletto", Rect2(982, 370, 66, 40))
	_add_hotspot(room1, "vai_stanza2", "Vai nell'altra stanza", Rect2(1198, 318, 82, 66))

	lvl2_hotspots.append(_add_hotspot(room1, "quadro_stelle", "Quadro", Rect2(105, 190, 142, 146)))
	lvl2_hotspots.append(_add_hotspot(room1, "valigia", "Valigia", Rect2(915, 534, 148, 110)))


func _build_room2_hotspots() -> void:
	_add_hotspot(room2, "finestra", "Finestra", Rect2(1000, 6, 278, 220))
	_add_hotspot(room2, "libreria", "Libreria", Rect2(13, 74, 275, 570))
	_add_hotspot(room2, "poltrona", "Poltrona", Rect2(243, 410, 265, 285))
	_add_hotspot(room2, "tavolino", "Tavolino", Rect2(196, 570, 100, 130))
	_add_hotspot(room2, "camino", "Camino", Rect2(483, 323, 415, 325))
	_add_hotspot(room2, "quadro_camino", "Quadro sul camino", Rect2(571, 38, 263, 176))
	_add_hotspot(room2, "lanterna", "Lanterna", Rect2(792, 216, 63, 110))
	_add_hotspot(room2, "mobile_dx", "Mobile basso", Rect2(1020, 440, 258, 250))
	_add_hotspot(room2, "telescopio", "Telescopio", Rect2(861, 234, 258, 460))
	_add_hotspot(room2, "vai_stanza1", "Torna nell'altra stanza", Rect2(0, 315, 74, 68))

	lvl2_hotspots.append(_add_hotspot(room2, "quadro_m", "Piccolo quadro", Rect2(313, 176, 76, 117)))
	lvl2_hotspots.append(_add_hotspot(room2, "tazza2", "Tazza", Rect2(228, 550, 44, 52)))


func _go_to_room(n: int) -> void:
	current_room = n
	room1.visible = n == 1
	room2.visible = n == 2


# ============================================================================
#  INTERAZIONI
# ============================================================================
func _on_hotspot(id: String) -> void:
	if transitioning:
		return
	match id:
		"vai_stanza2": _go_to_room(2)
		"vai_stanza1": _go_to_room(1)

		# ------------------------------------------------ stanza 1
		"foto":
			_on_foto()
		"diario":
			_open_diary()
		"libri":
			if level == 1:
				_show_message("Una fila di vecchi libri. Sul dorso qualcuno ha scritto delle lettere a penna.")
			elif state.books_solved:
				_show_message("I libri sono di nuovo in disordine. Ma ormai il loro segreto è svelato.")
			else:
				_open_books()
		"tazza":
			_show_message("Una tazza di caffè, freddo da chissà quanto.")
		"cassetti_sx":
			_show_message("Fogli sparsi, matite spuntate. Niente di utile.")
		"cassetti_dx":
			if level == 1:
				_show_message("I cassetti di destra sono incastrati. Non si aprono.")
			elif not state.fragment1_found:
				state.fragment1_found = true
				_add_item("frammento1")
				_show_message("Nel cassetto in alto, sotto una pila di carte, trovi un FRAMMENTO DI FOTOGRAFIA.")
			else:
				_show_message("Solo carte e vecchi appunti, ormai.")
		"lavagna":
			_show_message("Appunti di astronomia: Saturno, costellazioni, calcoli scritti in fretta.")
		"orologio":
			_show_message("Il pendolo oscilla piano. Le lancette segnano sempre la stessa ora.")
		"porta":
			_open_door_lock()
		"indizi":
			_open_image_overlay((P + "indizi_lvl1.png") if level == 1 else (P + "indizi_lvl2.png"),
				"Uno schema disegnato a mano. Da dove cominciare?")
		"ritratto":
			_show_message("Un ritratto in silhouette. Il profilo ti è familiare... sei tu?")
		"pianta":
			_show_message("Una pianta sorprendentemente viva, per una stanza chiusa.")
		"teca":
			_open_stelle_overlay()
		"cassetta":
			_on_cassetta()
		"mobiletto":
			_show_message("Le ante sono bloccate. Sopra c'è un bauletto, una pianta e una strana teca.")
		"quadro_stelle":
			_show_message("Una mappa stellare circolare. Non c'era, prima... o non ci avevi mai fatto caso.")
		"valigia":
			_show_message("Una valigia pronta, coperta di adesivi di viaggio. Qualcuno stava per partire.")

		# ------------------------------------------------ stanza 2
		"finestra":
			_show_message("La notte è limpida. Uno spicchio di cielo pieno di stelle.")
		"libreria":
			_show_message("Romanzi, atlanti e un piccolo cannocchiale d'ottone. Tutto in ordine.")
		"poltrona":
			_show_message("Una poltrona consumata, con una coperta piegata sul bracciolo. Il posto preferito di qualcuno.")
		"tavolino":
			if level == 2:
				_show_message("Il tavolino accanto alla poltrona. Ora c'è una tazza sopra.")
			else:
				_show_message("Un tavolino da lettura, accanto alla poltrona.")
		"tazza2":
			_show_message("Una tazza di caffè. È ancora tiepida... com'è possibile?")
		"camino":
			if level == 1:
				_show_message("Il fuoco scoppietta piano. Il calore non basta a scaldare la stanza.")
			else:
				_open_image_overlay(P + "puzzle_colori.png",
					"Dietro la grata, sul mattone: cinque segni di colore, uno dopo l'altro.")
		"quadro_camino":
			if level == 1 and not state.quadro_solved:
				_open_quadro_lock()
			elif level == 1:
				_show_message("Il quadro con il cielo delle Perseidi. La data 12/08 ha aperto il suo segreto.")
			else:
				_show_message("Il cielo notturno dipinto sopra il camino. Sembra brillare più di prima.")
		"lanterna":
			_show_message("Una vecchia lanterna a olio. La sua luce è calda e costante.")
		"mobile_dx":
			_show_message("Sul mobile è rimasto un quaderno aperto, pieno di osservazioni astronomiche.")
		"telescopio":
			_open_image_overlay(P + "puzzle_telescopio.png",
				"Attraverso l'oculare: le stelle più luminose sembrano disegnare qualcosa.")
		"quadro_m":
			_show_message("Un piccolo ricamo incorniciato: una \"M\" elegante, cucita a filo d'oro.")


func _on_foto() -> void:
	if state.photo_fixed:
		_open_photo_overlay()
		return
	if level == 1:
		_show_message("Una fotografia rovinata: mancano dei pezzi. Chissà dove sono finiti.")
		return
	if "frammento1" in inventory and "frammento2" in inventory:
		_open_photo_overlay()
	else:
		_show_message("Mancano ancora dei pezzi per ricomporre la fotografia.")


func _on_cassetta() -> void:
	if state.letter_found:
		_open_letter_overlay()
	elif "chiave" in inventory:
		state.letter_found = true
		_remove_item("chiave")
		_open_letter_overlay()
	else:
		_show_message("Un bauletto di legno con una piccola serratura. È chiuso a chiave.")


# ============================================================================
#  INVENTARIO
# ============================================================================
func _build_inventory_bar() -> void:
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0, 0, 0, 0.55)
	bar_bg.position = Vector2(0, 664)
	bar_bg.size = Vector2(1280, 56)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_bg)

	var label := Label.new()
	label.text = "INVENTARIO"
	label.position = Vector2(18, 678)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.65, 0.62, 0.55))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

	inventory_bar = HBoxContainer.new()
	inventory_bar.position = Vector2(140, 668)
	inventory_bar.add_theme_constant_override("separation", 12)
	add_child(inventory_bar)


func _item_name(id: String) -> String:
	match id:
		"chiave": return "Piccola Chiave"
		"frammento1": return "Frammento 1"
		"frammento2": return "Frammento 2"
		_: return id


func _item_icon(id: String) -> Texture2D:
	match id:
		"chiave":
			return load("res://assets/item_small_key.svg")
		"frammento1":
			return _atlas("frammento1.png", Rect2(174, 1086, 79, 154))
		"frammento2":
			return _atlas("frammento2.png", Rect2(231, 1143, 67, 97))
	return null


func _item_desc(id: String) -> String:
	match id:
		"chiave": return "Una piccola chiave, caduta da dietro il quadro sul camino."
		"frammento1": return "Un frammento di fotografia, trovato nei cassetti della scrivania."
		"frammento2": return "Un frammento di fotografia, era nascosto dietro ai libri."
	return ""


func _add_item(id: String) -> void:
	if id in inventory:
		return
	inventory.append(id)
	_refresh_inventory()


func _remove_item(id: String) -> void:
	inventory.erase(id)
	_refresh_inventory()


func _refresh_inventory() -> void:
	for c in inventory_bar.get_children():
		c.queue_free()
	for id in inventory:
		var b := Button.new()
		b.text = _item_name(id)
		b.custom_minimum_size = Vector2(0, 46)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 16)
		var icon := _item_icon(id)
		if icon:
			b.icon = icon
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 30)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.16, 0.13, 0.11, 0.9)
		sb.set_corner_radius_all(6)
		sb.set_border_width_all(1)
		sb.border_color = Color(0.55, 0.45, 0.3)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		b.add_theme_stylebox_override("normal", sb)
		var sb_h := sb.duplicate() as StyleBoxFlat
		sb_h.border_color = Color(0.95, 0.8, 0.35)
		b.add_theme_stylebox_override("hover", sb_h)
		b.add_theme_stylebox_override("pressed", sb_h)
		var captured: String = id
		b.pressed.connect(func() -> void: _show_message(_item_desc(captured)))
		inventory_bar.add_child(b)


# ============================================================================
#  MESSAGGI
# ============================================================================
func _build_message_panel() -> void:
	message_panel = Panel.new()
	message_panel.position = Vector2(290, 250)
	message_panel.size = Vector2(700, 230)
	message_panel.visible = false
	_style_panel(message_panel)
	msg_layer.add_child(message_panel)

	message_label = Label.new()
	message_label.position = Vector2(34, 26)
	message_label.size = Vector2(632, 130)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 22)
	message_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.85))
	message_panel.add_child(message_label)

	var ok := Button.new()
	ok.text = "OK"
	ok.position = Vector2(300, 176)
	ok.size = Vector2(100, 40)
	ok.focus_mode = Control.FOCUS_NONE
	ok.pressed.connect(func() -> void: message_panel.visible = false)
	message_panel.add_child(ok)


func _show_message(text: String) -> void:
	message_label.text = text
	message_panel.visible = true


# ============================================================================
#  OVERLAY GENERICI
# ============================================================================
func _close_overlay() -> void:
	for c in overlay_layer.get_children():
		c.queue_free()


func _overlay_root(dim := 0.75) -> Control:
	_close_overlay()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, dim)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(veil)
	overlay_layer.add_child(root)
	return root


func _add_close_button(root: Control) -> void:
	var b := Button.new()
	b.text = "✕"
	b.position = Vector2(1216, 14)
	b.size = Vector2(50, 50)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.4))
	b.pressed.connect(_close_overlay)
	root.add_child(b)


## Immagine a tutto schermo (indizi, telescopio, camino): un clic la chiude.
func _open_image_overlay(path: String, caption: String) -> void:
	var root := _overlay_root(0.85)
	var img := TextureRect.new()
	img.texture = load(path)
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_SCALE
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(img)
	_add_caption(root, caption)
	_add_click_to_close(root)
	_add_close_button(root)


func _add_caption(root: Control, caption: String) -> void:
	if caption == "":
		return
	var strip := ColorRect.new()
	strip.color = Color(0, 0, 0, 0.6)
	strip.position = Vector2(0, 652)
	strip.size = Vector2(1280, 68)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(strip)
	var lab := Label.new()
	lab.text = caption
	lab.position = Vector2(0, 652)
	lab.size = Vector2(1280, 68)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 22)
	lab.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lab)


func _add_click_to_close(root: Control) -> void:
	var b := Button.new()
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	b.pressed.connect(_close_overlay)
	root.add_child(b)
	root.move_child(b, 1)  # sopra l'immagine, sotto didascalia e ✕


## Zoom sulla teca: la piccola costellazione a forma di M.
func _open_stelle_overlay() -> void:
	var root := _overlay_root(0.88)
	var img := TextureRect.new()
	img.texture = _atlas("stelle_m.png", Rect2(3373, 952, 191, 146))
	img.position = Vector2(410, 170)
	img.size = Vector2(460, 352)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_SCALE
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(img)
	_add_caption(root, "Sotto il vetro, piccole stelle d'oro unite da fili neri: disegnano una \"M\".")
	_add_click_to_close(root)
	_add_close_button(root)


# ============================================================================
#  DIARIO (livello 1: pagina 11 -> 12/08)
# ============================================================================
const DIARY_TEXT := """12/08

Le Perseidi non deludono mai. Anche quest'anno siamo rimasti nell'osservatorio fino a notte fonda. Ogni volta ci ripromettiamo di rientrare presto, ma finiamo sempre per restare finché il cielo non inizia a schiarire.

Abbiamo finalmente annotato tutte le osservazioni e, per una volta, sembrano esserci davvero pochi errori. C'è ancora chi sostiene che passare così tante ore qui dentro sia una perdita di tempo, ma io non riesco a immaginare un posto migliore.

Domani dovremmo sistemare un po' lo studio. È sempre più pieno di libri, fogli e tazze dimenticate ovunque... anche se, in fondo, mi piace così."""

var diary_text_label: Label
var diary_page_label: Label


func _open_diary() -> void:
	var root := _overlay_root(0.8)

	var book := Panel.new()
	book.position = Vector2(290, 70)
	book.size = Vector2(700, 540)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.87, 0.80, 0.66)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(6)
	sb.border_color = Color(0.32, 0.22, 0.14)
	book.add_theme_stylebox_override("panel", sb)
	root.add_child(book)

	diary_page_label = Label.new()
	diary_page_label.position = Vector2(0, 18)
	diary_page_label.size = Vector2(700, 30)
	diary_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diary_page_label.add_theme_font_size_override("font_size", 18)
	diary_page_label.add_theme_color_override("font_color", Color(0.4, 0.3, 0.2))
	book.add_child(diary_page_label)

	diary_text_label = Label.new()
	diary_text_label.position = Vector2(56, 58)
	diary_text_label.size = Vector2(588, 420)
	diary_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	diary_text_label.add_theme_font_size_override("font_size", 19)
	diary_text_label.add_theme_color_override("font_color", Color(0.22, 0.16, 0.11))
	book.add_child(diary_text_label)

	var prev := Button.new()
	prev.text = "‹"
	prev.position = Vector2(16, 240)
	prev.size = Vector2(46, 60)
	prev.focus_mode = Control.FOCUS_NONE
	prev.add_theme_font_size_override("font_size", 34)
	prev.pressed.connect(func() -> void: _diary_flip(-1))
	book.add_child(prev)

	var next := Button.new()
	next.text = "›"
	next.position = Vector2(638, 240)
	next.size = Vector2(46, 60)
	next.focus_mode = Control.FOCUS_NONE
	next.add_theme_font_size_override("font_size", 34)
	next.pressed.connect(func() -> void: _diary_flip(1))
	book.add_child(next)

	_add_close_button(root)
	_diary_refresh()


func _diary_flip(dir: int) -> void:
	diary_page = clampi(diary_page + dir, 1, DIARY_PAGES)
	Audio.click()
	_diary_refresh()


func _diary_refresh() -> void:
	diary_page_label.text = "— Pagina %d —" % diary_page
	if diary_page == DIARY_TARGET_PAGE:
		diary_text_label.text = DIARY_TEXT
		diary_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		diary_text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	else:
		diary_text_label.text = ". . ."
		diary_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		diary_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


# ============================================================================
#  QUADRO SUL CAMINO — inserire la data 12/08 (livello 1)
# ============================================================================
var quadro_code := ""
var quadro_digit_labels: Array[Label] = []


func _open_quadro_lock() -> void:
	quadro_code = ""
	quadro_digit_labels.clear()
	var root := _overlay_root(0.85)

	var img := TextureRect.new()
	img.texture = load(P + "puzzle_quadro.png")
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_SCALE
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(img)

	var hint := Label.new()
	hint.text = "Sulla cornice, quattro rotelle numerate: g g / m m"
	hint.position = Vector2(0, 118)
	hint.size = Vector2(1280, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)

	var xs := [545, 605, 675, 735]
	for i in 4:
		var d := Label.new()
		d.text = "_"
		d.position = Vector2(xs[i] - 30, 190)
		d.size = Vector2(60, 80)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.add_theme_font_size_override("font_size", 56)
		d.add_theme_color_override("font_color", Color(0.93, 0.78, 0.35))
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(d)
		quadro_digit_labels.append(d)

	var slash := Label.new()
	slash.text = "/"
	slash.position = Vector2(610, 190)
	slash.size = Vector2(60, 80)
	slash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slash.add_theme_font_size_override("font_size", 56)
	slash.add_theme_color_override("font_color", Color(0.93, 0.78, 0.35, 0.8))
	slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(slash)

	_build_keypad(root, Vector2(475, 380), _quadro_press_digit, _quadro_clear, _quadro_submit)
	_add_close_button(root)


func _quadro_press_digit(n: String) -> void:
	if quadro_code.length() < 4:
		quadro_code += n
		_quadro_refresh()


func _quadro_clear() -> void:
	quadro_code = ""
	_quadro_refresh()


func _quadro_refresh() -> void:
	for i in 4:
		quadro_digit_labels[i].text = quadro_code[i] if i < quadro_code.length() else "_"


func _quadro_submit() -> void:
	if quadro_code == CODE_QUADRO:
		state.quadro_solved = true
		_close_overlay()
		Audio.door()
		_add_item("chiave")
		_show_message("Le rotelle si allineano sul 12/08: dietro il quadro scatta un meccanismo\ne una PICCOLA CHIAVE cade sulla mensola del camino. Raccolta.")
	else:
		quadro_code = ""
		_quadro_refresh()
		_show_message("Le rotelle girano a vuoto. Non è la data giusta.")


# ============================================================================
#  LETTERA (nel bauletto, livello 1)
# ============================================================================
func _open_letter_overlay() -> void:
	var root := _overlay_root(0.8)

	var sheet := Panel.new()
	sheet.position = Vector2(340, 50)
	sheet.size = Vector2(600, 580)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.89, 0.83, 0.70)
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.45, 0.35, 0.22)
	sheet.add_theme_stylebox_override("panel", sb)
	root.add_child(sheet)

	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.position = Vector2(44, 34)
	rt.size = Vector2(512, 512)
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt.add_theme_font_size_override("normal_font_size", 18)
	rt.add_theme_color_override("default_color", Color(0.25, 0.18, 0.12))
	rt.text = """Cara me,
ho deciso di lasciare qualche appunto sparso per lo studio. So già che finirò per dimenticare dove avrò messo tutto.

Per ricordarmi alcune osservazioni, ho numerato i raccoglitori in questo ordine:

  [color=#8a5a10]«3»[/color] → Costellazioni invernali
  [color=#8a5a10]«7»[/color] → Osservazioni al telescopio
  [color=#8a5a10]«5»[/color] → Fotografie sviluppate
  [color=#8a5a10]«2»[/color] → Appunti di ricerca

Spero che la prossima volta basti seguire quest'ordine invece di perdere un'intera serata a cercare fogli ovunque.

Forse è davvero arrivato il momento di rimettere un po' d'ordine."""
	sheet.add_child(rt)

	_add_click_to_close(root)
	_add_close_button(root)


# ============================================================================
#  PORTA — codice a 4 cifre (liv. 1: 3752 · liv. 2: la data 25/02)
# ============================================================================
var door_code := ""
var door_digit_labels: Array[Label] = []


func _open_door_lock() -> void:
	door_code = ""
	door_digit_labels.clear()
	var root := _overlay_root(0.82)

	var img := TextureRect.new()
	img.texture = load(P + "codice.png")
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_SCALE
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(img)

	var hint := Label.new()
	if level == 1:
		hint.text = "La porta è sbarrata da una serratura a combinazione: quattro cifre."
	else:
		hint.text = "La serratura è cambiata. Chiede di nuovo quattro cifre... una data?  g g / m m"
	hint.position = Vector2(0, 200)
	hint.size = Vector2(1280, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 21)
	hint.add_theme_color_override("font_color", Color(0.92, 0.88, 0.75))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)

	# cifre sopra i quattro trattini dipinti (centri ~566, 623, 683, 744)
	var xs := [566, 623, 683, 744]
	for i in 4:
		var d := Label.new()
		d.text = ""
		d.position = Vector2(xs[i] - 28, 282)
		d.size = Vector2(56, 66)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.add_theme_font_size_override("font_size", 50)
		d.add_theme_color_override("font_color", Color(0.93, 0.78, 0.35))
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(d)
		door_digit_labels.append(d)

	_build_keypad(root, Vector2(475, 400), _door_press_digit, _door_clear, _door_submit)
	_add_close_button(root)


func _door_press_digit(n: String) -> void:
	if door_code.length() < 4:
		door_code += n
		_door_refresh()


func _door_clear() -> void:
	door_code = ""
	_door_refresh()


func _door_refresh() -> void:
	for i in 4:
		door_digit_labels[i].text = door_code[i] if i < door_code.length() else ""


func _door_submit() -> void:
	var expected := CODE_LVL1 if level == 1 else CODE_LVL2
	if door_code == expected:
		_close_overlay()
		if level == 1:
			_goto_level2()
		else:
			_win()
	else:
		door_code = ""
		_door_refresh()
		_show_message("La serratura resiste. Combinazione errata.")


# ============================================================================
#  TASTIERINO condiviso (porta e quadro)
# ============================================================================
func _build_keypad(root: Control, pos: Vector2, on_digit: Callable,
		on_clear: Callable, on_submit: Callable) -> void:
	var panel := Panel.new()
	panel.position = pos
	panel.size = Vector2(330, 230)
	_style_panel(panel)
	root.add_child(panel)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.position = Vector2(15, 15)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	panel.add_child(grid)

	for n in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]:
		var b := Button.new()
		b.text = n
		b.custom_minimum_size = Vector2(53, 53)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 22)
		var captured: String = n
		b.pressed.connect(func() -> void:
			Audio.click()
			on_digit.call(captured))
		grid.add_child(b)

	var row := HBoxContainer.new()
	row.position = Vector2(15, 145)
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var clr := Button.new()
	clr.text = "CANC"
	clr.custom_minimum_size = Vector2(145, 55)
	clr.focus_mode = Control.FOCUS_NONE
	clr.pressed.connect(func() -> void:
		Audio.click()
		on_clear.call())
	row.add_child(clr)

	var ok := Button.new()
	ok.text = "OK"
	ok.custom_minimum_size = Vector2(145, 55)
	ok.focus_mode = Control.FOCUS_NONE
	ok.pressed.connect(func() -> void: on_submit.call())
	row.add_child(ok)


# ============================================================================
#  ENIGMA DEI LIBRI (livello 2) — clicca nell'ordine dei colori del camino
# ============================================================================
var books_status: Label

# Zone di clic sui dorsi, relative al ritaglio (989,1045)-(1253,1277), scala 2.4.
const BOOK_ZONES := {
	"R": Rect2(24, 48, 101, 482),
	"A": Rect2(125, 48, 86, 482),
	"I": Rect2(211, 48, 79, 482),
	"T": Rect2(290, 48, 101, 482),
	"M": Rect2(391, 24, 216, 506),
}


func _open_books() -> void:
	books_progress = 0
	var root := _overlay_root(0.85)

	var holder := Control.new()
	holder.position = Vector2(323, 30)
	holder.size = Vector2(634, 557)
	root.add_child(holder)

	var img := TextureRect.new()
	img.texture = _atlas("libri.png", Rect2(989, 1045, 264, 232))
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_SCALE
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(img)

	for letter in BOOK_ZONES:
		var b := Button.new()
		b.position = (BOOK_ZONES[letter] as Rect2).position
		b.size = (BOOK_ZONES[letter] as Rect2).size
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		var hover := StyleBoxFlat.new()
		hover.bg_color = Color(1, 1, 1, 0.07)
		hover.set_border_width_all(2)
		hover.border_color = Color(0.95, 0.8, 0.35, 0.8)
		b.add_theme_stylebox_override("hover", hover)
		var captured: String = letter
		b.pressed.connect(func() -> void: _book_clicked(captured))
		holder.add_child(b)

	books_status = Label.new()
	books_status.position = Vector2(0, 600)
	books_status.size = Vector2(1280, 40)
	books_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	books_status.add_theme_font_size_override("font_size", 26)
	books_status.add_theme_color_override("font_color", Color(0.93, 0.78, 0.35))
	books_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(books_status)

	var hint := Label.new()
	hint.text = "Cinque colori, un ordine. L'hai visto da qualche parte..."
	hint.position = Vector2(0, 645)
	hint.size = Vector2(1280, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.8, 0.78, 0.7))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)

	_add_close_button(root)
	_books_refresh()


func _books_refresh() -> void:
	var shown: Array[String] = []
	for i in books_progress:
		shown.append(BOOKS_ORDER[i])
	books_status.text = " · ".join(shown)


func _book_clicked(letter: String) -> void:
	Audio.click()
	if letter == BOOKS_ORDER[books_progress]:
		books_progress += 1
		_books_refresh()
		if books_progress == BOOKS_ORDER.size():
			state.books_solved = true
			_add_item("frammento2")
			_close_overlay()
			_show_message("L'ultimo libro scatta come un interruttore. Le lettere, rilette insieme, compongono un nome: Mirta?... Chissà chi è.\n\nDietro ai libri spunta un FRAMMENTO DI FOTOGRAFIA. Raccolto.")
	else:
		books_progress = 0
		_books_refresh()
		_show_message("Niente. I libri tornano al loro posto: dev'esserci un ordine preciso.")


# ============================================================================
#  FOTO DA RICOMPORRE (livello 2) -> data 25/02
# ============================================================================
func _open_photo_overlay() -> void:
	var root := _overlay_root(0.85)

	var holder := Control.new()
	holder.position = Vector2(408, 55)
	holder.size = Vector2(464, 545)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)

	var frame := TextureRect.new()
	frame.texture = _atlas("foto.png", Rect2(144, 1062, 172, 202))
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(frame)

	if state.photo_fixed:
		_photo_add_fragments(holder)
		_photo_add_date(holder)
		_add_caption(root, "La fotografia ricomposta. In basso, una data scritta a penna: 25/02.")
	else:
		state.photo_fixed = true
		_remove_item("frammento1")
		_remove_item("frammento2")
		_photo_add_fragments(holder)
		_photo_add_date(holder)
		_add_caption(root, "I frammenti combaciano. In basso riaffiora una data scritta a penna: 25/02.")

	_add_click_to_close(root)
	_add_close_button(root)


func _photo_add_fragments(holder: Control) -> void:
	# I frammenti sono esportati sullo stesso canvas della foto: gli offset
	# corrispondono alle posizioni originali (scala 2.7).
	var f1 := TextureRect.new()
	f1.texture = _atlas("frammento1.png", Rect2(174, 1086, 79, 154))
	f1.position = Vector2(81, 65)
	f1.size = Vector2(213, 416)
	f1.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	f1.stretch_mode = TextureRect.STRETCH_SCALE
	f1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(f1)

	var f2 := TextureRect.new()
	f2.texture = _atlas("frammento2.png", Rect2(231, 1143, 67, 97))
	f2.position = Vector2(235, 219)
	f2.size = Vector2(181, 262)
	f2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	f2.stretch_mode = TextureRect.STRETCH_SCALE
	f2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(f2)


func _photo_add_date(holder: Control) -> void:
	var date := Label.new()
	date.text = "25/02"
	date.position = Vector2(0, 448)
	date.size = Vector2(464, 60)
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	date.add_theme_font_size_override("font_size", 44)
	date.add_theme_color_override("font_color", Color(0.25, 0.17, 0.10))
	date.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(date)


# ============================================================================
#  CUTSCENE DI FINE LIVELLO (un clic salta al termine)
# ============================================================================
var cutscene_skip := false


func _cutscene_add_skip(root: Control) -> void:
	var b := Button.new()
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void: cutscene_skip = true)
	root.add_child(b)


## Attende `seconds`, ma esce subito se il giocatore clicca per saltare.
func _cutscene_wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds and not cutscene_skip:
		await get_tree().create_timer(0.1).timeout
		t += 0.1


func _cutscene_label(root: Control, text: String, rect: Rect2, size: int) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.position = rect.position
	lab.size = rect.size
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.add_theme_font_size_override("font_size", size)
	# lo sfondo dei PNG è trasparente: il testo cade sul velo nero, serve chiaro
	lab.add_theme_color_override("font_color", Color(0.48, 0.45, 0.40))
	lab.modulate.a = 0.0
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lab)
	return lab


## Cutscene 1 (dopo il livello 1): la pagina di diario con scritto "noi".
func _play_cutscene1() -> void:
	cutscene_skip = false
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.modulate.a = 0.0
	fade_layer.add_child(root)

	var img := TextureRect.new()
	img.texture = load(P + "cutscene1_pagina.png")
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_SCALE
	img.pivot_offset = Vector2(640, 360)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(img)

	# la pagina occupa la metà sinistra: la reazione appare nello spazio a destra
	var lab := _cutscene_label(root, "Noi... noi chi?", Rect2(580, 300, 660, 80), 34)
	_cutscene_add_skip(root)

	var tin := create_tween()
	tin.tween_property(root, "modulate:a", 1.0, 0.8)
	var drift := create_tween()
	drift.tween_property(img, "scale", Vector2(1.05, 1.05), 13.0)
	await tin.finished
	await _cutscene_wait(3.0)

	var tlab := create_tween()
	tlab.tween_property(lab, "modulate:a", 1.0, 0.8)
	await _cutscene_wait(8.1)

	drift.kill()
	var tout := create_tween()
	tout.tween_property(root, "modulate:a", 0.0, 0.8)
	await tout.finished
	root.queue_free()


## Cutscene 2 (dopo il livello 2): zoom sul quadro appeso alla parete,
## stesso sfondo bianco della cutscene 1.
func _play_cutscene2() -> void:
	cutscene_skip = false
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.modulate.a = 0.0
	fade_layer.add_child(root)

	var img := TextureRect.new()
	img.texture = load(P + "cutscene2_quadro.png")
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_SCALE
	# il quadro nell'immagine 3840x2160 è centrato su ~(3370, 561):
	# a schermo (1280x720) è il punto (1123, 187), usato come perno dello zoom
	img.pivot_offset = Vector2(1123, 187)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(img)

	var lab := _cutscene_label(root,
		"25/10 ... Mirta ... quel profilo ... mi è tutto così familiare, eppure non riesco ancora a ricordare",
		Rect2(80, 270, 620, 180), 30)
	_cutscene_add_skip(root)

	var tin := create_tween()
	tin.tween_property(root, "modulate:a", 1.0, 0.8)
	await tin.finished
	await _cutscene_wait(0.8)

	# zoom lento verso il quadro, che finisce nella metà destra dello schermo
	var final_scale := Vector2(2.4, 2.4)
	var final_pos := Vector2(960, 340) - img.pivot_offset
	var zoom := create_tween().set_parallel()
	zoom.tween_property(img, "scale", final_scale, 4.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	zoom.tween_property(img, "position", final_pos, 4.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _cutscene_wait(4.2)
	if cutscene_skip:
		zoom.kill()
		img.scale = final_scale
		img.position = final_pos

	var tlab := create_tween()
	tlab.tween_property(lab, "modulate:a", 1.0, 0.8)
	await _cutscene_wait(5.5)

	var tout := create_tween()
	tout.tween_property(root, "modulate:a", 0.0, 0.8)
	await tout.finished
	root.queue_free()


# ============================================================================
#  PASSAGGIO DI LIVELLO E VITTORIA
# ============================================================================
func _goto_level2() -> void:
	transitioning = true
	Audio.door()
	var veil := _make_fade()
	var tween := create_tween()
	tween.tween_property(veil, "modulate:a", 1.0, 0.7)
	await tween.finished

	await _play_cutscene1()

	var title := _fade_title(veil, "LIVELLO 2")
	await get_tree().create_timer(1.6).timeout

	level = 2
	_apply_level()
	_go_to_room(1)
	inventory.clear()
	_refresh_inventory()

	title.queue_free()
	var out := create_tween()
	out.tween_property(veil, "modulate:a", 0.0, 0.7)
	await out.finished
	veil.queue_free()
	transitioning = false
	_show_message("La porta si apre... sulla stessa stanza. Qualcosa, però, è cambiato.")


func _make_fade() -> Control:
	var veil := Control.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.modulate.a = 0.0
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.add_child(black)
	fade_layer.add_child(veil)
	return veil


func _fade_title(veil: Control, text: String) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.set_anchors_preset(Control.PRESET_FULL_RECT)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 64)
	lab.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	veil.add_child(lab)
	return lab


func _show_level_intro(text: String) -> void:
	transitioning = true
	var veil := _make_fade()
	veil.modulate.a = 1.0
	var title := _fade_title(veil, text)
	await get_tree().create_timer(1.4).timeout
	title.queue_free()
	var out := create_tween()
	out.tween_property(veil, "modulate:a", 0.0, 0.8)
	await out.finished
	veil.queue_free()
	transitioning = false


func _win() -> void:
	transitioning = true
	Audio.door()
	var veil := _make_fade()
	var tween := create_tween()
	tween.tween_property(veil, "modulate:a", 1.0, 0.9)
	await tween.finished

	await _play_cutscene2()

	var logo := TextureRect.new()
	logo.texture = load(P + "logo.png")
	# expand_mode prima di size (vedi MainMenu: evita il blocco alla min size)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_SCALE
	logo.position = Vector2(430, 180)
	logo.size = Vector2(420, 166)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(logo)

	var fine := Label.new()
	fine.text = "F I N E"
	fine.position = Vector2(0, 400)
	fine.size = Vector2(1280, 60)
	fine.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fine.add_theme_font_size_override("font_size", 40)
	fine.add_theme_color_override("font_color", Color(0.93, 0.78, 0.35))
	veil.add_child(fine)

	var sub := Label.new()
	sub.text = "25 febbraio. La porta finalmente si apre."
	sub.position = Vector2(0, 460)
	sub.size = Vector2(1280, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.85, 0.83, 0.75))
	veil.add_child(sub)

	var menu_btn := Button.new()
	menu_btn.text = "TORNA AL MENU INIZIALE"
	menu_btn.position = Vector2(490, 540)
	menu_btn.size = Vector2(300, 52)
	menu_btn.focus_mode = Control.FOCUS_NONE
	menu_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	menu_btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	veil.add_child(menu_btn)


# ============================================================================
#  MENU DI PAUSA (ESC)
# ============================================================================
var pause_root: Control


func _build_pause_menu() -> void:
	pause_root = Control.new()
	pause_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_root.visible = false
	pause_layer.add_child(pause_root)

	var veil := ColorRect.new()
	veil.color = Color(0.18, 0.18, 0.18, 0.92)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_root.add_child(veil)

	var continua := _pause_button("CONTINUA", Vector2(0, 280))
	continua.pressed.connect(func() -> void: pause_root.visible = false)
	pause_root.add_child(continua)

	var menu := _pause_button("TORNA AL MENU INIZIALE", Vector2(0, 370))
	menu.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	pause_root.add_child(menu)


func _pause_button(text: String, pos: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = Vector2(240, pos.y)
	b.size = Vector2(800, 60)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 34)
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	b.add_theme_color_override("font_hover_color", Color(0.95, 0.8, 0.35))
	b.add_theme_color_override("font_pressed_color", Color(0.95, 0.8, 0.35))
	return b


# ============================================================================
#  INPUT — ESC chiude nell'ordine: messaggio, overlay, pausa
# ============================================================================
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or transitioning:
		return
	if message_panel.visible:
		message_panel.visible = false
	elif overlay_layer.get_child_count() > 0:
		_close_overlay()
	else:
		pause_root.visible = not pause_root.visible
	get_viewport().set_input_as_handled()


# ============================================================================
#  helper
# ============================================================================
func _style_panel(p: Panel) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.10, 0.09, 0.97)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.75, 0.6, 0.3)
	p.add_theme_stylebox_override("panel", sb)
