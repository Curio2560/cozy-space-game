class_name BuildInfo
extends RefCounted
## Nome e versão do jogo, lidos das definições do projeto (uma única fonte de verdade).

static func game_name() -> String:
	return str(ProjectSettings.get_setting("application/config/name", ""))

static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))

static func label() -> String:
	return "%s v%s" % [game_name(), version()]
