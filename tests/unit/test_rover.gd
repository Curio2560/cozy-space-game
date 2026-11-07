extends GutTest
## Smoke tests do rover no planeta: entrar/sair, conduzir, endireitar e embates.

var run: Node3D

## Leva o jogador e o rover para o meio de uma estrada principal, com o rover alinhado com ela
## (conduzir em frente segue a estrada, sem árvores pelo caminho).
func _open_road() -> void:
	var d: PlanetData = run.planet.data
	var pts: PackedVector3Array = d.roads[0].points
	var i := pts.size() / 3
	run.teleport(pts[i])
	await wait_physics_frames(10)
	var along: Vector3 = run.planet.global_basis * (pts[i + 4] - pts[i])
	run.rover.place_at(run.planet.to_global(d.surface_point(pts[i + 2]) + pts[i + 2] * 1.0), along)
	await wait_physics_frames(40)

func before_each() -> void:
	run = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(60) # jogador e rover assentam

func after_each() -> void:
	for a in ["move_forward", "move_right", "vehicle"]:
		Input.action_release(a)

func _tap_vehicle() -> void:
	Input.action_press("vehicle")
	await wait_physics_frames(2)
	Input.action_release("vehicle")
	await wait_physics_frames(2)

func _height(body: Node3D) -> float:
	var d: PlanetData = run.planet.data
	var local: Vector3 = run.planet.to_local(body.global_position)
	return local.length() - (d.radius + d.height_at(local.normalized()))

func test_rover_rests_on_its_wheels() -> void:
	var rover: Rover = run.rover
	assert_eq(rover.grounded_wheels, 4, "as 4 rodas deviam tocar no chão")
	assert_gt(rover.global_basis.y.dot(rover.planet_up()), 0.95)
	assert_lt(rover.linear_velocity.length(), 0.5, "devia estar parado")

func test_enter_drive_and_exit() -> void:
	await _open_road()
	assert_true(run.can_enter_rover(), "o rover devia estar ao alcance no início")
	await _tap_vehicle()
	assert_true(run.driving)
	assert_false(run.player.visible)
	var start: Vector3 = run.rover.planet_up()
	Input.action_press("move_forward", 1.0)
	await wait_physics_frames(180)
	Input.action_release("move_forward")
	var arc: float = start.angle_to(run.rover.planet_up()) * run.planet.data.radius
	assert_gt(arc, 15.0, "o rover devia ter andado (andou %.1f m)" % arc)
	assert_lt(absf(_height(run.rover)), 2.5, "o rover afastou-se da superfície")
	await wait_physics_frames(60)
	await _tap_vehicle()
	assert_false(run.driving)
	assert_true(run.player.visible)
	await wait_physics_frames(60)
	assert_true(run.player.is_on_floor(), "o jogador devia sair para o chão")
	assert_lt(run.player.global_position.distance_to(run.rover.global_position), 5.0)

func test_rover_turns_when_steering() -> void:
	await _open_road()
	await _tap_vehicle()
	var f0: Vector3 = run.rover.forward()
	Input.action_press("move_forward", 1.0)
	Input.action_press("move_right", 1.0)
	await wait_physics_frames(90)
	var u: Vector3 = run.rover.planet_up()
	var a := f0 - u * f0.dot(u)
	var b: Vector3 = run.rover.forward() - u * run.rover.forward().dot(u)
	assert_gt(rad_to_deg(a.angle_to(b)), 30.0, "o rover devia ter virado")

func test_flipped_rover_rights_itself() -> void:
	var rover: Rover = run.rover
	var u := rover.planet_up()
	rover.global_transform = Transform3D(rover.global_basis.rotated(rover.forward(), PI), rover.global_position + u * 1.5)
	rover.linear_velocity = Vector3.ZERO
	rover.angular_velocity = Vector3.ZERO
	await wait_physics_frames(300)
	assert_gt(rover.global_basis.y.dot(rover.planet_up()), 0.9, "o rover devia ter-se endireitado")

func test_hard_landing_counts_as_bump() -> void:
	var rover: Rover = run.rover
	var u := rover.planet_up()
	rover.bump_total = 0.0
	rover.place_at(rover.global_position + u * 6.0, rover.forward())
	await wait_physics_frames(120)
	assert_gt(rover.bump_total, 0.0, "cair de 6 m devia contar como embate")

func test_cannot_enter_rover_from_far_away() -> void:
	run.spawn_near(run.planet.data.posts[1], run.planet.data.outpost_dir, 5.0)
	await wait_physics_frames(30)
	assert_false(run.can_enter_rover())
	await _tap_vehicle()
	assert_false(run.driving)

func test_rover_below_ground_is_put_back_on_top() -> void:
	var rover: Rover = run.rover
	var d: PlanetData = run.planet.data
	var dir: Vector3 = run.planet.to_local(rover.global_position).normalized()
	rover.global_position = run.planet.to_global(dir * (d.radius + d.height_at(dir) - 1.5))
	await wait_physics_frames(30)
	assert_gt(_height(rover), -0.1, "o rover ficou preso debaixo do chão")

func test_rover_climbs_a_relief() -> void:
	# Conduz em linha reta até ao topo de uma peça de relevo.
	var d: PlanetData = run.planet.data
	var r: Dictionary = d.reliefs[0]
	var foot: float = ReliefKit.piece(r.kind).radius * float(r.scale)
	var top_dir: Vector3 = r.dir
	# Rumo sem árvores nem pedregulhos (colisores) no caminho até ao topo.
	var start := Vector3.ZERO
	for h in 16:
		var cand := d.toward_point(top_dir, top_dir + SphereMath.basis_from_up(top_dir, TAU * h / 16.0).z, foot + 4.0)
		var clear := d.road_clearance(cand) > 3.0
		for p in d.placements:
			if p.collider <= 0.0 or not clear:
				continue
			# Distância do obstáculo ao segmento início→topo (aprox. no plano tangente).
			var ab := (top_dir - cand) * d.radius
			var ap := ((p.dir as Vector3) - cand) * d.radius
			var u := clampf(ap.dot(ab) / ab.length_squared(), 0.0, 1.0)
			if (ap - ab * u).length() < 3.5:
				clear = false
		if clear:
			start = cand
			break
	if start == Vector3.ZERO:
		pass_test("sem rumo livre até ao topo nesta seed")
		return
	run.teleport(start)
	await wait_physics_frames(10)
	run.rover.place_at(run.planet.to_global(d.surface_point(start) + start * 1.0), run.planet.global_basis * (top_dir - start))
	await wait_physics_frames(30)
	await _tap_vehicle()
	await wait_physics_frames(10)
	var best := INF
	for k in 12:
		var here: Vector3 = run.planet.to_local(run.rover.global_position).normalized()
		var to_top: Vector3 = run.planet.global_basis * (top_dir - here)
		var f: Vector3 = run.rover.forward()
		Input.action_press("move_forward", 1.0)
		Input.action_press("move_right", clampf(f.cross(to_top).dot(run.rover.planet_up()) * -3.0, -1.0, 1.0))
		await wait_physics_frames(30)
		best = minf(best, d.arc_m(run.planet.to_local(run.rover.global_position).normalized(), top_dir))
	assert_lt(best, foot * 0.35, "o rover não chegou perto do topo (%s)" % r.kind)
