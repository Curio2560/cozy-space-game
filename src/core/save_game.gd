class_name SaveGame
extends RefCounted
## Jogo guardado: um só espaço, JSON versionado em user://. Cada sistema dá a sua secção
## (planeta, carteira, entregas e, mais tarde, posto, quinta, upgrades, tripulação).
## Só fica ativo quando o jogo é aberto pelo menu (os testes e as cenas de dev não mexem no save).

const VERSION := 1
const DEFAULT_PATH := "user://save.json"

static var path := DEFAULT_PATH
## Ligado pelo menu ao entrar no jogo. Desligado = nem carrega nem guarda.
static var active := false

static func exists() -> bool:
	return FileAccess.file_exists(path)

## Escreve o estado (com a versão). Devolve se conseguiu.
static func write(state: Dictionary) -> bool:
	var data := state.duplicate(true)
	data["version"] = VERSION
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("save: não consegui escrever %s" % tmp)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	# Troca atómica: um save a meio nunca estraga o anterior.
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null or dir.rename(tmp.get_file(), path.get_file()) != OK:
		push_warning("save: não consegui substituir %s" % path)
		return false
	return true

## Estado guardado, ou {} se não houver save ou for de outra versão.
static func read() -> Dictionary:
	if not exists():
		return {}
	var json := JSON.new() # parse() não imprime erros (um save estragado não é um erro do jogo)
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_warning("save: ficheiro inválido, ignorado")
		return {}
	var data = json.data
	if not data is Dictionary:
		push_warning("save: ficheiro inválido, ignorado")
		return {}
	if int(data.get("version", 0)) != VERSION:
		push_warning("save: versão %s diferente de %d, ignorado" % [data.get("version"), VERSION])
		return {}
	return data

static func erase() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
