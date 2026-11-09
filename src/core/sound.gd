extends Node
## Som e música (autoload Sound, F5 #52). Efeitos com um conjunto fixo de leitores e música com
## troca suave (dia/noite). Volumes (0..1) guardados nas definições. Os ficheiros estão em
## assets/audio (gerados por tools/synth_audio.py; podem ser trocados por outros com o mesmo nome).

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const POOL := 10
const FADE := 1.5
const MUSIC_DB := -8.0
## Intervalo mínimo entre repetições do mesmo efeito (tiros muito seguidos).
const MIN_GAP := 0.05

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _streams := {}
var _last := {}
var _music: Array[AudioStreamPlayer] = []
var _music_on := 0
var current_music := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		m.volume_db = -60.0
		add_child(m)
		_music.append(m)
	set_volume("Music", Settings.get_volume("music"))
	set_volume("SFX", Settings.get_volume("sfx"))

func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) if ResourceLoader.exists(path) else null
	return _streams[path]

## Toca o efeito `name` (assets/audio/sfx/<name>.wav). `pitch_var` varia o tom (±).
func play(name: String, volume_db := 0.0, pitch_var := 0.05) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(name, -1.0)) < MIN_GAP:
		return
	_last[name] = now
	var s := _stream(SFX_DIR + name + ".wav")
	if s == null:
		return
	var p := _players[_next % POOL]
	_next += 1
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()

## Muda a música para `name` (em loop) com troca suave. "" pára.
func music(name: String) -> void:
	if name == current_music:
		return
	current_music = name
	var old := _music[_music_on]
	_music_on = 1 - _music_on
	var nw := _music[_music_on]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(old, "volume_db", -60.0, FADE)
	if name != "":
		var s := _stream(MUSIC_DIR + name + ".wav")
		if s is AudioStreamWAV:
			var w := s as AudioStreamWAV
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * w.mix_rate)
		nw.stream = s
		nw.volume_db = -60.0
		nw.play()
		tw.tween_property(nw, "volume_db", MUSIC_DB, FADE)

## Volume de um bus (0..1).
func set_volume(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))
