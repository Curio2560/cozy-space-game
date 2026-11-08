extends Node3D
## Vitrine das criaturas: todas em fila, em cel-shading, a alternar animações.
## `-- biome=acido` mostra o tom de outro bioma.

var _players: Array[AnimationPlayer] = []
var _creatures: Array[Node] = []
var _t := 0.0

func _ready() -> void:
	var biome := "prado"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("biome="):
			biome = a.substr(6)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("231a38")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c4bce0")
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.15
	add_child(sun)
	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	(ground.mesh as PlaneMesh).size = Vector2(40, 22)
	ground.position = Vector3(8, 0, 6)
	ground.material_override = CelShading.terrain(PlanetGenerator.BIOMES[biome].ground)
	add_child(ground)
	var ids := CreatureCatalog.ids()
	for i in ids.size():
		var c := CreatureCatalog.instantiate(ids[i], biome)
		c.position = Vector3((i % 10) * 1.8, 0, (i / 10) * 2.6)
		c.rotation.y = 0.35
		add_child(c)
		var ap := CreatureCatalog.animation_player(c)
		if ap:
			_players.append(ap)
			_creatures.append(c)
	var cam := Camera3D.new()
	cam.fov = 42
	add_child(cam)
	cam.position = Vector3(8.2, 11.0, 22.0)
	cam.look_at(Vector3(8.2, 0.6, 5.5))

func _process(delta: float) -> void:
	_t += delta
	var roles := ["idle", "move", "attack", "run"]
	var role: String = roles[int(_t / 1.5) % roles.size()]
	for i in _players.size():
		var c: Node = _creatures[i]
		var want := CreatureCatalog.anim(c, role if i % 2 == 0 else "idle")
		if want != "" and _players[i].current_animation != want:
			_players[i].play(want, 0.2)
