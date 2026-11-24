extends Control
## Diegetic UI decoration: carved wood, vines, lanterns and journey emblems.
var scene_kind: String = "title"
var muted: bool = false
var clock: float = 0.0
var progress: float = 0.0
var reduced_motion: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if not reduced_motion: clock += delta
	queue_redraw()

func _draw() -> void:
	if scene_kind == "icon_music":
		draw_line(Vector2(12, 23), Vector2(12, 5), Color("f6dfa1"), 3, true)
		draw_line(Vector2(28, 20), Vector2(28, 2), Color("f6dfa1"), 3, true)
		draw_line(Vector2(12, 5), Vector2(28, 2), Color("f6dfa1"), 5, true)
		draw_circle(Vector2(7, 25), 5, Color("f6dfa1"))
		draw_circle(Vector2(23, 22), 5, Color("f6dfa1"))
		if muted:
			draw_line(Vector2(2, 30), Vector2(32, 1), Color("e8ac7b"), 3, true)
		return
	if scene_kind == "icon_pause":
		draw_rect(Rect2(5, 4, 7, 23), Color("f6dfa1"))
		draw_rect(Rect2(21, 4, 7, 23), Color("f6dfa1"))
		return
	if scene_kind == "icon_sound":
		draw_colored_polygon(PackedVector2Array([Vector2(3, 11), Vector2(10, 11), Vector2(18, 4), Vector2(18, 28), Vector2(10, 21), Vector2(3, 21)]), Color("f6dfa1"))
		if muted:
			draw_line(Vector2(22, 10), Vector2(32, 22), Color("e8ac7b"), 3, true)
			draw_line(Vector2(22, 22), Vector2(32, 10), Color("e8ac7b"), 3, true)
		else:
			draw_arc(Vector2(17, 16), 10, -0.9, 0.9, 12, Color("f6dfa1"), 2, true)
			draw_arc(Vector2(17, 16), 16, -0.9, 0.9, 16, Color("f6dfa1"), 2, true)
		return
	if scene_kind == "hud":
		_coin(Vector2(51, 51), 15)
		_clock(Vector2(583, 49))
		_flag(Vector2(41, 111))
		# A little trail to an arch replaces the full-width web progress bar.
		draw_line(Vector2(1040, 681), Vector2(1224, 681), Color(0.15, 0.26, 0.22, 0.5), 3)
		for i in range(7):
			draw_circle(Vector2(1040 + i * 30.7, 681), 3, Color("e6d7ac"))
		_coin(Vector2(1040 + clampf(progress, 0, 1) * 184, 681), 7)
		draw_arc(Vector2(1234, 675), 8, PI, TAU, 14, Color("e9d8ab"), 3, true)
		draw_line(Vector2(1226, 675), Vector2(1226, 685), Color("e9d8ab"), 3)
		draw_line(Vector2(1242, 675), Vector2(1242, 685), Color("e9d8ab"), 3)
		return
	if scene_kind=="rekindling":
		draw_rect(Rect2(0,0,1280,78),Color(.04,.1,.12,.7))
		draw_rect(Rect2(0,570,1280,150),Color(.04,.1,.12,.75))
		return
	_vignette()
	if scene_kind == "title":
		_hanging_sign(Rect2(278, 137, 724, 119))
		_vine(Vector2(302, 127), 1)
		_vine(Vector2(978, 127), -1)
		_lantern(Vector2(1090, 166), 1.2)
		_lantern(Vector2(152, 229), 0.8)
	elif scene_kind == "paused":
		_hanging_sign(Rect2(410, 115, 460, 93))
		_lantern(Vector2(302, 305), 1.2)
		_lantern(Vector2(978, 305), 1.2)
	elif scene_kind == "language":
		_hanging_sign(Rect2(362, 78, 556, 94))
		_vine(Vector2(368, 75), 1)
		_vine(Vector2(912, 75), -1)
	elif scene_kind=="chapter":
		_hanging_sign(Rect2(145,78,990,94))
		_vine(Vector2(155,75),1)
		_vine(Vector2(1125,75),-1)
		_lantern(Vector2(170,350),1.3)
		_lantern(Vector2(1110,350),1.3)
	elif scene_kind == "complete":
		_wreath(Vector2(640, 106))
		for x in [454, 640, 826]:
			draw_circle(Vector2(x + 3, 340), 68, Color(0.08, 0.18, 0.16, 0.4))
			draw_circle(Vector2(x, 334), 66, Color("3d4d37"))
			draw_arc(Vector2(x, 334), 62, 0, TAU, 60, Color("b99b61"), 4, true)
			for i in range(8):
				draw_circle(Vector2(x, 334) + Vector2.from_angle(i * TAU / 8) * 56, 2, Color("e8cd8e"))
		_coin(Vector2(454, 296), 12)
		_clock(Vector2(640, 296))
		_flag(Vector2(826, 300))

func _vignette() -> void:
	for i in range(18):
		var alpha := (1.0 - i / 18.0) * 0.025
		draw_rect(Rect2(i * 9, 0, 9, 720), Color(0.04, 0.13, 0.13, alpha))
		draw_rect(Rect2(1271 - i * 9, 0, 9, 720), Color(0.04, 0.13, 0.13, alpha))
		draw_rect(Rect2(0, i * 4, 1280, 4), Color(0.04, 0.13, 0.13, alpha))
	if scene_kind != "title":
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.07, 0.17, 0.15, 0.48))

