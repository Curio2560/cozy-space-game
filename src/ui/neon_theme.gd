class_name NeonTheme
extends RefCounted
## Tema da interface (estilo do pack Sci-Fi Game UI): painéis escuros com bordas néon rosa e
## ciano, texto branco. Aplicado à janela inteira (Settings), por isso vale para todos os ecrãs.

const PINK := Color("ff2d95")
const CYAN := Color("19f0e0")
const BG := Color(0.05, 0.035, 0.11, 0.88)
const TEXT := Color("f4f2ff")
const ICONS := "res://assets/ui/icons/icon_%02d.png"
## Ícones do pack (numeração do pack).
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

## Fonte do jogo (Matcha Style, Khurasan Studio — grátis para uso comercial). Os símbolos que ela
## não tem (→ · ₂ º ª) vêm da fonte de reserva do Godot.
static func font() -> FontFile:
	if _font == null:
		_font = (load(FONT) as FontFile).duplicate()
		_font.fallbacks = [ThemeDB.fallback_font]
	return _font

static func icon(n: int) -> Texture2D:
	return load(ICONS % n)

static func box(bg: Color, border: Color, width: int, margin := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(margin)
	return s

static func make() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.set_stylebox("normal", "Button", box(BG, CYAN, 2))
	t.set_stylebox("hover", "Button", box(BG, PINK, 2))
	t.set_stylebox("pressed", "Button", box(Color(PINK, 0.35), PINK, 3))
	t.set_stylebox("disabled", "Button", box(Color(BG, 0.5), Color(CYAN, 0.3), 2))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", CYAN)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("icon_normal_color", "Button", TEXT)
	t.set_color("icon_hover_color", "Button", CYAN)
	t.set_stylebox("panel", "PanelContainer", box(Color(BG, 0.92), PINK, 3, 20))
	t.set_stylebox("panel", "Panel", box(Color(BG, 0.92), PINK, 3, 20))
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("background", "ProgressBar", box(Color(0.03, 0.02, 0.07, 0.8), Color(CYAN, 0.6), 1, 0))
	_theme = t
	return t
