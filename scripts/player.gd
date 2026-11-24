extends CharacterBody2D
## Movement is independent of level rules. Position is the center of the feet.

signal died
signal jumped
signal landed
signal dashed

@export var run_speed: float = 290.0
@export var acceleration: float = 1900.0
@export var jump_speed: float = 590.0
@export var gravity: float = 1500.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

var controls_enabled: bool = false
var dead: bool = false
var coyote_left: float = 0.0
var buffered_jump: float = 0.0
var facing: float = 1.0
var animation_time: float = 0.0
var was_grounded: bool = false
var air_jump_enabled: bool = false
var dash_enabled: bool = false
var air_jump_left: bool = true
var dash_ready: bool = true
var dash_left: float = 0

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 6.0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(24, 40)
	shape.shape = rectangle
	shape.position = Vector2(0, -20)
	add_child(shape)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not controls_enabled or dead:
		return
	animation_time += delta
	var grounded := is_on_floor()
	if grounded:
		air_jump_left = true
		dash_ready = true
	if dash_enabled and dash_ready and Input.is_action_just_pressed("dash"):
		dash_ready = false
		dash_left = 0.16
		dashed.emit()
	if dash_left > 0:
		dash_left -= delta
		velocity = Vector2(facing * 700,0)
		move_and_slide()
		queue_redraw()
		return
	coyote_left = coyote_time if grounded else maxf(0.0, coyote_left - delta)
	buffered_jump = maxf(0.0, buffered_jump - delta)
	if Input.is_action_just_pressed("jump"):
		buffered_jump = jump_buffer_time
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = move_toward(velocity.x, direction * run_speed, acceleration * delta)
	if absf(direction) > 0.05:
		facing = signf(direction)
	if not grounded:
		velocity.y = minf(velocity.y + gravity * delta, 900.0)
	if buffered_jump > 0.0 and coyote_left > 0.0:
		velocity.y = -jump_speed
		buffered_jump = 0.0
		coyote_left = 0.0
		jumped.emit()
	elif air_jump_enabled and air_jump_left and not grounded and Input.is_action_just_pressed("jump"):
		velocity.y = -jump_speed
		air_jump_left = false
		buffered_jump = 0
		jumped.emit()
	# A short press gives a low hop; holding the button gives a full jump.
	if Input.is_action_just_released("jump") and velocity.y < -160.0:
		velocity.y *= 0.48
	move_and_slide()
	if is_on_floor() and not was_grounded and velocity.y >= 0.0:
		landed.emit()
	was_grounded = is_on_floor()
	if position.y > 820.0:
		die()
	queue_redraw()

func die() -> void:
	if dead or not controls_enabled:
		return
	dead = true
	controls_enabled = false
	visible = false
	died.emit()

func respawn(at: Vector2) -> void:
	position = at
	velocity = Vector2.ZERO
	coyote_left = 0.0
	buffered_jump = 0.0
	was_grounded = false
	air_jump_left = true
	dash_ready = true
	dash_left = 0
	dead = false
	visible = true
	controls_enabled = true
	queue_redraw()

func _draw() -> void:
	if dash_left > 0:
		for i in range(1,5):
			draw_circle(Vector2(-facing*i*13,-21),15-i*2,Color(0.65,0.94,0.83,0.35-i*0.06))
	var stride := sin(animation_time * 17.0) * minf(absf(velocity.x) / run_speed, 1.0)
	var bob := absf(stride) * 1.5 if is_on_floor() else -1.0
	draw_set_transform(Vector2(0, bob), 0, Vector2(facing, 1))
	draw_ellipse_shadow()
	draw_line(Vector2(-7, -7), Vector2(-8 + stride * 3, 0), Color("24494b"), 6, true)
	draw_line(Vector2(7, -7), Vector2(8 - stride * 3, 0), Color("24494b"), 6, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -32), Vector2(11, -32), Vector2(17, -6), Vector2(0, -2), Vector2(-17, -6)]), Color("448c80"))
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -29), Vector2(3, -29), Vector2(5, -5), Vector2(-13, -8)]), Color("73b6a2"))
	draw_circle(Vector2(0, -34), 16, Color("448c80"))
	draw_circle(Vector2(1, -34), 11.5, Color("f6e9c5"))
	if fposmod(animation_time,5.3)>5.12:
		draw_line(Vector2(-5,-35),Vector2(-1,-35),Color("233f45"),2,true)
		draw_line(Vector2(4,-35),Vector2(8,-35),Color("233f45"),2,true)
	else:
		draw_circle(Vector2(-3, -35), 1.8, Color("233f45"))
		draw_circle(Vector2(6, -35), 1.8, Color("233f45"))
	var flutter := sin(animation_time * 10.0) * 3.0
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -25), Vector2(-25, -23 + flutter), Vector2(-20, -17 + flutter), Vector2(8, -23)]), Color("e99a69"))
	draw_line(Vector2(-10, -24), Vector2(10, -24), Color("f2b67f"), 5, true)
	# The ember carried in the story dims after spending aerial abilities.
	var ember:=1.0
	if air_jump_enabled and not air_jump_left: ember-=.3
	if dash_enabled and not dash_ready: ember-=.3
	draw_line(Vector2(9,-21),Vector2(17,-17),Color("73b6a2"),4,true)
	draw_circle(Vector2(20,-13),15,Color(1,.87,.47,.1*ember))
	draw_arc(Vector2(20,-20),5,PI,TAU,12,Color("e5c388"),2,true)
	draw_rect(Rect2(14,-20,12,15),Color("6d6650"))
	draw_rect(Rect2(16,-18,8,10),Color("e9c67c").lerp(Color("fff2b8"),ember))
	draw_line(Vector2(20,-18),Vector2(20,-8),Color("806f4b"),1,true)
	draw_rect(Rect2(13,-21,14,3),Color("ac9263"))
	draw_set_transform(Vector2.ZERO)

func draw_ellipse_shadow() -> void:
	if is_on_floor():
		draw_set_transform(Vector2(0, 1), 0, Vector2(1, 0.2))
		draw_circle(Vector2.ZERO, 18, Color(0.08, 0.19, 0.19, 0.15))
		draw_set_transform(Vector2.ZERO, 0, Vector2(facing, 1))
