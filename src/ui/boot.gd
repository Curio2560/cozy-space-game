extends Control
## Ecrã de arranque provisório (F0): nome, versão e atalhos para as cenas de teste.

const PLAY := "res://scenes/game/planet_run.tscn"
const SHOWCASE := "res://scenes/dev/showcase.tscn"
const CONTROLS := "res://scenes/dev/controls_test.tscn"
const PLANET := "res://scenes/dev/planet_view.tscn"

@onready var _title: Label = %Title
@onready var _version: Label = %Version
@onready var _play: Button = %Play
@onready var _showcase: Button = %Showcase
@onready var _controls: Button = %Controls
@onready var _planet: Button = %Planet
@onready var _language: Button = %Language

func _ready() -> void:
	_title.text = BuildInfo.game_name()
	_version.text = "v" + BuildInfo.version()
	# Jogar continua o jogo guardado (se houver); o save só fica ativo a partir daqui.
	_play.pressed.connect(func() -> void:
		SaveGame.active = true
		get_tree().change_scene_to_file(PLAY))
	_play.text = "BOOT_CONTINUE" if SaveGame.exists() else "BOOT_PLAY" # chaves: traduzidas sozinhas
	_showcase.pressed.connect(func() -> void: get_tree().change_scene_to_file(SHOWCASE))
	_controls.pressed.connect(func() -> void: get_tree().change_scene_to_file(CONTROLS))
	_planet.pressed.connect(func() -> void: get_tree().change_scene_to_file(PLANET))
	_language.pressed.connect(Settings.cycle_locale)
