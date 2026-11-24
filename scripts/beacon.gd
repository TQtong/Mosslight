extends Area2D
## The final destination is a lantern tower rather than another exit arch.
signal reached
var active: bool=false
var light_progress: float=0.0
var clock: float=0.0
var reduced_motion: bool=false

func _ready() -> void:
	collision_layer=0
	collision_mask=2
	var collider:=CollisionShape2D.new()
	var shape:=RectangleShape2D.new()
	shape.size=Vector2(96,130)
	collider.shape=shape
	collider.position.y=-60
	add_child(collider)
	body_entered.connect(func(body: Node2D) -> void:
		if body.get("controls_enabled") and not body.get("dead") and not active:
			active=true
			# The tower keeps lighting after the completed world stops its physics.
			process_mode=Node.PROCESS_MODE_ALWAYS
			reached.emit()
	)

func _process(delta: float) -> void:
	if not reduced_motion: clock+=delta
	if active: light_progress=1.0 if reduced_motion else move_toward(light_progress,1.0,delta/2.2)
	queue_redraw()

func _draw() -> void:
	var light:=smoothstep(0,1,light_progress)
	if light>0:
		var glow:=Vector2(0,-190)
		draw_colored_polygon(PackedVector2Array([glow+Vector2(-19,0),glow+Vector2(-340,-100),glow+Vector2(-340,100)]),Color(1,.87,.55,light*.12))
		draw_colored_polygon(PackedVector2Array([glow+Vector2(19,0),glow+Vector2(340,-100),glow+Vector2(340,100)]),Color(1,.87,.55,light*.12))
		for radius in [100,72,48]: draw_circle(glow,radius,Color(1,.85,.48,light*.065))
	draw_rect(Rect2(-64,-9,128,9),Color("677c82"))
	draw_colored_polygon(PackedVector2Array([Vector2(-42,-9),Vector2(42,-9),Vector2(29,-160),Vector2(-29,-160)]),Color("889c9e"))
	draw_colored_polygon(PackedVector2Array([Vector2(9,-10),Vector2(42,-9),Vector2(29,-160),Vector2(9,-160)]),Color("647d84"))
	for y in [-43,-81,-121,-153]:
		var half: float=30+(-160.0-y)*.075
		draw_line(Vector2(-half,y),Vector2(half,y),Color("b2c4ba"),3,true)
	draw_rect(Rect2(-15,-56,30,47),Color("344d59"))
	draw_arc(Vector2(0,-55),15,PI,TAU,16,Color("c0cdb2"),4,true)
	for y in [-91,-127]:
		draw_rect(Rect2(-7,y,14,20),Color("eec986") if active else Color("405d69"))
	draw_rect(Rect2(-43,-170,86,11),Color("d6b47a"))
	draw_rect(Rect2(-34,-215,68,45),Color("e6c67d").lerp(Color("fff1b5"),light))
	for x in [-33,-11,11,33]: draw_line(Vector2(x,-216),Vector2(x,-170),Color("4b6164"),4,true)
	draw_colored_polygon(PackedVector2Array([Vector2(-48,-216),Vector2(0,-243),Vector2(48,-216)]),Color("4f7076"))
	draw_line(Vector2(-48,-216),Vector2(48,-216),Color("d9bb80"),4,true)
	draw_circle(Vector2(0,-244),5,Color("edcf91"))
	if active:
		draw_circle(Vector2(0,-191),10+light*6,Color(1,.98,.78,light))
		for i in range(5):
			var at:=Vector2(sin(i*3.3)*27,-185-fposmod(clock*13+i*23,110))
			draw_circle(at,2,Color(1,.93,.66,light*.8))
