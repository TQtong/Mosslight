extends Node2D
## Screen-space scenery; camera offset gives each ridge a different parallax.

var camera_x: float = 640.0
var clock: float = 0.0
var biome: int = 0
var reduced_motion: bool = false
var dawn: float=0.0

func _process(delta: float) -> void:
	if not reduced_motion: clock += delta
	queue_redraw()

func _draw() -> void:
	if reduced_motion: camera_x=640
	for y in range(0, 720, 8):
		var upper: Color = [Color("91bdb9"),Color("b7979a"),Color("384f72")][clampi(biome,0,2)]
		var lower: Color = [Color("e5e8c7"),Color("efd8a5"),Color("a7c2d2")][clampi(biome,0,2)]
		upper=upper.lerp(Color("c39791"),dawn*.8)
		lower=lower.lerp(Color("ffe0b0"),dawn*.85)
		var color := upper.lerp(lower, float(y) / 720.0)
		draw_rect(Rect2(0, y, 1280, 8), color)
	draw_circle(Vector2(1000, 183), 106, Color(1, 0.95, 0.75, 0.1))
	draw_circle(Vector2(1000, 183), 80, Color(1, 0.95, 0.75, 0.15))
	draw_circle(Vector2(1000, 183), 57, Color("f6e6af"))
	for i in range(6):
		var x := fposmod(i * 293.0 - camera_x * 0.07 + clock * 3.0, 1650.0) - 180
		var y := 125.0 + fposmod(i * 81.0, 180)
		_cloud(Vector2(x, y), 0.8 + i * 0.07)
	var back: Color = [Color("99b9af"),Color("ae9f93"),Color("7f9db8")][clampi(biome,0,2)]
	_landmarks()
	_ridge(0.10, 420, 95, back, 71)
	_ridge(0.19, 500, 125, back.darkened(.12), 42)
	_ridge(0.30, 605, 110, back.darkened(.24), 13)
	if biome==2:
		_constellations()
		for i in range(40):
			draw_circle(Vector2(fposmod(i*179.3-camera_x*.02,1280),50+fposmod(i*51.7,280)),1.5,Color(0.96,0.93,0.79,1-dawn*.85))
	# Air below the islands stays light enough to separate the rock silhouettes.
	for y in range(610, 720, 5):
		draw_rect(Rect2(0, y, 1280, 5), Color(0.83, 0.88, 0.76, (y - 610) / 290.0))
	for i in range(17):
		var x := fposmod(i * 173.0 + sin(clock * 0.5 + i) * 12 - camera_x * 0.4, 1340) - 30
		var y := 240 + fposmod(i * 73.0 - clock * (6 + i % 3), 430)
		draw_circle(Vector2(x, y), 1.5, Color(0.98, 0.93, 0.72, 0.45))

func _cloud(at: Vector2, scale_factor: float) -> void:
	draw_set_transform(at, 0, Vector2.ONE * scale_factor)
	var color: Color=[Color("d6e1cc"),Color("e2cead"),Color("b8c9d7")][clampi(biome,0,2)]
	color=color.lerp(Color("f3dcc6"),dawn*.6)
	draw_circle(Vector2(0, 0), 22, color)
	draw_circle(Vector2(31, -10), 31, color)
	draw_circle(Vector2(66, 0), 24, color)
	draw_rect(Rect2(0, -1, 68, 23), color)
	draw_set_transform(Vector2.ZERO)

func _ridge(parallax: float, baseline: float, height: float, color: Color, seed_value: int) -> void:
	var points := PackedVector2Array([Vector2(-20, 740)])
	for i in range(-1, 25):
		var x := i * 80.0
		var sample_x := x + camera_x * parallax + seed_value
		var y := baseline - (sin(sample_x * 0.006) * 0.45 + sin(sample_x * 0.013 + 1.6) * 0.25 + 0.55) * height
		points.append(Vector2(x, y))
	points.append(Vector2(1900, 740))
	draw_colored_polygon(points, color)

func _landmarks() -> void:
	# Distant silhouettes sit behind ridges, separate from solid platforms.
	for i in range(7):
		var x:=fposmod(i*307.0-camera_x*.12,2000)-240
		var at:=Vector2(x,435+sin(i*1.7)*32)
		if biome==0: _woodland(at,115+(i%3)*33,i)
		elif biome==1: _ruins(at,115+(i%3)*24,i)
		else: _observatory(at,117+(i%3)*24,i)

