extends Control
## Ecrã de arranque provisório: prova que o projeto abre no telemóvel.

@onready var _title: Label = %Title
@onready var _version: Label = %Version
@onready var _showcase: Button = %Showcase

const SHOWCASE := "res://scenes/dev/showcase.tscn"

func _ready() -> void:
	_title.text = BuildInfo.game_name()
	_version.text = "v" + BuildInfo.version()
	_showcase.pressed.connect(func() -> void: get_tree().change_scene_to_file(SHOWCASE))
