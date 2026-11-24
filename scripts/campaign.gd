extends RefCounted
## Twelve authored routes. A span is [width, surface Y, gap after the island].
## The conversion helpers place decoration; the platform routes are hand-authored.
const Intro = preload("res://scripts/level_layout.gd")
const COUNT := 12

static func stage(index: int) -> Dictionary:
	index = clampi(index, 0, COUNT - 1)
	if index == 0:
		return {"id": "first_light", "name": "LEVEL_01", "chapter": 0, "width": Intro.WIDTH, "spawn": Intro.SPAWN, "finish": Intro.FINISH, "platforms": Intro.islands(), "bonus": [], "coins": Intro.coins(), "relics": [Vector2(890, 375), Vector2(2400, 265), Vector2(3850, 335)], "checkpoints": [Intro.CHECKPOINT], "spikes": Intro.SPIKES, "movers": [{"rect": Intro.MOVING_ISLAND, "travel": Intro.MOVING_TRAVEL}], "enemies": [], "springs": [], "crumble": [], "air_jump": false, "dash": false, "par": 35.0,"lessons":[_lesson(Vector2(300,560),"move",["move_left","move_right","jump"]),_lesson(Vector2(820,510),"relic",["jump"]),_lesson(Vector2(1510,515),"checkpoint",["retry"]),_lesson(Vector2(2890,460),"mover")]}
	var spans: Array = []
	match index:
		1: spans = [[650,560,85],[240,505,90],[280,450,100],[330,500,100],[240,445,100],[430,505,95],[240,450,110],[260,395,105],[400,455,90],[250,510,100],[300,450,110],[400,500,90],[250,445,100],[350,500,110],[240,445,95],[650,500,0]]
		2: spans = [[650,560,100],[230,510,100],[340,455,105],[310,510,100],[240,455,105],[430,500,95],[220,445,105],[360,500,110],[240,445,100],[320,500,105],[220,445,100],[430,505,110],[260,450,100],[650,500,0]]
		3: spans = [[650,560,100],[350,510,110],[250,450,110],[400,505,105],[270,450,110],[450,505,110],[240,445,110],[320,500,110],[270,440,110],[450,500,110],[280,440,100],[350,490,110],[250,430,100],[400,485,110],[260,430,100],[650,490,0]]
		4: spans = [[650,560,150],[300,410,170],[300,540,175],[310,385,180],[340,520,160],[440,400,170],[300,535,185],[300,380,180],[350,520,170],[350,390,180],[440,530,170],[300,375,180],[350,510,180],[650,420,0]]
		5: spans = [[650,550,160],[300,410,170],[320,530,180],[350,390,180],[320,520,170],[440,395,180],[300,540,180],[320,390,190],[350,520,175],[320,375,190],[450,520,180],[300,385,185],[350,510,170],[300,380,180],[650,460,0]]
		6: spans = [[650,550,175],[340,410,180],[300,530,190],[320,380,185],[350,520,180],[450,390,180],[300,530,185],[330,380,185],[350,510,180],[300,370,185],[450,520,190],[300,375,180],[350,510,180],[300,370,180],[650,460,0]]
		7: spans = [[650,550,180],[350,400,185],[300,535,190],[350,380,190],[330,520,185],[450,390,190],[300,530,190],[320,375,190],[350,510,185],[350,360,190],[450,520,190],[300,365,190],[350,510,190],[300,355,180],[350,490,190],[650,440,0]]
		8: spans = [[700,550,300],[340,500,320],[350,450,300],[350,500,330],[350,440,310],[500,500,320],[350,450,320],[350,500,330],[350,440,320],[400,500,330],[500,450,320],[350,500,310],[650,450,0]]
		9: spans = [[700,550,310],[350,490,330],[350,430,320],[350,490,340],[350,430,330],[500,490,330],[350,430,340],[350,490,330],[350,430,340],[400,490,330],[500,430,330],[350,490,320],[350,430,330],[650,480,0]]
		10: spans = [[700,550,320],[350,400,330],[350,530,340],[350,380,340],[350,520,330],[500,390,340],[350,530,340],[350,375,340],[350,510,340],[350,360,340],[500,520,340],[350,365,340],[350,510,330],[350,355,330],[650,460,0]]
		11: spans = [[700,550,320],[380,400,330],[380,535,340],[380,380,340],[380,520,340],[520,390,340],[380,530,340],[380,375,340],[380,510,340],[380,360,340],[520,520,340],[380,365,340],[380,510,340],[380,355,330],[400,490,330],[800,440,0]]
	return _build(index, spans)

