class_name BuildingBars
extends Control
## Barras de vida no HUD por cima dos edifícios danificados do posto (#41). Projeta a posição de
## cada edifício no ecrã; só desenha os que estão à frente da câmara e por perto.

const SHOW_RANGE := 60.0
const W := 90.0
const H := 12.0

var controller: OutpostController

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if controller == null or controller.run == null or controller.run.planet.data == null:
		return
	var run: Node3D = controller.run
	var cam: Camera3D = run.camera
	var st: Outpost = controller.state
	var d: PlanetData = run.planet.data
	for i in controller.slot_total():
		if not st.is_damaged(i):
			continue
		var dir := d.outpost_slots[i]
		var top: Vector3 = run.planet.to_global(d.surface_point(dir) + dir * (5.6 if st.slots[i].kind == "turret" else 4.0))
		if cam.is_position_behind(top) or cam.global_position.distance_to(top) > SHOW_RANGE:
			continue
		var p := cam.unproject_position(top) - Vector2(W * 0.5, 0)
		var f := st.hp(i) / st.max_hp(i)
		draw_rect(Rect2(p - Vector2(3, 3), Vector2(W + 6, H + 6)), CozyTheme.INK)
		draw_rect(Rect2(p, Vector2(W, H)), Color(0.25, 0.2, 0.32))
		var col := Color("ff6b6b") if f < 0.34 else (Color("ffc857") if f < 0.67 else Color("8fdc6b"))
		if f > 0.0:
			draw_rect(Rect2(p, Vector2(W * f, H)), col)
