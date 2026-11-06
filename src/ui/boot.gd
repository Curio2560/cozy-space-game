extends Control
## Ecrã de arranque provisório (F0): nome, versão e atalhos para as cenas de teste.

const SHOWCASE := "res://scenes/dev/showcase.tscn"
const CONTROLS := "res://scenes/dev/controls_test.tscn"

@onready var _title: Label = %Title
@onready var _version: Label = %Version
@onready var _showcase: Button = %Showcase
@onready var _controls: Button = %Controls
@onready var _language: Button = %Language

func _ready() -> void:
	_title.text = BuildInfo.game_name()
	_version.text = "v" + BuildInfo.version()
	_showcase.pressed.connect(func() -> void: get_tree().change_scene_to_file(SHOWCASE))
	_controls.pressed.connect(func() -> void: get_tree().change_scene_to_file(CONTROLS))
	_language.pressed.connect(Settings.cycle_locale)
