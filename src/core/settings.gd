extends Node
## Definições do jogador (autoload Settings), guardadas em user://settings.cfg.

const PATH := "user://settings.cfg"
const LOCALES := ["pt", "en"]

signal locale_changed(locale: String)

var _cfg := ConfigFile.new()

func _ready() -> void:
	# Tema néon para toda a interface: junta-se ao tema base do motor (o tema da janela não
	# chega aos controlos dentro de CanvasLayers).
	var f := CozyTheme.font()
	ThemeDB.get_default_theme().merge_with(CozyTheme.make())
	ThemeDB.get_default_theme().default_font = f
	ThemeDB.fallback_font = f # também para Label3D (nomes dos colonos) e desenho direto
	_cfg.load(PATH)
	var loc := str(_cfg.get_value("ui", "locale", ""))
	if loc == "":
		loc = "pt" if OS.get_locale_language() == "pt" else "en"
	set_locale(loc, false)

func locale() -> String:
	return TranslationServer.get_locale().substr(0, 2)

func set_locale(loc: String, save := true) -> void:
	if loc not in LOCALES:
		loc = "en"
	TranslationServer.set_locale(loc)
	if save:
		_cfg.set_value("ui", "locale", loc)
		_cfg.save(PATH)
	locale_changed.emit(loc)

## Qualidade da relva: "low", "mid" ou "high" (alta por omissão).
const GRASS := {"low": 0.35, "mid": 0.65, "high": 1.0}
const GRASS_ORDER := ["high", "mid", "low"]
signal grass_changed(factor: float)

func grass() -> String:
	var g := str(_cfg.get_value("video", "grass", "high"))
	return g if GRASS.has(g) else "high"

func grass_factor() -> float:
	return GRASS[grass()]

func cycle_grass() -> String:
	var g: String = GRASS_ORDER[(GRASS_ORDER.find(grass()) + 1) % GRASS_ORDER.size()]
	_cfg.set_value("video", "grass", g)
	_cfg.save(PATH)
	grass_changed.emit(GRASS[g])
	return g

## Volume (0..1) de "music" ou "sfx".
func get_volume(kind: String) -> float:
	return clampf(float(_cfg.get_value("audio", kind, 0.8)), 0.0, 1.0)

func set_volume(kind: String, v: float) -> void:
	_cfg.set_value("audio", kind, clampf(v, 0.0, 1.0))
	_cfg.save(PATH)

## Próximo passo do volume (0 → 25 → 50 → 75 → 100 → 0 %), para um botão no menu.
func cycle_volume(kind: String) -> float:
	var v := get_volume(kind) + 0.25
	if v > 1.01:
		v = 0.0
	set_volume(kind, v)
	return v

func cycle_locale() -> void:
	set_locale(LOCALES[(LOCALES.find(locale()) + 1) % LOCALES.size()])
