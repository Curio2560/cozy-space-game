class_name GalaxyMap
extends Control
## Viagem na nave (F5 #49): descolar → mapa da galáxia com a nave a viajar → aterrar (~8 s),
## com botão Saltar. Quando há escolha (depois da Lava), mostra 2 planetas e espera.
## Desenhado em 2D (sem cena 3D extra).

signal finished(option: Dictionary)

const TAKEOFF := 2.0
const TRAVEL := 4.0
const LANDING := 2.0
const BIOME_COLORS := {"prado": Color("7fd66b"), "acido": Color("b8f25a"), "lava": Color("ff7a45"), "gelo": Color("bfe6ff")}

var galaxy: Galaxy
var current_biome := "prado"
var options: Array = []
var chosen := {}
var t := 0.0
var _choosing := false
var _skip: Button
var _choice_box: HBoxContainer
var _title: Label
var _stars: PackedVector2Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 160:
		_stars.append(Vector2(rng.randf(), rng.randf()))
	_title = Label.new()
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.position.y = 40
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 36)
	_title.add_theme_color_override("font_color", CozyTheme.CREAM)
	_title.add_theme_color_override("font_outline_color", CozyTheme.INK)
	_title.add_theme_constant_override("outline_size", 8)
	add_child(_title)
	_skip = Button.new()
	_skip.text = "GALAXY_SKIP"
	_skip.custom_minimum_size = Vector2(200, 64)
	_skip.add_theme_font_size_override("font_size", 26)
	_skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_skip.offset_right = -30
	_skip.offset_bottom = -30
	_skip.pressed.connect(skip)
	add_child(_skip)
	_choice_box = HBoxContainer.new()
	_choice_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_choice_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_choice_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_choice_box.offset_bottom = -120
	_choice_box.add_theme_constant_override("separation", 30)
	add_child(_choice_box)
	visible = false

## Começa a viagem a partir do planeta atual de `galaxy`.
func begin(p_galaxy: Galaxy, p_biome := "prado") -> void:
	galaxy = p_galaxy
	current_biome = p_biome
	options = galaxy.next_options()
	chosen = options[0] if options.size() == 1 else {}
	t = 0.0
	_choosing = false
	for c in _choice_box.get_children():
		c.queue_free()
	visible = true
	_title.text = tr("GALAXY_TAKEOFF")

## Total da viagem (sem a escolha).
static func duration() -> float:
	return TAKEOFF + TRAVEL + LANDING

func choose(i: int) -> void:
	if i < 0 or i >= options.size():
		return
	chosen = options[i]
	_choosing = false
	_choice_box.visible = false

## Salta o resto da animação (se ainda houver escolha por fazer, vai direto para ela).
func skip() -> void:
	if chosen.is_empty():
		t = TAKEOFF
		return
	t = duration()

func _process(delta: float) -> void:
	if not visible or galaxy == null:
		return
	if chosen.is_empty() and t >= TAKEOFF:
		if not _choosing:
			_show_choices()
	else:
		t += delta
	if t < TAKEOFF:
		_title.text = tr("GALAXY_TAKEOFF")
	elif t < TAKEOFF + TRAVEL:
		_title.text = tr("GALAXY_TRAVEL") % tr("BIOME_" + str(chosen.get("biome", "")).to_upper()) if not chosen.is_empty() else tr("GALAXY_CHOOSE")
	else:
		_title.text = tr("GALAXY_LANDING")
	queue_redraw()
	if t >= duration() and not chosen.is_empty():
		visible = false
		finished.emit(chosen)

func _show_choices() -> void:
	_choosing = true
	_title.text = tr("GALAXY_CHOOSE")
	_choice_box.visible = true
	for i in options.size():
		var b := Button.new()
		b.text = tr("BIOME_" + str(options[i].biome).to_upper())
		b.custom_minimum_size = Vector2(280, 80)
		b.add_theme_font_size_override("font_size", 28)
		b.pressed.connect(choose.bind(i))
		_choice_box.add_child(b)

## Posições no ecrã dos planetas do caminho (o atual, o seguinte ou as 2 opções).
func _planet_points() -> Array:
	var w := size.x
	var h := size.y
	var here := Vector2(w * 0.22, h * 0.6)
	if options.size() == 1:
		return [here, Vector2(w * 0.78, h * 0.42)]
	return [here, Vector2(w * 0.72, h * 0.3), Vector2(w * 0.78, h * 0.72)]

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("120c22"))
	for s in _stars:
		draw_circle(s * size, 1.6, Color(1, 1, 1, 0.7))
	var pts := _planet_points()
	var here: Vector2 = pts[0]
	draw_circle(here, 46, BIOME_COLORS.get(current_biome, Color.WHITE).darkened(0.25))
	_label(here + Vector2(0, 80), tr("BIOME_" + current_biome.to_upper()))
	for i in options.size():
		var p: Vector2 = pts[i + 1]
		var picked: bool = not chosen.is_empty() and chosen == options[i]
		_dashed(here, p, Color(1, 1, 1, 0.6 if picked or chosen.is_empty() else 0.15))
		draw_circle(p, 54, BIOME_COLORS.get(options[i].biome, Color.WHITE))
		draw_arc(p, 54, 0, TAU, 48, CozyTheme.INK, 5.0, true)
		_label(p + Vector2(0, 90), tr("BIOME_" + str(options[i].biome).to_upper()))
	# A nave: descola do planeta atual, viaja, aterra no escolhido.
	var dest: Vector2 = here
	if not chosen.is_empty():
		dest = pts[options.find(chosen) + 1]
	var k := clampf((t - TAKEOFF) / TRAVEL, 0.0, 1.0)
	var lift := clampf(t / TAKEOFF, 0.0, 1.0)
	var pos := here.lerp(dest, smoothstep(0.0, 1.0, k)) + Vector2(0, -70 * lift * (1.0 - k) - 70 * (1.0 - clampf((t - TAKEOFF - TRAVEL) / LANDING, 0.0, 1.0)) * k)
	var dirv := (dest - here).normalized() if dest != here else Vector2.UP
	_ship(pos, dirv)

func _label(at: Vector2, text: String) -> void:
	var f := get_theme_default_font()
	var fs := 26
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(f, at - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, CozyTheme.INK)
	draw_string(f, at - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, CozyTheme.CREAM)

func _dashed(a: Vector2, b: Vector2, c: Color) -> void:
	var n := int(a.distance_to(b) / 18.0)
	for i in n:
		if i % 2 == 0:
			draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), c, 4.0)

func _ship(p: Vector2, d: Vector2) -> void:
	var side := Vector2(-d.y, d.x)
	var pts := PackedVector2Array([p + d * 26, p - d * 16 + side * 16, p - d * 8, p - d * 16 - side * 16])
	draw_colored_polygon(pts, Color("ffc857"))
	draw_polyline(pts + PackedVector2Array([pts[0]]), CozyTheme.INK, 4.0, true)
