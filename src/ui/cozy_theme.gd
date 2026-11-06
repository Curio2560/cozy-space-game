class_name CozyTheme
extends RefCounted
## Tema da interface em estilo cel-shaded (como o jogo): cores lisas e acolhedoras, contorno escuro
## grosso e sombra deslocada (sem desfocar), cantos redondos, fonte Matcha Style. Junta-se ao tema
## base do motor (Settings), por isso vale para todos os ecrãs.

const INK := Color("2a2140") # contorno e texto escuro
const CREAM := Color("fff6ea")
const PEACH := Color("ff9f7a")
const MINT := Color("6fd6b4")
const SUN := Color("ffc857")
const LILAC := Color("b79cff")
const SKY := Color("7cc8ff")
const ICONS := "res://assets/ui/icons/icon_%02d.png"
## Ícones (pack Sci-Fi Game UI, numeração do pack): brancos, tingidos de INK nos botões.
const ICON_PAUSE := 80
const ICON_GEAR := 71
const ICON_HOME := 83
const ICON_PIN := 44
const ICON_MONEY := 50
const ICON_GLOBE := 51
const ICON_EXIT := 69
const ICON_CLOSE := 76
const ICON_PLAY := 84
const ICON_WARNING := 86
const FONT := "res://assets/fonts/MatchaStyle.ttf"

static var _theme: Theme
static var _font: FontFile

static func icon(n: int) -> Texture2D:
	return load(ICONS % n)

## Fonte do jogo (Matcha Style, Khurasan Studio). Os símbolos que ela não tem (→ · ₂ º ª) vêm
## da fonte de reserva do Godot.
static func font() -> FontFile:
	if _font == null:
		_font = (load(FONT) as FontFile).duplicate()
		_font.fallbacks = [ThemeDB.fallback_font]
	return _font

## Caixa cel-shaded: cor lisa, contorno escuro, sombra sólida deslocada para baixo.
static func box(bg: Color, border := INK, width := 4, shadow := 5, radius := 14, margin := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	if shadow > 0:
		s.shadow_color = INK
		s.shadow_size = 0
		s.shadow_offset = Vector2(0, shadow)
	s.anti_aliasing = true
	return s

static func make() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.set_stylebox("normal", "Button", box(CREAM))
	t.set_stylebox("hover", "Button", box(SUN))
	var pressed := box(PEACH, INK, 4, 1)
	pressed.content_margin_top += 4 # afunda quando se carrega
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", box(Color(CREAM, 0.5), Color(INK, 0.4), 4, 0))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.5))
	t.set_color("icon_normal_color", "Button", INK)
	t.set_color("icon_hover_color", "Button", INK)
	t.set_color("icon_pressed_color", "Button", INK)
	t.set_stylebox("panel", "PanelContainer", box(Color(CREAM, 0.97), INK, 5, 8, 18, 18))
	t.set_stylebox("panel", "Panel", box(Color(CREAM, 0.97), INK, 5, 8, 18, 18))
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "CheckButton", INK)
	t.set_color("font_hover_color", "CheckButton", INK)
	t.set_color("font_pressed_color", "CheckButton", INK)
	t.set_stylebox("background", "ProgressBar", box(Color(INK, 0.55), INK, 3, 0, 9, 0))
	t.set_stylebox("panel", "TabContainer", box(Color(CREAM, 0.0), INK, 0, 0, 0, 8))
	t.set_stylebox("tab_selected", "TabContainer", box(SUN, INK, 4, 0, 10, 10))
	t.set_stylebox("tab_unselected", "TabContainer", box(CREAM, INK, 3, 0, 10, 10))
	t.set_stylebox("tab_hovered", "TabContainer", box(Color(SUN, 0.7), INK, 3, 0, 10, 10))
	for c in ["font_selected_color", "font_unselected_color", "font_hovered_color"]:
		t.set_color(c, "TabContainer", INK)
	t.set_font_size("font_size", "TabContainer", 24)
	t.set_stylebox("panel", "ItemList", box(Color(CREAM, 0.9), INK, 3, 0, 10, 6))
	t.set_stylebox("selected", "ItemList", box(SUN, INK, 2, 0, 8, 4))
	t.set_stylebox("selected_focus", "ItemList", box(SUN, INK, 2, 0, 8, 4))
	t.set_stylebox("hovered", "ItemList", box(Color(SUN, 0.5), INK, 0, 0, 8, 4))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	for c in ["font_color", "font_selected_color", "font_hovered_color"]:
		t.set_color(c, "ItemList", INK)
	t.set_constant("v_separation", "ItemList", 10)
	_theme = t
	return t
