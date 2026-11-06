class_name PlanetCulling
extends RefCounted
## Culling por hemisfério: uma região do planeta (cone de meio-ângulo `region_angle` à volta
## de `region_dir`) só pode ser vista se alguma parte dela estiver aquém do horizonte da câmara.

## `cam_local`: posição da câmara no espaço do planeta. `margin` cobre objetos altos (árvores).
static func region_visible(region_dir: Vector3, cam_local: Vector3, radius: float, region_angle: float, margin := 0.15) -> bool:
	var dist := cam_local.length()
	if dist <= radius * 1.001:
		return true
	var horizon := acos(clampf(radius / dist, -1.0, 1.0)) # ângulo do horizonte visto do centro
	return region_dir.angle_to(cam_local / dist) <= horizon + region_angle + margin