func _hanging_sign(rect: Rect2) -> void:
	var left := rect.position.x
	var right := rect.end.x
	var top := rect.position.y
	var bottom := rect.end.y
	for x in [left + 80, right - 80]:
		draw_line(Vector2(x + 2, 0), Vector2(x + 2, top + 14), Color("354d3e"), 7)
		draw_line(Vector2(x, 0), Vector2(x, top + 14), Color("ad9b67"), 4)
	var polygon := PackedVector2Array([Vector2(left + 18, top), Vector2(right - 18, top), Vector2(right, top + 18), Vector2(right - 4, bottom - 15), Vector2(right - 23, bottom), Vector2(left + 15, bottom - 3), Vector2(left, bottom - 21), Vector2(left + 2, top + 18)])
	var shadow := polygon.duplicate()
	for i in range(shadow.size()):
		shadow[i] += Vector2(4, 7)
	draw_colored_polygon(shadow, Color(0.08, 0.15, 0.13, 0.55))
	draw_colored_polygon(polygon, Color("544b33"))
	draw_polyline(polygon + PackedVector2Array([polygon[0]]), Color("c3a66c"), 3, true)
	for y in range(int(top + 20), int(bottom - 10), 23):
		draw_line(Vector2(left + 15, y), Vector2(right - 17, y + 2), Color(0.75, 0.62, 0.38, 0.15), 2, true)
	for x in [left + 20, right - 20]:
		draw_circle(Vector2(x, top + 21), 4, Color("d0b77d"))
		draw_circle(Vector2(x, bottom - 20), 4, Color("d0b77d"))

func _vine(at: Vector2, direction: float) -> void:
	var points := PackedVector2Array()
	for i in range(16):
		points.append(at + Vector2(direction * sin(i * 0.32) * 20, i * 12))
	draw_polyline(points, Color("365c42"), 4, true)
	for i in range(2, 15, 2):
		var p := points[i]
		var side := 1 if i % 4 == 0 else -1
		draw_colored_polygon(PackedVector2Array([p, p + Vector2(side * 20, -8), p + Vector2(side * 24, 5), p + Vector2(side * 8, 11)]), Color("80a76a"))
		draw_line(p, p + Vector2(side * 19, 3), Color("b3c58a"), 1, true)

func _lantern(at: Vector2, scale_factor: float) -> void:
	draw_set_transform(at, 0, Vector2.ONE * scale_factor)
	draw_line(Vector2(0, -130), Vector2(0, -26), Color("53694c"), 3)
	var glow := 0.11 + sin(clock * 2.3) * 0.025
	draw_circle(Vector2.ZERO, 40, Color(1, 0.85, 0.44, glow))
	draw_circle(Vector2.ZERO, 27, Color(1, 0.85, 0.44, glow))
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -19), Vector2(14, -19), Vector2(11, 19), Vector2(-11, 19)]), Color("f3d38b"))
	draw_rect(Rect2(-17, -23, 34, 7), Color("536449"))
	draw_rect(Rect2(-13, 17, 26, 6), Color("536449"))
	for x in [-10, 10]:
		draw_line(Vector2(x, -19), Vector2(x * 0.8, 18), Color("806a43"), 3)
	draw_circle(Vector2(0, 3 + sin(clock * 4)), 5, Color("fff1b8"))
	draw_set_transform(Vector2.ZERO)

func _coin(at: Vector2, radius: float) -> void:
	draw_circle(at + Vector2(1, 2), radius, Color("71542f"))
	draw_circle(at, radius, Color("edc978"))
	draw_arc(at, radius * 0.76, 0, TAU, 24, Color("fff1b4"), 2, true)
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -radius * 0.55), at + Vector2(radius * 0.3, 0), at + Vector2(0, radius * 0.55), at - Vector2(radius * 0.3, 0)]), Color("a17b40"))

func _clock(at: Vector2) -> void:
	draw_circle(at, 13, Color("d4ba7c"))
	draw_circle(at, 10, Color("344c3b"))
	draw_line(at, at + Vector2(0, -6), Color("f6e3af"), 2, true)
	draw_line(at, at + Vector2(5, 3), Color("f6e3af"), 2, true)
	draw_rect(Rect2(at + Vector2(-4, -17), Vector2(8, 4)), Color("d4ba7c"))

func _flag(at: Vector2) -> void:
	draw_line(at + Vector2(-6, 6), at + Vector2(-6, -15), Color("dac48d"), 3)
	draw_colored_polygon(PackedVector2Array([at + Vector2(-4, -15), at + Vector2(12, -11), at + Vector2(-4, -5)]), Color("e0aa75"))

func _wreath(at: Vector2) -> void:
	for side in [-1, 1]:
		for i in range(6):
			var p := at + Vector2(side * (20 + sin(i * 0.4) * 32), 32 - i * 12)
			draw_colored_polygon(PackedVector2Array([p, p + Vector2(side * 10, -11), p + Vector2(side * 24, -12), p + Vector2(side * 17, 1)]), Color("d3b676"))
	_coin(at, 23)
