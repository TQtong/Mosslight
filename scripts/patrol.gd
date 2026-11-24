extends Area2D
## A thorn moth patrol. It can be avoided or bounced on from above.
var origin: Vector2
var distance: float = 70
var speed: float = 60
var clock: float = 0
var defeated: bool = false

func _ready() -> void:
	origin = position
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 15
	shape.shape = circle
	add_child(shape)
	body_entered.connect(func(body: Node2D) -> void:
		if defeated or not body.get("controls_enabled") or body.get("dead"):
			return
		if body.velocity.y > 60 and body.global_position.y < global_position.y - 4:
			defeated = true
			body.velocity.y = -430
			queue_free()
		else:
			body.die()
	)

func _physics_process(delta: float) -> void:
	clock += delta
	position.x = origin.x + sin(clock * speed / maxf(distance,1)) * distance
	queue_redraw()

func _draw() -> void:
	var flutter := sin(clock*12)*3
	draw_circle(Vector2(-13,-5-flutter),12,Color("ae8e9a"))
	draw_circle(Vector2(13,-5-flutter),12,Color("ae8e9a"))
	draw_circle(Vector2.ZERO,13,Color("64536a"))
	draw_line(Vector2(-6,-10),Vector2(-10,-20),Color("edc394"),2,true)
	draw_line(Vector2(6,-10),Vector2(10,-20),Color("edc394"),2,true)
	draw_circle(Vector2(-4,-2),2,Color("f8dfa3"))
	draw_circle(Vector2(4,-2),2,Color("f8dfa3"))
