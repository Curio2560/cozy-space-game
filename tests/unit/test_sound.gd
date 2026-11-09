extends GutTest
## Som (#52): todos os efeitos e músicas existem, a música troca, o volume guarda-se.

const SFX := ["mech_shot", "laser", "hit", "slam", "boss_roar", "warn", "wave", "ship", "coin", "boom", "click"]

func test_all_sounds_load() -> void:
	for s in SFX:
		assert_true(ResourceLoader.exists(Sound.SFX_DIR + s + ".wav"), s)
	for m in ["day", "night"]:
		assert_true(ResourceLoader.exists(Sound.MUSIC_DIR + m + ".wav"), m)

func test_music_switch_and_loop() -> void:
	Sound.music("night")
	assert_eq(Sound.current_music, "night")
	var s: AudioStreamWAV = Sound._stream(Sound.MUSIC_DIR + "night.wav")
	assert_eq(s.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	Sound.music("day")
	assert_eq(Sound.current_music, "day")
	Sound.play("click")

func test_volume_cycle() -> void:
	var before := Settings.get_volume("sfx")
	var v := Settings.cycle_volume("sfx")
	assert_ne(v, before)
	Settings.set_volume("sfx", before)
