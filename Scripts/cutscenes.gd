extends RefCounted

const Story := preload("res://Scripts/story.gd")
const UIStyle := preload("res://Scripts/UI/ui_style.gd")
const CutsceneScript := preload("res://Scripts/cutscene.gd")


static func open(level: Node2D) -> Node:
	var cs = CutsceneScript.new()
	level.add_child(cs)
	cs.begin(level)
	return cs


static func chapter_intro(level: Node2D, index: int) -> void:
	var tree := level.get_tree()
	var player := tree.get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var cs = open(level)
	var chapter := Story.chapter(index)
	var lines: Array = Story.CUTSCENE_INTRO[index] if index >= 0 and index < Story.CUTSCENE_INTRO.size() else []
	var spawn := player.global_position
	var goal := _goal_node(tree)
	var threats := _threats(tree, spawn, 2)

	cs.fade_now(1.0)
	if goal != null:
		cs.cam_jump(goal.global_position + Vector2(0, 10), 2.9)
	cs.location(String(chapter.get("location", "")))
	await cs.fade(0.0, 1.0)
	if goal != null:
		cs.mark(goal, "EXTRACCIÓN", UIStyle.BAR_FILL)
		cs.cam_move(goal.global_position, 2.5, 2.6)
	if lines.size() > 0:
		await cs.say_line(lines[0])

	for e in threats:
		if not is_instance_valid(e):
			continue
		cs.cam_move(e.global_position, 2.8, 0.9)
		await cs.cam_wait()
		cs.mark(e, _threat_label(e), UIStyle.LIFE)
		cs.shake(2.0)
		await cs.wait(0.75)

	var entry := _entry_point(level, spawn, threats)
	if entry.distance_to(spawn) > 4.0:
		player.global_position = entry
	cs.cam_move(player.global_position, 2.9, 1.0)
	cs.cam_follow(player)
	await cs.walk(player, spawn, 70.0)
	if not threats.is_empty() and is_instance_valid(threats[0]):
		cs.face(player, threats[0].global_position)
	if lines.size() > 1:
		await cs.say_line(lines[1])
	cs.hide_dialog()

	var title := String(chapter.get("title", ""))
	var parts := title.split(" · ")
	var big := parts[0] if parts.size() > 0 else title
	var sub := parts[1] if parts.size() > 1 else ""
	var slogan := Story.CHAPTER_SLOGANS[index] if index >= 0 and index < Story.CHAPTER_SLOGANS.size() else ""
	var place := String(GameManager.level_data(index).get("name", ""))
	await cs.title_card(place, big, sub, slogan)
	await cs.end()


static func boss_intro(level: Node2D, boss: Node2D) -> void:
	if boss == null or not is_instance_valid(boss):
		Global.set_cutscene(false)
		return
	var tree := level.get_tree()
	var player := tree.get_first_node_in_group("player") as Node2D
	var cs = open(level)
	cs.flash(Color(1.0, 0.1, 0.1), 0.6)
	cs.cam_move(boss.global_position, 3.0, 1.0)
	await cs.cam_wait()
	cs.shake(7.0)
	if player != null and is_instance_valid(boss):
		var dir := (player.global_position - boss.global_position).normalized()
		var step := boss.global_position + dir * 22.0
		if level.has_method("is_walkable") and not level.is_walkable(step):
			step = boss.global_position
		cs.cam_follow(boss)
		await cs.walk(boss, step, 40.0)
		cs.face(boss, player.global_position)
		cs.face(player, boss.global_position)
	await cs.boss_card(Story.BOSS_NAME, Story.BOSS_TITLE)
	for line in Story.BOSS_ENTRANCE:
		_frame_speaker(cs, line, player, boss)
		await cs.say_line(line)
	cs.hide_dialog()
	if player != null and is_instance_valid(boss):
		cs.cam_move(boss.global_position.lerp(player.global_position, 0.5), 2.3, 0.6)
	await cs.stamp("¡ACABA CON ÉL!", UIStyle.LIFE, 0.7)
	await cs.end()


