extends GutTest

func test_debug_menu_is_enabled_in_debug_builds() -> void:
	assert_eq(DebugMenu.enabled, OS.is_debug_build())

func test_items_disappear_with_their_owner() -> void:
	var owner_node := Node.new()
	add_child(owner_node)
	var before := DebugMenu.item_count()
	var called := [false]
	var b := DebugMenu.add_button(owner_node, "DBG_RESET", func() -> void: called[0] = true)
	DebugMenu.add_slider(owner_node, "DBG_SPEED", 0.0, 10.0, 1.0, 5.0, func(_v: float) -> void: pass)
	assert_eq(DebugMenu.item_count(), before + 2)
	(b as Button).pressed.emit()
	assert_true(called[0])
	owner_node.queue_free()
	await wait_process_frames(2)
	assert_eq(DebugMenu.item_count(), before)
