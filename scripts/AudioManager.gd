extends Node
## Autoload "Audio" — musica di sottofondo (in loop, condivisa fra le scene)
## ed effetti sonori: click sugli oggetti e apertura della porta.

var music: AudioStreamPlayer
var sfx_click: AudioStreamPlayer
var sfx_door: AudioStreamPlayer


func _ready() -> void:
	music = AudioStreamPlayer.new()
	var stream := load("res://assets/parallax/musica.mp3")
	if stream is AudioStreamMP3:
		stream.loop = true
	music.stream = stream
	music.volume_db = -14.0
	add_child(music)
	music.play()

	sfx_click = _make_player("res://assets/parallax/click.mp3", -6.0)
	sfx_door = _make_player("res://assets/parallax/porta.mp3", -4.0)


func _make_player(path: String, vol_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = vol_db
	add_child(p)
	return p


func click() -> void:
	sfx_click.play()


func door() -> void:
	sfx_door.play()
