extends SceneTree
## Gera a textura de terra das estradas (cartoon, sem costuras): manchas suaves, fissuras,
## pedras chatas com contorno e sombra, pontinhos. Determinística (seed fixa).
## Uso: godot --headless --path . -s tools/road_texture.gd
const SIZE := 512
const OUT := "res://assets/terrain/road/dirt.png"

const BASE_A := Color("b97a48")
const BASE_B := Color("a0623a")
const DARK := Color("7d4a2a")
const STONE := Color("d9a46d")
const STONE_HI := Color("ecc08a")
const LINE := Color("6e3f22")

var rng := RandomNumberGenerator.new()
var img: Image

func _init() -> void:
	rng.seed = 1234
	img = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_base()
	for i in 14:
		_crack()
	for i in 70:
		_stone(rng.randf_range(4.0, 9.0))
	for i in 22:
		_stone(rng.randf_range(10.0, 22.0))
	for i in 260:
		_dot()
	img.generate_mipmaps()
	img.save_png(ProjectSettings.globalize_path(OUT))
	print("textura ", OUT)
	quit()

## Ruído de valor periódico (sem costuras): rede de `period` células.
func _vnoise(x: float, y: float, period: int, salt: int) -> float:
	var ix := int(floor(x))
	var iy := int(floor(y))
	var fx := x - ix
	var fy := y - iy
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := _h(posmod(ix, period), posmod(iy, period), salt)
	var b := _h(posmod(ix + 1, period), posmod(iy, period), salt)
	var c := _h(posmod(ix, period), posmod(iy + 1, period), salt)
	var d := _h(posmod(ix + 1, period), posmod(iy + 1, period), salt)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)

func _h(x: int, y: int, salt: int) -> float:
	var n := x * 374761393 + y * 668265263 + salt * 2147483647
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xffff) / 65535.0

func _base() -> void:
	for y in SIZE:
		for x in SIZE:
			var u := float(x) / SIZE
			var v := float(y) / SIZE
			var n := _vnoise(u * 4.0, v * 4.0, 4, 1) * 0.55 + _vnoise(u * 8.0, v * 8.0, 8, 2) * 0.3 + _vnoise(u * 16.0, v * 16.0, 16, 3) * 0.15
			# Manchas em 3 tons (cartoon): claro, médio, escuro.
			var c := BASE_A
			if n < 0.42:
				c = BASE_B
			if n < 0.3:
				c = DARK.lerp(BASE_B, 0.45)
			var fine := _vnoise(u * 48.0, v * 48.0, 48, 4)
			c = c.lerp(c.darkened(0.08), (0.6 if fine > 0.6 else 0.0))
			img.set_pixel(x, y, c)

func _put(x: int, y: int, c: Color) -> void:
	img.set_pixel(posmod(x, SIZE), posmod(y, SIZE), c)

func _disc(cx: float, cy: float, r: float, c: Color) -> void:
	for y in range(int(cy - r) - 1, int(cy + r) + 2):
		for x in range(int(cx - r) - 1, int(cx + r) + 2):
			if Vector2(x + 0.5 - cx, y + 0.5 - cy).length() <= r:
				_put(x, y, c)

func _crack() -> void:
	var p := Vector2(rng.randf() * SIZE, rng.randf() * SIZE)
	var ang := rng.randf() * TAU
	for i in rng.randi_range(12, 30):
		ang += rng.randf_range(-0.6, 0.6)
		var q := p + Vector2.from_angle(ang) * rng.randf_range(3.0, 7.0)
		for t in 8:
			var s := p.lerp(q, t / 8.0)
			_disc(s.x, s.y, 0.9, LINE)
		p = q
		if rng.randf() < 0.12: # ramo curto
			var bp := p
			var ba := ang + rng.randf_range(-1.4, 1.4)
			for k in 3:
				var bq := bp + Vector2.from_angle(ba) * 4.0
				for t in 6:
					var s2 := bp.lerp(bq, t / 6.0)
					_disc(s2.x, s2.y, 0.7, LINE)
				bp = bq

## Pedra chata: polígono irregular com sombra em baixo à direita, contorno e brilho em cima.
func _stone(r: float) -> void:
	var c := Vector2(rng.randf() * SIZE, rng.randf() * SIZE)
	var n := rng.randi_range(6, 9)
	var radii := []
	var rot := rng.randf() * TAU
	var stretch := rng.randf_range(0.7, 1.3)
	for i in n:
		radii.append(r * rng.randf_range(0.7, 1.15))
	var inside := func(p: Vector2, grow: float) -> bool:
		var d := (p - c).rotated(-rot)
		d.x /= stretch
		var a := fposmod(d.angle(), TAU) / TAU * n
		var i0 := int(a) % n
		var rr: float = lerpf(radii[i0], radii[(i0 + 1) % n], a - floor(a)) + grow
		return d.length() <= rr
	var reach := int(r * 1.6) + 4
	for y in range(int(c.y) - reach, int(c.y) + reach):
		for x in range(int(c.x) - reach, int(c.x) + reach):
			var p := Vector2(x + 0.5, y + 0.5)
			if inside.call(p - Vector2(2.0, 2.5), 0.5):
				if not inside.call(p, 1.2):
					_put(x, y, DARK) # sombra
			if inside.call(p, 1.2):
				_put(x, y, LINE) # contorno
			if inside.call(p, 0.0):
				var hi: bool = inside.call(p + Vector2(1.6, 1.6), -r * 0.25)
				_put(x, y, STONE if not hi else STONE.lerp(STONE_HI, 0.0))
				if not inside.call(p + Vector2(-2.0, -2.0), 0.0) or not inside.call(p + Vector2(0.0, -2.0), 0.0):
					_put(x, y, STONE_HI) # brilho na aresta de cima

func _dot() -> void:
	var c := Vector2(rng.randf() * SIZE, rng.randf() * SIZE)
	var r := rng.randf_range(1.0, 2.2)
	_disc(c.x + 0.8, c.y + 0.8, r, DARK)
	_disc(c.x, c.y, r, STONE if rng.randf() < 0.6 else DARK.lerp(BASE_B, 0.3))
