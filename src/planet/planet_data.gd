class_name PlanetData
extends RefCounted
## Dados de um planeta gerado (sem cena). Produzido por PlanetGenerator.generate().
## Direções são vetores unitários a partir do centro do planeta.

var seed: int
var biome: String
var radius: float
var height_amp: float
var noise: FastNoiseLite
## [{kind: String (caminho no kit), dir: Vector3, yaw: float, size: float (altura em m),
##   clear: float (raio livre em m), outline: bool, collider: float (raio do colisor / altura; 0 = sem)}]
var placements: Array[Dictionary] = []
## Postos dos colonos (direções).
var posts: Array[Vector3] = []
var outpost_dir: Vector3
var lair_dir: Vector3
## Zonas aplanadas: [{dir, angle (rad), h}] — postos, posto avançado e covil.
var flat_spots: Array[Dictionary] = []

## Altura do terreno (m, acima do raio) na direção `dir`.
func height_at(dir: Vector3) -> float:
	var d := dir.normalized()
	var h := noise.get_noise_3dv(d * radius) * height_amp
	for s in flat_spots:
		var ang := d.angle_to(s.dir)
		var r: float = s.angle
		if ang < r:
			var w := 1.0 - smoothstep(r * 0.55, r, ang)
			h = lerpf(h, s.h, w)
	return h

## Ponto da superfície na direção `dir` (coordenadas locais do planeta).
func surface_point(dir: Vector3) -> Vector3:
	var d := dir.normalized()
	return d * (radius + height_at(d))

## Normal do terreno (diferenças finitas sobre a superfície).
func normal_at(dir: Vector3) -> Vector3:
	var d := dir.normalized()
	var t1 := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	var t2 := d.cross(t1).normalized()
	var e := 0.5 / radius # ~0,5 m
	var p := surface_point(d)
	var a := surface_point(d + t1 * e) - p
	var b := surface_point(d + t2 * e) - p
	var n := a.cross(b).normalized()
	return n if n.dot(d) > 0.0 else -n

## Inclinação do terreno em graus (0 = plano).
func slope_deg(dir: Vector3) -> float:
	return rad_to_deg(normal_at(dir).angle_to(dir.normalized()))

## Distância à superfície (arco, em metros) entre duas direções.
func arc_m(a: Vector3, b: Vector3) -> float:
	return a.angle_to(b) * radius
