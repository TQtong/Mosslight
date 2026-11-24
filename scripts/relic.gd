extends Area2D
signal collected(at: Vector2)
var clock: float = 0
var taken: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 17
	shape.shape = circle
	add_child(shape)
	body_entered.connect(func(body: Node2D) -> void:
		if not taken and body.get("controls_enabled") and not body.get("dead"):
			taken = true
			collected.emit(global_position)
			queue_free()
	)

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	var p := Vector2(0,sin(clock*2.8)*4)
	draw_circle(p,27,Color(0.7,1,0.85,0.12))
	draw_colored_polygon(PackedVector2Array([p+Vector2(0,-19),p+Vector2(13,-3),p+Vector2(8,14),p+Vector2(0,20),p+Vector2(-8,14),p+Vector2(-13,-3)]),Color("b7ead0"))
	draw_line(p+Vector2(0,-14),p+Vector2(0,14),Color("fff3c4"),3,true)
	draw_line(p+Vector2(-7,-3),p+Vector2(7,5),Color("608e82"),2,true)
