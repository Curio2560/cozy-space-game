extends Control
## Ecrã de arranque provisório: prova que o projeto abre no telemóvel.

@onready var _title: Label = %Title
@onready var _version: Label = %Version

func _ready() -> void:
	_title.text = BuildInfo.game_name()
	_version.text = "v" + BuildInfo.version()
