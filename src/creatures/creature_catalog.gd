class_name CreatureCatalog
extends RefCounted
## Catálogo das criaturas (Quaternius Ultimate Monsters, CC0): 50 espécies em três famílias
## (big, blob, flying), todas com animações. Aparecem em todos os mundos com a cor ajustada
## ao bioma. Trocar ou acrescentar criaturas = editar esta tabela.
##
## Cada família usa nomes de animação diferentes; o jogo pede papéis (idle, move, run, attack,
## hit, death) e `anim()` devolve o nome certo.

const DIR := "res://assets/monsters/gltf/"

## família -> {altura por omissão (m), voa (paira a esta altura), papéis -> nomes de animação}
const FAMILIES := {
	"big": {"height": 1.6, "hover": 0.0,
		"anims": {"idle": "Idle", "move": "Walk", "run": "Run", "attack": "Punch", "hit": "HitReact", "death": "Death"}},
	"blob": {"height": 0.9, "hover": 0.0,
		"anims": {"idle": "Idle", "move": "Walk", "run": "Walk", "attack": "Bite_Front", "hit": "HitRecieve", "death": "Death"}},
	"flying": {"height": 1.2, "hover": 1.6,
		"anims": {"idle": "Flying_Idle", "move": "Flying_Idle", "run": "Fast_Flying", "attack": "Headbutt", "hit": "HitReact", "death": "Death"}},
}

## id ("família/Nome") -> altura própria quando foge à da família
const HEIGHTS := {
	"big/Yeti": 2.0, "big/Orc": 1.8, "big/Orc_Skull": 1.8, "big/Frog": 1.1, "big/Birb": 1.2, "big/Bunny": 1.3,
	"blob/Mushnub_Evolved": 1.2, "blob/GreenSpikyBlob": 1.0, "blob/Pigeon": 0.7, "blob/Chicken": 0.75,
	"flying/Dragon_Evolved": 1.8, "flying/Goleling_Evolved": 1.6, "flying/Alpaking_Evolved": 1.5,
}

const LOOPED_ROLES := ["idle", "move", "run"]

static var _ids: Array = []

## Todos os ids ("big/Alien", "blob/Cat", "flying/Dragon"…), lidos das pastas.
static func ids() -> Array:
	if _ids.is_empty():
		for fam: String in FAMILIES:
			for name in gltf_names(DirAccess.get_files_at(DIR + fam)):
				_ids.append(fam + "/" + name)
	return _ids

## Nomes (sem extensão) dos modelos .gltf numa listagem de pasta. No APK exportado os .gltf
## originais não existem: a pasta lista "X.gltf.import" (ou ".remap"), por isso aceitam-se os três.
static func gltf_names(files: PackedStringArray) -> Array:
	var out := []
	for f in files:
		var n := f.trim_suffix(".remap").trim_suffix(".import")
		if n.ends_with(".gltf"):
			n = n.trim_suffix(".gltf")
			if n not in out:
				out.append(n)
	out.sort()
	return out

static func family(id: String) -> String:
	return id.get_slice("/", 0)

static func height(id: String) -> float:
	return HEIGHTS.get(id, FAMILIES[family(id)].height)

static func hover(id: String) -> float:
	return FAMILIES[family(id)].hover

## Nome da animação para um papel (idle, move, run, attack, hit, death) nesta criatura.
## Se a criatura não a tiver, cai para idle e depois para a primeira que exista.
static func anim(creature: Node, role: String) -> String:
	var ap := animation_player(creature)
	if ap == null:
		return ""
	var fam_anims: Dictionary = FAMILIES[family(String(creature.get_meta(&"creature_id", "big/x")))].anims
	for name: String in [fam_anims.get(role, ""), fam_anims.idle]:
		if name != "" and ap.has_animation(name):
			return name
	var list := ap.get_animation_list()
	return list[0] if not list.is_empty() else ""

## Tom das criaturas em cada bioma.
static func tint_for(biome: String) -> Color:
	return {"prado": Color.WHITE, "acido": Color("d8ffc8"), "lava": Color("ffd0bc")}.get(biome, Color.WHITE)

## Instancia a criatura `id` em cel-shading, com a altura certa, o tom do bioma e a animação
## de repouso. Devolve um Node3D com a origem nos pés (os voadores já vêm a pairar); frente = +Z.
static func instantiate(id: String, biome := "prado") -> Node3D:
	var root := Node3D.new()
	root.name = id.replace("/", "_")
	root.set_meta(&"creature_id", id)
	var model: Node3D = (load(DIR + id + ".gltf") as PackedScene).instantiate()
	root.add_child(model)
	KitUtil.fit_height(model, height(id))
	model.position.y += hover(id)
	CelShading.apply(model, tint_for(biome))
	var ap := animation_player(root)
	if ap:
		for role in LOOPED_ROLES:
			var n := anim(root, role)
			if n != "":
				ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		var idle := anim(root, "idle")
		if idle != "":
			ap.play(idle)
	return root

static func animation_player(n: Node) -> AnimationPlayer:
	var aps := n.find_children("*", "AnimationPlayer", true, false)
	return aps[0] if not aps.is_empty() else null
