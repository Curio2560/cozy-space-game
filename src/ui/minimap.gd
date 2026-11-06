class_name Minimap
extends Control
## Minimapa redondo: o que está até RANGE metros do jogador, projetado no plano tangente e
## rodado com a câmara (em frente = para cima). Estradas, estruturas, criaturas, rover e o destino
## da entrega (preso à borda se estiver longe). Marcadores: Kenney Simple Space (CC0).

const RANGE := 70.0
const SIZE := 250.0
const KEN := "res://assets/ui/kenney_space/"
const TEX_PLAYER := preload(KEN + "ship_A.png")
const TEX_BASE := preload(KEN + "station_A.png")
const TEX_POST := preload(KEN + "satellite_A.png")
const TEX_LAIR := preload(KEN + "meteor_detailedLarge.png")
const TEX_ROVER := preload(KEN + "ship_sidesA.png")
const TEX_TARGET := preload(KEN + "icon_exclamationLarge.png")
const TEX_CREATURE := preload(KEN + "enemy_A.png")

var run: Node3D
var _timer := 0.0
## Para testes: última posição (no ecrã do minimapa) do destino da entrega.
var last_target_pos := Vector2.INF

func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = 1.0 / 15.0 # 15 vezes por segundo chega
		queue_redraw()

## Converte um ponto global para coordenadas do minimapa (centro = jogador, cima = em frente).
func to_map(world: Vector3) -> Vector2:
	var c: Node3D = run.carrier_node()
	var up: Vector3 = (c.global_position - run.planet.global_position).normalized()
	var fwd: Vector3 = -run.camera.global_basis.z
	fwd = (fwd - up * fwd.dot(up)).normalized()
	var right := fwd.cross(up).normalized()
	var v := world - c.global_position
	var k := (SIZE * 0.5) / RANGE
	return Vector2(v.dot(right), -v.dot(fwd)) * k + Vector2(SIZE, SIZE) * 0.5

## Um ponto só entra no mapa se estiver perto: pontos do outro lado do planeta projetavam-se
## para perto do centro e apareciam como estradas e marcadores fantasma.
func near(world: Vector3) -> bool:
	var c: Node3D = run.carrier_node()
	var up: Vector3 = (c.global_position - run.planet.global_position).normalized()
	var v := world - c.global_position
	return v.length() < RANGE * 1.3 and v.dot(up) > -RANGE * 0.5

func _inside(p: Vector2) -> bool:
	return p.distance_to(Vector2(SIZE, SIZE) * 0.5) < SIZE * 0.5 - 6.0

func _clamp_edge(p: Vector2) -> Vector2:
	var c := Vector2(SIZE, SIZE) * 0.5
	var d := p - c
	var r := SIZE * 0.5 - 16.0
	return c + d.limit_length(r)

func _icon(tex: Texture2D, p: Vector2, px: float, rot := 0.0, tint := Color.WHITE) -> void:
	draw_set_transform(p, rot, Vector2.ONE)
	var s := px / maxf(tex.get_width(), tex.get_height())
	var sz := Vector2(tex.get_width(), tex.get_height()) * s
	draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw() -> void:
	var c := Vector2(SIZE, SIZE) * 0.5
	if run == null or run.planet == null or run.planet.data == null:
		return
	var planet: Planet = run.planet
	var d: PlanetData = planet.data
	# Estilo cel: sombra sólida, fundo da cor do chão do bioma, contorno escuro grosso.
	draw_circle(c + Vector2(0, 6), SIZE * 0.5, CozyTheme.INK)
	draw_circle(c, SIZE * 0.5, Color(PlanetGenerator.BIOMES[d.biome].ground).darkened(0.05))
	var road_col := Color(PlanetGenerator.BIOMES[d.biome].palette.get("Road", Color("d9c49b"))).lightened(0.25)
	# Estradas.
	for road in d.roads:
		var pts: PackedVector3Array = road.points
		var prev := Vector2.INF
		var w: float = clampf(float(road.width) * (SIZE * 0.5) / RANGE, 2.0, 8.0)
		for i in pts.size():
			var wp := planet.to_global(d.surface_point(pts[i]))
			if not near(wp):
				prev = Vector2.INF
				continue
			var mp := to_map(wp)
			if prev != Vector2.INF and (_inside(mp) or _inside(prev)):
				draw_line(prev, mp, road_col, w, true)
			prev = mp
	# Estruturas.
	_marker(TEX_BASE, planet.to_global(d.surface_point(d.outpost_dir)), 30.0, false, CozyTheme.INK)
	for p in d.posts:
		_marker(TEX_POST, planet.to_global(d.surface_point(p)), 22.0, false, CozyTheme.INK)
	_marker(TEX_LAIR, planet.to_global(d.surface_point(d.lair_dir)), 22.0, false, Color(1.0, 0.45, 0.45))
	# Criaturas perto.
	for cr in run.creatures:
		if not is_instance_valid(cr):
			continue
		if not near(cr.global_position):
			continue
		var mp := to_map(cr.global_position)
		if _inside(mp):
			var hostile: bool = cr._hostile() or cr.carrying # vermelho só quando há perigo (com encomenda)
			_icon(TEX_CREATURE, mp, 14.0, 0.0, Color("e8455a") if hostile else Color(CozyTheme.INK, 0.55))
	# Rover (quando o jogador vai a pé).
	if not run.driving:
		_marker(TEX_ROVER, run.rover.global_position, 18.0, false, CozyTheme.INK)
	# Destino da entrega (pisca; preso à borda se estiver longe).
	last_target_pos = Vector2.INF
	var t = run.deliveries.target_world_position() if run.deliveries else null
	if t != null:
		var tp := _target_point(t)
		last_target_pos = tp
		var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
		_icon(TEX_TARGET, tp, 26.0 * pulse, 0.0, CozyTheme.INK)
		_icon(TEX_TARGET, tp, 22.0 * pulse, 0.0, CozyTheme.SUN)
	# Jogador no centro, a apontar para cima.
	_icon(TEX_PLAYER, c + Vector2(0, 2), 26.0, 0.0, CozyTheme.INK)
	_icon(TEX_PLAYER, c, 22.0, 0.0, CozyTheme.PEACH)
	draw_arc(c, SIZE * 0.5 - 4.0, 0.0, TAU, 64, CozyTheme.INK, 8.0, true)

## Posição do destino no mapa; se estiver longe (ou do outro lado do planeta) fica na borda, na
## direção certa (a mesma conta da seta do HUD).
func _target_point(world: Vector3) -> Vector2:
	if near(world):
		var tp := to_map(world)
		if _inside(tp):
			return tp
	var c: Node3D = run.carrier_node()
	var up: Vector3 = (c.global_position - run.planet.global_position).normalized()
	var ang := NavArrow.angle_to_target(c.global_position, up, run.camera.global_basis, world)
	var r := SIZE * 0.5 - 16.0
	return Vector2(SIZE, SIZE) * 0.5 + Vector2(sin(ang), -cos(ang)) * r

## Calcula as posições do desenho sem desenhar (testes).
func _draw_for_test() -> void:
	last_target_pos = Vector2.INF
	var t = run.deliveries.target_world_position() if run.deliveries else null
	if t != null:
		last_target_pos = _target_point(t)

func _marker(tex: Texture2D, world: Vector3, px: float, clamp_edge: bool, tint := Color.WHITE) -> void:
	if not clamp_edge and not near(world):
		return
	var mp := to_map(world)
	if not _inside(mp):
		if not clamp_edge:
			return
		mp = _clamp_edge(mp)
	_icon(tex, mp, px, 0.0, tint)