func _woodland(at: Vector2,height: float,seed_value: int) -> void:
	var ink:=Color("789f90")
	var leaf:=Color("8aac99")
	draw_colored_polygon(PackedVector2Array([at+Vector2(-13,15),at+Vector2(15,15),at+Vector2(5,-height),at+Vector2(-4,-height)]),ink)
	for side in [-1,1]:
		draw_line(at+Vector2(0,-height*.38),at+Vector2(side*41,-height*.75),ink,8,true)
	for crown in [Vector2(-35,-height*.79),Vector2(34,-height*.83),Vector2(0,-height)]:
		var shape:=PackedVector2Array()
		for j in range(15):
			var angle:=j*TAU/14
			var radius:=44+sin(j*2.7+seed_value)*5
			shape.append(at+crown+Vector2(cos(angle)*radius,sin(angle)*radius*.69))
		draw_colored_polygon(shape,leaf)
		leaf=leaf.darkened(.025)

func _ruins(at: Vector2,height: float,seed_value: int) -> void:
	var ink:=Color("a39087")
	var edge:=Color("c2b298")
	draw_rect(Rect2(at+Vector2(-76,0),Vector2(152,13)),ink)
	for side in [-1,1]:
		var column:=at+Vector2(side*54,-height)
		var h:=height if side<0 or seed_value%2==0 else height*.7
		var top:=at+Vector2(side*54,-h)
		draw_rect(Rect2(top-Vector2(12,0),Vector2(24,h)),ink)
		draw_rect(Rect2(top-Vector2(18,5),Vector2(36,8)),edge)
		for y in range(22,int(h)-8,27): draw_line(top+Vector2(-11,y),top+Vector2(11,y),edge,2,true)
		if side<0: draw_line(column+Vector2(-3,18),column+Vector2(-3,height-8),edge,3,true)
	if seed_value%2==0:
		draw_arc(at+Vector2(0,-height+2),54,PI,PI*1.45,20,ink,16,true)
		draw_arc(at+Vector2(0,-height+2),54,PI*1.57,TAU,20,ink,16,true)
		draw_circle(at+Vector2(0,-height-15),12,Color("cfbb98"))
	else:
		draw_colored_polygon(PackedVector2Array([at+Vector2(-40,-height-32),at+Vector2(28,-height-32),at+Vector2(12,-height-18),at+Vector2(-35,-height-18)]),edge)

func _observatory(at: Vector2,height: float,seed_value: int) -> void:
	var ink:=Color("6d87a5").lerp(Color("a5959b"),dawn*.5)
	var rim:=Color("9cb6c5").lerp(Color("c7b4a4"),dawn*.5)
	var center:=at+Vector2(0,-height)
	draw_colored_polygon(PackedVector2Array([at+Vector2(-18,15),at+Vector2(18,15),center+Vector2(9,22),center+Vector2(-9,22)]),ink)
	draw_arc(center,52,0,TAU,48,ink,9,true)
	draw_arc(center,44,0,TAU,48,rim,2,true)
	for angle in [-.55,.7]:
		var direction:=Vector2.from_angle(angle)
		draw_line(center-direction*64,center+direction*64,ink,5,true)
	for j in range(8):
		var direction:=Vector2.from_angle(j*TAU/8+.2)
		draw_line(center+direction*47,center+direction*55,rim,2,true)
	draw_circle(center,9,rim)
	if seed_value%2==0:
		draw_line(center+Vector2(0,-72),center+Vector2(0,58),rim,2,true)
		draw_circle(center+Vector2(0,-77),5,Color("d8d7bc"))

func _constellations() -> void:
	var star:=Color(.94,.93,.8,.55*(1-dawn*.85))
	var line:=Color(.82,.87,.89,.22*(1-dawn*.85))
	for i in range(3):
		var at:=Vector2(fposmod(90+i*403-camera_x*.025,1350)-35,85+(i%2)*65)
		var points:=PackedVector2Array([at,at+Vector2(28,28),at+Vector2(71,8),at+Vector2(104,37),at+Vector2(145,-4)])
		draw_polyline(points,line,1.5,true)
		for point in points: draw_circle(point,2.5,star)
