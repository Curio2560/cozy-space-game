extends Node
## Definições do jogador (autoload Settings), guardadas em user://settings.cfg.

const PATH := "user://settings.cfg"
const LOCALES := ["pt", "en"]

signal locale_changed(locale: String)

var _cfg := ConfigFile.new()

func _ready() -> void:
	# Tema néon para toda a interface: junta-se ao tema base do motor (o tema da janela não
	# chega aos controlos dentro de CanvasLayers).
	var f := NeonTheme.font()
	ThemeDB.get_default_theme().merge_with(NeonTheme.make())
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

func cycle_locale() -> void:
	set_locale(LOCALES[(LOCALES.find(locale()) + 1) % LOCALES.size()])
