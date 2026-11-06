extends GutTest
## Interface: tema néon, menu de pausa e minimapa.

var run: Node3D

func before_each() -> void:
	run = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(20)

func after_each() -> void:
	get_tree().paused = false

func test_neon_theme_applies_to_buttons() -> void:
	var b := Button.new()
	add_child_autofree(b)
	var sb := b.get_theme_stylebox("normal") as StyleBoxFlat
	assert_not_null(sb, "os botões deviam usar o tema néon")
	assert_eq(sb.border_color, CozyTheme.INK)
	assert_gt(sb.shadow_offset.y, 0.0, "sombra cel deslocada")

func test_pause_menu_pauses_and_resumes() -> void:
	var pm: PauseMenu = run.pause_menu
	pm.open()
	assert_true(get_tree().paused)
	assert_true(pm.is_open())
	pm.close()
	assert_false(get_tree().paused)

func test_pause_new_planet_changes_seed() -> void:
	var before: int = run.seed_value
	run.pause_menu.open()
	run.pause_menu.new_planet.emit()
	run.pause_menu.close()
	assert_ne(run.seed_value, before)

func test_minimap_shows_target_ahead_above_centre() -> void:
	var mm: Minimap = run.minimap
	var cam: Camera3D = run.camera
	var p: Node3D = run.player
	var up: Vector3 = (p.global_position - run.planet.global_position).normalized()
	var fwd := -cam.global_basis.z
	fwd = (fwd - up * fwd.dot(up)).normalized()
	var ahead := mm.to_map(p.global_position + fwd * 20.0)
	var centre := Vector2(Minimap.SIZE, Minimap.SIZE) * 0.5
	assert_lt(ahead.y, centre.y - 10.0, "o que está à frente aparece acima do centro")
	assert_almost_eq(ahead.x, centre.x, 3.0)

func test_minimap_clamps_far_target_to_edge() -> void:
	var dc: DeliveryController = run.deliveries
	dc.accept(dc.session.offers[0])
	run.minimap._draw_for_test()
	var tp: Vector2 = run.minimap.last_target_pos
	assert_ne(tp, Vector2.INF, "devia marcar o destino")
	var centre := Vector2(Minimap.SIZE, Minimap.SIZE) * 0.5
	assert_lte(tp.distance_to(centre), Minimap.SIZE * 0.5)

func test_game_font_is_matcha_with_fallback_for_symbols() -> void:
	var l := Label.new()
	add_child_autofree(l)
	var f := l.get_theme_font("font")
	assert_true(f.resource_path.contains("MatchaStyle") or (f is FontFile and (f as FontFile).fallbacks.size() > 0), "a fonte do jogo devia ser a Matcha Style")
	var mf := CozyTheme.font()
	assert_true(mf.has_char("ç".unicode_at(0)) and mf.has_char("ã".unicode_at(0)), "acentos portugueses")
	assert_gt(mf.fallbacks.size(), 0, "fonte de reserva para → · ₂")

func test_minimap_ignores_far_side_of_planet() -> void:
	var mm: Minimap = run.minimap
	var far: Vector3 = run.planet.global_position - (run.player.global_position - run.planet.global_position)
	assert_false(mm.near(far), "o outro lado do planeta não entra no minimapa")
	assert_true(mm.near(run.player.global_position + Vector3(0.1, 0, 0)))

func test_minimap_far_target_on_edge_in_arrow_direction() -> void:
	var mm: Minimap = run.minimap
	var p: Node3D = run.player
	var far: Vector3 = run.planet.global_position - (p.global_position - run.planet.global_position) * 0.98 + run.camera.global_basis.x * 5.0
	var tp := mm._target_point(far)
	var centre := Vector2(Minimap.SIZE, Minimap.SIZE) * 0.5
	assert_almost_eq(tp.distance_to(centre), Minimap.SIZE * 0.5 - 16.0, 1.0, "fica na borda")