static func boss_down(level: Node2D, pos: Vector2) -> void:
	var tree := level.get_tree()
	var player := tree.get_first_node_in_group("player") as Node2D
	var cs = open(level)
	cs.cam_move(pos, 3.1, 1.0)
	await cs.cam_wait()
	for line in Story.BOSS_LAST_WORDS:
		if line is Array and line.size() >= 2 and String(line[0]) == Story.HERO and player != null:
			cs.cam_follow(player, 2.9, 0.7)
		await cs.say_line(line)
	cs.hide_dialog()
	await cs.stamp("OBJETIVO ELIMINADO", UIStyle.OBJECTIVE, 1.0)
	await cs.end()


static func level_outro(level: Node2D, index: int, boss_level: bool) -> void:
	var tree := level.get_tree()
	var player := tree.get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var cs = open(level)
	cs.cam_follow(player, 3.0, 0.8)
	var lines: Array = Story.BOSS_LEVEL_OUTRO if boss_level else (Story.CUTSCENE_OUTRO[index] if index >= 0 and index < Story.CUTSCENE_OUTRO.size() else [])
	for line in lines:
		await cs.say_line(line)
	cs.hide_dialog()
	await cs.stamp("CONTRATO CANCELADO" if boss_level else "ZONA ASEGURADA", UIStyle.BAR_FILL, 1.0)
	await cs.end()


static func _frame_speaker(cs: Node, line: Variant, player: Node2D, boss: Node2D) -> void:
	if not (line is Array) or line.size() < 2:
		return
	var who := String(line[0])
	if who == Story.HERO and player != null and is_instance_valid(player):
		cs.cam_follow(player, 3.0, 0.6)
	elif who == Story.BOSS and boss != null and is_instance_valid(boss):
		cs.cam_follow(boss, 3.0, 0.6)


static func _goal_node(tree: SceneTree) -> Node2D:
	var ex := tree.get_first_node_in_group("exit_zone") as Node2D
	if ex != null:
		return ex
	return tree.get_first_node_in_group("doors") as Node2D


static func _threats(tree: SceneTree, from: Vector2, count: int) -> Array[Node2D]:
	var special: Array[Node2D] = []
	var regular: Array[Node2D] = []
	for n in tree.get_nodes_in_group("Enemies"):
		var e := n as Node2D
		if e == null or e.is_in_group("boss"):
			continue
		if e.has_method("is_alive") and not e.is_alive():
			continue
		if int(e.get("behavior")) == 3:
			continue
		var key := String(e.call("variant_key")) if e.has_method("variant_key") else "soldado"
		if key == "soldado":
			regular.append(e)
		else:
			special.append(e)
	var by_distance := func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(from) < b.global_position.distance_squared_to(from)
	special.sort_custom(by_distance)
	regular.sort_custom(by_distance)
	var out: Array[Node2D] = []
	for e in special + regular:
		if out.size() >= count:
			break
		out.append(e)
	return out


static func _threat_label(e: Node) -> String:
	var key := String(e.call("variant_key")) if e.has_method("variant_key") else "soldado"
	return String(Story.THREAT_LABELS.get(key, "ARMADO"))


static func _entry_point(level: Node2D, spawn: Vector2, threats: Array[Node2D]) -> Vector2:
	var toward := Vector2.RIGHT
	if not threats.is_empty() and is_instance_valid(threats[0]):
		toward = (threats[0].global_position - spawn).normalized()
	elif "map_bounds" in level:
		var bounds: Rect2 = level.get("map_bounds")
		if bounds.has_area():
			toward = (bounds.get_center() - spawn).normalized()
	if toward == Vector2.ZERO:
		toward = Vector2.RIGHT
	var back := -toward
	var best := spawn
	for step in range(1, 7):
		var p := spawn + back * 8.0 * float(step)
		if level.has_method("is_walkable") and not level.is_walkable(p):
			break
		best = p
	return best
