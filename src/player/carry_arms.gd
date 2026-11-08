class_name CarryArms
extends SkeletonModifier3D
## Braços a segurar uma caixa à frente do peito, por cima da animação (andar, correr, saltar).
## Cada osso do braço é rodado para o seu eixo Y (o comprimento do osso) apontar na direção
## pedida, no espaço do esqueleto (o modelo olha para +Z). A força vem de `influence`.

## [osso, direção alvo (espaço do esqueleto)]: braço para a frente e um pouco para baixo,
## antebraço para a frente e para dentro (mãos dos lados da caixa).
const POSE := [
	["UpperArm.L", Vector3(0.35, -0.55, 0.75)],
	["LowerArm.L", Vector3(-0.25, 0.05, 1.0)],
	["UpperArm.R", Vector3(-0.35, -0.55, 0.75)],
	["LowerArm.R", Vector3(0.25, 0.05, 1.0)],
]

var _bones := []

func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for e in POSE:
		var i := sk.find_bone(e[0])
		if i >= 0:
			_bones.append([i, (e[1] as Vector3).normalized()])

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for e in _bones:
		var i: int = e[0]
		var want: Vector3 = e[1]
		var g := sk.get_bone_global_pose(i)
		var cur := g.basis.y.normalized()
		if cur.dot(want) > 0.9999:
			continue
		var q := Quaternion(cur, want)
		g.basis = Basis(q) * g.basis
		sk.set_bone_global_pose(i, g)
