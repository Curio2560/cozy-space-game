extends GutTest
## Tripulação (#35): troca, XP só do ativo, níveis, vantagens, save, modelo no jogo.

func test_only_active_gains_xp_and_levels_up() -> void:
	var c := Crew.new()
	watch_signals(c)
	for i in 2:
		c.on_delivery(true) # 15 + 15
	assert_eq(c.level("FinnTheFrog"), 2)
	assert_signal_emitted(c, "leveled")
	assert_eq(c.level("RaeTheRedPanda"), 1)
	assert_true(c.select("RaeTheRedPanda"))
	c.on_delivery(false)
	assert_eq(int(c.xp["RaeTheRedPanda"]), Crew.XP_DELIVERY)
	assert_eq(int(c.xp["FinnTheFrog"]), 30)

func test_level_capped_at_five() -> void:
	var c := Crew.new()
	c.xp["FinnTheFrog"] = 99999
	assert_eq(c.level("FinnTheFrog"), Crew.MAX_LEVEL)
	assert_eq(c.xp_to_next("FinnTheFrog"), 0)

func test_perks_only_for_active() -> void:
	var c := Crew.new()
	assert_lt(c.acid_factor(), 1.0, "Finn ativo resiste ao ácido")
	assert_eq(c.farm_speed(), 1.0)
	c.select("BarbaraTheBee")
	assert_eq(c.acid_factor(), 1.0)
	assert_gt(c.farm_speed(), 1.0)
	c.select("FernandoTheFlamingo")
	assert_gt(c.jump_factor(), 1.0)
	c.select("RaeTheRedPanda")
	assert_gt(c.drive_factor(), 1.0)

func test_save_round_trip() -> void:
	var c := Crew.new()
	c.select("BarbaraTheBee")
	c.on_delivery(true)
	var d := Crew.new()
	d.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(d.active, "BarbaraTheBee")
	assert_eq(int(d.xp["BarbaraTheBee"]), 15)

func test_switching_in_game_changes_model_and_perks() -> void:
	var run: Node3D = (load("res://scenes/game/planet_run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_physics_frames(5)
	assert_eq(run.player.crew, "FinnTheFrog")
	run.crew.select("FernandoTheFlamingo")
	await wait_physics_frames(2)
	assert_eq(run.player.crew, "FernandoTheFlamingo")
	assert_gt(run.player.jump_factor, 1.0)
	assert_eq(run.player.visual.get_child_count(), 2, "um modelo + a caixa das mãos")
	run.crew.select("BarbaraTheBee")
	assert_gt(run.farm.farm.growth_speed, 1.0)
