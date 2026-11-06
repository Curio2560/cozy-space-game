class_name CreatureCatalog
extends RefCounted
## Catálogo das criaturas: um registo por espécie (modelo, altura, se tem animações).
## Os monstros do utilizador (Quaternius Ultimate Monsters, CC0) aparecem em todos os mundos
## com a cor ajustada ao bioma. Trocar ou acrescentar criaturas = editar esta tabela.

const GLTF := "res://assets/monsters/gltf/"
const OBJ := "res://assets/monsters/obj/"

## id -> {path, height (m), animated}
const CREATURES := {
	"Alien": {"path": GLTF + "Alien.gltf", "height": 1.5, "animated": true},
	"Birb": {"path": GLTF + "Birb.gltf", "height": 1.2, "animated": true},
	"BlueDemon": {"path": GLTF + "BlueDemon.gltf", "height": 1.6, "animated": true},
	"Bunny": {"path": GLTF + "Bunny.gltf", "height": 1.3, "animated": true},
	"Cactoro": {"path": GLTF + "Cactoro.gltf", "height": 1.4, "animated": true},
	"Demon": {"path": GLTF + "Demon.gltf", "height": 1.7, "animated": true},
	"Dino": {"path": GLTF + "Dino.gltf", "height": 1.4, "animated": true},
	"Fish": {"path": GLTF + "Fish.gltf", "height": 1.3, "animated": true},
	"Frog": {"path": GLTF + "Frog.gltf", "height": 1.1, "animated": true},
	"Monkroose": {"path": GLTF + "Monkroose.gltf", "height": 1.5, "animated": true},
	"MushroomKing": {"path": GLTF + "MushroomKing.gltf", "height": 1.6, "animated": true},
	"Ninja": {"path": GLTF + "Ninja.gltf", "height": 1.5, "animated": true},
	"Orc": {"path": GLTF + "Orc.gltf", "height": 1.8, "animated": true},
	"Orc_Skull": {"path": GLTF + "Orc_Skull.gltf", "height": 1.8, "animated": true},
	"Tribal": {"path": GLTF + "Tribal.gltf", "height": 1.6, "animated": true},
	"Yeti": {"path": GLTF + "Yeti.gltf", "height": 2.0, "animated": true},
	# Só em .obj (sem animações): movimento feito por código (saltinhos).
	"Cat": {"path": OBJ + "Cat.obj", "height": 0.8, "animated": false},
	"Chicken": {"path": OBJ + "Chicken.obj", "height": 0.7, "animated": false},
	"Dog": {"path": OBJ + "Dog.obj", "height": 0.9, "animated": false},
	"GreenBlob": {"path": OBJ + "GreenBlob.obj", "height": 0.9, "animated": false},
	"GreenSpikyBlob": {"path": OBJ + "GreenSpikyBlob.obj", "height": 1.0, "animated": false},
	"Mushnub": {"path": OBJ + "Mushnub.obj", "height": 0.9, "animated": false},
	"Mushnub_Evolved": {"path": OBJ + "Mushnub_Evolved.obj", "height": 1.3, "animated": false},
	"Pigeon": {"path": OBJ + "Pigeon.obj", "height": 0.6, "animated": false},
	"PinkBlob": {"path": OBJ + "PinkBlob.obj", "height": 0.9, "animated": false},
	"Wizard": {"path": OBJ + "Wizard.obj", "height": 1.5, "animated": false},
}
const LOOPED := ["Idle", "Walk", "Run", "Jump_Idle"]

## Tom das criaturas em cada bioma.
static func tint_for(biome: String) -> Color:
	return {"prado": Color.WHITE, "acido": Color("d8ffc8"), "lava": Color("ffd0bc")}.get(biome, Color.WHITE)

## Instancia a criatura `id` em cel-shading, com a altura certa e o tom do bioma.
## Devolve um Node3D com a origem nos pés (a frente é +Z).
static func instantiate(id: String, biome := "prado") -> Node3D:
	var def: Dictionary = CREATURES[id]
	var root := Node3D.new()
	root.name = id
	var model: Node3D
	if def.animated:
		model = (load(def.path) as PackedScene).instantiate()
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = load(def.path)
		model = mi
	root.add_child(model)
	KitUtil.fit_height(model, def.height)
	CelShading.apply(model, tint_for(biome))
	var ap := animation_player(root)
	if ap:
		for a in LOOPED:
			if ap.has_animation(a):
				ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		if ap.has_animation("Idle"):
			ap.play("Idle")
	return root

static func animation_player(n: Node) -> AnimationPlayer:
	var aps := n.find_children("*", "AnimationPlayer", true, false)
	return aps[0] if not aps.is_empty() else null

static func ids() -> Array:
	return CREATURES.keys()
