class_name NavArrow
extends Control
## Seta no HUD que aponta para um alvo na superfície do planeta, relativa à câmara.
## 0 rad = em frente (para cima no ecrã); positivo = para a direita.

var angle := 0.0
var color := Color("ffc857")

## Ângulo do alvo no plano tangente em `player_pos`, visto pela câmara `cam_basis`.
static func angle_to_target(player_pos: Vector3, up: Vector3, cam_basis: Basis, target_pos: Vector3) -> float:
	var t := target_pos - player_pos
	t = t - up * t.dot(up)
	var fwd := -cam_basis.z
	fwd = fwd - up * fwd.dot(up)
	if fwd.length() < 0.001:
		fwd = cam_basis.y - up * cam_basis.y.dot(up)
	fwd = fwd.normalized()
	var right := fwd.cross(up).normalized()
	return atan2(t.dot(right), t.dot(fwd))

func _ready() -> void:
	custom_minimum_size = Vector2(96, 96)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_angle(a: float) -> void:
	angle = a
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.45
	draw_circle(c, r, Color(0.14, 0.1, 0.22, 0.55))
	var rot := Transform2D(angle, c)
	var pts := PackedVector2Array([Vector2(0, -r * 0.8), Vector2(r * 0.5, r * 0.45), Vector2(0, r * 0.2), Vector2(-r * 0.5, r * 0.45)])
	for i in pts.size():
		pts[i] = rot * pts[i]
	draw_colored_polygon(pts, color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.14, 0.1, 0.22), 3.0, true)
