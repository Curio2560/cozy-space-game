extends GutTest
## Rastos das rodas, pó e manchas de terra.

var run: Node3D

func before_each() -> void:
	run = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(60)

func after_each() -> void:
	Input.action_release("move_forward")

func test_driving_leaves_tracks_and_dust() -> void:
	var tr: TireTracks = run.tracks
	var before := tr.placed
	run.enter_rover()
	Input.action_press("move_forward", 1.0)
	await wait_physics_frames(120)
	assert_gt(tr.placed - before, 20, "o rover devia deixar rastos")
	assert_true(run.dust.emitting, "devia levantar pó em velocidade")

func test_standing_still_leaves_no_tracks() -> void:
	var tr: TireTracks = run.tracks
	var before := tr.placed
	await wait_physics_frames(60)
	assert_eq(tr.placed, before)

func test_tracks_fade_with_time() -> void:
	var tr := TireTracks.new()
	add_child_autofree(tr)
	tr.mark(0, Vector3(0, 10, 0), Vector3.UP, Vector3.FORWARD)
	var a0 := tr.alpha_of(0)
	assert_gt(a0, 0.0)
	tr._time += TireTracks.LIFETIME * 0.5
	tr._fade_timer = 0.0
	tr._process(0.0)
	assert_lt(tr.alpha_of(0), a0)

func test_dirt_patches_off_road_and_nothing_grows_on_them() -> void:
	var d: PlanetData = run.planet.data
	assert_gt(d.dirt_patches.size(), 60)
	for p in d.placements:
		for patch in d.dirt_patches:
			assert_gt(d.arc_m(p.dir, patch.dir), float(patch.radius) * 0.9, "%s em cima de uma mancha de terra" % p.kind)
	assert_not_null(run.planet.dirt_mesh)

func test_houses_face_the_road() -> void:
	var d: PlanetData = run.planet.data
	for i in d.posts.size():
		var house: Node3D = run.planet.get_node("Post%d" % i)
		var fwd := house.global_basis.z.normalized()
		var to_door: Vector3 = run.planet.to_global(d.surface_point(d.post_doors[i])) - house.global_position
		assert_gt(fwd.dot(to_door.normalized()), 0.9, "a casa %d devia estar virada para a estrada" % i)
