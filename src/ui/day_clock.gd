class_name DayClock
extends Label
## Relógio no HUD (#37): dia atual e quanto falta para anoitecer / amanhecer.
## Fica a pulsar no aviso (30 s antes da noite).

var cycle: DayCycle

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_theme_font_size_override("font_size", 22)
	add_theme_color_override("font_outline_color", CozyTheme.INK)
	add_theme_constant_override("outline_size", 7)

static func clock(seconds: float) -> String:
	var s := int(ceil(seconds))
	return "%d:%02d" % [s / 60, s % 60]

func _process(_delta: float) -> void:
	if cycle == null:
		return
	var warn := not cycle.is_night() and cycle.time_to_night() <= DayCycle.WARN_BEFORE
	if cycle.is_night():
		text = tr("CLOCK_NIGHT") % [cycle.day, clock(cycle.time_to_morning())]
		add_theme_color_override("font_color", Color("a9c4ff"))
	else:
		text = tr("CLOCK_DAY") % [cycle.day, clock(cycle.time_to_night())]
		add_theme_color_override("font_color", Color("ffb36b") if warn else CozyTheme.CREAM)
	modulate.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.006)) if warn else 1.0