static func _build(index: int, spans: Array) -> Dictionary:
	var chapter := index / 4
	var islands: Array[Rect2] = []
	var lights: Array[Vector2] = []
	var spikes: Array[Vector2] = []
	var enemies: Array[Dictionary] = []
	var movers: Array[Dictionary] = []
	var crumble: Array[int] = []
	var springs: Array[Vector2] = []
	var x := -100.0
	for i in range(spans.size()):
		var spec: Array = spans[i]
		var moth: bool=index>=3 and (i%5==2 or (index==3 and i==1)) and i<spans.size()-1
		var fragile: bool = index in [3,6,7,10,11] and i%5==3
		# Patrol encounters use landing/run-up space, rather than placing a moth
		# inside the only safe arrival area of a precision platform.
		var width: float=maxf(float(spec[0]),620) if moth else float(spec[0])
		if index>=4 and width>=400 and not fragile: width=maxf(width,600)
		var rect := Rect2(x, float(spec[1]), width, 170 + (i % 3) * 15)
		islands.append(rect)
		for offset in range(65, int(rect.size.x) - 30, 110):
			lights.append(rect.position + Vector2(offset, -50))
		# Spikes are on wide landing areas, clear of the incoming jump's landing.
		if rect.size.x >= 400 and i > 0 and i < spans.size() - 1 and not fragile and not moth:
			spikes.append(rect.position + Vector2(rect.size.x * .52, 0))
		# Keep the arrival side of each island clear; the first moth is introduced alone.
		if moth:
			enemies.append({"at":rect.position+Vector2(rect.size.x*.6,-14),"range":25,"speed":55+index*3})
		if fragile:
			crumble.append(i)
		if index in [5,7,10,11] and i % 6 == 4:
			springs.append(rect.position + Vector2(rect.size.x - 55, 0))
		x += rect.size.x + float(spec[2])
	# Selected route islands move gently; each has a safe neighboring landing.
	if index in [2,5,7,9,11]:
		for i in [3,8]:
			movers.append({"index": i, "travel": 25.0 if index < 4 else 35.0, "vertical": index >= 5})
	var checkpoints: Array[Vector2] = []
	for i in [5,10]:
		if i < islands.size() - 1:
			checkpoints.append(islands[i].position + Vector2(55,0))
	var relics: Array[Vector2] = []
	var bonus: Array[Rect2] = []
	for i in [2,7,islands.size() - 3]:
		var host := islands[i]
		var height := 85.0 if index < 4 else 155.0
		var perch := Rect2(host.position + Vector2(host.size.x * 0.55 - 40, -height), Vector2(105,35))
		bonus.append(perch)
		relics.append(perch.position + Vector2(52,-42))
	var last := islands[-1]
	var lessons: Array=[]
	if index==1: lessons.append(_lesson(islands[0].position+Vector2(390,0),"jump",["jump"]))
	if index in [2,5,9]: lessons.append(_lesson(islands[2].position+Vector2(islands[2].size.x-70,0),"mover"))
	if index==3: lessons.append(_lesson(islands[0].position+Vector2(islands[0].size.x-100,0),"moth"))
	if index in [3,6,10]: lessons.append(_lesson(islands[2].position+Vector2(islands[2].size.x-70,0),"crumble"))
	if index==4: lessons.append(_lesson(islands[0].position+Vector2(390,0),"double",["jump"]))
	if index in [5,7]: lessons.append(_lesson(islands[4].position+Vector2(60,0),"spring"))
	if index==8: lessons.append(_lesson(islands[0].position+Vector2(390,0),"dash",["jump","dash"]))
	if index==11: lessons.append(_lesson(last.position+Vector2(80,0),"beacon"))
	return {"id": "stage_%02d" % (index+1), "name": "LEVEL_%02d" % (index+1), "chapter": chapter, "width": int(last.end.x + 140), "spawn": Vector2(180,islands[0].position.y), "finish": last.position + Vector2(last.size.x-125,0), "platforms": islands, "bonus": bonus, "coins": lights, "relics": relics, "checkpoints": checkpoints, "spikes": spikes, "movers": movers, "enemies": enemies, "springs": springs, "crumble": crumble, "air_jump": index>=4, "dash": index>=8, "par": float(last.end.x / 175.0 + 25),"lessons":lessons}

static func _lesson(at: Vector2,kind: String,actions: Array=[]) -> Dictionary:
	return {"at":at,"kind":kind,"title":"GUIDE_"+kind.to_upper()+"_TITLE","body":"GUIDE_"+kind.to_upper()+"_BODY","actions":actions}
