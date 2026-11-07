extends GutTest
## Construtor de módulos (DBG → Construir) e edifícios montados.

var run: Node3D

func before_each() -> void:
	run = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(20)

func test_modules_are_listed() -> void:
	assert_gte(BuildingKit.modules().size(), 80)
	assert_true(BuildingKit.modules().has("Wall_1"))

func test_place_rotate_undo_clear() -> void:
	var b: ModuleBuilder = run.builder
	b.selected = "Wall_1"
	b.place()
	b.rotate_90()
	b.place()
	assert_eq(b.placed.size(), 2)
	assert_eq(int(b.placed[1].r), 90)
	b.undo()
	assert_eq(b.placed.size(), 1)
	b.clear()
	assert_eq(b.placed.size(), 0)

func test_prefab_places_all_its_parts_and_layout_text() -> void:
	var b: ModuleBuilder = run.builder
	b.selected = "★ Casa do colono"
	b.place()
	assert_eq(b.placed.size(), BuildingKit.colonist_house().size())
	var t := b.layout_text()
	assert_true(t.begins_with("[") and t.contains('"m": "DoorSingle_Wall_SideA"'))

func test_snaps_to_grid() -> void:
	var b: ModuleBuilder = run.builder
	var c := b.cursor_local()
	assert_almost_eq(fmod(absf(c.x), ModuleBuilder.GRID), 0.0, 0.001)
	assert_almost_eq(fmod(absf(c.z), ModuleBuilder.GRID), 0.0, 0.001)

func test_planet_uses_modular_buildings() -> void:
	var house: Node3D = run.planet.get_node("Post0")
	assert_not_null(house.get_node_or_null("Mesh"), "a casa do colono devia ser um edifício montado")
	assert_not_null(run.planet.get_node("Outpost").get_node_or_null("Mesh"))

func test_build_mode_closes_debug_and_shows_bar_and_ghost() -> void:
	var b: ModuleBuilder = run.builder
	if not DebugMenu.is_open():
		DebugMenu.toggle()
	b.enter_mode()
	assert_false(DebugMenu.is_open(), "o painel DBG fecha para se ver onde se constrói")
	assert_true(b._bar.visible)
	assert_true(b._ghost.visible)
	var before := b.selected
	b.cycle(1)
	assert_ne(b.selected, before)
	b.place()
	assert_gt(b.placed.size(), 0)
	b.exit_mode()
	assert_false(b._bar.visible)

func test_first_piece_lands_in_front_of_player_on_the_surface() -> void:
	var b: ModuleBuilder = run.builder
	b.selected = "Wall_1"
	b.place()
	var anchor: Vector3 = b._anchor.global_position
	var p: Vector3 = run.player.global_position
	assert_lt(anchor.distance_to(p), ModuleBuilder.AHEAD + 3.0, "a primeira peça fica à frente do jogador")
	var up: Vector3 = (anchor - run.planet.global_position).normalized()
	assert_gt(b._anchor.global_basis.y.normalized().dot(up), 0.99, "assente no chão, de pé")
	var d: PlanetData = run.planet.data
	var local: Vector3 = run.planet.to_local(anchor)
	assert_almost_eq(local.length(), d.radius + d.height_at(local.normalized()), 0.2)
