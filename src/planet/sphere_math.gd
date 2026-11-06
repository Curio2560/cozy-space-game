class_name SphereMath
extends RefCounted
## Utilitários de orientação à superfície de uma esfera.

## Base com o eixo Y = `up` e rodada `yaw` radianos à volta dele.
static func basis_from_up(up: Vector3, yaw := 0.0) -> Basis:
	var u := up.normalized()
	var ref := Vector3.FORWARD if absf(u.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := ref.cross(u).normalized()
	var z := x.cross(u).normalized()
	return Basis(u, yaw) * Basis(x, u, z)
