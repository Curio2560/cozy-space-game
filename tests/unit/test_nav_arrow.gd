extends GutTest
## A seta tem de apontar certo em qualquer ponto da esfera.

func _cam_basis(up: Vector3, fwd: Vector3) -> Basis:
	var f := (fwd - up * fwd.dot(up)).normalized()
	return Basis(f.cross(up).normalized(), up, -f) # câmara a olhar para `fwd`

func test_points_ahead_right_left_behind_everywhere() -> void:
	for up: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.RIGHT, Vector3(0.3, -0.8, 0.5).normalized()]:
		var ref := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
		var fwd := (ref - up * ref.dot(up)).normalized()
		var right := fwd.cross(up).normalized()
		var p := up * 60.0
		var cam := _cam_basis(up, fwd)
		assert_almost_eq(NavArrow.angle_to_target(p, up, cam, p + fwd * 20.0), 0.0, 0.01, "em frente @ %s" % up)
		assert_almost_eq(NavArrow.angle_to_target(p, up, cam, p + right * 20.0), PI / 2, 0.01, "direita @ %s" % up)
		assert_almost_eq(NavArrow.angle_to_target(p, up, cam, p - right * 20.0), -PI / 2, 0.01, "esquerda @ %s" % up)
		assert_almost_eq(absf(NavArrow.angle_to_target(p, up, cam, p - fwd * 20.0)), PI, 0.01, "atrás @ %s" % up)

func test_target_beyond_horizon_still_points_the_right_way() -> void:
	# Alvo do outro lado do planeta, ligeiramente à direita: a seta aponta para a direita/em frente.
	var up := Vector3.UP
	var cam := _cam_basis(up, Vector3.FORWARD)
	var target := Vector3(10, -60, -5)
	var a := NavArrow.angle_to_target(up * 60.0, up, cam, target)
	assert_gt(a, 0.0)

func test_format_time() -> void:
	assert_eq(DeliveryHud.format_time(65.2), "1:06")
	assert_eq(DeliveryHud.format_time(9.0), "0:09")
	assert_eq(DeliveryHud.format_time(-12.0), "-0:12")
