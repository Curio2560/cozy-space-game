class_name HelpersPage
extends VBoxContainer
## Separador "Ajudantes" do terminal (#59): quantos há e construir mais.

var run: Node3D
var _text: Label
var _btn: Button

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 22)
	add_child(_text)
	_btn = Button.new()
	_btn.custom_minimum_size = Vector2(0, 64)
	_btn.add_theme_font_size_override("font_size", 24)
	_btn.pressed.connect(func() -> void:
		if run.build_helper():
			refresh())
	add_child(_btn)

func refresh() -> void:
	if run == null:
		return
	var sq: HelperSquad = run.helpers
	if not run.research.helpers_unlocked():
		_text.text = tr("HELPERS_LOCKED")
		_btn.visible = false
		return
	_text.text = tr("HELPERS_INFO") % [sq.count, HelperSquad.MAX]
	_btn.visible = sq.count < HelperSquad.MAX
	_btn.text = tr("HELPERS_BUILD") % SlotMenu.cost_text(HelperSquad.COST)
	_btn.disabled = not sq.can_build()
