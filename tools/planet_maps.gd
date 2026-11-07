extends SceneTree
## Gera o mapa-mundo (equirretangular) de cada planeta do céu a partir dos 6 fotogramas do
## Tiny Planet Pack: cada fotograma mostra a face virada para nós com o planeta rodado
## 360°/6; cada ponto (longitude, latitude) é lido nos fotogramas onde está mais de frente
## (média pesada dos dois melhores). O sentido de rotação deteta-se sozinho (o que der
## fotogramas vizinhos mais coerentes).
## Uso: godot --headless --path . -s tools/planet_maps.gd
const DIR := "res://assets/sky/planets/"
const FRAMES := 6
const W := 256
const H := 128

func _init() -> void:
	for f in DirAccess.get_files_at(DIR):
		if not f.ends_with(".png") or f.ends_with("_map.png"):
			continue
		var sheet := Image.load_from_file(DIR + f)
		sheet.convert(Image.FORMAT_RGBA8)
		var disc := _disc(sheet)
		_limb = _limb_profile(sheet, disc)
		var best: Image = null
		var best_err := INF
		for sgn in [1.0, -1.0]:
			var r := _build(sheet, disc, sgn)
			if r[1] < best_err:
				best_err = r[1]
				best = r[0]
		var out := DIR.replace("res://", "") + f.get_basename() + "_map.png"
		best.save_png(ProjectSettings.globalize_path("res://" + out))
		print("mapa ", out, " erro ", best_err)
	quit()

## Centro e raio do disco do planeta no fotograma 0 (pelo alfa).
func _disc(sheet: Image) -> Vector3:
	var fw := sheet.get_width() / FRAMES
	var minx := fw
	var maxx := 0
	var miny := sheet.get_height()
	var maxy := 0
	for y in sheet.get_height():
		for x in fw:
			if sheet.get_pixel(x, y).a > 0.5:
				minx = mini(minx, x)
				maxx = maxi(maxx, x)
				miny = mini(miny, y)
				maxy = maxi(maxy, y)
	return Vector3((minx + maxx + 1) * 0.5, (miny + maxy + 1) * 0.5, maxf(maxx - minx + 1, maxy - miny + 1) * 0.5)

const LIMB_BINS := 16
var _limb := PackedFloat32Array()

## Luminosidade média por anel (distância ao centro do disco, 0..1) em todos os fotogramas:
## o desenho escurece para as bordas; dividir por isto tira esse sombreado pintado.
func _limb_profile(sheet: Image, disc: Vector3) -> PackedFloat32Array:
	var fw := sheet.get_width() / FRAMES
	var sum := PackedFloat32Array()
	var cnt := PackedFloat32Array()
	sum.resize(LIMB_BINS)
	cnt.resize(LIMB_BINS)
	for k in FRAMES:
		for y in sheet.get_height():
			for x in fw:
				var c := sheet.get_pixel(k * fw + x, y)
				if c.a < 0.5:
					continue
				var r := Vector2(x + 0.5 - disc.x, y + 0.5 - disc.y).length() / disc.z
				var bin := mini(int(r * LIMB_BINS), LIMB_BINS - 1)
				sum[bin] += c.get_luminance()
				cnt[bin] += 1.0
	var out := PackedFloat32Array()
	out.resize(LIMB_BINS)
	var center := sum[0] / maxf(cnt[0], 1.0)
	for i in LIMB_BINS:
		out[i] = (sum[i] / maxf(cnt[i], 1.0)) / maxf(center, 0.001)
	return out

func _sample(sheet: Image, disc: Vector3, k: int, sx: float, sy: float) -> Color:
	var fw := sheet.get_width() / FRAMES
	var px := clampi(int(disc.x + sx * disc.z * 0.97), 0, fw - 1)
	var py := clampi(int(disc.y - sy * disc.z * 0.97), 0, sheet.get_height() - 1)
	var c := sheet.get_pixel(posmod(k, FRAMES) * fw + px, py)
	var r := Vector2(sx, sy).length() * 0.97
	var shade := clampf(_limb[mini(int(r * LIMB_BINS), LIMB_BINS - 1)], 0.35, 1.0)
	return Color(minf(c.r / shade, 1.0), minf(c.g / shade, 1.0), minf(c.b / shade, 1.0), c.a)

## [imagem, erro]: erro = diferença entre os dois fotogramas usados (menor = sentido certo).
func _build(sheet: Image, disc: Vector3, sgn: float) -> Array:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var err := 0.0
	var step := TAU / FRAMES
	for y in H:
		var lat := PI * (0.5 - (y + 0.5) / H)
		for x in W:
			var lon := TAU * (x + 0.5) / W
			# Fotograma k mostra de frente a longitude sgn*k*step.
			var fk := lon / step * sgn
			var k0 := int(floor(fk))
			# Candidatos: fotogramas onde o ponto está a menos de 70° da frente. Peso: mais de
			# frente e mais claro (os fotogramas trazem sombras pintadas; evita-as).
			var acc := Color(0, 0, 0, 0)
			var wsum := 0.0
			var lums := []
			for k: int in [k0 - 1, k0, k0 + 1, k0 + 2]:
				var d: float = wrapf(lon - sgn * k * step, -PI, PI)
				if absf(d) > deg_to_rad(70.0):
					continue
				var sx := cos(lat) * sin(d)
				var sy := sin(lat)
				var col := _sample(sheet, disc, k, sx, sy)
				var lum := col.get_luminance()
				lums.append(lum)
				var w := pow(cos(d), 4.0) * (lum + 0.1)
				acc += col * w
				wsum += w
			var c: Color = acc / maxf(wsum, 0.0001)
			if lums.size() >= 2:
				err += absf(lums[0] - lums[1])
			c.a = 1.0
			img.set_pixel(x, y, c)
	return [img, err]
