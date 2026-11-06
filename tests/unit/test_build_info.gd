extends GutTest

func test_game_name_is_correio_cosmico() -> void:
	assert_eq(BuildInfo.game_name(), "Correio Cósmico")

func test_version_is_semver() -> void:
	var re := RegEx.create_from_string("^\\d+\\.\\d+\\.\\d+$")
	assert_not_null(re.search(BuildInfo.version()), "versão '%s' não é X.Y.Z" % BuildInfo.version())

func test_version_matches_android_export_preset() -> void:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK)
	assert_eq(str(cfg.get_value("preset.0.options", "version/name")), BuildInfo.version())

func test_boot_scene_shows_name_and_version() -> void:
	var boot: Control = load("res://scenes/ui/boot.tscn").instantiate()
	add_child_autofree(boot)
	assert_eq((boot.get_node("%Title") as Label).text, "Correio Cósmico")
	assert_eq((boot.get_node("%Version") as Label).text, "v" + BuildInfo.version())

func test_boot_has_button_to_showcase_scene() -> void:
	var boot: Control = load("res://scenes/ui/boot.tscn").instantiate()
	add_child_autofree(boot)
	assert_not_null(boot.get_node_or_null("%Showcase"))
	assert_true(ResourceLoader.exists(boot.SHOWCASE), "a cena da vitrine não existe")

func test_android_launcher_icons_exist() -> void:
	var cfg := ConfigFile.new()
	cfg.load("res://export_presets.cfg")
	for key in ["main_192x192", "adaptive_foreground_432x432", "adaptive_background_432x432", "adaptive_monochrome_432x432"]:
		var path := str(cfg.get_value("preset.0.options", "launcher_icons/" + key, ""))
		assert_ne(path, "", "ícone %s não definido" % key)
		assert_true(ResourceLoader.exists(path), "ícone %s não existe: %s" % [key, path])
