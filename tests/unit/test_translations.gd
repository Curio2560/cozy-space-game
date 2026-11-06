extends GutTest

var _prev := ""

func before_each() -> void:
	_prev = Settings.locale()

func after_each() -> void:
	Settings.set_locale(_prev, false)

func test_every_key_has_pt_and_en() -> void:
	var f := FileAccess.open("res://i18n/strings.csv", FileAccess.READ)
	var header := f.get_csv_line()
	assert_eq(Array(header), ["keys", "en", "pt"])
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 3 or row[0] == "":
			continue
		assert_ne(row[1], "", "%s sem inglês" % row[0])
		assert_ne(row[2], "", "%s sem português" % row[0])

func test_switching_locale_changes_text() -> void:
	Settings.set_locale("pt", false)
	assert_eq(tr("UI_BACK"), "Voltar")
	Settings.set_locale("en", false)
	assert_eq(tr("UI_BACK"), "Back")

func test_cycle_locale_alternates() -> void:
	Settings.set_locale("pt", false)
	var path_backup := FileAccess.get_file_as_string(Settings.PATH)
	Settings.cycle_locale()
	assert_eq(Settings.locale(), "en")
	Settings.cycle_locale()
	assert_eq(Settings.locale(), "pt")
	if path_backup != "":
		var w := FileAccess.open(Settings.PATH, FileAccess.WRITE)
		w.store_string(path_backup)

func test_unknown_locale_falls_back_to_english() -> void:
	Settings.set_locale("xx", false)
	assert_eq(Settings.locale(), "en")
