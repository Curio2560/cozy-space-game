class_name UpgradesPage
extends VBoxContainer
## Separador "Melhorias" do terminal: linhas do rover e slots do posto, com nível e preço.

var run: Node3D
var _rows: VBoxContainer

const LINES := ["speed", "cargo", "shield", "suspension", "slots"]

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	add_child(_rows)

func refresh() -> void:
	if run == null:
		return
	var up: Upgrades = run.upgrades
	for c in _rows.get_children():
		c.queue_free()
	for line in LINES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var l := Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 22)
		var stars := "●".repeat(up.level(line)) + "○".repeat(up.max_level(line) - up.level(line))
		l.text = "%s  %s\n%s" % [tr("UPG_" + line.to_upper()), stars, tr("UPG_" + line.to_upper() + "_INFO")]
		row.add_child(l)
		var b := Button.new()
		var cost := up.next_cost(line)
		b.text = tr("UPG_MAX") if cost.is_empty() else SlotMenu.cost_text(cost)
		b.custom_minimum_size = Vector2(220, 64)
		b.add_theme_font_size_override("font_size", 22)
		b.disabled = cost.is_empty() or not run.wallet.can_afford(cost)
		b.pressed.connect(func() -> void:
			if run.buy_upgrade(line):
				refresh())
		row.add_child(b)
		_rows.add_child(row)
