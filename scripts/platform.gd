extends AnimatableBody2D
## A moss-covered island. Its origin is its upper left corner.

var size: Vector2 = Vector2(200, 160)
var base_position: Vector2 = Vector2.ZERO
var travel: float = 0.0
var clock: float = 0.0
var vertical_travel: bool = false
var one_way: bool = false
var is_crumbling: bool = false
var biome: int = 0
var collapse_left: float = -1
var restore_left: float = 0
var collider: CollisionShape2D

func configure(rect: Rect2, horizontal_travel: float = 0.0) -> void:
	position = rect.position
	base_position = position
	size = rect.size
	travel = horizontal_travel

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	collider = CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collider.shape = rectangle
	collider.position = size / 2.0
	collider.one_way_collision = one_way
	add_child(collider)
	queue_redraw()

func _physics_process(delta: float) -> void:
	clock += delta
	if travel > 0.0:
		position = base_position + (Vector2.DOWN if vertical_travel else Vector2.RIGHT) * sin(clock * 1.1) * travel
	if not is_crumbling:
		return
	if restore_left > 0:
		restore_left -= delta
		if restore_left <= 0:
			visible = true
			collider.set_deferred("disabled",false)
			collapse_left = -1
	elif collapse_left > 0:
		collapse_left -= delta
		if collapse_left <= 0:
			visible = false
			collider.set_deferred("disabled",true)
			restore_left = 3.0
	else:
		var player = get_tree().get_first_node_in_group("player")
		if player and player.is_on_floor() and absf(player.position.y-position.y)<3 and player.position.x>position.x-10 and player.position.x<position.x+size.x+10:
			collapse_left = 1.1
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var rock: Color = [Color("8c9a83"),Color("a59480"),Color("78899e")][clampi(biome,0,2)]
	var grass: Color = [Color("4e7961"),Color("887c52"),Color("5e8191")][clampi(biome,0,2)]
	draw_colored_polygon(PackedVector2Array([Vector2(0, 4), Vector2(w, 4), Vector2(w - 8, h * 0.7), Vector2(w * 0.72, h), Vector2(w * 0.31, h - 15), Vector2(12, h * 0.72)]), rock)
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.55, 9), Vector2(w - 2, 9), Vector2(w - 8, h * 0.7), Vector2(w * 0.72, h), Vector2(w * 0.64, h * 0.5)]), rock.darkened(.16))
	draw_rect(Rect2(0, 0, w, 14), grass)
	var lip: Color=[Color("b1d19a"),Color("d5ba80"),Color("bad8d7")][clampi(biome,0,2)]
	var blade_color: Color=[Color("89b78a"),Color("b5a668"),Color("99c4c3")][clampi(biome,0,2)]
	draw_rect(Rect2(0, 0, w, 5), lip)
	for i in range(8, int(w) - 5, 23):
		var drop := 7.0 + fposmod(float(i) * 1.73, 19.0)
		draw_line(Vector2(i, 7), Vector2(i + 2, drop), grass, 5, true)
	for i in range(18, int(w) - 12, 56):
		var blade := 5.0 + fposmod(float(i) * 1.17, 7.0)
		draw_line(Vector2(i, 0), Vector2(i - 4, -blade), blade_color, 2, true)
		draw_line(Vector2(i, 0), Vector2(i + 4, -blade + 2), blade_color, 2, true)
	for i in range(22, int(w) - 10, 61):
		draw_line(Vector2(i, 38), Vector2(i + 16, 44), Color("a5ae95"), 3, true)
	if h>80:
		if biome==0:
			for x in range(39,int(w)-20,117):
				draw_polyline(PackedVector2Array([Vector2(x,18),Vector2(x+8,45),Vector2(x+2,68),Vector2(x+12,86)]),Color("6f8066"),3,true)
		elif biome==1:
			for y in [59,96,133]:
				var inset:=maxf(18,w*.3*clampf((y/h-.65)/.35,0,1))
				draw_line(Vector2(inset,y),Vector2(w-inset,y),rock.darkened(.18),2,true)
				for x in range(int(inset)+16+(y%2)*35,int(w-inset)-5,88): draw_line(Vector2(x,y-33),Vector2(x,y),rock.darkened(.18),2,true)
		else:
			for x in range(43,int(w)-25,134):
				draw_arc(Vector2(x,74),12,0,TAU,16,Color("a7bfc2"),2,true)
				draw_colored_polygon(PackedVector2Array([Vector2(x,65),Vector2(x+4,74),Vector2(x,83),Vector2(x-4,74)]),Color("c3d8d1"))
	if travel > 0.0:
		draw_line(Vector2(16, 23), Vector2(w - 16, 23), Color("f7d58d"), 3, true)
	if is_crumbling:
		for x in range(20,int(w)-20,65):
			draw_polyline(PackedVector2Array([Vector2(x,8),Vector2(x+13,26),Vector2(x+7,38),Vector2(x+17,55)]),Color("4a4f50"),3,true)
		if collapse_left>0:
			draw_line(Vector2(0,3),Vector2(w*collapse_left/1.1,3),Color("edb180"),5,true)
